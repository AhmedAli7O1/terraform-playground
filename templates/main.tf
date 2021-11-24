terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.66.0"
    }
  }
}

# Tenant Variables (External)
variable "tenant_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

# Locals (For reusability)
locals {
  func_name = "${var.tenant_name}_playground"
}

# Configure AWS via external vars
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Allow the lambda to assume the role that gives it access to resources
data "aws_iam_policy_document" "best_lambda_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    effect = "Allow"

    sid = ""
  }
}

# The access given to the lambda function
data "aws_iam_policy_document" "best_lambda_exec_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:ca-central-1:165671112300:log-group:/aws/lambda/${local.func_name}:*"
    ]
  }
}

# The role given to the lambda function 
resource "aws_iam_role" "best_lambda_role" {
  name = "${local.func_name}_role"

  assume_role_policy = data.aws_iam_policy_document.best_lambda_assume_policy.json

  inline_policy {
    name = "${local.func_name}_policy"

    policy = data.aws_iam_policy_document.best_lambda_exec_policy.json
  }
}

# The log group that will contain the lambda function logs
resource "aws_cloudwatch_log_group" "lambda_playground_logs" {
  name              = "/aws/lambda/${local.func_name}"
  retention_in_days = "30"
}

# The lambda creation
resource "aws_lambda_function" "best_lambda" {
  function_name = local.func_name
  role          = aws_iam_role.best_lambda_role.arn
  handler       = "index.handler"

  s3_bucket = "aali-terraform-playground"
  s3_key    = "lambda.zip"

  runtime = "nodejs14.x"

  environment {
    variables = {
      foo = "bar"
    }
  }
}