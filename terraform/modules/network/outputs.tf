output "vpc_id" {
  description = "ID of the project VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "Security group ID for the load balancer"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group ID for ECS application tasks"
  value       = aws_security_group.app.id
}