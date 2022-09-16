data "aws_acm_certificate" "tls" {
  
  domain      = var.domain
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}