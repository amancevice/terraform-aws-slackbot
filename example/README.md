# Example Slackbot Configuration

This project illustrates how to use the `amancevice/slackbot/aws` Terraform module to create a Slackbot backend.

> NOTE — To reduce latency this project is nested as a region-specific module that can be replicated to multiple AWS regions. View the [`region`](./region) module for the application Terraform.

## Prerequisites

This project depends on the following preexisting resources:

- Route53 hosted zone (eg, `mydomain.com`)
- ACM Certificate capable of supporing your custom subdomain (eg, `slack.mydomain.com`)

## Application Features

### HTTP API Routes

```plaintext
https://slack.example.com
├── /health
│   └── ANY
├── /install
│   └── ANY
├── /oauth           ╮
│   └── GET          │
├── /callbacks       │
│   └── POST         │
├── /events          │
│   └── POST         ├─ Publish events to EventBridge
├── /menus           │
│   └── POST         │
├── /slash           │
│   └── /{cmd}       │
│       └── POST     ╯
└── /-
    ├── callbacks    ╮
    │   └── POST     │
    ├── menus        │
    │   └── POST     ├─ Respond Synchronously
    └── slash        │
        └── scopes   │
            └── POST ╯
```

### Asynchronous Handlers

#### App Home Opened

`app_home_opened` events are received by AWS Step Functions, which assembles the home view, encodes the [`views.publish`](https://api.slack.com/methods/views.publish) payload, and sends the request to the Slack API.

```plaintext
  ╭─────────╮
  │ GetView │
  ╰────┬────╯
╭──────┴──────╮
│  EncodeView │
╰──────┬──────╯
╭──────┴──────╮
│ PublishView │
╰─────────────╯
```

#### Open Modal

When the button on the home page with the action ID `open_modal` is pressed, an event is sent to AWS Step Functions, which assembles the modal view, encodes the [`views.open`](https://api.slack.com/methods/views.open) payload, and sends the request to the Slack API.


```plaintext
  ╭─────────╮
  │ GetView │
  ╰────┬────╯
╭──────┴──────╮
│  EncodeView │
╰──────┬──────╯
 ╭─────┴─────╮
 │  OpenView │
 ╰───────────╯
```

### Synchronous Handlers

#### Slash Command

The `/scopes` command is handled by sending a POST payload to the `response_url` provided in the original request.

POST body:

```json
{
  "text": "Choose a Slack OAuth scope to learn more",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "plain_text",
        "text": "Choose a Slack OAuth scope to learn more"
      }
    },
    {
      "block_id": "slack_oauth_scopes",
      "type": "actions",
      "elements": [
        {
          "type": "external_select",
          "action_id": "slack_oauth_scopes",
          "placeholder": {
            "type": "plain_text",
            "text": "Select scope"
          }
        }
      ]
    }
  ]
}
```

#### External Menu

When a user begins typing in the interactive component supplied above, a request is sent to the `/menus` endpoint, which is in turn forwarded to the `/-/menus` endpoint and it responds with a JSON payload for the options to display:

```json
{
  "options": [
    {
      "value": "<scope>",
      "text": {
        "type": "plain_text",
        "text": "<scope>"
      }
    },
    …
  ]
}
```

#### Callbacks

After the scope is selected, Slack sends a payload to the asynchronous `/callbacks` endpoint, which in turn calls the synchronous `/-/callbacks` endpoint, which responds with an updated payload with a button to view details of the Slack OAuth scope:

```json
{
  "text": "Choose a Slack OAuth scope to learn more",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "plain_text",
        "text": "Choose a Slack OAuth scope to learn more"
      }
    },
    {
      "block_id": "slack_oauth_scopes",
      "type": "actions",
      "elements": [
        {
          "type": "external_select",
          "action_id": "slack_oauth_scopes",
          "placeholder": {
            "type": "plain_text",
            "text": "Select scope"
          },
          "initial_option": {
            "value": "<scope>",
            "text": {
              "type": "plain_text",
              "text": "<scope>"
            }
          }
        },
        {
          "type": "button",
          "action_id": "open_slack_oauth_scope",
          "text": {"type": "plain_text", "text": "Open"},
          "url": "https://api.slack.com/scopes/<scope>",
        },
      ]
    }
  ]
}
```
