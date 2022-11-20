"""
CloudFront Events
"""
import base64
import json
from urllib.parse import parse_qsl


class ProxyEvent:
    """
    Handler for a CloudFront request event
    """

    def __init__(self, event):
        self.event = event

    def __getitem__(self, key):
        return self.event[key]

    def get_body(self):
        """
        Get Base64-decoded body from request
        """
        data = self.event["body"]
        if self.event["isBase64Encoded"]:
            return base64.b64decode(data).decode()
        return data

    def get_header(self, header, default=None):
        """
        Get header from request
        """
        headers = self.event.get("headers") or {}
        header = headers.get(header) or default
        return header

    def get_query(self):
        """
        Get query from request
        """
        query = self.event.get("queryStringParameters") or {}
        return query


class SlackEvent(ProxyEvent):
    def get_source(self):
        """
        Get EventBridge DetailType source
        """
        detail = self.get_detail()
        return detail.get("type")

    def get_detail_type(self):
        """
        Get EventBridge DetailType field
        """
        raise NotImplementedError

    def get_detail(self):
        """
        Get EventBridge Detail field
        """
        body = self.get_body()
        detail = json.loads(body) if body else None
        return detail

    def get_entries(self, event_bus_name):
        """
        Get EventBridge entry
        """
        source = self.get_source()
        detail_type = self.get_detail_type()
        detail = self.get_detail()
        entry = {
            "EventBusName": event_bus_name,
            "Source": source,
            "DetailType": detail_type,
            "Detail": json.dumps(detail),
        }
        yield entry


class Callback(SlackEvent):
    def get_detail(self):
        body = self.get_body()
        detail = json.loads(dict(parse_qsl(body))["payload"])
        return detail

    def get_entries(self, event_bus_name):
        source = self.get_source()
        detail = self.get_detail()
        entry = {
            "EventBusName": event_bus_name,
            "Source": source,
            "Detail": json.dumps(detail),
        }
        if source == "block_actions":
            actions = detail.get("actions") or []
            for action in actions:
                entry["DetailType"] = action.get("action_id")
                yield entry
        elif source == "block_suggestion":
            entry["DetailType"] = detail.get("action_id")
            yield entry
        elif source == "view_closed":
            view = detail.get("view")
            entry["DetailType"] = view.get("callback_id")
            yield entry
        elif source == "view_submission":
            view = detail.get("view")
            entry["DetailType"] = view.get("callback_id")
            yield entry
        else:
            # interactive_message/message_action/shortcut
            entry["DetailType"] = detail.get("callback_id")
            yield entry


class EventCallback(SlackEvent):
    def get_source(self):
        return "event_callback"

    def get_detail_type(self):
        detail = self.get_detail()
        event = detail.get("event") or {}
        detail_type = event.get("type")
        return detail_type


class BlockSuggestion(Callback):
    def get_detail_type(self):
        detail = self.get_detail()
        detail_type = detail.get("action_id")
        return detail_type


class OAuth(SlackEvent):
    ...


class Slash(SlackEvent):
    def get_source(self):
        return "slash_command"

    def get_detail_type(self):
        detail = self.get_detail()
        detail_type = detail.get("command")
        return detail_type

    def get_detail(self):
        body = self.get_body()
        detail = dict(parse_qsl(body))
        return detail
