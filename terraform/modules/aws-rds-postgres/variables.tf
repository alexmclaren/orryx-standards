# AWS RDS PostgreSQL Module — input variables
# Version: 1.0.0

variable "db_name" {
  description = "Database name; also used as the identifier prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. production, staging)"
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the RDS instance and its security group"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach PostgreSQL (port 5432), e.g. the ECS task SG"
  type        = list(string)
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
}

variable "master_password" {
  description = "Master password for the database. Use Secrets Manager in production."
  type        = string
  sensitive   = true
}

variable "postgres_version" {
  description = "PostgreSQL engine version (must stay within the postgres15 parameter-group family)"
  type        = string
  default     = "15.10"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper limit for storage autoscaling in GB"
  type        = number
  default     = 100
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption. null uses the AWS-managed RDS key."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention period in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy (set true only for non-production)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm actions; empty string disables alarm actions"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
