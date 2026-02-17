output "jenkins_public_ip" {
  description = "Public IP of Jenkins EC2"
  value       = aws_instance.jenkins.public_ip
}

output "app_public_ip" {
  description = "Public IP of App EC2"
  value       = aws_instance.app.public_ip
}

output "app_endpoint" {
  description = "ALB DNS if enabled, otherwise app host URL"
  value       = var.create_alb ? "http://${aws_lb.app[0].dns_name}" : "http://${aws_instance.app.public_ip}"
}

output "jenkins_url" {
  description = "Jenkins web URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}
