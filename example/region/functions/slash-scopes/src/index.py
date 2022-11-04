import base64
import json
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from logger import logger


@logger.bind
def handler(event, _):
    if event.get("isBase64Encoded"):
        body = json.loads(base64.b64decode(body).decode())
    else:
        body = json.loads(event["body"])
    url = body["response_url"]
    headers = {"content-type": "application/json; charset=utf-8"}
    text = "Choose a Slack OAuth scope to learn more"
    blocks = [
        {
            "type": "section",
            "text": {"type": "plain_text", "text": text},
        },
        {
            "block_id": "slack_oauth_scopes",
            "type": "actions",
            "elements": [
                {
                    "type": "external_select",
                    "action_id": "slack_oauth_scopes",
                    "placeholder": {"type": "plain_text", "text": "Select scope"},
                }
            ],
        },
    ]
    message = {"text": text, "blocks": blocks}
    data = json.dumps(message).encode()
    try:
        req = Request(url, data, headers, method="POST")
        with urlopen(req):
            return {"statusCode": 200}
    except HTTPError:
        return {"statusCode": 403}
