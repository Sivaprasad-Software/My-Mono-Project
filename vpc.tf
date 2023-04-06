provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIATAGFDTG4T5XDHH4E"
  secret_key = "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"
}
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "engro-vpc"
  }
}
resource "aws_subnet" "public_sn" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "engro-public-subnet"
  }
}
resource "aws_subnet" "private_sn" {
  vpc_id     = aws_vpc.my_vpc.id
  availability_zone = "ap-south-1b"
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "engro-private-subnet"
  }
}
resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "engro-gateway"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gateway.id
  }
  tags = {
    Name = "public_route_table"
  }
}
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "private_route_table"
  }
}
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_sn.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "private_association" {
  subnet_id      = aws_subnet.private_sn.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_ecs_cluster" "my_cluster" {
  name = "egro-cluster"
}
resource "aws_ecs_task_definition" "my_task_definition" {
  family = "my-task"
  container_definitions = jsonencode([{
    name  = "nginx"
    image = "nginx:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
  cpu                      = 512
  memory                   = 1024
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
}
resource "aws_security_group" "ecs-sg" {
  name_prefix = "ecs-"
  vpc_id      = aws_vpc.my_vpc.id
  tags = {
    Name = "engro-sg"
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "my_service" {
  name            = "my-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    assign_public_ip = true
    subnets          = [aws_subnet.public_sn.id]
    security_groups  = [aws_security_group.ecs-sg.id]
  }
load_balancer {
    target_group_arn = aws_lb_target_group.my_lb_target_group.arn
    container_name   = "nginx"
    container_port   = 80
  }
}
resource "aws_s3_bucket" "my_bucket" {
  bucket = "egro-siva-bucket916"
  acl    = "private"
  tags   = {
    Environment = "test"
  }
}
resource "aws_s3_bucket_policy" "my_bucket_policy" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowAccessFromEC2Role"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:role/ec2-role"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ]
  })
}
resource "aws_lb" "my_lb" {
  name = "egro-lb"
  subnets = [aws_subnet.public_sn.id,aws_subnet.private_sn.id]
  security_groups = [aws_security_group.ecs-sg.id]
  load_balancer_type = "application"

  access_logs {
    bucket = "egro-siva-bucket916"
    enabled = true
    prefix = "engro-lb"
  }

  tags = {
    Name = "engro-lb"
  }
}
resource "aws_lb_target_group" "my_lb_target_group" {
  name_prefix = "my-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
}
resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.my_lb_target_group.arn
    type = "forward"
  }
}



