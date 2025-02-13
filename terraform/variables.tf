variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r5.large"
}

variable "rds_cluster_identifier" {
  description = "RDS cluster identifier"
  type        = string
  default     = "dataops-hub-cluster"
}

variable "database_name" {
  description = "Name of the database"
  type        = string
  default     = "dataops_hub"
}

variable "database_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "database_port" {
  description = "Port for database connections"
  type        = number
  default     = 5432
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "countries" {
  description = "List of countries"
  type        = list(string)
  default     = ["Germany", "France", "Italy", "Spain", "Portugal"]
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
} 