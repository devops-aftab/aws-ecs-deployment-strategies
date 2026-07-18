# ==========================================
# 1. NETWORKING: MULTI-AZ VPC & IGW
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "ecs-fargate-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "ecs-fargate-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "ecs-fargate-public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "ecs-fargate-public-subnet-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "ecs-fargate-public-rt" }
}

resource "aws_route_table_association" "assoc_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ==========================================
# 2. SECURITY GROUPS (ALB & Fargate Tasks)
# ==========================================
resource "aws_security_group" "alb_sg" {
  name        = "ecs-fargate-alb-sg"
  description = "Allows public HTTP traffic to the load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "fargate_task_sg" {
  name        = "ecs-fargate-task-sg"
  description = "Controls traffic reaching the serverless Fargate tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allows traffic only from ALB directly to container port 80"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 3. APPLICATION LOAD BALANCER (ALB)
# ==========================================
resource "aws_lb" "ecs_alb" {
  name               = "ecs-fargate-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-fargate-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Crucial: Fargate requires 'ip' targets due to awsvpc networking mode

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_tg.arn
  }
}

# ==========================================
# 4. IAM SECURITY ROLES & OBSERVABILITY
# ==========================================

# ECS Task Execution Role (allows container engine to pull images and route logs)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-fargate-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# CloudWatch Log Group for streaming container output standard logs
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/fargate-web-app"
  retention_in_days = 7
}

# ==========================================
# 5. ECS CLUSTER, TASK & SERVICE DEFINITION
# ==========================================
resource "aws_ecs_cluster" "main" {
  name = "portfolio-ecs-fargate-cluster"
}

# Task Definition Blueprint
resource "aws_ecs_task_definition" "web_task" {
  family                   = "ecs-fargate-web-app-task"
  network_mode             = "awsvpc" # Mandatory for Fargate configurations
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"    # Explicitly declared at the task level for Fargate
  memory                   = "512"    # Explicitly declared at the task level for Fargate
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = "nginxdemos/hello:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80 # Must match containerPort exactly under awsvpc mode
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    }
  ])
}

# ECS Service Orchestrator
resource "aws_ecs_service" "web_service" {
  name            = "ecs-fargate-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  # Necessary block to map networking allocations directly onto the serverless task
  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.fargate_task_sg.id]
    assign_public_ip = true # Required to fetch images from DockerHub over the public IGW
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "web-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http_listener]
}