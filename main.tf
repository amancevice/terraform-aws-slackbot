locals {
  function_name    = "${coalesce(var.lambda_function_name, "slack-${var.api_name}-api")}"
  role_name        = "${coalesce(var.role_name, "slack-${var.api_name}")}"
  runtime          = "nodejs8.10"
  topic_arn_prefix = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}"
  topic_prefix     = "${coalesce(var.sns_topic_prefix, "slack_${var.api_name}_")}"
  publisher_prefix = "${local.topic_arn_prefix}:${local.topic_prefix}"
  function_names   = [
    "${aws_lambda_function.api.function_name}",
    "${aws_lambda_function.post_message.function_name}",
    "${aws_lambda_function.post_ephemeral.function_name}",
  ]
}

data archive_file lambda {
  source_file = "${path.module}/index.js"
  output_path = "${path.module}/package.lambda.zip"
  type        = "zip"
}

data aws_caller_identity current {
}

data aws_region current {
}

data aws_iam_policy_document assume_role {
  statement = {
    actions = ["sts:AssumeRole"]

    principals = {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data aws_iam_policy_document api {
  statement = {
    sid       = "DecryptKmsKey"
    actions   = ["kms:Decrypt"]
    resources = ["${data.aws_kms_key.key.arn}"]
  }

  statement = {
    sid       = "GetSecretValue"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["${data.aws_secretsmanager_secret.secret.arn}"]
  }

  statement = {
    sid       = "PublishEvents"
    actions   = ["sns:Publish"]
    resources = ["${local.publisher_prefix}*"]
  }

  statement = {
    sid       = "WriteLambdaLogs"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}

data aws_kms_key key {
  key_id = "${var.kms_key_id}"
}

data aws_secretsmanager_secret secret {
  name = "${var.secret_name}"
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

resource aws_api_gateway_stage stage {
  deployment_id = "${aws_api_gateway_deployment.api.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  stage_name    = "${var.api_stage_name}"
  tags          = "${var.api_stage_tags}"
}

resource aws_cloudwatch_log_group logs {
  count             = "${length(local.function_names)}"
  name              = "/aws/lambda/${element(local.function_names, count.index)}"
  retention_in_days = "${var.log_group_retention_in_days}"
  tags              = "${var.log_group_tags}"
}

resource aws_iam_role role {
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
  description        = "Slackbot resource access"
  name               = "${local.role_name}"
  path               = "${var.role_path}"
  tags               = "${var.role_tags}"
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

resource aws_lambda_function api {
  description      = "Slack request handler"
  filename         = "${data.archive_file.lambda.output_path}"
  function_name    = "${local.function_name}"
  handler          = "index.handler"
  kms_key_arn      = "${data.aws_kms_key.key.arn}"
  layers           = ["${aws_lambda_layer_version.slackend.arn}"]
  memory_size      = "${var.lambda_memory_size}"
  role             = "${aws_iam_role.role.arn}"
  runtime          = "${local.runtime}"
  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  tags             = "${var.lambda_tags}"
  timeout          = "${var.lambda_timeout}"

  environment = {
    variables = {
      AWS_SECRET     = "${data.aws_secretsmanager_secret.secret.name}"
      AWS_SNS_PREFIX = "${local.publisher_prefix}"
      BASE_URL       = "${var.base_url}"
      DEBUG          = "${var.debug}"
    }
  }
}

resource aws_lambda_function post_message {
  description      = "Post Slack message via SNS"
  filename         = "${data.archive_file.lambda.output_path}"
  function_name    = "${local.function_name}-post-message"
  handler          = "index.postMessage"
  kms_key_arn      = "${data.aws_kms_key.key.arn}"
  layers           = ["${aws_lambda_layer_version.slackend.arn}"]
  role             = "${aws_iam_role.role.arn}"
  runtime          = "${local.runtime}"
  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  tags             = "${var.lambda_tags}"
  timeout          = 15

  environment = {
    variables = {
      AWS_SECRET = "${data.aws_secretsmanager_secret.secret.name}"
      DEBUG      = "${var.debug}"
    }
  }
}

resource aws_lambda_function post_ephemeral {
  description      = "Post Slack ephemeral message via SNS"
  filename         = "${data.archive_file.lambda.output_path}"
  function_name    = "${local.function_name}-post-ephemeral"
  handler          = "index.postEphemeral"
  kms_key_arn      = "${data.aws_kms_key.key.arn}"
  layers           = ["${aws_lambda_layer_version.slackend.arn}"]
  role             = "${aws_iam_role.role.arn}"
  runtime          = "${local.runtime}"
  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  tags             = "${var.lambda_tags}"
  timeout          = 15

  environment = {
    variables = {
      AWS_SECRET = "${data.aws_secretsmanager_secret.secret.name}"
      DEBUG      = "${var.debug}"
    }
  }
}

resource aws_lambda_layer_version slackend {
  description         = "Slackend dependencies"
  filename            = "${path.module}/package.zip"
  layer_name          = "${var.lambda_layer_name}"
  compatible_runtimes = ["${local.runtime}"]
  source_code_hash    = "${base64sha256(file("${path.module}/package.zip"))}"
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

resource aws_sns_topic oauth {
  name = "${local.topic_prefix}oauth"
}

resource aws_sns_topic post_message {
  name = "${local.topic_prefix}post_message"
}

resource aws_sns_topic post_ephemeral {
  name = "${local.topic_prefix}post_ephemeral"
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
