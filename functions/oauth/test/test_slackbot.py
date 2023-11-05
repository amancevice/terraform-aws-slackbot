from unittest import mock

from app.slackbot import Slackbot


class TestSlackbot:
    def setup_method(self):
        with mock.patch("boto3.client"):
            self.subject = Slackbot()
        self.subject.oauth.client_secret = "CLIENT_SECRET"
        self.subject.signer.secret = "SECRET!"

    def test_generate_state(self):
        returned = self.subject.oauth.generate_state("1234567890")
        expected = "1234567890.e1e92108ff40f32f1962dd0fd27cfc1f86b9ecc6992b9468c2dfc0e84812c07b"
        assert returned == expected

    def test_verify_state(self):
        state = "1234567890.e1e92108ff40f32f1962dd0fd27cfc1f86b9ecc6992b9468c2dfc0e84812c07b"
        returned = self.subject.oauth.verify_state(state)
        expected = True
        assert returned == expected

    def test_verify_state_fail(self):
        state = "1234567890.BAD"
        returned = self.subject.oauth.verify_state(state)
        expected = False
        assert returned == expected
