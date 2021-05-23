import json
import hmac
import hashlib
from datetime import datetime
from unittest import mock

import pytest

with mock.patch('urllib.request.urlopen') as mock_open:
    mock_open.headers = {'content-type': 'application/json'}
    mock_open.return_value\
        .read.return_value\
        .decode.return_value = json.dumps({'ok': True})
    from src.slack import Slack
    from src.events import HttpEvent


class TestSlack:
    def setup(self):
        self.subject = Slack(signing_secret='SECRET')
        self.subject.verify = True
        self.subject.routes = {
            'GET /resource': lambda x: x
        }

    def test_handle(self):
        event = HttpEvent({'routeKey': 'GET /resource'})
        assert self.subject.handle(event) == event

    def test_handle_not_found(self):
        event = HttpEvent({'routeKey': 'POST /resource'})
        with pytest.raises(Exception):
            self.subject.handle(event)

    @mock.patch('src.slack.Slack.post')
    def test_install(self, mock_post):
        res = {
            'app_id': 'A0123456789',
            'team': {'id': 'T0123456789'},
        }
        loc = 'slack://app?team=T0123456789&id=A0123456789'
        mock_post.return_value = res
        event = {
            'queryStringParameters': {
                'state': self.subject.state,
                'code': '<code>',
            }
        }
        ret = self.subject.install(HttpEvent(event), '<oauth-method>')
        exp = (res, loc)
        assert ret == exp

    @pytest.mark.parametrize(('event', 'redir'), [
        (
            {'queryStringParameters': {'state': 'FIZZ', 'error': 'BUZZ'}},
            None,
        ),
        (
            {'queryStringParameters': {'state': 'FIZZ'}},
            None,
        ),
        (
            {'queryStringParameters': {'state': 'FIZZ', 'error': 'BUZZ'}},
            'https://redirect.com/',
        ),
        (
            {'queryStringParameters': {'state': 'FIZZ'}},
            'https://redirect.com/',
        ),
    ])
    def test_install_err(self, event, redir):
        if redir:
            self.subject.oauth_error_uri = redir
            ret = self.subject.install(HttpEvent(event), '<oauth-method>')
            exp = (None, redir)
            assert ret == exp
        else:
            with pytest.raises(Exception):
                self.subject.install(HttpEvent(event), '<oauth-method>')

    @pytest.mark.parametrize(('state', 'oauth_install_uri', 'exp'), [
        (
            'state-1',
            'https://example.com/install',
            'https://example.com/install?state=state-1&redirect_uri='
        ),
        (
            'state-2',
            'https://example.com/install?fizz=buzz',
            'https://example.com/install?fizz=buzz&state=state-2&redirect_uri='
        ),
    ])
    def test_install_url(self, state, oauth_install_uri, exp):
        self.subject.state = state
        self.subject.oauth_install_uri = oauth_install_uri
        assert self.subject.install_url == exp

    def test_post(self):
        ret = self.subject.post(
            'api/chat.postMessage',
            json.dumps({'text': 'FIZZ'}),
            {'content-type': 'application/json; charset=utf-8'},
        )
        exp = {'ok': True}
        assert ret == exp

    def test_randstate(self):
        assert self.subject.randstate() != self.subject.randstate()

    @pytest.mark.parametrize(('code', 'body', 'headers', 'exp'), [
        (
            204,
            None,
            {},
            {
                'statusCode': 204,
                'body': None,
                'headers': {
                    'content-type': 'application/json; charset=utf-8',
                    'content-length': '0',
                }
            },
        ),
        (
            302,
            None,
            {
                'location': 'https://redirect.com/',
            },
            {
                'statusCode': 302,
                'body': None,
                'headers': {
                    'content-type': 'application/json; charset=utf-8',
                    'content-length': '0',
                    'location': 'https://redirect.com/'
                }
            },
        )
    ])
    def test_respond(self, code, body, headers, exp):
        assert self.subject.respond(code, body, **headers) == exp

    def test_route(self):
        ret = self.subject.route('GET /resource')(lambda x: x)({})
        exp = {}
        assert ret == exp

    def test_verify_slack_signature(self):
        ts = str(int(datetime.utcnow().timestamp()))
        data = f'{ self.subject.signing_version }:{ ts }:BODY'.encode()
        secret = self.subject.signing_secret.encode()
        hex = hmac.new(secret, data, hashlib.sha256).hexdigest()
        sig = f'{ self.subject.signing_version }={ hex }'
        event = HttpEvent({
            'body': 'BODY',
            'headers': {
                'x-slack-request-timestamp': ts,
                'x-slack-signature': sig
            }
        })
        assert self.subject.verify_slack_signature(event)

    @pytest.mark.parametrize(('body', 'delta'), [
        ('BODY', 3600),
        ('YDOB', 0),
    ])
    def test_verify_slack_signature_fail(self, body, delta):
        ts = str(int(datetime.utcnow().timestamp() - delta))
        data = f'{ self.subject.signing_version }:{ ts }:BODY'.encode()
        secret = self.subject.signing_secret.encode()
        hex = hmac.new(secret, data, hashlib.sha256).hexdigest()
        sig = f'{ self.subject.signing_version }={ hex }'
        event = HttpEvent({
            'body': body,
            'headers': {
                'x-slack-request-timestamp': ts,
                'x-slack-signature': sig
            }
        })
        with pytest.raises(Exception):
            self.subject.verify_slack_signature(event)
