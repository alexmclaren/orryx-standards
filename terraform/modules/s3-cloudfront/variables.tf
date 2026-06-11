# Variables for S3 + CloudFront module

variable "product_name" {
  description = "Product name — used as a prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for frontend assets"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for the CloudFront distribution (leave empty for default *.cloudfront.net)"
  type        = string
  default     = ""
}

variable "domain_aliases" {
  description = "Additional domain aliases (e.g. www.example.com)"
  type        = list(string)
  default     = []
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_100 = US/EU only, PriceClass_All = global)"
  type        = string
  default     = "PriceClass_100"
  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
