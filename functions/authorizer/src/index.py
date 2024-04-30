import hmac
import os
from datetime import datetime, UTC
from hashlib import sha256

from logger import logger

secret = os.environ["SIGNING_SECRET"]


@logger.bind
def handler(event, *_):
    # Extract signing details
    body = event["body"]
    signature = event["signature"]
    ts = event["ts"]

    # Raise if message is older than 5min or in the future
    try:
        delta = int(now()) - int(ts)
    except ValueError:
        raise Forbidden("Request timestamp invalid")
    if delta > 5 * 60:
        raise Forbidden("Request timestamp is too old")
    elif delta < 0:
        raise Forbidden("Request timestamp is in the future")

    # Raise if signatures do not match
    expected = sign(secret, body, ts)
    logger.debug("GIVEN SIGNATURE    %s", signature)
    logger.debug("EXPECTED SIGNATURE %s", expected)
    if signature != expected:
        raise Forbidden("Invalid signature")

    return True


def now():
    return datetime.now(UTC).timestamp()


def sign(secret, body, ts=None):
    ts = ts or str(int(now()))
    data = f"v0:{ts}:{body}"
    logger.debug("STRING TO SIGN %s", data)
    hex = hmac.new(secret.encode(), data.encode(), sha256).hexdigest()
    signature = f"v0={hex}"
    return signature


class Forbidden(Exception): ...
