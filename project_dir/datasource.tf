data "aws_iam_role" "deployment_role" {

  name = "CodeDeployRole"
}

data "aws_iam_policy" "deployment_policy" {
  name = "AWSCodeDeployRole"
}

data "aws_iam_role" "pipeline" {

  name = "AWSCodePipelineServiceRole-ap-south-1-nodejsapp-pipeline"
}

data "aws_iam_policy" "codedeploy_managed_policy" {

  name = "AWSCodeDeployRole"
}
