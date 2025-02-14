# VPC and Network Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dataops-hub-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets   = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + length(var.availability_zones))]
  database_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 2 * length(var.availability_zones))]

  enable_nat_gateway = true
  single_nat_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group = true

  # Use NAT Gateway for outbound connectivity
  create_database_subnet_route_table     = false
  create_database_internet_gateway_route = false
  create_database_nat_gateway_route      = false
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "dataops-hub-rds-sg"
  description = "Security group for RDS cluster"
  vpc_id      = module.vpc.vpc_id

  # Allow access from application security group
  ingress {
    from_port       = var.database_port
    to_port         = var.database_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Allow access from admin IP
  ingress {
    from_port   = var.database_port
    to_port     = var.database_port
    protocol    = "tcp"
    cidr_blocks = ["89.115.70.77/32"]
    description = "Allow PostgreSQL access from admin IP"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "dataops-hub-rds-sg"
  }
}

# Security Group for Application
resource "aws_security_group" "app" {
  name        = "dataops-hub-app-sg"
  description = "Security group for application"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dataops-hub-app-sg"
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name        = "dataops-hub-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["89.115.70.77/32"]
    description = "Allow SSH from admin IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dataops-hub-bastion-sg"
  }
}

# Bastion Host
resource "aws_instance" "bastion" {
  ami                         = "ami-0faab6bdbac9486fb" # Amazon Linux 2023
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.bastion.id]
  key_name              = "dataops-hub-bastion"

  user_data = <<-EOF
  #!/bin/bash
  dnf update -y
  dnf install -y postgresql15
  EOF

  tags = {
    Name = "dataops-hub-bastion"
  }
}

# Update RDS security group to allow access from bastion
resource "aws_security_group_rule" "rds_bastion" {
  type                     = "ingress"
  from_port                = var.database_port
  to_port                  = var.database_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion.id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow PostgreSQL access from bastion host"
}

# RDS Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier = var.rds_cluster_identifier
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = var.database_name
  master_username    = var.database_username
  master_password    = random_password.master.result

  skip_final_snapshot = var.skip_final_snapshot
  deletion_protection = var.deletion_protection
  storage_encrypted   = var.storage_encrypted

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  depends_on = [module.vpc]
}

# RDS Cluster Instances
resource "aws_rds_cluster_instance" "instances" {
  count              = 2
  identifier         = "${var.rds_cluster_identifier}-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.rds_instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = var.engine_version

  auto_minor_version_upgrade   = true
  performance_insights_enabled = var.enable_performance_insights
}

# Generate random master password for RDS
resource "random_password" "master" {
  length  = 16
  special = true
}

# Store database credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "dataops-hub/rds-credentials"
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = var.database_username
    password = random_password.master.result
    host     = aws_rds_cluster.main.endpoint
    port     = var.database_port
    dbname   = var.database_name
  })
}

# S3 Bucket for data storage
resource "aws_s3_bucket" "data" {
  bucket = "dataops-hub-data"
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Output important information
output "rds_cluster_endpoint" {
  description = "RDS cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = aws_rds_cluster.main.reader_endpoint
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.data.id
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing RDS credentials"
  value       = aws_secretsmanager_secret.rds_credentials.name
}

# Add bastion host public IP output
output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}