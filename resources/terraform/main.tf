###############################################################################
# Main
###############################################################################



################################### Terraform ######################################


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.2"

  backend "s3" {
    bucket       = "okl-tf-state-bucket-sage"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster" "eks_cluster_okl" {
  name = aws_eks_cluster.eks_cluster_okl.name
}

data "aws_eks_cluster_auth" "eks_cluster_okl" {
  name = aws_eks_cluster.eks_cluster_okl.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster_okl.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster_okl.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster_okl.name]
  }
  # config_path = "~/.kube/config"
  # config_context = "arn:aws:eks:us-east-1:388691194728:cluster/eks-j3v6tjjj-okl"
}

# Force provider to wait until cluster exists
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "aws eks wait cluster-active --name ${aws_eks_cluster.eks_cluster_okl.name}"
  }
}

resource "null_resource" "wait_for_access" {
  provisioner "local-exec" {
    command = "sleep 20"
  }
}

resource "null_resource" "wait_for_nodes" {
  provisioner "local-exec" {
    command = "aws eks wait nodegroup-active --cluster-name ${aws_eks_cluster.eks_cluster_okl.name} --nodegroup-name my-nodegroup"
  }
}

data "aws_caller_identity" "current" {}


################################### Variables #########################################


variable "aws_region" {
  description = "Location of AWS resources"
  type    = string
}

variable "project_name" {
  description = "Global name of project"
  type    = list(string)
  default = ["ml-platform", "data-products", "ai-labs"]
}

variable "prefix" {
  description = "Prefix added to resource names/tags"
  type        = string
  default     = "okl"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"


  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "training_instance_type" {
  description = "Instance type for training the ML model"
  type        = string
  default     = null
}

variable "inference_instance_type" {
  description = "Instance type for training the ML model"
  type        = string
  default     = null
}

variable "volume_size_sagemaker" {
  description = "Volume size SageMaker instance in GB"
  type        = number
  default     = 5
}

variable "production_variants" {
  description = "Specifies a model variants config and the resources to deploy them."
  type = set(object(
    {
      accelerator_type       = string
      initial_instance_count = number
      initial_variant_weight = number
      instance_type          = string
      model_name             = string
      variant_name           = string
    }
  ))
  default = [{
    accelerator_type       = null
    initial_instance_count = 1,
    initial_variant_weight = 1,
    instance_type          = "ml.t2.medium",
    model_name             = null
    variant_name           = "variant",
  }]
}

variable "kms_key_arn" {
  description = "ARN of AWS KMS key that SageMaker AI uses to encrypt data on the storage volume "
  type        = string
  default     = null
}

###### VPC ######

variable "cidr_block" {
  description = "IPv4 CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_tenancy" {
  description = "Tenancy option for instances in the VPC"
  type        = string
  default     = "default"
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable_network_address_usage_metrics" {
  description = "Determines whether network address usage metrics are enabled for the VPC"
  type        = bool
  default     = false
}

variable "azs" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}


variable "sage_subnets" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

###### S3 ######

variable "s3_bucket_input_models_path" {
  description = "S3 path where training data is stored"
  type        = string
  default     = null
}

variable "s3_object_output_data" {
  description = "S3 path or folder name where training data is stored"
  type        = string
  default     = null
}

variable "s3_bucket_output_models_path" {
  description = "S3 path were the output (trained models etc.) will be stored"
  type        = string
  default     = null
}

variable "bucket" {
  description = "Name of s3 bucket"
  type        = string
  default     = "sagemaker-bucket"
}

variable "bucket_prefix" {
  description = "Bucket prefix designating the owner of the s3 bucket"
  type        = string
  default     = "okl-bucket"
}

variable "cloud_bucket" {
  description = "Name of cloudwatch bucket provide storage for logs"
  type        = string
  default     = "cloudwatch-bucket"
}

variable "cloud_bucket_prefix" {
  description = "Bucket prefix designating the owner of the cloud s3 bucket"
  type        = string
  default     = "cloud-okl"
}

# Challenge: generate replica bucket for each bucket dynamically 
variable "replica_bucket" {
  description = "Name of replica bucket provide storage for logs"
  type        = set(string)
  default     = ["replica-bucket"]
}

variable "replica_bucket_prefix" {
  description = "Bucket prefix designating the owner of the replica s3 bucket"
  type        = string
  default     = "replica-okl"
}

variable "force_destroy" {
  description = "The bucket will be empirical and attached to the lifecycle of the application"
  type        = bool
  default     = true
}

variable "hosted_zone_id" {
  description = "Name of the Region where AWS resource is desired"
  type        = string
  default     = "us-east-1"
}

variable "cors_rule" {
  description = "Set of origins and methods (cross-origin access to allow)"
  type = set(object(
    {
      allowed_headers = list(string)
      allowed_methods = list(string)
      allowed_origins = list(string)
      expose_headers  = list(string)
      max_age_seconds = number
    }
  ))
  # Tighten in Prod
  default = [{
    allowed_headers = ["*"],
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "HEAD"],
    allowed_origins = ["http://localhost:*", "https://*.sagemaker.aws"],
    expose_headers  = ["ETag", "Content-Type", "Content-Length"],
    max_age_seconds = 3000
  }]
}


variable "grant" {
  description = "Configuration block that defines permissions"
  type = set(object(
    {
      id          = string
      permissions = set(string)
      type        = string
      uri         = string
    }
  ))
  # Flatten list of resources to pass to uri
  default = [{
    id = null
    permissions = [
      "READ", "WRITE", "READ_ACP", "WRITE_ACP", "FULL_CONTROL"
    ]
    type = "CanonicalUser"
    uri  = null
  }]
}

variable "lifecycle_rule" {
  description = "S3 Lifecycle rule to store objects throughout the lifecycle by transitioning to lower-cost storage classes or deleting expired objects"
  type = set(object(
    {
      abort_incomplete_multipart_upload_days = number
      enabled                                = bool
      expiration = list(object(
        {
          date                         = string
          days                         = number
          expired_object_delete_marker = bool
        }
      ))
      id = string
      noncurrent_version_expiration = list(object(
        {
          days = number
        }
      ))
      noncurrent_version_transition = set(object(
        {
          days          = number
          storage_class = string
        }
      ))
      prefix = string
      tags   = map(string)
      transition = set(object(
        {
          date          = string
          days          = number
          storage_class = string
        }
      ))
    }
  ))
  default = [{
    abort_incomplete_multipart_upload_days = 7
    enabled                                = false
    expiration = [
      {
        date                         = "2028-01-13" # RFC3339 Timestamp Format
        days                         = 90
        expired_object_delete_marker = false
      }
    ]
    id = "expiration-365"
    noncurrent_version_expiration = [
      {
        days = 365
      }
    ]
    noncurrent_version_transition = [
      {
        days          = 180
        storage_class = "GLACIER"
      }
    ]
    prefix = null
    tags   = null
    transition = [
      {
        date          = "2028-03-26" # RFC3339 Timestamp Format
        days          = 180
        storage_class = "GLACIER"
      }
    ]
  }]
}

variable "logging" {
  description = "Provides the configuration of storage for logging"
  type = set(object(
    {
      target_bucket = string
      target_prefix = string
    }
  ))
  default = [{
    target_bucket = null
    target_prefix = null
  }]
}

variable "object_lock_configuration" {
  description = "Provide the configuration of storage for logging"
  type = set(object(
    {
      object_lock_enabled = string
      rule = list(object(
        {
          default_retention = list(object(
            {
              days  = number
              mode  = string
              years = number
            }
          ))
        }
      ))
    }
  ))
  default = [{
    object_lock_enabled = "Enabled"
    rule = [
      {
        default_retention = [
          {
            days  = 180
            mode  = "GOVERNANCE"
            years = 3
          }
        ]
      }
    ]
  }]
}

variable "replication_configuration" {
  description = "To manage replication configuration changes to an S3 bucket"
  type = set(object(
    {
      role = string
      rules = set(object(
        {
          destination = list(object(
            {
              access_control_translation = list(object(
                {
                  owner = string
                }
              ))
              account_id         = string
              bucket             = string
              replica_kms_key_id = string
              storage_class      = string
            }
          ))
          filter = list(object(
            {
              prefix = string
              tags   = map(string)
            }
          ))
          id       = string
          prefix   = string
          priority = number
          source_selection_criteria = list(object(
            {
              sse_kms_encrypted_objects = list(object(
                {
                  enabled = bool
                }
              ))
            }
          ))
          status = string
        }
      ))
    }
  ))
  default = [{
    role = null
    rules = [
      {
        destination = [
          {
            access_control_translation = [
              {
                owner = "Destination"
              }
            ]
            account_id         = null
            bucket             = null
            replica_kms_key_id = null
            storage_class      = "STANDARD"
          }
        ]
        filter = [
          {
            prefix = null
            tags   = null
          }
        ]
        id       = "bucket-replica-rule"
        prefix   = null
        priority = 1
        source_selection_criteria = [
          {
            sse_kms_encrypted_objects = [
              {
                enabled = false
              }
            ]
          }
        ]
        status = "Enabled"
      }
    ]
  }]
}


variable "server_side_encryption_configuration" {
  description = "A S3 bucket server-side encryption configuration."
  type = set(object(
    {
      rule = list(object(
        {
          apply_server_side_encryption_by_default = list(object(
            {
              kms_master_key_id = string
              sse_algorithm     = string
            }
          ))
        }
      ))
    }
  ))
  default = [{
    rule = [
      {
        apply_server_side_encryption_by_default = [
          {
            kms_master_key_id = null
            sse_algorithm     = "AES256"
          }
        ]
      }
    ]
  }]
}

variable "versioning" {
  description = "Configuration to controlling versioning on an S3 bucket"
  type = set(object(
    {
      enabled    = bool
      mfa_delete = bool
    }
  ))
  default = [{
    enabled    = true
    mfa_delete = false
  }]
}

variable "website" {
  description = "nested mode: NestingList, min items: 0, max items: 1"
  type = set(object(
    {
      error_document           = string
      index_document           = string
      redirect_all_requests_to = string
      routing_rules            = string
    }
  ))
  default = [{
    error_document           = null
    index_document           = "index.html"
    redirect_all_requests_to = "index_document"
    routing_rules            = null
  }]
}

###### EKS ######

variable "eks_oidc_provider_arn" {
  description = "The ARN of the IAM OIDC provider for the EKS cluster."
  type        = string
  # Note: EKS cluster details in the AWS console or
  # consider getting dynamically and make dependent (depend-on) on other resource   
  # example: arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53BF441
  # default = aws_eks_cluster.eks_cluster_okl.arn
  default = null
}

variable "enabled_cluster_log_types" {
  description = "Log type corresponds to a component of the Kubernetes control plane"
  type        = set(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}


variable "cluster_version" {
  description = "Version of EKS cluster"
  type        = string
  default     = "1.30"
}

variable "encryption_config" {
  description = "Key Management Service and encryption for EKS"
  type = set(object(
    {
      provider = list(object(
        {
          key_arn = string
        }
      ))
      resources = set(string)
    }
  ))
  default = [{
    provider = [
      {
        key_arn = null
      }
    ]
    resources = []
    }
  ]
}

variable "timeouts" {
  description = "Configuration options for times for action"
  type = set(object(
    {
      create = string
      delete = string
      update = string
    }
  ))
  default = [{
    create = "60m"
    delete = "120m"
    update = "30m"
  }]
}

variable "vpc_config" {
  description = "VPC configuration for EKS cluster"
  type = set(object(
    {
      cluster_security_group_id = string
      endpoint_private_access   = bool
      endpoint_public_access    = bool
      public_access_cidrs       = set(string)
      security_group_ids        = set(string)
      subnet_ids                = set(string)
      vpc_id                    = string
    }
  ))
  default = [{
    cluster_security_group_id = null
    endpoint_private_access   = false
    endpoint_public_access    = true
    public_access_cidrs       = null
    security_group_ids        = null
    subnet_ids                = null
    vpc_id                    = null
  }]
}

# Passed from config.auto.tfvars which is included in .gitignore file 
variable "aws_access_key_id" {
  description = "AWS access id key for account"
  type        = string
}

variable "aws_secret_access_key" {
  description = "AWS key or password to access resources and services"
  type        = string
}

variable "ghcr_secret" {
  description = "Github access key"
  type        = string
}

variable "enable_accelerator" {
  type    = bool
  default = false
}

variable "accelerator_type" {
  type    = string
  default = "ml.eia2.medium"
}

locals {
  bucket                       = "${var.bucket_prefix}-sagemaker-${random_string.bucket.result}"
  s3_bucket_input_models_path  = "${var.prefix}-input-sagemaker-${var.environment}"
  s3_bucket_output_models_path = "${var.prefix}-output-sagemaker-${var.environment}"
  replica_bucket = [
    for b in var.replica_bucket : "${var.prefix}-${b}-${var.environment}"
  ]
  random_grant_name            = random_string.grant.result
  s3_object_output_data        = "transcribe-output-${var.environment}"
  bucket_prefix                = "okl"
  prefix                       = "okl"
  cloud_bucket                 = var.cloud_bucket
  bucket_iam_arn               = aws_iam_role.iam_sage_okl.arn
  production_variants_indexed = flatten([
    for prod_variant in var.production_variants : [
      for model_key, model_resource in aws_sagemaker_model.sagemodel_okl :
      merge(prod_variant, {
        model_name          = model_resource.name,
        random_variant_name = "${prod_variant.variant_name}-${model_key}"
        zero_accelerator    = var.enable_accelerator ? var.accelerator_type : null
      })
    ]
  ])
  grant_uri = [
    null,
    "arn:aws:s3:::${local.s3_bucket_input_models_path}",
    "arn:aws:s3:::${local.s3_bucket_output_models_path}",
    "arn:aws:s3:::${local.s3_object_output_data}",
    [
   for i in range(length(var.replica_bucket)) :
      "arn:aws:s3:::${local.replica_bucket[i]}"
    ]
  ]
  
  # A nested loop to create a list of grant objects.
  # The outer loop iterates through each permission set defined in `var.grant`.
  # The inner loop iterates through every URI in `local.grant_uri`.
  # The `flatten` function takes the nested list
  # created by the loops and produces a single, flat list of objects
  # that can be used in a `for_each`.
  s3_grant_list = flatten([
    for grant_config in var.grant : [
      for uri in local.grant_uri :
      merge(grant_config, { uri = uri, id = "${local.random_grant_name}" })
    ]
  ])

  replication_configuration_index = flatten([
    for rg in var.replication_configuration : [
      # Iterate over the replica bucket resources to get their ARNs and other properties
      for bucket_name, bucket_resource in aws_s3_bucket.replica_bucket : {
        # Reconstruct the object for the dynamic block. 'merge' can't modify nested objects
        role  = rg.role
        rules = toset([
          for rule in rg.rules : {
            # Copy existing attributes from the original rule
            id                        = rule.id
            priority                  = rule.priority
            status                    = rule.status
            filter                    = rule.filter
            source_selection_criteria = rule.source_selection_criteria

            # Add the `bucket_prefix` that the dynamic "rules" block expects
            bucket_prefix = local.bucket_prefix

            # Reconstruct the destination to add the 'bucket_id'
            destination = [
              for dest in rule.destination : {
                # Copy existing destination attributes
                access_control_translation = dest.access_control_translation
                account_id                 = dest.account_id
                replica_kms_key_id         = dest.replica_kms_key_id
                storage_class              = dest.storage_class

                # Add 'bucket_id' with the replica bucket's ARN for the dynamic "destination" block
                bucket_id = bucket_resource.arn
              }
            ]
          }
        ])
      }
    ]
  ])


  # Create a vpc configuration for each subnet 
  # In this case the vpc configuration will be the same for each subnet
  vpc_config_zip = {
    for i in range(length(var.sage_subnets)) :
     var.sage_subnets[i] => merge(    
      {subnet_cidr = var.sage_subnets[i]},
      {vpc_config = var.vpc_config }
    )
  }
}

################################### Resources ######################################


# Option: utilize policy document instead of aws_iam_role_policy for this project???
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = "ServiceSagemaker"

    actions = [
      "sts:AssumeRoleWithWebIdentity",
      "sagemaker:CreateTrainingJob",
      "sagemaker:DescribeTrainingJob",
      "sagemaker:StopTrainingJob",
      "sagemaker:createModel",
      "sagemaker:createEndpointConfig",
      "sagemaker:createEndpoint",
      "sagemaker:addTags"
    ]

    effect = "Allow"
    # principals {
      # type = "Service"
      # identifiers = [
        # "sagemaker.amazonaws.com",
        # "scheduler.amazonaws.com",
        # "glue.amazonaws.com"
      # ]
    # }
    resources = ["*"]
  }

  statement {
    sid = "SagemakerS3"
    # Least privilege should be observed
    actions = [
      # "s3:GetObject",
      # "s3:PutObject",
      # "s3:DeleteObject",
      # "s3:AbortMultipartUpload",
      # "s3:CreateBucket",
      # "s3:GetBucketLocation",
      # "s3:ListBucket",
      # "s3:ListAllMyBuckets",
      # "s3:GetBucketCors",
      # "s3:PutBucketCors"  
      "s3:*"
    ]

    effect = "Allow"

    resources = concat(
      [
        "arn:aws:s3:::${local.s3_bucket_input_models_path}",
        "arn:aws:s3:::${local.s3_bucket_input_models_path}/*",
        "arn:aws:s3:::${local.s3_bucket_output_models_path}",
        "arn:aws:s3:::${local.s3_bucket_output_models_path}/*",
      ],
      [for b in local.replica_bucket : "arn:aws:s3:::${b}"],
      [for b in local.replica_bucket : "arn:aws:s3:::${b}/*"]
    )
  }
}

data "aws_iam_policy_document" "sage_role" {
  statement {
    sid = "ServiceSagemaker"

    actions = [
      "sts:AssumeRole"
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = [
        "sagemaker.amazonaws.com",
        "scheduler.amazonaws.com",
        "glue.amazonaws.com"
      ]
    }
  }
}


data "aws_iam_policy_document" "s3_access" {
  statement {
    sid = "SagemakerS3"

    actions = [
      # "s3:GetObject",
      # "s3:PutObject",
      # "s3:DeleteObject",
      # "s3:AbortMultipartUpload"
      # "s3:CreateBucket",
      # "s3:GetBucketLocation",
      # "s3:ListBucket",
      # "s3:ListAllMyBuckets",
      # "s3:GetBucketCors",
      # "s3:PutBucketCors"  
      "s3:*"
    ]
    effect  = "Allow"

    resources = concat(
      [
        "arn:aws:s3:::${local.s3_bucket_input_models_path}",
        "arn:aws:s3:::${local.s3_bucket_input_models_path}/*",
        "arn:aws:s3:::${local.s3_bucket_output_models_path}",
        "arn:aws:s3:::${local.s3_bucket_output_models_path}/*",
      ],
      [for b in local.replica_bucket : "arn:aws:s3:::${b}"],
      [for b in local.replica_bucket : "arn:aws:s3:::${b}/*"]
    )
  }
}

locals {
  sagemaker_instance_types = [
    # FREE TIER
    "ml.t3.medium",
    "ml.m5.large",

    # GENERAL PURPOSE (CPU)
    "ml.t3.xlarge",
    "ml.t3.2xlarge",
    "ml.m5.xlarge",
    "ml.m5.2xlarge",
    "ml.m5.4xlarge",
    "ml.m5.12xlarge",
    "ml.m5.24xlarge",
    "ml.m5d.large",
    "ml.m5d.xlarge",
    "ml.m5d.2xlarge",
    "ml.m5d.4xlarge",
    "ml.m5d.8xlarge",
    "ml.m5d.12xlarge",
    "ml.m5d.24xlarge",
    "ml.c5.large",
    "ml.c5.xlarge",
    "ml.c5.2xlarge",
    "ml.c5.4xlarge",
    "ml.c5.9xlarge",
    "ml.c5.18xlarge",

    # COMPUTE OPTIMIZED
    "ml.c5n.large",
    "ml.c5n.xlarge",
    "ml.c5n.2xlarge",
    "ml.c5n.4xlarge",
    "ml.c5n.9xlarge",
    "ml.c5n.18xlarge",

    # MEMORY OPTIMIZED
    "ml.r5.large",
    "ml.r5.xlarge",
    "ml.r5.2xlarge",
    "ml.r5.4xlarge",
    "ml.r5.8xlarge",
    "ml.r5.12xlarge",
    "ml.r5.16xlarge",
    "ml.r5.24xlarge",

    # GPU — INFERENCE
    "ml.g4dn.xlarge",
    "ml.g4dn.2xlarge",
    "ml.g4dn.4xlarge",
    "ml.g4dn.8xlarge",
    "ml.g4dn.12xlarge",
    "ml.g4dn.16xlarge",

    # GPU — TRAINING
    "ml.p3.2xlarge",
    "ml.p3.8xlarge",
    "ml.p3.16xlarge",
    "ml.p3dn.24xlarge",

    # NEXT‑GEN GPU
    "ml.p4d.24xlarge",
    "ml.p4de.24xlarge",

    # ACCELERATORS (Inferentia / Trainium)
    "ml.inf1.xlarge",
    "ml.inf1.2xlarge",
    "ml.inf1.6xlarge",
    "ml.inf1.24xlarge",
    "ml.trn1.2xlarge",
    "ml.trn1.32xlarge",

    # MULTI‑MODEL ENDPOINTS (MMS)
    "ml.m5.large",
    "ml.m5.xlarge",
    "ml.m5.2xlarge",
    "ml.m5.4xlarge",
    "ml.m5.12xlarge",
    "ml.m5.24xlarge",

    # EDGE / SMALL FOOTPRINT
    "ml.c6i.large",
    "ml.c6i.xlarge",
    "ml.c6i.2xlarge",
    "ml.c6i.4xlarge",
    "ml.c6i.8xlarge",
    "ml.c6i.12xlarge",
    "ml.c6i.16xlarge",
    "ml.c6i.24xlarge",
    "ml.c6i.32xlarge"
  ]
}


resource "aws_iam_role_policy" "s3_access" {
  role   = aws_iam_role.iam_sage_okl.id
  policy = data.aws_iam_policy_document.s3_access.json
}


resource "aws_iam_role" "iam_sage_okl" {
  name = "iam-sage-okl"
  assume_role_policy = data.aws_iam_policy_document.sage_role.json
}


# Option: different approach to create sagemaker iam policy 
# resource "aws_iam_policy" "iam_policy_sage_okl" {
# name   = "iam-policy-sage-okl"
# policy = <<-EOF
# {
# "Version": "2012-10-17",
# "Statement": [
# {
# "Effect": "Allow",
# "Action": [
# "sagemaker:CreateTrainingJob",
# "sagemaker:DescribeTrainingJob",
# "sagemaker:StopTrainingJob",
# "sagemaker:createModel",
# "sagemaker:createEndpointConfig",
# "sagemaker:createEndpoint",
# "sagemaker:addTags"
# ],
# "Resource": [
#  "*"
# ]
# },
# {
# "Effect": "Allow",
# "Action": [
# "sagemaker:ListTags"
# ],
# "Resource": [
#  "*"
# ]
# },
# {
# "Effect": "Allow",
# "Action": [
# "iam:PassRole"
# ],
# "Resource": [
#  "*"
# ],
# "Condition": {
# "StringEquals": {
# "iam:PassedToService": "sagemaker.amazonaws.com"
# }
# }
# },
# {
# "Effect": "Allow",
# "Action": [
# "events:PutTargets",
# "events:PutRule",
# "events:DescribeRule"
# ],
# "Resource": [
# "*"
# ]
# }
# ]
# }
# EOF
# }

# resource "aws_iam_role" "iam_okl" {
# name = "iam-okl"
# assume_role_policy = jsonencode({
# Version = "2012-10-17"
# Statement = [{
# Action = [
# # "sts:AssumeRole",

# "sagemaker:CreateTrainingJob",
# "sagemaker:DescribeTrainingJob",
# "sagemaker:StopTrainingJob",
# "sagemaker:createModel",
# "sagemaker:createEndpointConfig",
# "sagemaker:createEndpoint",
# "sagemaker:addTags"
# ]
# Principal = {
# Service = "sagemaker.amazonaws.com"
# }
# Effect = "Allow"
# Sid    = "ServiceSageMaker"
# }]
# })
# }


##### VPC #####

resource "aws_vpc" "sage_vpc" {
  cidr_block                           = var.cidr_block
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_dns_support                   = var.enable_dns_support
  instance_tenancy                     = var.instance_tenancy
  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = { Name = "${var.prefix}-sage-vpc" }
}


resource "aws_subnet" "sage_subnets" {
  count      = length(var.sage_subnets)
  vpc_id     = aws_vpc.sage_vpc.id
  cidr_block = var.sage_subnets[count.index]

  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.prefix}-sage-sb-${count.index + 1}" }
}

data "aws_sagemaker_prebuilt_ecr_image" "ecr_image" {
  for_each        = { for item in local.project_teams : item.team => item }
  repository_name = each.value.config.image
  image_tag       = each.value.config.image_tag
}
resource "aws_sagemaker_domain" "sagemaker_domain_okl" {
  domain_name = "sagemaker-domain-okl"
  auth_mode   = "IAM"

  vpc_id     = aws_vpc.sage_vpc.id
  subnet_ids = [for i in range(length(aws_subnet.sage_subnets)) : aws_subnet.sage_subnets[i].id]

  default_user_settings {
    execution_role = aws_iam_role.iam_sage_okl.arn
  }
}


resource "aws_sagemaker_user_profile" "sagemaker_profile_okl" {
  domain_id         = aws_sagemaker_domain.sagemaker_domain_okl.id
  user_profile_name = "sagemaker-profile-okl"
  user_settings {
    execution_role = aws_iam_role.iam_sage_okl.arn
  }
}

resource "aws_sagemaker_model" "sagemodel_okl" {
  for_each           = { for item in local.project_teams : item.team => item }
  name               = "${each.value.project}-${each.key}-model"
  execution_role_arn = aws_iam_role.iam_sage_okl.arn


  primary_container {
    image = data.aws_sagemaker_prebuilt_ecr_image.ecr_image[each.key].registry_path
  }
}

resource "aws_sagemaker_endpoint_configuration" "sage_config" {
  kms_key_arn = var.kms_key_arn
  name        = "sage-config-${var.environment}"

  dynamic "production_variants" {
    for_each = local.production_variants_indexed
    content {
      accelerator_type       = production_variants.value.zero_accelerator
      initial_instance_count = production_variants.value.initial_instance_count
      initial_variant_weight = production_variants.value.initial_variant_weight
      instance_type          = production_variants.value.instance_type
      model_name             = production_variants.value.model_name
      variant_name           = production_variants.value.random_variant_name
    }
  }
}
resource "aws_sagemaker_endpoint" "sage_endpoint_okl" {
  endpoint_config_name = aws_sagemaker_endpoint_configuration.sage_config.name
  name                 = "sage-endpoint-okl"
}

###### ECR Repository #####

locals {
  project = {
    ml-platform = {
      "fraud-detection" = {
        service_account_name = "fraud-api-sa"
        image                = "sagemaker-xgboost"
        image_tag            = "1.7-1"
        kubernetes_namespace = "fraud-detection"
      },
      "recommendations" = {
        service_account_name = "reco-api-sa"
        image                = "factorization-machines"
        image_tag            = "1"
        kubernetes_namespace = "recommendations"
      }
      "forecasting" = {
        service_account_name = "forecast-api-sa"
        image                = "linear-learner"
        image_tag            = "1"
        kubernetes_namespace = "forecasting"
      }
    }

    data-products = {
        "financial-service" = {
          client_account_name  = "fin-api-ca"
          image                = "sagemaker-xgboost"
          image_tag            = "1.7-1"
          kubernetes_namespace = "financial-service"
        },
        "outdoor-recreation" = {
          client_account_name  = "recreation-api-ca"
          image                = "kmeans"
          image_tag            = "1"
          kubernetes_namespace = "outdoor-recreation"
        },
        "legal-tech" = {
          client_account_name  = "legal-api-ca"
          image                = "blazingtext"
          image_tag            = "1"
          kubernetes_namespace = "legal-tech"
        }
      }
    }
    ai-labs = {
      "quantization" = {
        lab_account_name     = "quant-api",
        image                = "seq2seq"
        image_tag            = "1"
        kubernetes_namespace = "quantization"
      },
      "fine-tuning" = {
        lab_account_name     = "ft-api",
        image                = "djl-inference",
        image_tag            = "0.25.0-cpu-py39-ubuntu20.04-v1.0"
        kubernetes_namespace = "fine-tuning"
      },
      "eval" = {
        lab_account_name     = "eval-api",
        image                = "autogluon-inference"
        image_tag            = "0.8.2-cpu-py39"
        kubernetes_namespace = "eval"
      }
    }
  
  # Common tags to apply to all resources
  common_tags = {
    Project     = "okl-platform"
    Environment = var.environment
    ManagedBy   = "okl"
  }

  # Flatten the nested project map to access both project and team names
  project_teams = flatten([
    for proj, teams in local.project : [
      for team, config in teams : {
        project = proj
        team    = team
        config  = config
      }
    ]
  ])

}

resource "aws_ecr_repository" "ecr_repository" {
  for_each = { for item in local.project_teams : item.team => item }
  # for_each = merge(values(local.project)...)

  name                 = "${each.value.project}/${each.key}-service"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
}


# Challenge: full build-out of s3 bucket
resource "aws_s3_bucket" "sagemaker_s3_okl" {
  bucket         = local.bucket
  force_destroy  = var.force_destroy
  # hosted_zone_id = var.hosted_zone_id

  dynamic "cors_rule" {
    for_each = var.cors_rule
    content {
      allowed_headers = cors_rule.value["allowed_headers"]
      allowed_methods = cors_rule.value["allowed_methods"]
      allowed_origins = cors_rule.value["allowed_origins"]
      expose_headers  = cors_rule.value["expose_headers"]
      max_age_seconds = cors_rule.value["max_age_seconds"]
    }
  }
  # Deprecated (will keep)
  dynamic "grant" {
    for_each = local.s3_grant_list
    content {
      id          = grant.value.id
      permissions = grant.value.permissions
      type        = grant.value.type
      uri         = null
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rule
    content {
      abort_incomplete_multipart_upload_days = lifecycle_rule.value["abort_incomplete_multipart_upload_days"]
      enabled                                = lifecycle_rule.value["enabled"]
      id                                     = lifecycle_rule.value["id"]
      prefix                                 = lifecycle_rule.value["prefix"]
      tags                                   = lifecycle_rule.value["tags"]

      dynamic "expiration" {
        for_each = lifecycle_rule.value.expiration
        content {
          date                         = expiration.value["date"]
          days                         = expiration.value["days"]
          expired_object_delete_marker = expiration.value["expired_object_delete_marker"]
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = lifecycle_rule.value.noncurrent_version_expiration
        content {
          days = noncurrent_version_expiration.value["days"]
        }
      }

      dynamic "noncurrent_version_transition" {
        for_each = lifecycle_rule.value.noncurrent_version_transition
        content {
          days          = noncurrent_version_transition.value["days"]
          storage_class = noncurrent_version_transition.value["storage_class"]
        }
      }

      dynamic "transition" {
        for_each = lifecycle_rule.value.transition
        content {
          date          = transition.value["date"]
          days          = transition.value["days"]
          storage_class = transition.value["storage_class"]
        }
      }

    }
  }

  dynamic "logging" {
    for_each = var.logging
    content {
      target_bucket = local.cloud_bucket
      target_prefix = local.prefix
    }
  }

  dynamic "object_lock_configuration" {
    for_each = var.object_lock_configuration
    content {
      object_lock_enabled = object_lock_configuration.value["object_lock_enabled"]

      dynamic "rule" {
        for_each = object_lock_configuration.value.rule
        content {

          dynamic "default_retention" {
            for_each = rule.value.default_retention
            content {
              days  = default_retention.value["days"]
              mode  = default_retention.value["mode"]
              years = default_retention.value["years"]
            }
          }

        }
      }

    }
  }

  dynamic "replication_configuration" {
    for_each = local.replication_configuration_index
    content {
      role = local.bucket_iam_arn

      dynamic "rules" {
        for_each = replication_configuration.value.rules
        content {
          id       = rules.value["id"]
          prefix   = rules.value["bucket_prefix"]
          priority = rules.value["priority"]
          status   = rules.value["status"]

          dynamic "destination" {
            for_each = rules.value.destination
            content {
              account_id         = destination.value["account_id"]
              bucket             = destination.value["bucket_id"]
              replica_kms_key_id = destination.value["replica_kms_key_id"]
              storage_class      = destination.value["storage_class"]

              dynamic "access_control_translation" {
                for_each = destination.value.access_control_translation
                content {
                  owner = access_control_translation.value["owner"]
                }
              }

            }
          }

          dynamic "filter" {
            for_each = rules.value.filter
            content {
              prefix = local.bucket_prefix
              tags   = filter.value["tags"]
            }
          }

          dynamic "source_selection_criteria" {
            for_each = rules.value.source_selection_criteria
            content {
              dynamic "sse_kms_encrypted_objects" {
                for_each = source_selection_criteria.value.sse_kms_encrypted_objects
                content {
                  enabled = sse_kms_encrypted_objects.value["enabled"]
                }
              }

            }
          }

        }
      }

    }
  }

  dynamic "server_side_encryption_configuration" {
    for_each = var.server_side_encryption_configuration
    content {
      dynamic "rule" {
        for_each = server_side_encryption_configuration.value.rule
        content {
          dynamic "apply_server_side_encryption_by_default" {
            for_each = rule.value.apply_server_side_encryption_by_default
            content {
              kms_master_key_id = apply_server_side_encryption_by_default.value["kms_master_key_id"]
              sse_algorithm     = apply_server_side_encryption_by_default.value["sse_algorithm"]
            }
          }

        }
      }

    }
  }

  dynamic "versioning" {
    for_each = var.versioning
    content {
      enabled    = versioning.value["enabled"]
      mfa_delete = versioning.value["mfa_delete"]
    }
  }

  # dynamic "website" {
  # for_each = var.website
  # content {
  # error_document           = website.value["error_document"]
  # index_document           = website.value["index_document"]
  # redirect_all_requests_to = website.value["redirect_all_requests_to"]
  # routing_rules            = website.value["routing_rules"]
  # }
  # }

}

resource "aws_s3_bucket_versioning" "sagemaker_s3_okl_versioning" {
  bucket = aws_s3_bucket.sagemaker_s3_okl.id
  versioning_configuration {
    # Convert boolean to the required string status
    status     = one(var.versioning).enabled ? "Enabled" : "Suspended"
    mfa_delete = one(var.versioning).mfa_delete ? "Enabled" : "Disabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "sagemaker_s3_okl_ownership" {
  bucket = aws_s3_bucket.sagemaker_s3_okl.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}


# Replaced grant parameter
# aws_s3_bucket_ownership_controls will override
# resource "aws_s3_bucket_acl" "bucket_data_acl" {
  # bucket = aws_s3_bucket.sagemaker_s3_okl.id
  # acl    = "public-read"
# }

resource "aws_s3_object" "bucket_object" {
  bucket = aws_s3_bucket.sagemaker_s3_okl.id
  key    = "transcribe"
  source = "/transcribe.json"
}

resource "aws_s3_bucket" "cloudwatch_bucket" {
  bucket        = "${var.cloud_bucket_prefix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket" "replica_bucket" {
  for_each = toset(local.replica_bucket)

  bucket        = each.value
  force_destroy = true
}

##### Kubernetes #####

resource "kubernetes_namespace_v1" "kube_ns_okl" {
  for_each = { for item in local.project_teams : item.team => item }
  metadata {
    name = each.value.config.kubernetes_namespace
  }

  depends_on = [
    aws_eks_access_entry.eks_entry,
    aws_eks_cluster.eks_cluster_okl, 
    null_resource.wait_for_cluster,
    null_resource.wait_for_access,
    null_resource.wait_for_nodes
    ]
  
}


resource "kubernetes_role_v1" "kube_gen_role" {
  for_each = kubernetes_namespace_v1.kube_ns_okl
  metadata {
    name = "kube-${each.value.metadata[0].name}-role"
    labels = {
      role = "kube-role"
    }

    namespace = each.value.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = [
      "pods",
      "secrets",
      "configmaps",
      "services",
      "endpoints",
      "events"
    ]
    verbs = ["get", "list", "watch", "create", "update", "patch"]
  }
}

resource "kubernetes_role_binding_v1" "kube_role_binding_okl" {
  count = length(kubernetes_namespace_v1.kube_ns_okl)
  metadata {
    name      = "kube-${values(kubernetes_namespace_v1.kube_ns_okl)[count.index].metadata[0].name}-role-binding-okl"
    namespace = values(kubernetes_namespace_v1.kube_ns_okl)[count.index].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "kube-${values(kubernetes_namespace_v1.kube_ns_okl)[count.index].metadata[0].name}-role"
  }
  subject {
    kind      = "User"
    name      = data.aws_caller_identity.current.arn
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = values(kubernetes_namespace_v1.kube_ns_okl)[count.index].metadata[0].name
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_cluster_role_binding_v1" "terraform_admin_okl" {
  count = length(kubernetes_namespace_v1.kube_ns_okl)

  metadata {
    name = "kube-${values(kubernetes_namespace_v1.kube_ns_okl)[count.index].metadata[0].name}-admin-okl"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "kube-${values(kubernetes_namespace_v1.kube_ns_okl)[count.index].metadata[0].name}-cluster-admin-okl"
  }

  subject {
    kind      = "User"
    name      = data.aws_caller_identity.current.arn
    api_group = "rbac.authorization.k8s.io"
  }
}


resource "kubernetes_config_map_v1" "app_config" {
  for_each = { for item in local.project_teams : item.team => item }
  metadata {
    # Create a unique config map in each team's namespace
    name      = "kube-${each.value.config.kubernetes_namespace}-config-map"
    namespace = each.value.config.kubernetes_namespace
    labels    = { owner = "kube-terraform" }
  }


  data = {
    endpoint_name = aws_sagemaker_endpoint.sage_endpoint_okl.name,
    aws_region    = var.aws_region
    log_level     = "info"

    aws_access_key_id     = var.aws_access_key_id
    aws_secret_access_key = var.aws_secret_access_key
    ghcr_secret           = var.ghcr_secret

  }

  depends_on = [
    kubernetes_namespace_v1.kube_ns_okl,
    aws_eks_cluster.eks_cluster_okl
  ]
}

# resource "kubernetes_secret" "aws_credentials" {
  # for_each = { for item in local.project_teams : item.team => item }
# 
  # metadata {
    # name      = "aws-credentials"
    # namespace = each.value.config.kubernetes_namespace
  # }
# 
  # Use variables to pass in secrets, not hardcoded values
  # data = {
    # aws_access_key_id     = var.aws_access_key_id
    # aws_secret_access_key = var.aws_secret_access_key
  # }
# 
  # type = "Opaque"
# 
  # depends_on = [
    # kubernetes_namespace_v1.kube_ns_okl,
    # aws_eks_cluster.eks_cluster_okl,
    # aws_eks_access_policy_association.eks_policy
  # ]
# }

##### EKS Cluster #####

## Import EKS Cluster

# Filter out local zones, which are not currently supported 
# with managed node groups
# data "aws_availability_zones" "available" {
# filter {
# name   = "opt-in-status"
# values = ["opt-in-not-required"]
# }
# }
# 
# locals {
# cluster_name = "eks-${random_string.cluster.result}-${var.prefix}"
# }
# 
# resource "random_string" "cluster" {
# length  = 8
# special = false
# upper = false
# }
# 
# module "vpc" {
# source  = "terraform-aws-modules/vpc/aws"
# version = "5.8.1"
# 
# name = "eks-vpc-okl"
# 
# cidr = "10.0.0.0/16"
# azs  = slice(data.aws_availability_zones.available.names, 0, 3)
# 
# private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
# public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
# 
# enable_nat_gateway   = true
# single_nat_gateway   = true
# enable_dns_hostnames = true
# 
# public_subnet_tags = {
# "kubernetes.io/role/elb" = 1
# }
# 
# private_subnet_tags = {
# "kubernetes.io/role/internal-elb" = 1
# }
# }
# 
# module "eks" {
# source  = "terraform-aws-modules/eks/aws"
# version = "20.8.5"
# 
# cluster_name    = local.cluster_name
# cluster_version = "1.30"
# 
# cluster_endpoint_public_access           = true
# enable_cluster_creator_admin_permissions = true
# 
# cluster_addons = {
# aws-ebs-csi-driver = {
# service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
# }
# }
# 
# vpc_id     = module.vpc.vpc_id
# subnet_ids = module.vpc.private_subnets
# 
# eks_managed_node_group_defaults = {
# ami_type = "AL2_x86_64"
# 
# }
# 
# eks_managed_node_groups = {
# one = {
# name = "node-group-1"
# 
# instance_types = ["t3.small"]
# 
# min_size     = 1
# max_size     = 3
# desired_size = 2
# }
# 
# two = {
# name = "node-group-2"
# 
# instance_types = ["t3.small"]
# 
# min_size     = 1
# max_size     = 2
# desired_size = 1
# }
# }
# }
# 
# 
# https://aws.amazon.com/blogs/containers/amazon-ebs-csi-driver-is-now-generally-available-in-amazon-eks-add-ons/ 
# data "aws_iam_policy" "ebs_csi_policy" {
# arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
# }
# 
# module "irsa-ebs-csi" {
# source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
# version = "5.39.0"
# 
# create_role                   = true
# role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
# provider_url                  = module.eks.oidc_provider
# role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
# oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
# }


## Created EKS Cluster

locals {
  cluster_name = "eks-${random_string.cluster.result}-${var.prefix}"
}

resource "random_string" "cluster" {
  length  = 8
  special = false
  upper   = false
}

resource "random_string" "bucket" {
  length  = 16
  special = false
  upper   = false
}

resource "random_string" "grant" {
 length  = 32
 special = false
 upper   = false
}



resource "aws_kms_key" "eks_kms_key" {
  description             = "A symmetric encryption KMS key"
  enable_key_rotation     = true
  deletion_window_in_days = 20
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "key-default-1"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_eks_cluster" "eks_cluster_okl" {
  enabled_cluster_log_types = var.enabled_cluster_log_types
  name                      = local.cluster_name
  role_arn                  = aws_iam_role.cluster.arn
  version                   = var.cluster_version

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  lifecycle {
    prevent_destroy = false
  }

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cloudwatch_cluster_okl,
    aws_iam_role.cluster
  ]


  dynamic "timeouts" {
    for_each = var.timeouts
    content {
      create = timeouts.value["create"]
      delete = timeouts.value["delete"]
      update = timeouts.value["update"]
    }
  }

  # The aws_eks_cluster is design to only accept on vpc_config
  vpc_config {
    endpoint_private_access = one(var.vpc_config).endpoint_private_access
    endpoint_public_access  = one(var.vpc_config).endpoint_public_access
    public_access_cidrs     = one(var.vpc_config).public_access_cidrs
    security_group_ids      = one(var.vpc_config).security_group_ids
    subnet_ids              = aws_subnet.sage_subnets[*].id
  }
}

resource "aws_eks_access_entry" "eks_entry" {
  cluster_name  = aws_eks_cluster.eks_cluster_okl.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"


  # Ensure the cluster is created before trying to add an access entry
  depends_on = [aws_eks_cluster.eks_cluster_okl]
}

resource "aws_eks_access_policy_association" "eks_policy" {
  cluster_name  = aws_eks_cluster.eks_cluster_okl.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_caller_identity.current.arn

  access_scope {
    type       = "cluster"
    
  }

  depends_on = [aws_eks_cluster.eks_cluster_okl]
}

# Considered adding iam role cluster to general iam but
# best practice is separated resources 
resource "aws_iam_role" "cluster" {
  name = "eks-role-okl"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

# aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
# aws_iam_role_policy_attachment.cluster_AmazonEKSComputePolicy,
# aws_iam_role_policy_attachment.cluster_AmazonEKSBlockStoragePolicy,
# aws_iam_role_policy_attachment.cluster_AmazonEKSLoadBalancingPolicy,
# aws_iam_role_policy_attachment.cluster_AmazonEKSNetworkingPolicy,

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_cloudwatch_log_group" "cloudwatch_cluster_okl" {
  # The log group name format is /aws/eks/<cluster-name>/cluster??
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name = local.cluster_name
  # name_prefix = var.prefix
  retention_in_days = 30

  log_group_class = "STANDARD"
}

# resource "aws_cloudwatch_log_delivery" "cloudwatch_storage" {
#   delivery_source_name     = aws_cloudwatch_log_delivery_source.cloudwatch_cluster_okl.name
#   delivery_destination_arn = aws_s3_bucket.cloudwatch_bucket.arn
# }


################################### Outputs #########################################


output "region" {
  description = "The AWS region and location of resources"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.sage_vpc.id
}

output "vpc_arn" {
  description = "AWS resource identifier for VPC"
  value       = aws_vpc.sage_vpc.arn
}

output "sagemaker_arn" {
  description = "The resource identifier for Sagemaker"
  value       = {for sage, model in aws_sagemaker_model.sagemodel_okl : sage => model.arn }
}

output "sagemaker_id" {
  description = "The unique identifier Sagemaker"
  value       = {for sage, model in aws_sagemaker_model.sagemodel_okl : sage => model.id }
}

output "sagemaker_name" {
  description = "The canonical name for the Sagemaker resource"
  value       = {for sage, model in aws_sagemaker_model.sagemodel_okl : sage => model.name }
}

output "sagemaker_meta" {
  description = "Sagemaker config data"
  value       = {for sage, model in aws_sagemaker_model.sagemodel_okl : sage => model.arn }
}

output "sagemaker_endpoint" {
  description = "Sagemaker endpoint to access resource"
  value       = aws_sagemaker_endpoint.sage_endpoint_okl
}

output "s3_arn" {
  description = "AWS resource identifier for s3"
  value       = aws_s3_bucket.sagemaker_s3_okl.arn
}

output "bucket" {
  description = "S3 bucket tasked for sagemaker"
  value       = aws_s3_bucket.sagemaker_s3_okl.bucket
}
output "ecr_repository_url" {
  description = "ECR URL for the Docker Image"
  value       = { for team, repo in aws_ecr_repository.ecr_repository : team => repo.repository_url }
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.eks_cluster_okl.name
}

output "eks_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.eks_cluster_okl.endpoint
}

output "eks_kubeconfig_certificate_authority_data" {
  description = "EKS certification for data access control"
  value       = aws_eks_cluster.eks_cluster_okl.certificate_authority[0].data
}

# TODO: review, may need client, client key, and certificate authority 
output "eks_meta" {
  description = "EKS resource config"
  value       = aws_eks_cluster.eks_cluster_okl
}
