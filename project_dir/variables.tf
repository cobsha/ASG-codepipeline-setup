variable "region" {}
variable "env" {}

variable "project" {}

variable "sg" {}

variable "domain" {}


variable "instance_role" {}

variable "instance_type" {}

variable "az" {

  type = list(any)
}

variable "cw_namespace" {}

variable "key_name" {

}

variable "vpc_id" {
  
}

variable "subnets" {

  type = list(any)
}


variable "image_name" {
  
}

variable "sns_topic_name" {
  
}

variable "bucket_name" {
  
}