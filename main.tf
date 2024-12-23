provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "weather_api" {
  filename      = "lambda.zip"  # Path to the zipped Lambda function
  function_name = "weather-api"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "src.handler"
  runtime       = "nodejs22.x"
  environment {
    variables = {
      OPENWEATHER_API_KEY = "LbNfnyihODYUT7fBSN0TQ621penUNIT1"  # Replace with your API key
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_api_gateway_rest_api" "weather_api" {
  name        = "weather-api"
  description = "API for getting current weather data"
}

resource "aws_api_gateway_resource" "weather_resource" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  parent_id   = aws_api_gateway_rest_api.weather_api.root_resource_id
  path_part   = "weather"
}

resource "aws_api_gateway_method" "get_weather" {
  rest_api_id   = aws_api_gateway_rest_api.weather_api.id
  resource_id   = aws_api_gateway_resource.weather_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.weather_api.id
  resource_id             = aws_api_gateway_resource.weather_resource.id
  http_method             = aws_api_gateway_method.get_weather.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.weather_api.arn}/invocations"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  function_name = aws_lambda_function.weather_api.function_name
}

resource "aws_api_gateway_deployment" "weather_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  }

data "aws_region" "current" {}

output "api_url" {
  value = "https://${aws_api_gateway_rest_api.weather_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/prod/weather"
}

resource "aws_s3_bucket" "weather_data_bucket" {
  bucket = "weather-project-data-bucket"
}

terraform {
  backend "s3" {
    bucket         = "weather-project-data-bucket"           # S3 bucket name
    key            = "./terraform.tfstate"           # Path to store the state file
    region         = "us-east-1"                           # AWS region for your S3 bucket
    encrypt        = true                                  # Enable encryption for the state file
    acl            = "private"                             # Access control list for the state file
  }
}