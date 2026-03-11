########################################
# Terraform Provider
########################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

########################################
# VARIABLES
########################################
variable "bucket_name" {
  default = "terraform-cur-demo-bucket-12345"
}

variable "iam_user_name" {
  default = "cur-report-user"
}

variable "cur_report_name" {
  default = "terraform-cur-report"
}

########################################
# S3 BUCKET FOR CUR
########################################
resource "aws_s3_bucket" "cur_bucket" {
  bucket = var.bucket_name
}

########################################
# S3 BUCKET POLICY FOR CUR
########################################
resource "aws_s3_bucket_policy" "cur_policy" {

  bucket = aws_s3_bucket.cur_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "billingreports.amazonaws.com"
        }

        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketPolicy"
        ]

        Resource = "arn:aws:s3:::${var.bucket_name}"
      },
      {
        Effect = "Allow"

        Principal = {
          Service = "billingreports.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = "arn:aws:s3:::${var.bucket_name}/*"
      }
    ]
  })
}

########################################
# COST AND USAGE REPORT
########################################
resource "aws_cur_report_definition" "cur_report" {

  report_name = var.cur_report_name
  time_unit   = "HOURLY"

  format      = "textORcsv"
  compression = "GZIP"

  additional_schema_elements = [
    "RESOURCES"
  ]

  s3_bucket = aws_s3_bucket.cur_bucket.bucket
  s3_region = "us-east-1"
  s3_prefix = "cur-report"

  report_versioning = "OVERWRITE_REPORT"
}

########################################
# IAM USER
########################################
resource "aws_iam_user" "cur_user" {
  name = var.iam_user_name
}

########################################
# POLICY 1
########################################
resource "aws_iam_policy" "account_org_policy" {

  name        = "account-org"
  description = "Account and Organization access policy"

  policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "NotAction": [
    "iam:*",
    "organizations:*",
    "account:*"
   ],
   "Resource": "*"
  },
  {
   "Effect": "Allow",
   "Action": [
    "account:GetAccountInformation",
    "account:GetGovCloudAccountInformation",
    "account:GetPrimaryEmail",
    "account:ListRegions",
    "iam:CreateServiceLinkedRole",
    "iam:DeleteServiceLinkedRole",
    "iam:ListRoles",
    "organizations:DescribeEffectivePolicy",
    "organizations:DescribeOrganization"
   ],
   "Resource": "*"
  }
 ]
}
POLICY
}

########################################
# POLICY 2
########################################
resource "aws_iam_policy" "cloudscore_policy" {

  name        = "cloudscore"
  description = "Cloud cost and monitoring operations policy"

  policy = <<POLICY
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Sid": "CloudscoreDocOperations",
   "Effect": "Allow",
   "Action": [
    "s3:Get*",
    "s3:List*",
    "s3:PutObject",
    "s3:GetObject",
    "s3:PutBucketPolicy",
    "ec2:Describe*",
    "cloudwatch:GetMetricStatistics",
    "iam:GetAccessKeyLastUsed",
    "iam:ListUsers",
    "iam:GetLoginProfile",
    "iam:ListAccessKeys",
    "ce:GetCostAndUsage",
    "ce:GetReservationPurchaseRecommendation",
    "ce:GetSavingsPlansPurchaseRecommendation",
    "ce:GetRightsizingRecommendation",
    "cur:DescribeReportDefinitions",
    "cur:PutReportDefinition",
    "sts:GetCallerIdentity",
    "sts:AssumeRole",
    "sts:GetSessionToken",
    "support:DescribeTrustedAdvisorChecks",
    "support:DescribeTrustedAdvisorCheckSummaries",
    "support:DescribeTrustedAdvisorCheckResult",
    "support:RefreshTrustedAdvisorCheck"
   ],
   "Resource": "*"
  }
 ]
}
POLICY
}

########################################
# ATTACH POLICY 1
########################################
resource "aws_iam_user_policy_attachment" "attach_policy1" {

  user       = aws_iam_user.cur_user.name
  policy_arn = aws_iam_policy.account_org_policy.arn

}

########################################
# ATTACH POLICY 2
########################################
resource "aws_iam_user_policy_attachment" "attach_policy2" {

  user       = aws_iam_user.cur_user.name
  policy_arn = aws_iam_policy.cloudscore_policy.arn

}
