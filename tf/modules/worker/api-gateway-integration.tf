
resource "aws_api_gateway_resource" "worker_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "worker"
}

### - Worker OPTIONS begins

resource "aws_api_gateway_method" "worker_options" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.worker_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "worker_options" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.worker_resource.id
  http_method = aws_api_gateway_method.worker_options.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "worker_options" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.worker_resource.id
  http_method = aws_api_gateway_method.worker_options.http_method
  type        = "MOCK"
}

resource "aws_api_gateway_integration_response" "worker_options" {
  rest_api_id         = aws_api_gateway_rest_api.api_gateway.id
  resource_id         = aws_api_gateway_resource.worker_resource.id
  http_method         = aws_api_gateway_method_response.worker_options.http_method
  status_code         = aws_api_gateway_method_response.worker_options.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on         = [aws_api_gateway_integration.worker_options]
}

### - Worker OPTIONS ends
### - Worker GET begins

resource "aws_api_gateway_request_validator" "request_params_validator" {
  name                        = "${var.app_deployment}-request-params-validator"
  rest_api_id                 = aws_api_gateway_rest_api.api_gateway.id
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "worker_get" {
  rest_api_id          = aws_api_gateway_rest_api.api_gateway.id
  resource_id          = aws_api_gateway_resource.worker_resource.id
  http_method          = "GET"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.api_gateway_authorizer.id
  request_validator_id = aws_api_gateway_request_validator.request_params_validator.id
  request_parameters   = {
    "method.request.header.Authorization" = true
  }
}

resource "aws_api_gateway_method_response" "worker_get" {
  rest_api_id         = aws_api_gateway_rest_api.api_gateway.id
  resource_id         = aws_api_gateway_resource.worker_resource.id
  http_method         = aws_api_gateway_method.worker_get.http_method
  status_code         = "200"
  response_models = {
    "application/json" : aws_api_gateway_model.worker_response_model.name
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "false"
  }
}

resource "aws_api_gateway_integration" "worker_get" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.worker_resource.id
  http_method             = aws_api_gateway_method.worker_get.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.worker.invoke_arn
}

resource "aws_api_gateway_integration_response" "worker_get" {
  rest_api_id         = aws_api_gateway_rest_api.api_gateway.id
  resource_id         = aws_api_gateway_resource.worker_resource.id
  http_method         = aws_api_gateway_method_response.worker_get.http_method
  status_code         = aws_api_gateway_method_response.worker_get.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [aws_api_gateway_integration.worker_get]
}

resource "aws_api_gateway_model" "worker_response_model" {
  rest_api_id  = aws_api_gateway_rest_api.api_gateway.id
  name         = "WorkerResponse"
  description  = "Worker Response Model"
  content_type = "application/json"

  schema = <<EOF
{
   "$schema":"http://json-schema.org/draft-04/schema#",
   "title":"WorkerResponse",
   "type":"object",
   "properties": {
      "message": {
         "type":"string"
      }
   }
}
EOF
}

resource "aws_lambda_permission" "worker" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.worker.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*"
}

### - Worker GET ends
