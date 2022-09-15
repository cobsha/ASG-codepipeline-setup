module "alb" {

  source  = "../modules/alb"
  env     = var.env
  project = var.project
  domain  = var.domain
  vpc_id = var.vpc_id
  subnets = var.subnets
}

module "asg" {

  source        = "../modules/asg"
  instance_role = var.instance_role
  instance_type = var.instance_type
  az            = var.az
  cw_namespace  = var.cw_namespace
  project       = var.project
  env           = var.env
  alb_sg        = module.alb.alb_sg.id
  tg            = module.alb.traget_group.arn
  key           = var.key_name
  sns_topic_name = var.sns_topic_name
  image_name = var.image_name

}


resource "aws_iam_role" "codedeploy" {

    assume_role_policy    = file("codedeploy_assume_role_policy.json")
    
    description           = "Allows CodeDeploy to call AWS services such as Auto Scaling on our behalf."
    force_detach_policies = false
    managed_policy_arns   = [
        "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
    ]
    max_session_duration  = 3600
    name                  = "${var.project}-codedeploy-role"
    path                  = "/"
    tags                  = {
        "Name" = "${var.project}-codedeploy-role"
    }

}


resource "aws_iam_policy" "pipeline" {


    description = "Policy used for CodePipeline"
    name        = "${var.project}-codepipeline-role-policy"
    path        = "/service-role/"
    policy      = file("pipeline_iam_policy.json")
    tags        = {
    
      name = "${var.project}-codepipeline-role-policy"
    }
}


resource "aws_iam_role" "pipeline" {

    assume_role_policy    = file("pipeline_assume_role_policy.json")
    
    force_detach_policies = false

    managed_policy_arns   = [
        aws_iam_policy.pipeline.arn
    ]
    max_session_duration  = 3600
    name                  = "${var.project}-codepipeline-role"
    path                  = "/service-role/"
    tags                  = {
      
      "Name" = "${var.project}-codepipeline-role"
    }

}


resource "aws_codedeploy_app" "node_app" {

  name             = "node_app"
  compute_platform = "Server"
  tags = {
    env = var.env
  }
}


resource "aws_codedeploy_deployment_group" "deployment_group" {

  app_name               = aws_codedeploy_app.node_app.name
  autoscaling_groups     = [module.asg.asg_op.name]
  deployment_config_name = "CodeDeployDefault.HalfAtATime"
  deployment_group_name  = "demo-code-deployment"
  service_role_arn       = aws_iam_role.codedeploy.arn
  tags                   = {}

  auto_rollback_configuration {

    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
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
  role_arn = aws_iam_role.pipeline.arn
  tags     = {}


  artifact_store {
    location = "artifact-for-codedeploy"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      category = "Source"
      configuration = {
        "PollForSourceChanges" = "false"
        "S3Bucket"             = "artifact-for-codedeploy"
        "S3ObjectKey"          = "SampleWebApp.zip"
      }
      input_artifacts  = []
      name             = "Source"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceArtifact"]
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
      category = "Deploy"
      configuration = {
        "ApplicationName"     = aws_codedeploy_app.node_app.name
        "DeploymentGroupName" = aws_codedeploy_deployment_group.deployment_group.deployment_group_name
      }
      input_artifacts  = ["SourceArtifact"]
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


