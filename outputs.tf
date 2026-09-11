output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "private_subnet_id" {
  description = "ID of the private subnet."
  value       = aws_subnet.private.id
}

output "instance_id" {
  description = "ID of the private EC2 instance. Use this to open a Session Manager shell."
  value       = aws_instance.private.id
}

output "instance_private_ip" {
  description = "Private IP of the instance. There is no public IP by design."
  value       = aws_instance.private.private_ip
}

output "nat_gateway_public_ip" {
  description = "Elastic IP the instance appears as when it reaches the internet."
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : null
}

output "session_manager_command" {
  description = "Command to open a shell on the private instance."
  value       = "aws ssm start-session --target ${aws_instance.private.id} --region ${var.aws_region}"
}
