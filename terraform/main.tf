terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "devops-challenge"
}

data "aws_caller_identity" "current" {}

module "ecr" {
  source       = "./modules/ecr"
  project_name = "damolak-devops-challenge"
}
module "network" {
  source       = "./modules/network"
  project_name = "damolak-devops-challenge"
}
output "aws_account_id" {
  description = "AWS account used by Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_identity_arn" {
  description = "Identity Terraform uses to access AWS"
  value       = data.aws_caller_identity.current.arn
}

output "ecr_repository_url" {
  description = "Private ECR repository URL"
  value       = module.ecr.repository_url
}
output "vpc_id" {
  description = "ID of the project VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for the load balancer"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  value       = module.network.private_subnet_ids
}

output "alb_security_group_id" {
  description = "Security group ID for the load balancer"
  value       = module.network.alb_security_group_id
}

output "app_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = module.network.app_security_group_id
}
module "ecs" {
  source = "./modules/ecs"

  project_name          = "damolak-devops-challenge"
  ecr_repository_url    = module.ecr.repository_url
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.network.alb_security_group_id
  app_security_group_id = module.network.app_security_group_id
}

output "alb_dns_name" {
  description = "Public URL hostname for the application"
  value       = module.ecs.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.ecs_service_name
}

# Allow GitHub Actions to authenticate to AWS using OIDC.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name    = "github-actions-oidc"
    Project = "damolak-devops-challenge"
  }
}

output "github_actions_oidc_provider_arn" {
  description = "GitHub Actions OIDC identity provider ARN"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
# IAM role assumed by GitHub Actions from the main branch only.
resource "aws_iam_role" "github_actions" {
  name = "damolak-devops-challenge-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:10Johnny/damolak-devops-challenge:ref:refs/heads/main"
        }
      }
    }]
  })

  tags = {
    Project = "damolak-devops-challenge"
  }
}

# Permissions for pushing images and updating the ECS deployment.
resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "damolak-devops-challenge-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = "arn:aws:ecr:us-east-1:${data.aws_caller_identity.current.account_id}:repository/damolak-devops-challenge-api"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService"
        ]
        Resource = "arn:aws:ecs:us-east-1:${data.aws_caller_identity.current.account_id}:service/damolak-devops-challenge/damolak-devops-challenge-service"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/damolak-devops-challenge-ecs-execution"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "IAM role assumed by GitHub Actions for deployment"
  value       = aws_iam_role.github_actions.arn
}