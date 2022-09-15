module "alb" {

  source = "../modules/alb"
  env = var.env
  project = var.project
  sg = var.sg
  domain = var.domain
}

module "asg" {
  
  source = "../modules/asg"
  instance_role = var.instance_role
  instance_type = var.instance_type
  az = var.az
  cw_namespace = var.cw_namespace
  project = var.project
  env = var.env
  sg = var.sg
  tg = module.alb.traget_group.arn
  key = var.key_name

}



resource "aws_codedeploy_app" "node_app" {

  name             = "node_app"
  compute_platform = "Server"
  tags             = {
  env = var.env
    }
}


resource "aws_codedeploy_deployment_group" "deployment_group" {

  app_name               = aws_codedeploy_app.node_app.name
  autoscaling_groups     = [ module.asg.asg_op.name ]
  deployment_config_name = "CodeDeployDefault.HalfAtATime"
  deployment_group_name  = "demo-code-deployment"
  service_role_arn       = data.aws_iam_role.deployment_role.arn
  tags                   = {}

  auto_rollback_configuration {
    
    enabled = true
    events  = [ "DEPLOYMENT_FAILURE" ]
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {

    target_group_info {
      name = module.alb.traget_group.name
        }
    }
}

resource "aws_codepipeline" "codepipeline" {

  name     = "demo"
  role_arn = data.aws_iam_role.pipeline.arn
  tags     = {}
  

  artifact_store {
    location = "artifact-for-codedeploy"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category         = "Source"
      configuration    = {
      "PollForSourceChanges" = "false"
      "S3Bucket"             = "artifact-for-codedeploy"
      "S3ObjectKey"          = "SampleWebApp.zip"
        }
      input_artifacts  = []
      name             = "Source"
      namespace        = "SourceVariables"
      output_artifacts = [ "SourceArtifact" ]
      owner            = "AWS"
      provider         = "S3"
      region           = "ap-south-1"
      run_order        = 1
      version          = "1"
        }
  }
    stage {
      name = "Deploy"

      action {
      category         = "Deploy"
      configuration    = {
      "ApplicationName"     = aws_codedeploy_app.node_app.name
      "DeploymentGroupName" = aws_codedeploy_deployment_group.deployment_group.deployment_group_name
      }
      input_artifacts  = [ "SourceArtifact" ]
      name             = "Deploy"
      namespace        = "DeployVariables"
      output_artifacts = []
      owner            = "AWS"
      provider         = "CodeDeploy"
      region           = "ap-south-1"
      run_order        = 1
      version          = "1"
      }
    }
    depends_on = [
      aws_codedeploy_deployment_group.deployment_group
    ]
}