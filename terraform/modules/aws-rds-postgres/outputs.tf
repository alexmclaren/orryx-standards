# AWS RDS PostgreSQL Module — outputs
# Version: 1.0.0

output "endpoint" {
  description = "Connection endpoint in address:port format"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "DNS address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Port the database listens on"
  value       = aws_db_instance.main.port
}

output "instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.main.db_name
}

output "security_group_id" {
  description = "Security group attached to the RDS instance"
  value       = aws_security_group.rds.id
}

output "subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.main.name
}
