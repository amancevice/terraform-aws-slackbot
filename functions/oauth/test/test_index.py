import json
from io import BytesIO
from unittest import mock

with mock.patch("urllib.request.urlopen"):
    with mock.patch("urllib.request.Request"):
        import index


class TestHandler:
    def setup_method(self):
        self.response = {"ok": True}
        index.urlopen.return_value = BytesIO(json.dumps(self.response).encode())

    def test_handler(self):
        event = {"code": "JAZZ"}
        returned = index.handler(event)
        index.Request.assert_called_once_with(
            "https://slack.com/api/oauth.v2.access",
            "client_id=FIZZ&client_secret=BUZZ&code=JAZZ".encode(),
            {"content-type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        index.urlopen.assert_called_once_with(index.Request.return_value)
        assert returned == self.response
