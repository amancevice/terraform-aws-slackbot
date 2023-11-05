import base64
import json
import os
from time import time
from unittest import mock
from urllib.parse import urlencode

import pytest

from index import handler


class TestHandler:
    def setup_method(self):
        self.data = {"fizz": "buzz"}
        self.callback = urlencode({"payload": json.dumps(self.data)})
        self.menu = urlencode({"payload": json.dumps(self.data)})
        self.event = json.dumps(self.data)
        self.slash = urlencode(self.data)

    def test_callback(self):
        event = {"body": self.callback, "path": "/callbacks"}
        assert handler(event) == self.data

    def test_event(self):
        event = {"body": self.event, "path": "/events"}
        assert handler(event) == self.data

    def test_menu(self):
        event = {"body": self.menu, "path": "/menus"}
        assert handler(event) == self.data

    def test_slash(self):
        event = {"body": self.slash, "path": "/slash"}
        assert handler(event) == {"type": "slash_command", **self.data}
