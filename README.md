=========================================================================================================== Cloud Formation ===========================================================
AWSTemplateFormatVersion: "2010-09-09"
Description: CUR Report + IAM User + Policies

Parameters:
  BucketName:
    Type: String
    Default: terraform-cur-demo-bucket-12345

  IAMUserName:
    Type: String
    Default: cur-report-user

  CURReportName:
    Type: String
    Default: terraform-cur-report

Resources:

########################################
# S3 BUCKET
########################################
  CURBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Ref BucketName

########################################
# S3 BUCKET POLICY
########################################
  CURBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref CURBucket
      PolicyDocument:
        Version: "2012-10-17"
        Statement:

          - Effect: Allow
            Principal:
              Service: billingreports.amazonaws.com
            Action:
              - s3:GetBucketAcl
              - s3:GetBucketPolicy
            Resource: !Sub arn:aws:s3:::${BucketName}

          - Effect: Allow
            Principal:
              Service: billingreports.amazonaws.com
            Action:
              - s3:PutObject
            Resource: !Sub arn:aws:s3:::${BucketName}/*

########################################
# COST AND USAGE REPORT
########################################
  CURReport:
    Type: AWS::CUR::ReportDefinition
    Properties:
      ReportName: !Ref CURReportName
      TimeUnit: HOURLY
      Format: textORcsv
      Compression: GZIP
      AdditionalSchemaElements:
        - RESOURCES
      S3Bucket: !Ref BucketName
      S3Region: us-east-1
      S3Prefix: cur-report
      ReportVersioning: OVERWRITE_REPORT

########################################
# IAM USER
########################################
  CURUser:
    Type: AWS::IAM::User
    Properties:
      UserName: !Ref IAMUserName

########################################
# POLICY 1
########################################
  AccountOrgPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: account-org
      Users:
        - !Ref CURUser
      PolicyDocument:
        Version: "2012-10-17"
        Statement:

          - Effect: Allow
            NotAction:
              - iam:*
              - organizations:*
              - account:*
            Resource: "*"

          - Effect: Allow
            Action:
              - account:GetAccountInformation
              - account:GetGovCloudAccountInformation
              - account:GetPrimaryEmail
              - account:ListRegions
              - iam:CreateServiceLinkedRole
              - iam:DeleteServiceLinkedRole
              - iam:ListRoles
              - organizations:DescribeEffectivePolicy
              - organizations:DescribeOrganization
            Resource: "*"

########################################
# POLICY 2
########################################
  CloudscorePolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: cloudscore
      Users:
        - !Ref CURUser
      PolicyDocument:
        Version: "2012-10-17"
        Statement:

          - Sid: CloudscoreDocOperations
            Effect: Allow
            Action:
              - s3:Get*
              - s3:List*
              - s3:PutObject
              - s3:GetObject
              - s3:PutBucketPolicy
              - ec2:Describe*
              - cloudwatch:GetMetricStatistics
              - iam:GetAccessKeyLastUsed
              - iam:ListUsers
              - iam:GetLoginProfile
              - iam:ListAccessKeys
              - ce:GetCostAndUsage
              - ce:GetReservationPurchaseRecommendation
              - ce:GetSavingsPlansPurchaseRecommendation
              - ce:GetRightsizingRecommendation
              - cur:DescribeReportDefinitions
              - cur:PutReportDefinition
              - sts:GetCallerIdentity
              - sts:AssumeRole
              - sts:GetSessionToken
              - support:DescribeTrustedAdvisorChecks
              - support:DescribeTrustedAdvisorCheckSummaries
              - support:DescribeTrustedAdvisorCheckResult
              - support:RefreshTrustedAdvisorCheck
            Resource: "*"
			
			
			
			aws cloudformation create-stack \
--stack-name cur-stack \
--template-body file://cur-template.yaml \
--capabilities CAPABILITY_NAMED_IAM

====================================================================== Single AWS CLI Script============================================================================================
#!/bin/bash

# VARIABLES
BUCKET_NAME="terraform-cur-demo-bucket-12345"
USER_NAME="cur-report-user"
CUR_REPORT_NAME="terraform-cur-report"
REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Creating S3 bucket..."
aws s3api create-bucket \
--bucket $BUCKET_NAME \
--region $REGION

echo "Creating bucket policy..."
cat > bucket-policy.json <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
  {
   "Effect": "Allow",
   "Principal": { "Service": "billingreports.amazonaws.com" },
   "Action": [
    "s3:GetBucketAcl",
    "s3:GetBucketPolicy"
   ],
   "Resource": "arn:aws:s3:::$BUCKET_NAME"
  },
  {
   "Effect": "Allow",
   "Principal": { "Service": "billingreports.amazonaws.com" },
   "Action": "s3:PutObject",
   "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
  }
 ]
}
EOF

aws s3api put-bucket-policy \
--bucket $BUCKET_NAME \
--policy file://bucket-policy.json

echo "Creating CUR report..."
cat > cur-report.json <<EOF
{
 "ReportName": "$CUR_REPORT_NAME",
 "TimeUnit": "HOURLY",
 "Format": "textORcsv",
 "Compression": "GZIP",
 "AdditionalSchemaElements": ["RESOURCES"],
 "S3Bucket": "$BUCKET_NAME",
 "S3Region": "$REGION",
 "S3Prefix": "cur-report",
 "ReportVersioning": "OVERWRITE_REPORT"
}
EOF

aws cur put-report-definition \
--region $REGION \
--report-definition file://cur-report.json

echo "Creating IAM user..."
aws iam create-user \
--user-name $USER_NAME

echo "Creating policy 1..."
cat > account-org-policy.json <<EOF
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
EOF

aws iam create-policy \
--policy-name account-org \
--policy-document file://account-org-policy.json

echo "Creating policy 2..."
cat > cloudscore-policy.json <<EOF
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
EOF

aws iam create-policy \
--policy-name cloudscore \
--policy-document file://cloudscore-policy.json

echo "Attaching policies..."

aws iam attach-user-policy \
--user-name $USER_NAME \
--policy-arn arn:aws:iam::$ACCOUNT_ID:policy/account-org

aws iam attach-user-policy \
--user-name $USER_NAME \
--policy-arn arn:aws:iam::$ACCOUNT_ID:policy/cloudscore

echo "Setup complete!"
-----------------------------------
setup-cur.sh
chmod +x setup-cur.sh
./setup-cur.sh

