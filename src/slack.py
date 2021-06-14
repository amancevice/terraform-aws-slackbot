import hashlib
import hmac
import json
import random
import string
from datetime import datetime
from urllib.parse import (urlencode, urlsplit, urlunsplit)
from urllib.request import (Request, urlopen)

from errors import (Forbidden, NotFound)
from logger import logger


class Slack:
    def __init__(self, **params):
        self.client_id = params.get('client_id')
        self.client_secret = params.get('client_secret')
        self.oauth_error_uri = params.get('oauth_error_uri')
        self.oauth_install_uri = params.get('oauth_install_uri')
        self.oauth_redirect_uri = params.get('oauth_redirect_uri')
        self.oauth_success_uri = params.get('oauth_success_uri') \
            or 'slack://app?team={TEAM_ID}&id={APP_ID}'
        self.routes = params.get('routes') or {}
        self.signing_secret = params.get('signing_secret')
        self.signing_version = params.get('signing_version') or 'v0'
        self.state = self.randstate()
        self.token = params.get('token')
        self.verify = params.get('verify')

    def handle(self, event):
        # Extract route method
        route = self.routes.get(event.route_key)

        # Raise 404 NOT FOUND if bad route
        if route is None:
            raise NotFound(f"No route defined for '{ event.route_key }'")

        # Execute request
        return route(event)

    def install(self, event, method='oauth.v2.access'):
        # Handle denials
        if event.query.get('error'):
            logger.error(event.query['error'])
            if self.oauth_error_uri:
                return None, self.oauth_error_uri
            raise Forbidden('OAuth error')

        # Check state
        if self.state != event.query['state']:
            logger.error('States do not match')
            if self.oauth_error_uri:
                return None, self.oauth_error_uri
            raise Forbidden('States do not match')

        # Set up OAuth
        payload = urlencode(dict(
            code=event.query.get('code'),
            client_id=self.client_id,
            client_secret=self.client_secret,
            redirect_uri=self.oauth_redirect_uri,
        ))

        # Execute OAuth and redirect
        url = f'https://slack.com/api/{ method }'
        headers = {'content-type': 'application/x-www-form-urlencoded'}
        result = self.post(url, payload, headers)
        app_id = result.get('app_id')
        team_id = result.get('team', {}).get('id')
        channel_id = result.get('incoming_webhook', {}).get('channel_id')
        location = self.oauth_success_uri.format(
            APP_ID=app_id or '',
            TEAM_ID=team_id or '',
            CHANNEL_ID=channel_id or '',
        )

        return result, location

    @property
    def install_url(self):
        *url, query, fragment = urlsplit(self.oauth_install_uri)
        if query:
            query += '&'
        query += urlencode({
            'state': self.state or '',
            'redirect_uri': self.oauth_redirect_uri or '',
        })
        return urlunsplit(url + [query, fragment])

    def post(self, url, body=None, headers=None, **_):
        # Prepare request
        data = body.encode('utf-8')
        headers = {k.lower(): v for k, v in (headers or {}).items()}

        # Execute request
        logger.info('POST %s %s', url, body)
        req = Request(url=url, data=data, headers=headers, method='POST')
        res = urlopen(req)

        # Parse response
        resdata = res.read().decode()
        try:
            resjson = json.loads(resdata)
        except Exception:  # pragma: no cover
            resjson = {'ok': False}

        # Log response & return
        log = logger.info if resjson['ok'] else logger.error
        log('RESPONSE [%d] %s', res.status, resdata)
        return resjson

    def randstate(self):
        chars = string.ascii_letters + '1234567890'
        state = str.join('', (random.choice(chars) for _ in range(8)))
        return state

    @staticmethod
    def respond(status_code, body=None, **headers):
        body = json.dumps(body) if body else None
        if int(status_code) < 400:
            logger.info('RESPONSE [%d] %s', status_code, str(body or 'null'))
        else:
            logger.error('RESPONSE [%d] %s', status_code, str(body or 'null'))
        headers = {
            'content-length': str(len(body or '')),
            'content-type': 'application/json; charset=utf-8',
            **{k.lower(): v for k, v in headers.items() if v}
        }
        return dict(statusCode=status_code, headers=headers, body=body)

    def route(self, key):
        def inner(handler):
            def wrapper(event):
                return handler(event)
            # Set handler for route
            self.routes[key] = wrapper

            return wrapper
        return inner

    def verify_slack_signature(self, event):
        if not self.verify:  # pragma: no cover
            logger.warning('VERIFICATION DISABLED')
            return True

        # 403 FORBIDDEN if message is older than 5min
        now = datetime.utcnow().timestamp()
        ts = event.headers.get('x-slack-request-timestamp')
        delta = int(now) - int(ts or '0')
        if delta > 5 * 60:
            raise Forbidden('Request too old')

        # 403 FORBIDDEN if signatures do not match
        data = f'{ self.signing_version }:{ ts }:{ event.body }'.encode()
        secret = self.signing_secret.encode()
        hex = hmac.new(secret, data, hashlib.sha256).hexdigest()
        ret = f'{ self.signing_version }={ hex }'
        exp = event.headers.get('x-slack-signature')
        if ret != exp:
            raise Forbidden('Signatures do not match')

        return True
