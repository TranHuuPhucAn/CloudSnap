# Input variables
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "cloudsnap"
}

variable "notification_email" {
  description = "Email address for SNS job completion alerts"
  type        = string
}