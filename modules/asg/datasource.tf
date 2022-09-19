data "aws_ami" "ami" {

  most_recent      = true
  owners           = ["self"]

  filter {
    name   = "name"
    values = [var.image_name]
  }

}
