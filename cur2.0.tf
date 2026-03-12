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
# S3 BUCKET FOR CUR (DYNAMIC NAME)
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
# POLICY 2 (UPDATED CLOUDSCORE POLICY)
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
   {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudscoreDocOperations",
            "Effect": "Allow",
            "Action": [
                "s3:Get*",
                "iam:GetAccessKeyLastUsed",
                "cloudwatch:GetMetricStatistics",
                "ec2:Describe*",
                "s3:ListAllMyBuckets",
                "iam:ListUsers",
                "iam:GetLoginProfile",
                "cur:DescribeReportDefinitions",
                "account:Get*",
                "account:GetContactInformation",
                "account:List*",
                "billing:Get*",
                "billing:ListBillingViews",
                "billing:PutContractInformation",
                "billing:Update*",
                "ce:CreateCostCategoryDefinition",
                "ce:DeleteCostCategoryDefinition",
                "ce:DescribeCostCategoryDefinition",
                "ce:GetCostAndUsage",
                "ce:ListCostAllocationTags",
                "ce:ListCostCategoryDefinitions",
                "ce:ListTagsForResource",
                "ce:TagResource",
                "ce:UntagResource",
                "ce:UpdateCostAllocationTagsStatus",
                "ce:UpdateCostCategoryDefinition",
                "consolidatedbilling:Get*",
                "consolidatedbilling:GetAccountBillingRole",
                "consolidatedbilling:List*",
                "cur:DeleteReportDefinition",
                "cur:DescribeReportDefinitions",
                "cur:Get*",
                "cur:GetClassic*",
                "cur:GetUsage*",
                "cur:ModifyReportDefinition",
                "cur:PutClassic*",
                "cur:PutReportDefinition",
                "cur:Validate*",
                "freetier:Get*",
                "invoicing:Get*",
                "invoicing:List*",
                "payments:CreatePaymentInstrument",
                "payments:DeletePaymentInstrument",
                "payments:Get*",
                "payments:List*",
                "pricing:DescribeServices",
                "purchase-orders:AddPurchaseOrder",
                "purchase-orders:DeletePurchaseOrder",
                "purchase-orders:GetPurchaseOrder",
                "purchase-orders:ListPurchaseOrderInvoices",
                "purchase-orders:ListPurchaseOrders",
                "purchase-orders:UpdatePurchaseOrder",
                "purchase-orders:UpdatePurchaseOrderStatus",
                "s3:PutBucketAcl",
                "s3:PutAccountPublicAccessBlock",
                "s3:ListJobs",
                "s3:DescribeMultiRegionAccessPointOperation",
                "s3:ListMultipartUploadParts",
                "s3:PutObject",
                "s3:GetObject",
                "s3:DescribeJob",
                "s3:ListBucketVersions",
                "s3:ListBucket",
                "s3:PutObjectAcl",
                "s3:GetBucketPublicAccessBlock",
                "s3:GetMultiRegionAccessPointPolicyStatus",
                "s3:ListBucketMultipartUploads",
                "s3:PutBucketPublicAccessBlock",
                "s3:ListAllMyBuckets",
                "s3:GetBucketCORS",
                "s3:GetBucketLocation",
                "s3:GetAccessPointPolicy",
                "s3:GetObjectVersion",
                "s3:GetBucketLocation",
                "s3:ListAllMyBuckets",
                "s3:PutBucketPolicy",
                "support:AddAttachmentsToSet",
                "sustainability:GetCarbonFootprintSummary",
                "tax:BatchPut*",
                "tax:Get*",
                "tax:List*",
                "tax:Put*",
                "tax:UpdateExemptions",
                "s3:GetBucketPublicAccessBlock",
                "s3:GetBucketPolicyStatus",
                "s3:GetBucketTagging",
                "iam:GetAccessKeyLastUsed",
                "cloudwatch:GetMetricStatistics",
                "ec2:Describe*",
                "s3:ListAllMyBuckets",
                "iam:ListUsers",
                "s3:GetBucketLocation",
                "iam:GetLoginProfile",
                "iam:ListAccessKeys",
                "sts:GetSessionToken",
                "sts:AssumeRole",
                "sts:GetFederationToken",
                "sts:SetSourceIdentity",
                "sts:DecodeAuthorizationMessage",
                "sts:GetAccessKeyInfo",
                "sts:GetCallerIdentity",
                "sts:GetServiceBearerToken",
                "iam:ListAccessKeys",
                "ce:GetReservationPurchaseRecommendation",
                "ce:GetSavingsPlansPurchaseRecommendation",
                "ce:GetRightsizingRecommendation",
                "support:DescribeTrustedAdvisorChecks",
                "support:DescribeTrustedAdvisorCheckSummaries",
                "support:RefreshTrustedAdvisorCheck",
                "support:DescribeTrustedAdvisorCheckResult"
            ],
            "Resource": "*"
        }
    ]
}
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
