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
# DATA SOURCES
########################################
data "aws_caller_identity" "current" {}

data "aws_iam_account_alias" "current" {}

########################################
# VARIABLES
########################################
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

  bucket = "cur-${data.aws_iam_account_alias.current.account_alias}-${data.aws_caller_identity.current.account_id}"

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
          "s3:GetBucketPolicy",
          "s3:GetBucketLocation"
        ]

        Resource = aws_s3_bucket.cur_bucket.arn
      },
      {
        Effect = "Allow"

        Principal = {
          Service = "billingreports.amazonaws.com"
        }

        Action = "s3:PutObject"

        Resource = "${aws_s3_bucket.cur_bucket.arn}/*"
      }
    ]
  })
}

########################################
# COST AND USAGE REPORT (LEGACY CUR)
########################################
resource "aws_cur_report_definition" "cur_report_legacy" {

  report_name = "${var.cur_report_name}-legacy"

  time_unit   = "HOURLY"

  format      = "textORcsv"
  compression = "GZIP"

  additional_schema_elements = [
    "RESOURCES"
  ]

  s3_bucket = aws_s3_bucket.cur_bucket.bucket
  s3_region = "us-east-1"
  s3_prefix = "cur-legacy"

  report_versioning = "OVERWRITE_REPORT"
}

########################################
# COST AND USAGE REPORT (CUR 2.0)
########################################
resource "aws_cur_report_definition" "cur_report_v2" {

  report_name = "${var.cur_report_name}-v2"

  time_unit   = "HOURLY"

  format      = "Parquet"
  compression = "Parquet"

  additional_schema_elements = [
    "RESOURCES"
  ]

  s3_bucket = aws_s3_bucket.cur_bucket.bucket
  s3_region = "us-east-1"
  s3_prefix = "cur-v2"

  report_versioning = "OVERWRITE_REPORT"

  refresh_closed_reports = true
}

########################################
# IAM USER
########################################
resource "aws_iam_user" "cur_user" {
  name = var.iam_user_name
}

########################################
# IAM ACCESS KEY
########################################
resource "aws_iam_access_key" "cur_user_access_key" {

  user = aws_iam_user.cur_user.name

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
    "account:GetPrimaryEmail",
    "account:ListRegions",
    "iam:CreateServiceLinkedRole",
    "iam:DeleteServiceLinkedRole",
    "iam:ListRoles",
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
     "ec2:Describe*",
     "cloudwatch:GetMetricStatistics",
     "iam:GetAccessKeyLastUsed",
     "iam:ListUsers",
     "iam:GetLoginProfile",
     "iam:ListAccessKeys",
     "s3:ListAllMyBuckets",
     "s3:GetBucketLocation",
     "cur:DescribeReportDefinitions",
     "ce:GetCostAndUsage",
     "ce:GetReservationPurchaseRecommendation",
     "ce:GetSavingsPlansPurchaseRecommendation",
     "ce:GetRightsizingRecommendation",
     "support:DescribeTrustedAdvisorChecks",
     "support:DescribeTrustedAdvisorCheckSummaries",
     "support:DescribeTrustedAdvisorCheckResult"
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

########################################
# OUTPUTS
########################################

output "iam_user_name" {
  value = aws_iam_user.cur_user.name
}

output "access_key_id" {
  value = aws_iam_access_key.cur_user_access_key.id
}

output "secret_access_key" {
  value = aws_iam_access_key.cur_user_access_key.secret
}
