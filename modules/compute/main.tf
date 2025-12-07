# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Use existing key pair
data "aws_key_pair" "main" {
  key_name = "argo-key-pair"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg-${formatdate("MMDDhhmm", timestamp())}"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "5000"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

# ALB Listener - HTTP
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.main.arn
      }
    }
  }
}

# IAM Role for EC2 SSM
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-${var.environment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM policy for SSM Parameter Store access
resource "aws_iam_role_policy" "ssm_parameter_access" {
  name = "${var.project_name}-${var.environment}-ssm-params"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/aws-sec-pillar/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-${formatdate("YYYYMMDD-hhmm", timestamp())}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = data.aws_key_pair.main.key_name

  vpc_security_group_ids = [var.ec2_security_group]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(file("${path.module}/../../scripts/setup-backend.sh"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-${var.environment}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 600
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg"
    propagate_at_launch = false
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = data.aws_key_pair.main.key_name
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_security_group]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(file("${path.module}/../../scripts/setup-bastion.sh"))

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }
}