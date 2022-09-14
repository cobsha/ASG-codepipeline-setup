data "aws_ami" "ami" {

  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["nodeapp"]
  }

}

data "aws_sns_topic" "sns" {
  name = "application_alerts"
}