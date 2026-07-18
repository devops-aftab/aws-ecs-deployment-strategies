# ==========================================
# 1. NETWORKING: MULTI-AZ VPC & IGW
# ==========================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "ecs-ec2-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "ecs-ec2-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "ecs-public-subnet-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "ecs-public-subnet-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "ecs-public-rt" }
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
# 2. SECURITY GROUPS (ALB & EC2 Hosts)
# ==========================================
resource "aws_security_group" "alb_sg" {
  name        = "ecs-alb-sg"
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

resource "aws_security_group" "ec2_sg" {
  name        = "ecs-ec2-host-sg"
  description = "Controls traffic reaching physical EC2 host instances"
  vpc_id      = aws_vpc.main.id

  # Connects the ALB to the host's dynamic container ports
  ingress {
    description     = "Allows traffic only from ALB to dynamic host ports"
    from_port       = 0
    to_port         = 65535
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
  name               = "ecs-ec2-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "ecs_tg" {
  name        = "ecs-ec2-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # Crucial for EC2 cluster mapping

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
# 4. IAM SECURITY ROLES (Deep Drill Configuration)
# ==========================================

# ROLE A: ECS Instance Profile (attached to EC2 host machine)
# 1. Define the trust "hat" (EC2 is trusted to wear it)
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

# 2. Add the permissions (What the hat-wearer is actually allowed to do)
resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# 3. Create the "lanyard" so EC2 can wear the badge
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile" 
  role = aws_iam_role.ecs_instance_role.name
}

# ROLE B: ECS Task Execution Role (allows container engine to pull/execute tasks)
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"

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

# ==========================================
# 5. AUTO SCALING GROUP & LAUNCH TEMPLATE
# ==========================================

# Dynamic lookup of the latest official, AWS ECS-Optimized Amazon Linux 2 AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_template" {
  name_prefix   = "ecs-host-template-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance_profile.arn
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  # Dynamically render and inject our userdata script, passing the cluster name
  user_data = base64encode(templatefile("userdata.sh", {
    cluster_name = aws_ecs_cluster.main.name
  }))

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "ecs_asg" {
  name                = "ecs-asg"
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  launch_template {
    id      = aws_launch_template.ecs_template.id
    version = "$Latest"
  }

  min_size     = 1
  max_size     = 3
  desired_capacity = 2 # Starts 2 EC2 instances to demonstrate multi-AZ load balancing

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# ==========================================
# 6. ECS CLUSTER, TASK & SERVICE DEFINITION
# ==========================================
resource "aws_ecs_cluster" "main" {
  name = "portfolio-ecs-ec2-cluster"
}

# Task Definition Blueprint
resource "aws_ecs_task_definition" "web_task" {
  family             = "ecs-web-app-task"
  network_mode       = "bridge" # Uses native Docker bridge networking on the EC2 host
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = "nginxdemos/hello:latest" # Lightweight demo app showing Hostname/IP addresses dynamically
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 0 # Setting hostPort to 0 instructs AWS to use Dynamic Host Port Mapping!
        }
      ]
    }
  ])
}

# ECS Service Orchestrator
resource "aws_ecs_service" "web_service" {
  name            = "ecs-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web_task.arn
  desired_count   = 2 # Keeps 2 container tasks running across our host fleet

  # Tells the ECS Service how to register dynamic ports to our ALB Target Group
  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg.arn
    container_name   = "web-app"
    container_port   = 80
  }

  # Ensure the Auto Scaling Group instances boot up first before deploying the service
  depends_on = [
    aws_lb_listener.http_listener,
    aws_autoscaling_group.ecs_asg
  ]
}