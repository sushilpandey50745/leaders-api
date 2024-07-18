provider "aws" {
  region = var.aws_region
}

# Data source to get availability zones
data "aws_availability_zones" "available" {}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_vpc" "laravel_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "laravel-vpc"
  }
}

resource "aws_internet_gateway" "laravel_igw" {
  vpc_id = aws_vpc.laravel_vpc.id

  tags = {
    Name = "laravel-igw"
  }
}

resource "aws_route_table" "laravel_route_table" {
  vpc_id = aws_vpc.laravel_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.laravel_igw.id
  }

  tags = {
    Name = "laravel-route-table"
  }
}

resource "aws_route_table_association" "laravel_route_table_association" {
  count          = 2
  subnet_id      = aws_subnet.laravel_subnet[count.index].id
  route_table_id = aws_route_table.laravel_route_table.id
}

resource "aws_subnet" "laravel_subnet" {
  count                     = 2
  vpc_id                    = aws_vpc.laravel_vpc.id
  cidr_block                = cidrsubnet(aws_vpc.laravel_vpc.cidr_block, 8, count.index)
  availability_zone         = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch   = true

  tags = {
    Name = "laravel-subnet-${count.index}"
  }
}

resource "aws_security_group" "laravel_sg" {
  vpc_id = aws_vpc.laravel_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "laravel-sg"
  }
}

resource "aws_cloudwatch_log_group" "laravel_log_group" {
  name              = "laravel-log-group"
  retention_in_days = 7

  tags = {
    Name = "laravel-log-group"
  }
}

resource "aws_cloudwatch_log_group" "nginx_log_group" {
  name              = "nginx-log-group"
  retention_in_days = 7

  tags = {
    Name = "nginx-log-group"
  }
}

resource "aws_dynamodb_table" "laravel_table" {
  name         = "LaravelTable"
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "laravel-table"
  }
}

resource "aws_ecs_cluster" "laravel_cluster" {
  name = "laravel-cluster"
}

resource "aws_launch_configuration" "laravel_launch_config" {
  name          = "laravel-launch-configuration"
  image_id      = "ami-0ec0e125bb6c6e8ec" # Amazon Linux 2 AMI
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.laravel_cluster.name} >> /etc/ecs/ecs.config
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "example_lc" {
 name          = "laravel-launch-configuration"
  image_id      = "ami-0ec0e125bb6c6e8ec" # Amazon Linux 2 AMI
  instance_type = var.instance_type
  key_name      = var.key_name

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.example_cluster.name} >> /etc/ecs/ecs.config
    yum update -y
    yum install -y aws-cfn-bootstrap
    /opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource ECSAutoScalingGroup --region ${AWS::Region}
  EOF
}

resource "aws_autoscaling_group" "laravel_asg" {
  desired_capacity     = 2
  max_size             = 2
  min_size             = 1
  vpc_zone_identifier  = aws_subnet.laravel_subnet[*].id
  launch_configuration = aws_launch_configuration.laravel_launch_config.id

  tag {
    key                 = "Name"
    value               = "laravel-ecs-instance"
    propagate_at_launch = true
  }

  # Additional configuration options as needed
}

resource "aws_ecs_task_definition" "laravel_task" {
  family                   = "laravel-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "laravel-container"
      image     = "227275596988.dkr.ecr.ap-south-1.amazonaws.com/leaders-api-php-laravel:latest" # Replace with your image URI
      essential = true
      portMappings = [
        {
          containerPort = 9000
          hostPort      = 9000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.laravel_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "laravel"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:9000/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    },
    {
      name      = "nginx-container"
      image     = "227275596988.dkr.ecr.ap-south-1.amazonaws.com/leaders-api-nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.nginx_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "laravel_service" {
  name            = "laravel-service"
  cluster         = aws_ecs_cluster.laravel_cluster.id
  task_definition = aws_ecs_task_definition.laravel_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.laravel_subnet[*].id
    security_groups  = [aws_security_group.laravel_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.laravel_tg.arn
    container_name   = "nginx-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.laravel_listener]
}

resource "aws_lb" "laravel_lb" {
  name               = "laravel-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.laravel_sg.id]
  subnets            = aws_subnet.laravel_subnet[*].id

  enable_deletion_protection = false

  tags = {
    Name = "laravel-lb"
  }
}

resource "aws_lb_target_group" "laravel_tg" {
  name        = "laravel-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.laravel_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "laravel-tg"
  }
}

resource "aws_lb_listener" "laravel_listener" {
  load_balancer_arn = aws_lb.laravel_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.laravel_tg.arn
  }
}
