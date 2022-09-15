region = "ap-south-1"

env = "stage"

project = "goodbits"

sg = "sg-04a8aaa4c987841c1"

domain = "cobbtech.site"

instance_role = "arn:aws:iam::642071678120:instance-profile/codepipeline-goodbits"

instance_type = "t2.micro"

az = ["ap-south-1a", "ap-south-1b"]

cw_namespace = "ASG_Memory_goodbits"

key_name = "key"

vpc_id = "vpc-0df744a2b608347ef"

subnets = [ "subnet-0cb244d676ad47723", "subnet-0e7c40917890df42a", "subnet-0218b14d25be14071", ]

image_name = "nodeapp"

sns_topic_name = "application_alerts"