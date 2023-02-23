terraform {
  backend "s3" {
    bucket  = "zachschipono.com-terraform"
    key     = "computer_store/terraform.tfstate"
    region  = "us-west-1"
    profile = "personal"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = local.region
  profile = local.profile
}

locals {
  region  = "us-west-1"
  profile = "personal"
}

resource "aws_ecr_repository" "computer_store" {
  name                 = "computer_store"
  image_tag_mutability = "MUTABLE"

  lifecycle {
    prevent_destroy = true
  }
}


# RDS
resource "random_password" "rds_pg" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "private_subnets" {
  name       = "private_subnet_group"
  subnet_ids = [
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
  ]
  tags = {
    Name = "private-subnet-group"
  }
}

resource "aws_db_instance" "computer_store" {
  db_name                = "computer_store"
  allocated_storage      = 5
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  port                   = 5432
  username               = "computer_store_user"
  password               = random_password.rds_pg.result
  db_subnet_group_name   = aws_db_subnet_group.private_subnets.name
  vpc_security_group_ids = [aws_security_group.rds.id]
}


# ECS
resource "aws_ecs_task_definition" "backend_task_definition" {
  family = "computer_store"
  cpu    = 1024
  memory = 2048
  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.backend_task_execution_role.arn
  task_role_arn            = aws_iam_role.backend_task_role.arn
  container_definitions    = jsonencode([
    {
      name         = "computer_store"
      image        = "${aws_ecr_repository.computer_store.repository_url}:latest"
      portMappings = [
        {
          protocol      = "tcp"
          containerPort = 8080
          hostPort      = 8080
        }
      ]
      environment = [
        {
          name  = "DEBUG",
          value = "False"
        },
        {
          name  = "ENV",
          value = "production"
        },
        {
          name  = "POSTGRES_DB",
          value = aws_db_instance.computer_store.db_name
        },
        {
          name  = "POSTGRES_USER",
          value = aws_db_instance.computer_store.username
        },
        {
          name  = "POSTGRES_PASSWORD",
          value = aws_db_instance.computer_store.password
        },
        {
          name  = "POSTGRES_HOST",
          value = aws_db_instance.computer_store.address
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          awslogs-region        = local.region
          awslogs-group         = aws_cloudwatch_log_group.computer_store.name
          awslogs-stream-prefix = "backend"
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "computer_store" {
  name = "ecs/computer_store"
}

resource "aws_ecs_service" "backend" {
  name                   = "backend"
  task_definition        = aws_ecs_task_definition.backend_task_definition.arn
  launch_type            = "FARGATE"
  enable_execute_command = true
  desired_count          = 1
  cluster                = aws_ecs_cluster.computer_store.id

  network_configuration {
    assign_public_ip = false

    security_groups = [
      aws_security_group.egress_all.id,
      aws_security_group.ingress_api.id
    ]
    subnets = [
      aws_subnet.private_c.id,
      aws_subnet.private_b.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.computer_store.arn
    container_name   = "computer_store"
    container_port   = 8080
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_ecs_cluster" "computer_store" {
  name = "computer_store"
}


# Application Load Balancer
resource "aws_lb_target_group" "computer_store" {
  name        = "computer-store"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.computer_store.id

  health_check {
    enabled  = true
    path     = "/health"
    interval = 60
    timeout  = 30
    matcher  = "200"
  }

  depends_on = [aws_alb.computer_store]
}

resource "aws_alb" "computer_store" {
  name               = "computer-store"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_c.id,
    aws_subnet.public_b.id,
  ]

  security_groups = [
    aws_security_group.http.id,
    aws_security_group.https.id,
    aws_security_group.egress_all.id,
  ]

  depends_on = [aws_internet_gateway.internet_gateway]
}

resource "aws_alb_listener" "computer_store_http" {
  load_balancer_arn = aws_alb.computer_store.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "computer_store_https" {
  load_balancer_arn = aws_alb.computer_store.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.computer_store.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.computer_store.arn
  }
}


# IAM setup for ECS
resource "aws_iam_role" "backend_task_execution_role" {
  name               = "backend_task_execution_role"
  assume_role_policy = data.aws_iam_policy_document.backend_task_assume_role.json
}

data "aws_iam_policy_document" "backend_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "default_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "backend_task_default_execution_role" {
  role       = aws_iam_role.backend_task_execution_role.id
  policy_arn = data.aws_iam_policy.default_execution_role.arn
}


# - Task Role
resource "aws_iam_role" "backend_task_role" {
  name               = "backend_task_role"
  assume_role_policy = data.aws_iam_policy_document.backend_task_assume_role.json
}

data "aws_iam_policy_document" "backend_task_role" {
  statement {
    actions   = ["rds:*"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "backend_task_role" {
  name   = "backend_task_role_policy"
  role   = aws_iam_role.backend_task_role.id
  policy = data.aws_iam_policy_document.backend_task_role.json
}


# VPC
resource "aws_vpc" "computer_store" {
  cidr_block = "10.0.0.0/16"
}


# - Subnets
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.computer_store.id
  cidr_block        = "10.0.1.128/25"
  availability_zone = "${local.region}b"

  tags = {
    "Name" = "public-${local.region}b"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.computer_store.id
  cidr_block        = "10.0.2.128/25"
  availability_zone = "${local.region}b"

  tags = {
    "Name" = "private-${local.region}b"
  }
}

resource "aws_subnet" "public_c" {
  vpc_id            = aws_vpc.computer_store.id
  cidr_block        = "10.0.1.0/25"
  availability_zone = "${local.region}c"

  tags = {
    "Name" = "public-${local.region}c"
  }
}

resource "aws_subnet" "private_c" {
  vpc_id            = aws_vpc.computer_store.id
  cidr_block        = "10.0.2.0/25"
  availability_zone = "${local.region}c"

  tags = {
    "Name" = "private-${local.region}c"
  }
}


# - Route Tables & Gateways
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.computer_store.id
  tags   = {
    "Name" = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.computer_store.id
  tags   = {
    "Name" = "private"
  }
}

resource "aws_route_table_association" "public_b_subnet" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_b_subnet" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_c_subnet" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_c_subnet" {
  subnet_id      = aws_subnet.private_c.id
  route_table_id = aws_route_table.private.id
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.computer_store.id
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  subnet_id     = aws_subnet.public_b.id
  allocation_id = aws_eip.nat.id
  depends_on    = [aws_internet_gateway.internet_gateway]
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.id
}


# - Security Groups
resource "aws_security_group" "http" {
  name        = "http"
  description = "HTTP traffic"
  vpc_id      = aws_vpc.computer_store.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "https" {
  name        = "https"
  description = "HTTPS traffic"
  vpc_id      = aws_vpc.computer_store.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "egress_all" {
  name        = "egress-all"
  description = "Allow all outbound traffic"
  vpc_id      = aws_vpc.computer_store.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ingress_api" {
  name        = "ingress-api"
  description = "Allow ingress to API"
  vpc_id      = aws_vpc.computer_store.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "rds"
  description = "Allow access to DB Port"
  vpc_id      = aws_vpc.computer_store.id

  ingress {
    from_port   = "5432"
    to_port     = "5432"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Domain & Cert
resource "aws_acm_certificate" "computer_store" {
  domain_name       = "store.zschipono.com"
  validation_method = "DNS"
}

data "aws_route53_zone" "computer_store" {
  name         = "zschipono.com"
  private_zone = false
}

resource "aws_route53_record" "computer_store" {
  for_each = {
    for dvo in aws_acm_certificate.computer_store.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.computer_store.zone_id
}

resource "aws_acm_certificate_validation" "computer_store" {
  certificate_arn         = aws_acm_certificate.computer_store.arn
  validation_record_fqdns = [for record in aws_route53_record.computer_store : record.fqdn]
}

resource "aws_route53_record" "computer_store_alias" {
  name    = "store.zschipono.com"
  type    = "A"
  zone_id = data.aws_route53_zone.computer_store.zone_id

  alias {
    name                   = aws_alb.computer_store.dns_name
    zone_id                = aws_alb.computer_store.zone_id
    evaluate_target_health = true
  }
}
