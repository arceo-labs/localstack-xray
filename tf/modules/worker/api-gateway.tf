locals {
  api_gateway_name = "${var.app_deployment}-api-gateway"
  api_hostname     = "${var.app_deployment}.${data.aws_route53_zone.hosted_zone.name}"
}

data "aws_iam_policy_document" "gateway_assume_role" {
  statement {
    sid     = "1"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com", "lambda.amazonaws.com"]
    }
  }
}

resource "aws_api_gateway_rest_api" "api_gateway" {
  name = local.api_gateway_name
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/api_gw/${local.api_gateway_name}"
  retention_in_days = 7
}

resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_rest_api.api_gateway.body,
      aws_api_gateway_resource.worker_resource.id,
      aws_api_gateway_method.worker_options.id,
      aws_api_gateway_method_response.worker_options.id,
      aws_api_gateway_integration.worker_options.id,
      aws_api_gateway_integration_response.worker_options.id,
      aws_api_gateway_method.worker_get.id,
      aws_api_gateway_method_response.worker_get.id,
      aws_api_gateway_integration.worker_get.id,
      aws_api_gateway_integration_response.worker_get.id,
      aws_api_gateway_authorizer.api_gateway_authorizer.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration_response.worker_options,
    aws_api_gateway_integration_response.worker_get,
    aws_api_gateway_authorizer.api_gateway_authorizer
  ]
}

resource "aws_api_gateway_method_settings" "api_gateway" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = aws_api_gateway_stage.api_gateway_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    data_trace_enabled = true
    logging_level      = "INFO"

    throttling_rate_limit  = 10000
    throttling_burst_limit = 5000
  }
}

resource "aws_api_gateway_stage" "api_gateway_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "api"

  xray_tracing_enabled = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format          = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

### Authorizer starts

resource "aws_lambda_permission" "api_gateway_authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

resource "aws_api_gateway_authorizer" "api_gateway_authorizer" {
  name                             = "${var.app_deployment}-api-gateway-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.api_gateway.id
  authorizer_uri                   = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials           = aws_iam_role.authorizer_invocation.arn
  type                             = "TOKEN"
  identity_source                  = "method.request.header.Authorization"
  identity_validation_expression   = "^Bearer [-0-9a-zA-z\\.]*$"
  authorizer_result_ttl_in_seconds = 0
}

resource "aws_iam_role" "authorizer_invocation" {
  name = "${var.app_deployment}-api-gateway-authorizer-invocation"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.gateway_assume_role.json
}

data "aws_iam_policy_document" "authorizer_invocation" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.authorizer.arn]
  }
}

resource "aws_iam_role_policy" "authorizer_invocation" {
  name   = "${var.app_deployment}-authorizer-invocation"
  policy = data.aws_iam_policy_document.authorizer_invocation.json
  role   = aws_iam_role.authorizer_invocation.id
}

### Authorizer ends

### API Path resources starts

### API Path resources ends

data "aws_route53_zone" "hosted_zone" {
  name         = var.hosted_zone
  zone_id      = var.hosted_zone_id
  private_zone = false
}

resource "aws_acm_certificate" "api" {
  domain_name       = local.api_hostname
  validation_method = "DNS"
}

locals {
  api_domain_validation_option = tolist(aws_acm_certificate.api.domain_validation_options)[0]
}

resource "aws_route53_record" "api_cert_validation" {
  allow_overwrite = true
  name            = local.api_domain_validation_option.resource_record_name
  records         = [local.api_domain_validation_option.resource_record_value]
  ttl             = 60
  type            = local.api_domain_validation_option.resource_record_type
  zone_id         = data.aws_route53_zone.hosted_zone.zone_id
}

resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [aws_route53_record.api_cert_validation.fqdn]
}

resource "aws_api_gateway_domain_name" "api" {
  certificate_arn = aws_acm_certificate_validation.api.certificate_arn
  domain_name     = local.api_hostname
}

resource "aws_api_gateway_base_path_mapping" "subdomain" {
  api_id      = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = aws_api_gateway_deployment.api_deployment.stage_name
  domain_name = aws_api_gateway_domain_name.api.domain_name
}

resource "aws_route53_record" "api" {
  name    = aws_api_gateway_domain_name.api.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.hosted_zone.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.api.cloudfront_domain_name
    zone_id                = aws_api_gateway_domain_name.api.cloudfront_zone_id
  }
}
