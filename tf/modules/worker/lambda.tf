locals {
  lambda_subnet_ids             = try(module.vpc.private_subnets, [])
  lambda_sgs                    = [aws_security_group.vpc_traffic_lambda_sg.id]
  lambda_ts_artifact_local_path = "../../dist/"
  metrics_namespace             = "${var.app_deployment}-service"
}

# ---- Common Datasource / Resources for lambda starts

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid = "assume-role"
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vpc_lambda_base_policy_doc" {
  statement {
    sid    = "VpcNetworkInterfaces"
    effect = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:AttachNetworkInterface",
    ]
    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "xray_tracing_write_access" {
  statement {
    sid    = "XRayTracingWriteAccess"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_security_group" "vpc_traffic_lambda_sg" {
  name        = "${var.app_deployment}-lambda-sg"
  description = "Allow TLS outbound traffic"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.app_deployment}-lambda-sg"
  }
}

# ---- Common Datasource / Resources for lambda ends

# ---- Datasource / Resources for "authorizer lambda" starts

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${var.app_deployment}-authorizer-handler"
  retention_in_days = 7
}

data "aws_iam_policy_document" "authorizer" {
  source_policy_documents = [
    data.aws_iam_policy_document.vpc_lambda_base_policy_doc.json,
    data.aws_iam_policy_document.xray_tracing_write_access.json
  ]

  statement {
    sid    = "LogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = [
      aws_cloudwatch_log_group.authorizer.arn
    ]
  }

  statement {
    sid    = "LogStream"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.authorizer.arn}:log-stream:*"
    ]
  }
}

resource "aws_iam_policy" "authorizer" {
  name   = "rsw-${var.app_deployment}-authorizer-policy"
  policy = data.aws_iam_policy_document.authorizer.json
}

resource "aws_iam_role" "authorizer" {
  name               = "${var.app_deployment}-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "authorizer" {
  role = aws_iam_role.authorizer.name
  policy_arn = aws_iam_policy.authorizer.arn
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.app_deployment}-authorizer-handler"
  role             = aws_iam_role.authorizer.arn
  handler          = "authorizer.handler"
  runtime          = var.lambda_node_runtime
  architectures    = var.lambda_node_arch
  filename         = "${local.lambda_ts_artifact_local_path}/authorizer.zip"
  source_code_hash = filebase64sha256("${local.lambda_ts_artifact_local_path}/authorizer.zip")
  memory_size      = 1024
  timeout          = 600
  environment {
    variables = {
      POWERTOOLS_SERVICE_NAME      = "${var.app_deployment}-worker-handler"
      POWERTOOLS_METRICS_NAMESPACE = local.metrics_namespace
      AWS_XRAY_DEBUG_MODE          = "TRUE"
      LOG_LEVEL                    = "INFO"
      ENV_LOCAL                    = var.env_local
    }
  }
  tracing_config {
    mode = "Active"
  }
  ephemeral_storage {
    size = 1024
  }
  vpc_config {
    security_group_ids = local.lambda_sgs
    subnet_ids         = local.lambda_subnet_ids
  }
  depends_on = [
    aws_iam_role_policy_attachment.authorizer
  ]
}

# ---- Datasource / Resources for "authorizer lambda" ends

# ---- Datasource / Resources for "Worker Lambda" starts

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${var.app_deployment}-worker-handler"
  retention_in_days = 7
}

data "aws_iam_policy_document" "worker" {
  source_policy_documents = [
    data.aws_iam_policy_document.vpc_lambda_base_policy_doc.json,
    data.aws_iam_policy_document.xray_tracing_write_access.json
  ]

  statement {
    sid    = "LogGroup"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = [
      aws_cloudwatch_log_group.worker.arn
    ]
  }
  statement {
    sid    = "LogStream"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.worker.arn}:log-stream:*"
    ]
  }
}

resource "aws_iam_policy" "worker" {
  name   = "${var.app_deployment}-worker-policy"
  policy = data.aws_iam_policy_document.worker.json
}

resource "aws_iam_role" "worker" {
  name               = "${var.app_deployment}-worker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "worker" {
  role = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.worker.arn
}

resource "aws_lambda_function" "worker" {
  function_name    = "${var.app_deployment}-worker-handler"
  role             = aws_iam_role.worker.arn
  handler          = "worker.handler"
  runtime          = var.lambda_node_runtime
  architectures    = var.lambda_node_arch
  filename         = "${local.lambda_ts_artifact_local_path}/worker.zip"
  source_code_hash = filebase64sha256("${local.lambda_ts_artifact_local_path}/worker.zip")
  memory_size      = 1024
  timeout          = 30
  ephemeral_storage {
    size = 1024
  }
  tracing_config {
    mode = "Active"
  }
  environment {
    variables = {
      POWERTOOLS_SERVICE_NAME      = "${var.app_deployment}-worker-handler"
      POWERTOOLS_METRICS_NAMESPACE = local.metrics_namespace
      LOG_LEVEL                    = "INFO"
      ENV_LOCAL                    = var.env_local
    }
  }
  vpc_config {
    security_group_ids = local.lambda_sgs
    subnet_ids         = local.lambda_subnet_ids
  }
  depends_on = [
    aws_iam_role_policy_attachment.worker
  ]
}

# ---- Datasource / Resources for "Worker Lambda" ends
