import os

from logger import logger
from secret import getSecret
from signer import authorize


secret = getSecret(os.environ["SIGNING_SECRET_PARAMETER"])


@logger.bind
def handler(event, *_):
    return authorize(secret, **event)
