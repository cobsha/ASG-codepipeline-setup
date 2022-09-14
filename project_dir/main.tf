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
  tg = module.alb.tg_arn
  key = var.key_name

}
