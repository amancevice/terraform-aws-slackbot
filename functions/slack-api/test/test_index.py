import json
from unittest import mock

import pytest

with mock.patch("boto3.client") as mock_client:
    mock_client.return_value.get_secret_value.return_value = {"SecretString": "{}"}
    import index

HEADERS = {
    "authorization": "Bearer xoxb-test",
    "content-type": "application/json; charset=utf-8",
}
EVENTS = [
    {
        "method": "POST",
        "url": "https://slack.com/api/chat.postMessage",
        "data": json.dumps({"text": "Hello, world"}),
    }
]


class TestHandler:
    def setup_method(self):
        index.send_request = mock.MagicMock()

    @pytest.mark.parametrize("event", EVENTS)
    def test_handler(self, event):
        index.handler(event)
        index.send_request.assert_called_once_with(
            event["method"],
            event["url"],
            event["data"],
            HEADERS,
        )
