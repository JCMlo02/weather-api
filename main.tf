provider "aws" {
  region = "us-east-1"
}

resource "aws_lambda_function" "weather_api" {
  function_name = "weather-api"
  role          = aws_iam_role.lambda_execution.arn
  package_type = "Image"
  environment {
    variables = {
      API_KEY = "LbNfnyihODYUT7fBSN0TQ621penUNIT1"
    }
  }
  image_uri     = "${aws_ecr_repository.lambda_repo.repository_url}:latest"
}

# Create an ECR repository to store the Docker image
resource "aws_ecr_repository" "lambda_repo" {
  name = "weather-lambda-repo"
}

resource "aws_iam_policy" "lambda_ecr_policy" {
  name        = "LambdaECRPolicy"
  description = "Policy for Lambda to access ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer"
        ]
        Effect   = "Allow"
        Resource = aws_ecr_repository.lambda_repo.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ecr_attachment" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_ecr_policy.arn
}

resource "aws_iam_role" "lambda_execution" {
  name = "lambda_execution_role"

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
  
  resource "aws_iam_role_policy" "lambda_s3_policy" {
    name   = "lambda_s3_policy"
    role   = aws_iam_role.lambda_execution.id
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Effect = "Allow"
          Resource = "arn:aws:s3:::weather-project-data-bucket/*"
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
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "get_weather_method_response" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_resource.id
  http_method = aws_api_gateway_method.get_weather.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
  }
}

resource "aws_api_gateway_integration_response" "get_weather_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_resource.id
  http_method = aws_api_gateway_method.get_weather.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods"     = "'POST,OPTIONS'"
  }

  depends_on = [aws_api_gateway_integration.lambda_integration]
}
resource "aws_api_gateway_method" "options_weather" {
  rest_api_id   = aws_api_gateway_rest_api.weather_api.id
  resource_id   = aws_api_gateway_resource.weather_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id             = aws_api_gateway_rest_api.weather_api.id
  resource_id             = aws_api_gateway_resource.weather_resource.id
  http_method             = aws_api_gateway_method.options_weather.http_method
  integration_http_method = "OPTIONS"
  type                    = "MOCK"
    request_templates = {
    "application/json" = jsonencode(
      {
        statusCode = 200
      }
    )
  }
}

resource "aws_api_gateway_method_response" "options_method_response" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_resource.id
  http_method = aws_api_gateway_method.options_weather.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Headers"     = true
    "method.response.header.Access-Control-Allow-Methods"     = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  resource_id = aws_api_gateway_resource.weather_resource.id
  http_method = aws_api_gateway_method.options_weather.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'*'"
    "method.response.header.Access-Control-Allow-Headers"     = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key'"
    "method.response.header.Access-Control-Allow-Methods"     = "'OPTIONS,POST'"
  }
  depends_on = [aws_api_gateway_integration.options_integration]
}

resource "aws_api_gateway_rest_api_policy" "weather_api_policy" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id

  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "execute-api:Invoke",
      "Resource": "arn:aws:execute-api:us-east-1:788228759732:6liw8ik1wf/*"
    }
  ]
})
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.weather_api.id
  resource_id             = aws_api_gateway_resource.weather_resource.id
  http_method             = aws_api_gateway_method.get_weather.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.weather_api.invoke_arn
  }

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  principal     = "*"
  function_name = aws_lambda_function.weather_api.function_name
  source_arn    = "${aws_api_gateway_rest_api.weather_api.execution_arn}/*"
  depends_on = [aws_lambda_function.weather_api]
}

resource "aws_api_gateway_deployment" "weather_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.weather_api.id
  depends_on  = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_method.options_weather,
    aws_api_gateway_method.get_weather,
    aws_api_gateway_integration_response.options_integration_response,
    aws_api_gateway_integration_response.get_weather_integration_response,
    aws_api_gateway_method_response.options_method_response,
    aws_api_gateway_method_response.get_weather_method_response
  ]
}

resource "aws_api_gateway_stage" "weather_api_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.weather_api.id
  deployment_id = aws_api_gateway_deployment.weather_api_deployment.id
  
}

output "api_url" {
  value = "https://${aws_api_gateway_rest_api.weather_api.id}.execute-api.us-east-1.amazonaws.com/prod/weather"
}

# Use your manually created S3 bucket
resource "aws_s3_bucket" "weather_data_bucket" {
  bucket = "weather-project-data-bucket"  # Use your existing bucket name here
}

# Terraform Backend (S3 for state file storage)
terraform {
  backend "s3" {
    bucket         = "weather-project-data-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    acl            = "private"
  }
}