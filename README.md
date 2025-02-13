# DataOps Hub

A comprehensive data warehouse solution for banking data across European countries using AWS infrastructure.

## Project Overview

This project implements a data warehouse solution for banking transaction data across multiple European countries. It uses AWS services and follows DevOps best practices for deployment and management.

### Tech Stack

- **Cloud Platform**: AWS
- **ETL Processing**: Python, Apache Spark, Scala
- **Database**: Amazon RDS (PostgreSQL)
- **CI/CD**: GitHub Actions
- **Infrastructure as Code**: Terraform
- **Containerization**: Docker, Kubernetes

## Project Structure

```
dataops-hub/
├── terraform/           # Infrastructure as Code
├── src/                # Source code
│   ├── etl/            # ETL jobs
│   ├── data_generator/ # Data generation scripts
│   └── utils/          # Utility functions
├── k8s/                # Kubernetes manifests
├── docker/             # Docker configurations
├── .github/            # GitHub Actions workflows
└── tests/              # Test suites
```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0.0
- Docker
- kubectl
- Python >= 3.8
- Java >= 8 (for Spark)

## Setup Instructions

1. Configure AWS credentials:
```bash
aws configure
```

2. Initialize Terraform:
```bash
cd terraform
terraform init
```

3. Deploy infrastructure:
```bash
terraform plan
terraform apply
```

4. Build and deploy ETL jobs:
```bash
cd src/etl
docker build -t dataops-hub-etl .
```

## Security

- All sensitive data is encrypted at rest and in transit
- IAM roles follow the principle of least privilege
- Network security groups restrict access to resources
- Secrets are managed through AWS Secrets Manager

## Contributing

Please follow the standard Git flow process:
1. Create a feature branch
2. Make changes
3. Submit a pull request

## License

MIT License 