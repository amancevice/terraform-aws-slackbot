import boto3

from logger import logger


class States:
    def __init__(self, boto3_session=None):
        self.boto3_session = boto3_session or boto3.Session()
        self.client = self.boto3_session.client('stepfunctions')

    def fail(self, task_token, error, cause):
        params = dict(taskToken=task_token, error=error, cause=cause)
        logger.info('SEND TASK FAILURE %s', logger.json(params))
        return self.client.send_task_failure(**params)

    def heartbeat(self, task_token):
        params = dict(taskToken=task_token)
        logger.info('SEND TASK HEARTBEAT %s', logger.json(params))
        return self.client.send_task_heartbeat(**params)

    def succeed(self, task_token, output):
        params = dict(taskToken=task_token, output=output)
        logger.info('SEND TASK SUCCESS %s', logger.json(params))
        return self.client.send_task_success(**params)
