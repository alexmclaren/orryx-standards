# =============================================================================
# S3 + CloudFront module — private bucket + OAC + distribution
#
# NOTE: This module is a CANDIDATE FOR UPSTREAMING to orryx-standards.
#       The canonical orryx-standards repository did not have an S3/CloudFront
#       module as of template creation (2026-06-10). When an upstream module is
#       added, replace the local source reference in the parent terraform/main.tf
#       with the remote git source (same pattern as aws-ecs-service and
#       aws-rds-postgres).
#
# Version: 1.0.0
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ---------------------------------------------------------------------------
# S3 bucket (private — no public access)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name        = var.bucket_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# Origin Access Control (OAC) — modern replacement for OAI
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.product_name}-${var.environment}-oac"
  description                       = "OAC for ${var.product_name} frontend (${var.environment})"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy — allow CloudFront OAC to read objects
data "aws_iam_policy_document" "s3_cloudfront" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.s3_cloudfront.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# ---------------------------------------------------------------------------
# ACM Certificate (optional — only created when custom domain is specified)
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "frontend" {
  # ACM certificates for CloudFront MUST be in us-east-1
  count    = var.domain_name != "" ? 1 : 0
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = var.domain_aliases
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.product_name}-${var.environment}-cert"
  })
}

resource "aws_acm_certificate_validation" "frontend" {
  count    = var.domain_name != "" ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.frontend[0].arn
  validation_record_fqdns = [for r in aws_acm_certificate.frontend[0].domain_validation_options : r.resource_record_name]
}

# ---------------------------------------------------------------------------
# CloudFront Distribution
# ---------------------------------------------------------------------------

locals {
  s3_origin_id = "${var.product_name}-${var.environment}-s3"

  aliases = var.domain_name != "" ? concat([var.domain_name], var.domain_aliases) : []

  viewer_certificate = var.domain_name != "" ? {
    acm_certificate_arn            = aws_acm_certificate_validation.frontend[0].certificate_arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = false
    } : {
    acm_certificate_arn            = null
    ssl_support_method             = null
    minimum_protocol_version       = null
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.product_name} frontend (${var.environment})"
  default_root_object = "index.html"
  aliases             = local.aliases
  price_class         = var.price_class
  wait_for_deployment = false

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.s3_origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id          = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized (managed)
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin (managed)
  }

  # SPA routing: return index.html for 403/404 so React Router works
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "viewer_certificate" {
    for_each = [local.viewer_certificate]
    content {
      acm_certificate_arn            = viewer_certificate.value.acm_certificate_arn
      ssl_support_method             = viewer_certificate.value.ssl_support_method
      minimum_protocol_version       = viewer_certificate.value.minimum_protocol_version
      cloudfront_default_certificate = viewer_certificate.value.cloudfront_default_certificate
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.product_name}-${var.environment}-cf"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}
