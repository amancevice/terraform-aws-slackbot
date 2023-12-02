import json
from urllib.parse import urlencode

import pytest

import index


class TestHandler:
    def setup_method(self):
        self.data = {"fizz": "buzz"}
        self.callback = urlencode({"payload": json.dumps(self.data)})
        self.menu = urlencode({"payload": json.dumps(self.data)})
        self.event = json.dumps(self.data)
        self.slash = urlencode(self.data)

    def test_callback(self):
        event = {"body": self.callback, "routeKey": "POST /callback"}
        assert index.handler(event) == self.data

    def test_event(self):
        event = {"body": self.event, "routeKey": "POST /event"}
        assert index.handler(event) == self.data

    def test_menu(self):
        event = {"body": self.menu, "routeKey": "POST /menu"}
        assert index.handler(event) == self.data

    def test_slash(self):
        event = {"body": self.slash, "routeKey": "POST /slash"}
        assert index.handler(event) == {"type": "slash_command", **self.data}
