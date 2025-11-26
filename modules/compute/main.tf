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
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Launch Template
resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-${var.environment}-${formatdate("YYYYMMDD-hhmm", timestamp())}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  key_name      = data.aws_key_pair.main.key_name

  vpc_security_group_ids = [var.ec2_security_group]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              apt update -y
              apt install -y apache2
              systemctl start apache2
              systemctl enable apache2
              
              # Create simple API endpoints
              cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head><title>Company Registration API</title></head>
<body>
<h1>Company Registration API</h1>
<p>Status: Running</p>
<p>Endpoints:</p>
<ul>
<li><a href="/health">/health</a> - Health check</li>
<li>/api/companies - Company registration</li>
</ul>
</body>
</html>
HTMLEOF
              
              # Create health endpoint
              mkdir -p /var/www/html/health
              cat > /var/www/html/health/index.html << 'HEALTHEOF'
{
  "status": "healthy",
  "timestamp": "$(date -Iseconds)",
  "message": "Company Registration API is running"
}
HEALTHEOF
              
              # Restart Apache
              systemctl restart apache2
              EOF
  )

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
  health_check_grace_period = 300
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

  tags = {
    Name = "${var.project_name}-${var.environment}-bastion"
  }
}