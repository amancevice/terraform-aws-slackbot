import base64
import json
import os
from datetime import datetime, UTC
from unittest import mock
from urllib.parse import urlencode

import pytest

with mock.patch("boto3.client") as mock_client:
    mock_client.return_value.get_parameter.return_value = {
        "Parameter": {"Value": "FIZZ"}
    }
    from index import handler
    from signer import Forbidden


class TestHandler:
    @mock.patch("signer.now")
    def test_bad_signature(self, mock_time):
        mock_time.return_value = 1234567890.9
        event = {"body": "fizz=buzz", "signature": "BAD", "ts": "1234567890"}
        with pytest.raises(Forbidden):
            handler(event)

    @mock.patch("signer.now")
    @mock.patch("signer.sign")
    def test_future_ts(self, mock_sign, mock_time):
        mock_time.return_value = 1234567890.9
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "1234567899"}
        with pytest.raises(Forbidden):
            handler(event)

    @mock.patch("signer.now")
    @mock.patch("signer.sign")
    def test_stale_ts(self, mock_sign, mock_time):
        mock_time.return_value = 1234567890.9
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "1134567890"}
        with pytest.raises(Forbidden):
            handler(event)

    @mock.patch("signer.sign")
    def test_invalid_ts(self, mock_sign):
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "BAD"}
        with pytest.raises(Forbidden):
            handler(event)

    @mock.patch("signer.now")
    @mock.patch("signer.sign")
    def test_valid(self, mock_sign, mock_time):
        mock_time.return_value = 1234567890.9
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "1234567890"}
        assert handler(event) is True
