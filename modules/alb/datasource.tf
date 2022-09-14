data "aws_vpc" "default" {
  
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_acm_certificate" "tls" {
  domain      = var.domain
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}