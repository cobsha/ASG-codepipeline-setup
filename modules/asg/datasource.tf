data "aws_ami" "ami" {

  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = [var.image_name]
  }

}

data "aws_sns_topic" "sns" {
  name = var.sns_topic_name
}