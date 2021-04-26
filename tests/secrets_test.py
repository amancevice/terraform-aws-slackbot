import json
import os
from unittest.mock import MagicMock

from src.secrets import (export, fetch)

os.environ['SECRET_ID'] = 'SECRET'


class TestSecrets:
    def setup(self):
        self.boto3_session = MagicMock()
        self.boto3_session\
            .client.return_value\
            .get_secret_value.return_value = {
                'SecretString': json.dumps({'FIZZ': 'BUZZ'})
            }

    def test_export(self):
        export(SecretId='mock', boto3_session=self.boto3_session)
        assert os.getenv('FIZZ') == 'BUZZ'

    def test_fetch(self):
        ret = fetch(SecretId='mock', boto3_session=self.boto3_session)
        assert ret == {'FIZZ': 'BUZZ'}
