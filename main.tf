locals {
  function_name    = "${coalesce(var.lambda_function_name, "slack-${var.api_name}-api")}"
  kms_key_alias    = "${coalesce(var.kms_key_alias, "alias/slack/${var.api_name}")}"
  role_name        = "${coalesce(var.role_name, "slack-${var.api_name}")}"
  secret_name      = "${coalesce(var.secret_name, "slack/${var.api_name}")}"

  topic_arn_prefix = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  topic_prefix     = "slack_${var.api_name}_"
  publisher_prefix = "${local.topic_arn_prefix}:${local.topic_prefix}"

  secrets {
    BOT_ACCESS_TOKEN  = "${var.slack_bot_access_token}"
    CLIENT_ID         = "${var.slack_client_id}"
    CLIENT_SECRET     = "${var.slack_client_secret}"
    SIGNING_SECRET    = "${var.slack_signing_secret}"
    SIGNING_VERSION   = "${var.slack_signing_version}"
    USER_ACCESS_TOKEN = "${var.slack_user_access_token}"
  }

  function_names = [
    "${aws_lambda_function.api.function_name}",
    "${aws_lambda_function.post_message.function_name}",
    "${aws_lambda_function.post_ephemeral.function_name}",
  ]
}

data aws_caller_identity current {
}

data aws_region current {
}

data aws_iam_policy_document assume_role {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data aws_iam_policy_document api {
  statement {
    sid       = "DecryptKmsKey"
    actions   = ["kms:Decrypt"]
    resources = ["${aws_kms_key.key.arn}"]
  }

  statement {
    sid       = "GetSecretValue"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["${aws_secretsmanager_secret.slack_secret.arn}"]
  }

  statement {
    sid       = "PublishEvents"
    actions   = ["sns:Publish"]
    resources = ["${local.publisher_prefix}*"]
  }

  statement {
    sid       = "WriteLambdaLogs"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

resource aws_api_gateway_deployment api {
  depends_on  = [
    "aws_api_gateway_integration.proxy_any",
    "aws_api_gateway_method.any",
    "aws_api_gateway_resource.proxy",
  ]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  stage_name  = "${var.api_stage_name}"
}

resource aws_api_gateway_integration proxy_any {
  content_handling        = "CONVERT_TO_TEXT"
  http_method             = "${aws_api_gateway_method.any.http_method}"
  integration_http_method = "POST"
  resource_id             = "${aws_api_gateway_resource.proxy.id}"
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  timeout_milliseconds    = 3000
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.api.invoke_arn}"
}

resource aws_api_gateway_method any {
  authorization = "NONE"
  http_method   = "ANY"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
}

resource aws_api_gateway_resource proxy {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "{proxy+}"
}

resource aws_api_gateway_rest_api api {
  description            = "${var.api_description}"
  name                   = "${var.api_name}"
  endpoint_configuration = ["${var.api_endpoint_configuration}"]
}

resource aws_cloudwatch_log_group logs {
  count             = "${length(local.function_names)}"
  name              = "/aws/lambda/${element(local.function_names, count.index)}"
  retention_in_days = "${var.cloudwatch_log_group_retention_in_days}"
}

resource aws_iam_role role {
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
  description        = "Slackbot resource access"
  name               = "${local.role_name}"
  path               = "${var.role_path}"
}

resource aws_iam_role_policy api {
  name        = "api"
  role        = "${aws_iam_role.role.id}"
  policy      = "${data.aws_iam_policy_document.api.json}"
}

resource aws_iam_role_policy_attachment additional_policies {
  count      = "${length(var.role_policy_attachments)}"
  role       = "${aws_iam_role.role.name}"
  policy_arn = "${element(var.role_policy_attachments, count.index)}"
}

resource aws_kms_key key {
  deletion_window_in_days = "${var.kms_key_deletion_window_in_days}"
  description             = "${var.kms_key_name}"
  enable_key_rotation     = "${var.kms_key_enable_key_rotation}"
  is_enabled              = "${var.kms_key_is_enabled}"
  key_usage               = "${var.kms_key_usage}"
  policy                  = "${var.kms_key_policy}"
  tags                    = "${var.kms_key_tags}"
}

resource aws_kms_alias key_alias {
  name          = "${local.kms_key_alias}"
  target_key_id = "${aws_kms_key.key.key_id}"
}

resource aws_lambda_function api {
  description      = "Slack request handler"
  filename         = "${path.module}/package.zip"
  function_name    = "${local.function_name}"
  handler          = "index.handler"
  kms_key_arn      = "${aws_kms_key.key.arn}"
  memory_size      = "${var.lambda_memory_size}"
  role             = "${aws_iam_role.role.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("${path.module}/package.zip"))}"
  tags             = "${var.lambda_tags}"
  timeout          = "${var.lambda_timeout}"

  environment {
    variables {
      OAUTH_REDIRECT    = "${var.oauth_redirect}"
      PUBLISHER_PREFIX  = "${local.publisher_prefix}"
      SLACKEND_BASE_URL = "${var.base_url}"
      SLACK_SECRET      = "${aws_secretsmanager_secret.slack_secret.name}"
      VERIFY_REQUESTS   = "${var.verify_requests}"
    }
  }
}

resource aws_lambda_function post_message {
  description      = "Post Slack message via SNS"
  filename         = "${path.module}/package.zip"
  function_name    = "${local.function_name}-post-message"
  handler          = "index.postMessage"
  kms_key_arn      = "${aws_kms_key.key.arn}"
  role             = "${aws_iam_role.role.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("${path.module}/package.zip"))}"
  tags             = "${var.lambda_tags}"
  timeout          = 15

  environment {
    variables {
      SLACK_SECRET = "${aws_secretsmanager_secret.slack_secret.name}"
    }
  }
}

resource aws_lambda_function post_ephemeral {
  description      = "Post Slack ephemeral message via SNS"
  filename         = "${path.module}/package.zip"
  function_name    = "${local.function_name}-post-ephemeral"
  handler          = "index.postEphemeral"
  kms_key_arn      = "${aws_kms_key.key.arn}"
  role             = "${aws_iam_role.role.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${base64sha256(file("${path.module}/package.zip"))}"
  tags             = "${var.lambda_tags}"
  timeout          = 15

  environment {
    variables {
      SLACK_SECRET = "${aws_secretsmanager_secret.slack_secret.name}"
    }
  }
}

resource aws_lambda_permission invoke_api {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.api.arn}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

resource aws_lambda_permission invoke_post_message {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.post_message.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.post_message.arn}"
}

resource aws_lambda_permission invoke_post_ephemeral {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.post_ephemeral.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.post_ephemeral.arn}"
}

resource aws_secretsmanager_secret slack_secret {
  description             = "Slackbot access tokens."
  kms_key_id              = "${aws_kms_key.key.key_id}"
  name                    = "${local.secret_name}"
  recovery_window_in_days = "${var.secret_recovery_window_in_days}"
  rotation_lambda_arn     = "${var.secret_rotation_lambda_arn}"
  rotation_rules          = "${var.secret_rotation_rules}"
  tags                    = "${var.secret_tags}"
}

resource aws_secretsmanager_secret_version slack_secret_version {
  secret_id     = "${aws_secretsmanager_secret.slack_secret.id}"
  secret_string = "${jsonencode(local.secrets)}"
}

resource aws_sns_topic post_message {
  name = "slack_${var.api_name}_post_message"
}

resource aws_sns_topic post_ephemeral {
  name = "slack_${var.api_name}_post_ephemeral"
}

resource aws_sns_topic_subscription post_message_subscription {
  endpoint  = "${aws_lambda_function.post_message.arn}"
  protocol  = "lambda"
  topic_arn = "${aws_sns_topic.post_message.arn}"
}

resource aws_sns_topic_subscription post_ephemeral_subscription {
  endpoint  = "${aws_lambda_function.post_ephemeral.arn}"
  protocol  = "lambda"
  topic_arn = "${aws_sns_topic.post_ephemeral.arn}"
}
