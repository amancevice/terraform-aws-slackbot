import base64
import json
import re
from urllib.request import urlopen

from logger import logger


@logger.bind
def handler(event, _):
    # Parse body
    if event["isBase64Encoded"]:
        body = json.loads(base64.b64decode(event["body"]))
    else:
        body = json.loads(event["body"])
    body_type = body.get("type")
    action_id = body.get("action_id")
    seachterm = body.get("value")

    # Get menu options
    options = []
    if body_type == "block_suggestion" and action_id == "slack_oauth_scopes":
        options = slack_oauth_scopes(seachterm)

    # Send response
    response = {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps({"options": options}),
    }
    return response


def slack_oauth_scopes(term):
    url = "https://api.slack.com/scopes"
    with urlopen(url) as res:
        html = res.read().decode()
    scopes = re.findall(r"&quot;name&quot;:&quot;(.*?)&quot;", html)
    options = [
        {"value": x, "text": {"type": "plain_text", "text": x}}
        for x in scopes
        if x.startswith(term)
    ]
    return options
