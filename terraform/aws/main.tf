# https://developer.hashicorp.com/terraform/tutorials/aws-get-started/
# terraform init - initalizes, must be ran from where main.tf exists
# terraform plan - show changes to be made by apply
# terraform apply - apply the configurations, only changes what's required
# terraform show - show details of a created resource
# terraform destroy - destroys the configuration
#
# Commands to import my resources
# terraform import aws_s3_bucket.primary_bucket jacehickman.com /
# terraform import aws_s3_bucket.www_bucket www.jacehickman.com /
# terraform import aws_s3_bucket.tf_state terraform-state-jacehickman /
# terraform import aws_s3_bucket_cors_configuration.primary_bucket_cors jacehickman.com /
# terraform import aws_s3_bucket_policy.primary_bucket_policy jacehickman.com /
# terraform import aws_s3_bucket_policy.www_bucket_policy www.jacehickman.com /
# terraform import aws_cloudfront_distribution.s3_distribution E3EERE5S6HGZEH /
# terraform import aws_route53_zone.my_dns Z07797793UO05BKPV64D2 /
# terraform import aws_route53_record.root_a Z07797793UO05BKPV64D2_jacehickman.com._A /
# terraform import aws_route53_record.root_aaaa Z07797793UO05BKPV64D2_jacehickman.com._AAAA /
# terraform import aws_route53_record.www_a Z07797793UO05BKPV64D2_www.jacehickman.com._A /
# terraform import aws_route53_record.acm_validation_root Z07797793UO05BKPV64D2__cef29cd4059092c98fac7dd45306cf95.jacehickman.com._CNAME /
# terraform import aws_route53_record.acm_validation_www Z07797793UO05BKPV64D2__68c1ae93d3c6c01e143b71af9bd0b6fc.www.jacehickman.com._CNAME /
# terraform import aws_dynamodb_table.visitor_table VisitorTable /
# terraform import aws_lambda_function.updateItem_py updateItem /
# terraform import aws_iam_role.table_role VisitorCounter_Role /
# terraform import aws_api_gateway_rest_api.api z3v2iubne2 /
# terraform import aws_api_gateway_method.post_method z3v2iubne2/by9gf2juxc/POST /
# terraform import aws_api_gateway_method.options_method z3v2iubne2/by9gf2juxc/OPTIONS /
# terraform import aws_api_gateway_integration.lambda_integration z3v2iubne2/by9gf2juxc/POST /
# terraform import aws_api_gateway_integration.options_mock z3v2iubne2/by9gf2juxc/OPTIONS /
# terraform import aws_api_gateway_method_response.post_response z3v2iubne2/by9gf2juxc/POST/200 /
# terraform import aws_api_gateway_method_response.options_response z3v2iubne2/by9gf2juxc/OPTIONS/200 /
# terraform import aws_api_gateway_integration_response.post_integration_response z3v2iubne2/by9gf2juxc/POST/200 /
# terraform import aws_api_gateway_integration_response.options_mock_response z3v2iubne2/by9gf2juxc/OPTIONS/200 /
# terraform import aws_api_gateway_deployment.api_deployment z3v2iubne2/k7n2ch /
# terraform import aws_api_gateway_stage.api_stage z3v2iubne2/beta /
# terraform import aws_lambda_permission.apigw_lambda updateItem/3d15f824-5ab5-4252-b00d-74a119d02657

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.69.0"
    }
  }
}

provider "aws" {
    region = "us-east-2"
}

# S3 bucket to host the tf_state
resource "aws_s3_bucket" "tf_state" {
  bucket = "terraform-state-jacehickman"
  force_destroy = true
}

# DynamoDB table to lock the tf_state
resource "aws_dynamodb_table" "tf_lock" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# S3 bucket to host the main website
resource "aws_s3_bucket" "primary_bucket" {
  bucket = "jacehickman.com"
  force_destroy  = true
}

# Policy for the primary website to set index/error docs
resource "aws_s3_bucket_website_configuration" "primary_website" {
  bucket = aws_s3_bucket.primary_bucket.id

  index_document {
    suffix = "resume.html"  
  }

  error_document {
    key = "error.html" 
  }
}

# Allows public access to the wesbite
resource "aws_s3_bucket_public_access_block" "primary_public_access" {
  bucket = aws_s3_bucket.primary_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read policy for the primary bucket
resource "aws_s3_bucket_policy" "primary_bucket_policy" {
  bucket = aws_s3_bucket.primary_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",         
        Effect    = "Allow",                   
        Principal = "*",                           
        Action    = "s3:GetObject",                
        Resource  = "${aws_s3_bucket.primary_bucket.arn}/*" 
      }
    ]
  })
  depends_on = [ aws_s3_bucket_public_access_block.primary_public_access ]
}

# CORS policy for the primary bucket allows GET and POST from my site
resource "aws_s3_bucket_cors_configuration" "primary_bucket_cors" {
  bucket = aws_s3_bucket.primary_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["https://jacehickman.com"]
    expose_headers  = []
  }
}

# www bucket for redirection to primary
resource "aws_s3_bucket" "www_bucket" {
  bucket = "www.jacehickman.com"
}

# Redirects from www to https site
resource "aws_s3_bucket_website_configuration" "www_website" {
  bucket = aws_s3_bucket.www_bucket.id
  redirect_all_requests_to {
    host_name = "jacehickman.com"  
    protocol  = "https"           
  }
}

# Public access for www bucket
resource "aws_s3_bucket_public_access_block" "www_public_access" {
  bucket = aws_s3_bucket.www_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read policy for www
resource "aws_s3_bucket_policy" "www_bucket_policy" {
  bucket = aws_s3_bucket.www_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",         
        Effect    = "Allow",                   
        Principal = "*",                           
        Action    = "s3:GetObject",                
        Resource  = "${aws_s3_bucket.www_bucket.arn}/*" 
      }
    ]
  })
  depends_on = [ aws_s3_bucket_public_access_block.primary_public_access ]
}

# CloudFront for website content
# Includes TLS cert
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "jacehickman.com.s3-website.us-east-2.amazonaws.com"
    origin_id = "jacehickman.com.s3-website.us-east-2.amazonaws.com"
    custom_origin_config {
      http_port = 80
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = ["TLSv1.2"]
      origin_read_timeout = 30
      origin_keepalive_timeout = 5
    }
  }
  # retain_on_delete = true
  aliases = ["jacehickman.com", "www.jacehickman.com"]
  enabled         = true
  is_ipv6_enabled = true
  default_root_object = "resume.html"

  default_cache_behavior {
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    allowed_methods  = ["GET", "HEAD"]  
    cached_methods   = ["GET", "HEAD"]  
    target_origin_id = "jacehickman.com.s3-website.us-east-2.amazonaws.com"
    viewer_protocol_policy = "redirect-to-https" 
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400  
    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn
    ssl_support_method = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# DNS zone for my website
data "aws_route53_zone" "my_dns" {
  name = "jacehickman.com"
}

# A records for root and www buckets
resource "aws_route53_record" "root_a" {
  zone_id = data.aws_route53_zone.my_dns.zone_id
  name    = "jacehickman.com"
  type    = "A"

  alias {
    name = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_a" {
  zone_id = data.aws_route53_zone.my_dns.zone_id
  name    = "www.jacehickman.com"
  type    = "A"

  alias {
    name = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

# AAAA records for ipv6 support
resource "aws_route53_record" "root_aaaa" {
  zone_id = data.aws_route53_zone.my_dns.zone_id
  name    = "jacehickman.com"
  type    = "AAAA"

  alias {
    name = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}


 # CNAME Records for TLS cert validation
 resource "aws_route53_record" "acm_validation_root" {
   zone_id = data.aws_route53_zone.my_dns.zone_id
   name    = "_cef29cd4059092c98fac7dd45306cf95.jacehickman.com"
   type    = "CNAME"
   ttl     = 300
 
   records = [
     "_bbd23e6d7204f1be8c423377d9e725c8.htgdxnmnnj.acm-validations.aws"
   ]
 }
 
 resource "aws_route53_record" "acm_validation_www" {
   zone_id = data.aws_route53_zone.my_dns.zone_id
   name    = "_68c1ae93d3c6c01e143b71af9bd0b6fc.www.jacehickman.com"
   type    = "CNAME"
   ttl     = 300
 
   records = [
     "_154bbfe80fdedc0f1f81df2e81f0f799.htgdxnmnnj.acm-validations.aws"
   ]
 }

# DynamoDB table to store visitor_count
# visitor_count is added by Lambda and doesn't need to be defined
resource "aws_dynamodb_table" "visitor_table" {
  name = "VisitorTable"
  hash_key = "visitor_id"
  billing_mode = "PROVISIONED"
  read_capacity = 1
  write_capacity = 1

  attribute {
    name = "visitor_id"
    type = "N"
  }
}

# API Gateway to expose Lambda function
resource "aws_api_gateway_rest_api" "api" {
  name = "CloudResumeAPI"
}

# POST method for Lambda
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}
 
# Integrate with Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.updateItem_py.invoke_arn
}

# API response config
resource "aws_api_gateway_method_response" "post_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# Integration response config
resource "aws_api_gateway_integration_response" "post_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.post_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'https://jacehickman.com'"
  }
  depends_on = [
    aws_api_gateway_method.post_method,
    aws_api_gateway_method_response.post_response,
    aws_api_gateway_integration.lambda_integration
  ]
}

# Set permission so API can invoke Lambda
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "3d15f824-5ab5-4252-b00d-74a119d02657"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.updateItem_py.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# OPTIONS method for CORS
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_rest_api.api.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Mock integrations for OPTIONS
resource "aws_api_gateway_integration" "options_mock" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Response method for OPTIONS
resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [
    aws_api_gateway_method.options_method,
    aws_api_gateway_method_response.options_response,
    aws_api_gateway_integration.options_mock
  ]
}

# Integration response for OPTIONS
resource "aws_api_gateway_integration_response" "options_mock_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  
  depends_on = [
    aws_api_gateway_integration.options_mock,
    aws_api_gateway_method_response.options_response
  ]

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin" = "'https://jacehickman.com'"
  }
}

# Deploy the API to the stage beta
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "beta"
}

# API gateway deployment
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  depends_on = [
    aws_api_gateway_method.post_method,
    aws_api_gateway_method_response.post_response,
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration_response.post_integration_response,

    aws_api_gateway_method.options_method,
    aws_api_gateway_method_response.options_response,
    aws_api_gateway_integration.options_mock,
    aws_api_gateway_integration_response.options_mock_response,
  ]
}

# IAM Role for Lambda to access DynamoDB
resource "aws_iam_role" "lambda_dynamodb_role" {
  name = "lambda-dynamodb-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda-dynamodb-access-policy"
  description = "Allows Lambda functions to read/write VisitorTable"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ]
      Resource = "arn:aws:dynamodb:us-east-2:*:table/VisitorTable"
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_dynamodb_attachment" {
  name       = "lambda-dynamodb-policy-attachment"
  roles      = [aws_iam_role.lambda_dynamodb_role.name]
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}


# Lambda function for update visitor count
resource "aws_lambda_function" "updateItem_py" {
 function_name = "updateItem"  
  role = aws_iam_role.lambda_dynamodb_role.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.10"
  filename = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
}