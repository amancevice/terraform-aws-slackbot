import json
import os
from urllib.parse import parse_qsl

from errors import (Forbidden, NotFound)
from events import (Events, HttpEvent, EventBridgeEvent)
from logger import logger
from secrets import export
from slack import Slack
from states import States

export(SecretId=os.getenv('SECRET_ID'))
EVENTS_BUS_NAME = os.getenv('EVENTS_BUS_NAME')
EVENTS_SOURCE = os.getenv('EVENTS_SOURCE')
SLACK_CLIENT_ID = os.getenv('SLACK_CLIENT_ID')
SLACK_CLIENT_SECRET = os.getenv('SLACK_CLIENT_SECRET')
SLACK_DISABLE_VERIFICATION = os.getenv('SLACK_DISABLE_VERIFICATION')
SLACK_OAUTH_ERROR_URI = os.getenv('SLACK_OAUTH_ERROR_URI')
SLACK_OAUTH_INSTALL_URI = os.getenv('SLACK_OAUTH_INSTALL_URI')
SLACK_OAUTH_REDIRECT_URI = os.getenv('SLACK_OAUTH_REDIRECT_URI')
SLACK_OAUTH_SUCCESS_URI = os.getenv('SLACK_OAUTH_SUCCESS_URI')
SLACK_SIGNING_SECRET = os.getenv('SLACK_SIGNING_SECRET')
SLACK_SIGNING_VERSION = os.getenv('SLACK_SIGNING_VERSION')
SLACK_TOKEN = os.getenv('SLACK_TOKEN')

events = Events(bus=EVENTS_BUS_NAME, source=EVENTS_SOURCE)
slack = Slack(
    client_id=SLACK_CLIENT_ID,
    client_secret=SLACK_CLIENT_SECRET,
    oauth_error_uri=SLACK_OAUTH_ERROR_URI,
    oauth_install_uri=SLACK_OAUTH_INSTALL_URI,
    oauth_redirect_uri=SLACK_OAUTH_REDIRECT_URI,
    oauth_success_uri=SLACK_OAUTH_SUCCESS_URI,
    signing_secret=SLACK_SIGNING_SECRET,
    signing_version=SLACK_SIGNING_VERSION,
    token=SLACK_TOKEN,
    verify=not SLACK_DISABLE_VERIFICATION,
)
states = States()


@slack.route('GET /health')
def get_health(event):
    return slack.respond(200, {'ok': True})


@slack.route('GET /install')
def get_install(event):
    return slack.respond(302, None, location=slack.install_url)


@slack.route('GET /oauth')
def get_oauth(event):
    detail, location = slack.install(event, 'api/oauth.access')
    events.publish('oauth', detail, event.headers.get('x-amzn-trace-id'))
    return slack.respond(302, None, location=location)


@slack.route('GET /oauth/v2')
def get_oauth_v2(event):
    detail, location = slack.install(event, 'api/oauth.v2.access')
    if detail:
        events.publish('oauth', detail, event.headers.get('x-amzn-trace-id'))
    return slack.respond(302, None, location=location)


@slack.route('HEAD /health')
def head_health(event):
    return slack.respond(200)


@slack.route('HEAD /install')
def head_install(event):
    return slack.respond(302, None, location=slack.install_url)


@slack.route('POST /callbacks')
def post_callbacks(event):
    # Verify Slack signature
    slack.verify_slack_signature(event)

    # Extract message
    detail = json.loads(dict(parse_qsl(event.body))['payload'])

    # Inject action IDs for block actions (makes pattern matching easier)
    if any(detail.get('actions') or []):
        action_ids = [x['action_id'] for x in detail['actions']]
        detail.update(action_ids=action_ids)

    # Publish event
    events.publish('callback', detail, event.headers.get('x-amzn-trace-id'))

    # Respond 204 NO CONTENT
    return slack.respond(204)


@slack.route('POST /events')
def post_events(event):
    # Extract message
    detail = json.loads(event.body)

    # First-time URL verification for events
    if detail.get('type') == 'url_verification':
        # Respond 200 OK for URL verification
        return slack.respond(200, {'challenge': detail.get('challenge')})

    # Verify Slack signature
    slack.verify_slack_signature(event)

    # Publish event
    events.publish('event', detail, event.headers.get('x-amzn-trace-id'))

    # Respond 204 NO CONTENT for normal events
    return slack.respond(204)


@slack.route('POST /slash/{cmd}')
def post_slash_cmd(event):
    # Verify Slack signature
    slack.verify_slack_signature(event)

    # Extract message
    detail = dict(parse_qsl(event.body))

    # Publish event
    events.publish('slash', detail, event.headers.get('x-amzn-trace-id'))

    # Respond 204 NO CONTENT
    return slack.respond(204)


@logger.bind
def post(event, context=None):
    event = EventBridgeEvent(event)
    result = slack.post(**event.detail)
    if result['ok']:
        events.publish('result', result)
    if result['ok'] and event.task_token:
        states.succeed(event.task_token, json.dumps(result))
    elif event.task_token:
        states.fail(event.task_token, result['error'], json.dumps(result))
    return result


@logger.bind
def proxy(event, context=None):
    try:
        return slack.handle(HttpEvent(event))
    except Forbidden as err:
        return slack.respond(403, {'message': str(err)})
    except NotFound as err:
        return slack.respond(404, {'message': str(err)})
    except Exception as err:
        return slack.respond(500, {'message': str(err)})
