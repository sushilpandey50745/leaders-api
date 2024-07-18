output "vpc_id" {
  value = aws_vpc.laravel_vpc.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.laravel_cluster.name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.laravel_table.name
}

output "load_balancer_dns" {
  value = aws_lb.laravel_lb.dns_name
}
