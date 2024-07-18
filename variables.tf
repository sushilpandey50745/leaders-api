variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "ap-south-1"
}
variable "instance_type" {
  description = "EC2 instance type for Laravel launch configuration"
  default     = "t2.micro"  # Default instance type, change as needed
}
variable "key_name"{
  description = "Key Pair"
  default = "clouddeploy"
}


