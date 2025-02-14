# VPC and Network Configuration
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dataops-hub-vpc"
  cidr = var.vpc_cidr

  azs              = var.availability_zones
  private_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets   = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + length(var.availability_zones))]
  database_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 2 * length(var.availability_zones))]

  create_database_subnet_group = false
  enable_nat_gateway          = true
  single_nat_gateway          = false
  enable_dns_hostnames        = true
  enable_dns_support          = true
  create_igw                  = true

  tags = {
    Environment = var.environment
    Project     = "dataops-hub"
    ManagedBy   = "terraform"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "dataops-hub-rds-sg"
  description = "Security group for RDS cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = var.database_port
    to_port         = var.database_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
    description     = "Allow access from application security group"
  }

  ingress {
    from_port   = var.database_port
    to_port     = var.database_port
    protocol    = "tcp"
    cidr_blocks = ["89.115.70.77/32"]
    description = "Allow PostgreSQL access from admin IP"
  }

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

# RDS Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier              = var.rds_cluster_identifier
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = var.engine_version
  database_name                   = var.database_name
  master_username                 = var.database_username
  master_password                 = random_password.master.result
  db_subnet_group_name            = aws_db_subnet_group.public.id
  vpc_security_group_ids          = [aws_security_group.rds.id]
  port                            = var.database_port
  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = "03:00-04:00"
  skip_final_snapshot            = true
  deletion_protection            = false # Temporarily disable deletion protection
  storage_encrypted              = var.storage_encrypted
  enabled_cloudwatch_logs_exports = ["postgresql"]

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      final_snapshot_identifier
    ]
  }

  depends_on = [module.vpc]
}

# Create a subnet group using public subnets
resource "aws_db_subnet_group" "public" {
  name       = "dataops-hub-public"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "dataops-hub-public"
  }
}

# RDS Cluster Instances
resource "aws_rds_cluster_instance" "instances" {
  count                        = 2
  identifier                   = "${var.rds_cluster_identifier}-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.main.id
  instance_class               = var.rds_instance_class
  engine                       = aws_rds_cluster.main.engine
  engine_version               = var.engine_version
  db_subnet_group_name         = aws_db_subnet_group.public.id
  auto_minor_version_upgrade   = true
  performance_insights_enabled = var.enable_performance_insights
  publicly_accessible         = true
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