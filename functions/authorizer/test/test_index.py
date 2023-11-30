from unittest import mock

import pytest

import index


class TestHandler:
    @mock.patch("index.now")
    def test_bad_signature(self, mock_time):
        mock_time.return_value = 1234567890.9
        event = {"body": "fizz=buzz", "signature": "BAD", "ts": "1234567890"}
        with pytest.raises(index.Forbidden):
            index.handler(event)

    @mock.patch("index.now")
    @mock.patch("index.sign")
    def test_future_ts(self, mock_sign, mock_time):
        mock_time.return_value = 1234567890.9
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "1234567899"}
        with pytest.raises(index.Forbidden):
            index.handler(event)

    @mock.patch("index.now")
    @mock.patch("index.sign")
    def test_stale_ts(self, mock_sign, mock_time):
        mock_time.return_value = 1234567890.9
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "1134567890"}
        with pytest.raises(index.Forbidden):
            index.handler(event)

    @mock.patch("index.sign")
    def test_invalid_ts(self, mock_sign):
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "BAD"}
        with pytest.raises(index.Forbidden):
            index.handler(event)

    @mock.patch("index.now")
    @mock.patch("index.sign")
    def test_valid(self, mock_sign, mock_time):
        mock_time.return_value = 1234567890.9
        mock_sign.return_value = "GOOD"
        event = {"body": "fizz=buzz", "signature": "GOOD", "ts": "1234567890"}
        assert index.handler(event) is True
