import base64
import json
import os
from time import time
from unittest import mock
from urllib.parse import urlencode

import pytest

with mock.patch("boto3.client") as mock_client:
    mock_client.return_value.get_secret_value.return_value = {"SecretString": "{}"}
    from app import slackbot
    from app.logger import logger
    from index import handler, bot


def get_event(route_key, querystring=None, body=None, ts=None):
    if body:
        ts = ts or str(int(time()))
        data = base64.b64encode(body.encode()).decode()
        signature = bot.signer.sign(body, ts)
        headers = {"x-slack-request-timestamp": ts, "x-slack-signature": signature}
    else:
        data = ""
        headers = {}
    method, path = route_key.split(" ")
    event = {
        "routeKey": route_key,
        "rawPath": path,
        "rawQueryString": querystring,
        "headers": headers,
        "body": data,
        "isBase64Encoded": True,
        "requestContext": {
            "domainName": "slack.example.com",
            "http": {"method": method},
        },
    }
    return event


def read_event(name):
    dirname = os.path.dirname(__file__)
    filename = os.path.join(dirname, f"events/{name}.json")
    with open(filename) as stream:
        return json.load(stream)


class TestHandler:
    def setup_method(self):
        logger.logger.disabled = True

        slackbot.urlopen = mock.MagicMock()
        bot.oauth.generate_state = mock.MagicMock()
        bot.oauth.verify_state = mock.MagicMock()
        bot.event_bus.client = mock.MagicMock()

        bot.oauth.generate_state.return_value = "TS.STATE"
        bot.oauth.verify_state.return_value = True

        bot.oauth.client_id = "CLIENT_ID"
        bot.oauth.client_secret = "CLIENT_SECRET"
        bot.oauth.scope = "A B C"
        bot.oauth.user_scope = "D E F"
        bot.signer.secret = "SECRET!"

    def test_error(self):
        returned = handler({})
        expected = {
            "statusCode": "500",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_bad_route(self):
        event = get_event("GET /fizz")
        returned = handler(event)
        expected = {
            "statusCode": "403",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_bad_signature(self):
        event = get_event("POST /callbacks", None, "{}")
        event["headers"]["x-slack-signature"] = "BAD"
        returned = handler(event)
        expected = {
            "statusCode": "403",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_future_ts(self):
        event = get_event("POST /callbacks", None, "{}")
        event["headers"]["x-slack-request-timestamp"] = str(int(time() + 600))
        returned = handler(event)
        expected = {
            "statusCode": "403",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_old_ts(self):
        event = get_event("POST /callbacks", None, "{}")
        event["headers"]["x-slack-request-timestamp"] = str(int(time() - 3600))
        returned = handler(event)
        expected = {
            "statusCode": "403",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_invalid_ts(self):
        event = get_event("POST /callbacks", None, "{}")
        event["headers"]["x-slack-request-timestamp"] = "BAD"
        returned = handler(event)
        expected = {
            "statusCode": "403",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_bad_headers(self):
        event = get_event("POST /callbacks", None, "{}")
        del event["headers"]["x-slack-request-timestamp"]
        del event["headers"]["x-slack-signature"]
        returned = handler(event)
        expected = {
            "statusCode": "403",
            "body": json.dumps({"ok": False}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_any_health(self):
        event = get_event("ANY /health")
        returned = handler(event)
        expected = {
            "statusCode": "200",
            "body": json.dumps({"ok": True}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected

    def test_any_install(self):
        event = get_event("ANY /install")
        returned = handler(event)
        assert returned["statusCode"] == "302"
        assert returned["headers"]["location"] == (
            "https://slack.com/oauth/v2/authorize?"
            "client_id=CLIENT_ID&"
            "scope=A+B+C&"
            "user_scope=D+E+F&state=TS.STATE"
        )

    def test_any_oauth(self):
        slackbot.urlopen.return_value.read.return_value.decode.return_value = (
            json.dumps(
                {
                    "ok": True,
                    "app_id": "APP_ID",
                    "team": {"id": "TEAM_ID"},
                    "incoming_webhook": {"channel_id": "CHANNEL_ID"},
                }
            )
        )
        event = get_event("ANY /oauth", "code=CODE&state=STATE")
        returned = handler(event)
        assert returned["statusCode"] == "302"
        assert returned["headers"]["location"] == "slack://open?team=TEAM_ID"

    def test_post_callbacks_block_actions(self):
        data = read_event("block_actions")
        body = urlencode({"payload": json.dumps(data)})
        event = get_event("POST /callbacks", None, body)
        handler(event)
        bot.event_bus.client.put_events.assert_called_once_with(
            Entries=[
                {
                    "EventBusName": "slackbot",
                    "Source": "block_actions",
                    "DetailType": "action_id",
                    "Detail": json.dumps(data),
                }
            ]
        )

    @pytest.mark.parametrize("name", ["view_closed", "view_submission"])
    def test_post_callbacks_view(self, name):
        data = read_event(name)
        body = urlencode({"payload": json.dumps(data)})
        event = get_event("POST /callbacks", None, body)
        handler(event)
        bot.event_bus.client.put_events.assert_called_once_with(
            Entries=[
                {
                    "EventBusName": "slackbot",
                    "Source": name,
                    "DetailType": "my_callback",
                    "Detail": json.dumps(data),
                }
            ]
        )

    def test_post_events_verification(self):
        data = read_event("url_verification")
        body = json.dumps(data)
        event = get_event("POST /events", None, body)
        returned = handler(event)
        expected = {
            "statusCode": "200",
            "body": json.dumps({"challenge": "<challenge>"}),
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected
        bot.event_bus.client.put_events.assert_not_called()

    def test_post_events(self):
        data = read_event("event_callback")
        body = json.dumps(data)
        event = get_event("POST /events", None, body)
        returned = handler(event)
        expected = {
            "statusCode": "200",
            "body": "",
            "headers": {"content-type": "application/json; charset=utf-8"},
        }
        assert returned == expected
        bot.event_bus.client.put_events.assert_called_once_with(
            Entries=[
                {
                    "EventBusName": "slackbot",
                    "Source": "event_callback",
                    "DetailType": "app_home_opened",
                    "Detail": json.dumps(data),
                }
            ]
        )

    def test_post_menus(self):
        data = read_event("block_suggestion")
        body = urlencode({"payload": json.dumps(data)})
        event = get_event("POST /menus", None, body)
        handler(event)
        bot.event_bus.client.put_events.assert_called_once_with(
            Entries=[
                {
                    "EventBusName": "slackbot",
                    "Source": "block_suggestion",
                    "DetailType": "action_id",
                    "Detail": json.dumps(data),
                }
            ]
        )

    def test_post_slash(self):
        data = read_event("slash_command")
        body = urlencode(data)
        event = get_event("POST /slash/{cmd}", None, body)
        handler(event)
        bot.event_bus.client.put_events.assert_called_once_with(
            Entries=[
                {
                    "EventBusName": "slackbot",
                    "Source": "slash_command",
                    "DetailType": "/my-command",
                    "Detail": json.dumps(data),
                }
            ]
        )
