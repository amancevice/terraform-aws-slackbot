from unittest.mock import MagicMock

from src.states import States


class TestStates:
    def setup(self):
        self.boto3_session = MagicMock()
        self.subject = States(boto3_session=self.boto3_session)

    def test_fail(self):
        self.subject.fail('<token>', 'error', '{}')
        self.subject.client.send_task_failure.assert_called_once_with(
            taskToken='<token>',
            error='error',
            cause='{}',
        )

    def test_heartbeat(self):
        self.subject.heartbeat('<token>')
        self.subject.client.send_task_heartbeat.assert_called_once_with(
            taskToken='<token>',
        )

    def test_succeed(self):
        self.subject.succeed('<token>', {'fizz': 'buzz'})
        self.subject.client.send_task_success.assert_called_once_with(
            taskToken='<token>',
            output={'fizz': 'buzz'},
        )
