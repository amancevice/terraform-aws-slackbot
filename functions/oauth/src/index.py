import os

from logger import logger
from secret import getSecret
from oauth import authorize


client_id = getSecret(os.environ["CLIENT_ID_PARAMETER"])
client_secret = getSecret(os.environ["CLIENT_SECRET_PARAMETER"])


@logger.bind
def handler(event, *_):
    return authorize(client_id, client_secret, **event)
