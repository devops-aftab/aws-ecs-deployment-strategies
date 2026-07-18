output "alb_dns_name" {
  value       = "http://${aws_lb.ecs_alb.dns_name}"
  description = "Public ALB address. Open this URL in your browser and refresh to watch load-balancing in action!"
}