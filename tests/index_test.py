import json
from unittest import mock

with mock.patch('boto3.Session'):
    with mock.patch('secrets.fetch'):
        from src import index


class TestIndex:
    def setup(self):
        index.slack.oauth_install_uri = 'https://example.com/install'
        index.slack.oauth_redirect_uri = 'https://example.com/success'
        index.slack.state = 'state'
        index.slack.verify = False

        index.events.publish = mock.MagicMock()
        index.slack.install = mock.MagicMock()
        index.slack.install.return_value = (
            {'ok': True},
            'https://example.com/success',
        )

    def test_get_health(self):
        ret = index.proxy({'routeKey': 'GET /health'})
        exp = {
            'statusCode': 200,
            'body': json.dumps({'ok': True}),
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': str(len(json.dumps({'ok': True}))),
            }
        }
        assert ret == exp

    def test_get_install(self):
        ret = index.proxy({'routeKey': 'GET /install'})
        exp = {
            'statusCode': 302,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
                'location': 'https://example.com/install?state=state',
            }
        }
        assert ret == exp

    def test_get_oauth(self):
        ret = index.proxy({
            'routeKey': 'GET /oauth',
            'queryStringParameters': {'code': 'CODE'},
            'headers': {'x-amzn-trace-id': '<trace-id>'}
        })
        exp = {
            'statusCode': 302,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
                'location': index.slack.oauth_redirect_uri
            }
        }
        index.events.publish.assert_called_once_with(
            'oauth',
            {'ok': True},
            '<trace-id>',
        )
        assert ret == exp

    def test_get_oauth_v2(self):
        ret = index.proxy({
            'routeKey': 'GET /oauth/v2',
            'queryStringParameters': {'code': 'CODE'},
            'headers': {'x-amzn-trace-id': '<trace-id>'}
        })
        exp = {
            'statusCode': 302,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
                'location': index.slack.oauth_redirect_uri
            }
        }
        index.events.publish.assert_called_once_with(
            'oauth',
            {'ok': True},
            '<trace-id>',
        )
        assert ret == exp

    def test_head_health(self):
        ret = index.proxy({'routeKey': 'HEAD /health'})
        exp = {
            'statusCode': 200,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
            }
        }
        assert ret == exp

    def test_head_install(self):
        ret = index.proxy({'routeKey': 'HEAD /install'})
        exp = {
            'statusCode': 302,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
                'location': 'https://example.com/install?state=state',
            }
        }
        assert ret == exp

    def test_post_callbacks(self):
        ret = index.proxy({
            'routeKey': 'POST /callbacks',
            'body': 'payload={"actions": [{"action_id": "buzz"}]}',
            'headers': {'x-amzn-trace-id': '<trace-id>'}
        })
        exp = {
            'statusCode': 204,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
            }
        }
        index.events.publish.assert_called_once_with(
            'callback',
            {'actions': [{'action_id': 'buzz'}], 'action_ids': ['buzz']},
            '<trace-id>',
        )
        assert ret == exp

    def test_post_events(self):
        ret = index.proxy({
            'routeKey': 'POST /events',
            'body': '{"fizz": "buzz"}',
            'headers': {'x-amzn-trace-id': '<trace-id>'}
        })
        exp = {
            'statusCode': 204,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
            }
        }
        index.events.publish.assert_called_once_with(
            'event',
            {'fizz': 'buzz'},
            '<trace-id>',
        )
        assert ret == exp

    def test_post_events_verification(self):
        ret = index.proxy({
            'routeKey': 'POST /events',
            'body': '{"type": "url_verification", "challenge": "CHALLENGE"}',
            'headers': {'x-amzn-trace-id': '<trace-id>'}
        })
        exp = {
            'statusCode': 200,
            'body': '{"challenge": "CHALLENGE"}',
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '26',
            }
        }
        index.events.publish.assert_not_called()
        assert ret == exp

    def test_post_slash_cmd(self):
        ret = index.proxy({
            'routeKey': 'POST /slash/{cmd}',
            'body': 'fizz=buzz',
            'headers': {'x-amzn-trace-id': '<trace-id>'}
        })
        exp = {
            'statusCode': 204,
            'body': None,
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '0',
            }
        }
        index.events.publish.assert_called_once_with(
            'slash',
            {'fizz': 'buzz'},
            '<trace-id>',
        )
        assert ret == exp

    def test_403(self):
        index.slack.verify = True
        event = {'routeKey': 'POST /slash/{cmd}'}
        exp = {
            'statusCode': 403,
            'body': '{"message": "Request too old"}',
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '30',
            }
        }
        assert index.proxy(event) == exp
        index.slack.verify = False

    def test_404(self):
        event = {'routeKey': 'GET /'}
        exp = {
            'statusCode': 404,
            'body': '{"message": "No route defined for \'GET /\'"}',
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '43',
            }
        }
        assert index.proxy(event) == exp

    def test_500(self):
        index.slack.handle = mock.MagicMock()
        index.slack.handle.side_effect = Exception('<msg>')
        event = {'routeKey': 'POST /slash/{cmd}'}
        exp = {
            'statusCode': 500,
            'body': '{"message": "<msg>"}',
            'headers': {
                'content-type': 'application/json; charset=utf-8',
                'content-length': '20',
            }
        }
        assert index.proxy(event) == exp

    def test_post(self):
        event = {
            'detail': {'text': 'FIZZ'},
            'detail-type': 'api/chat.postMessage',
        }
        index.slack.post = mock.MagicMock()
        index.post(event)
        index.slack.post.assert_called_once_with(
            {'text': 'FIZZ'},
            'api/chat.postMessage',
        )
