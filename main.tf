provider "aws" {
  region = "us-east-1"  # Set your desired AWS region
}

resource "aws_lambda_function" "event_lambda_function" {
  function_name    = "Lambda-event-schedule"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_execution_role.arn
  filename         = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")  # Path to your Lambda function code
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "LambdaExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess",
  ]
}

resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "SchedulerAPI"
  protocol_type = "HTTP"
}



resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.api_gateway.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.event_lambda_function.invoke_arn
}

resource "aws_apigatewayv2_route" "api_gateway_route_get" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "GET /"  # Define the route key to match the GET method and root path
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}


resource "aws_cloudwatch_event_rule" "eventbridge_rule" {
  name                = "event-schedule"
  schedule_expression =  "cron(0/5 * * * ? *)"

  state               = "ENABLED"
}



output "api_endpoint" {
  description = "URL of the API endpoint"
  value       = aws_apigatewayv2_api.api_gateway.api_endpoint
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.event_lambda_function.function_name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.eventbridge_rule.name
}
