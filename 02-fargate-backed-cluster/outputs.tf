output "alb_dns_name" {
  value       = "http://${aws_lb.ecs_alb.dns_name}"
  description = "Public Fargate ALB address. Open this URL in your browser to verify serverless deployment!"
}