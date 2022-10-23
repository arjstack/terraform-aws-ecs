module "ecs_cluster" {
    source = "./cluster"

    count = var.create_cluster ? 1 : 0

    cluster_name    = var.cluster_name
    use_fargate     = var.use_fargate

    enable_cloudwatch_container_insights = var.enable_cloudwatch_container_insights

    enable_execute_command_configuration = var.enable_execute_command_configuration
    execute_command_configurations = var.execute_command_configurations

    fargate_capacity_providers = var.fargate_capacity_providers
    autoscaling_capacity_providers = var.autoscaling_capacity_providers

    default_tags = var.default_tags
}

# ECS Task Roles
module "iam_ecs" {
    source = "git::https://github.com/arjstack/terraform-aws-iam.git?ref=v1.0.0"
    
    count = var.create_service ? 1 : 0
    
    policies = var.policies
    service_linked_roles = local.ecs_task_roles
}

## Create Service Discovery Private DNS Namespace.
resource aws_service_discovery_private_dns_namespace "this" {
    count = var.create_dns_namespace ? 1 : 0
    
    name        = (var.dns_name != "") ? var.dns_name : format("%s.ecs.local", var.cluster_name)
    description = "Service Discovery Private DNS Namespace for ECS Cluster - ${var.cluster_name}"
    
    vpc         = var.vpc_id
}

## Security Group for ECS Service/Task
module "ecs_security_group" {
    source = "git::https://github.com/arjstack/terraform-aws-security-groups.git?ref=v1.0.0"

    count = (var.create_service && var.create_sg) ? 1 : 0

    vpc_id = var.vpc_id
    name = var.sg_name

    ingress_rules = local.sg_ingress_rules
    egress_rules  = local.sg_egress_rules
}

## ECS Service
module "ecs_service" {
    source = "./service"

    count = var.create_service ? 1 : 0
    
    cluster_name = var.cluster_name
    cluster_arn  = local.cluster_arn
    use_fargate  = var.use_fargate    
    aws_region = var.aws_region
    account_id = data.aws_caller_identity.current.account_id

    service_name = var.service_name
    service_min_capacity = lookup(var.service_scalability, "min_capacity", 1)
    service_max_capacity = lookup(var.service_scalability, "max_capacity", lookup(var.service_scalability, "min_capacity", 1))
    service_desired_capacity = lookup(var.service_scalability, "desired_capacity", lookup(var.service_scalability, "min_capacity", 1))
    launch_type = var.service_launch_type
    
    service_task_network_mode   = var.service_task_network_mode
    service_task_pid_mode       = var.service_task_pid_mode
    ecs_task_execution_role_arn = module.iam_ecs[0].service_linked_roles["ecs-task-execution"].arn
    ecs_task_role_arn           = module.iam_ecs[0].service_linked_roles["ecs-task"].arn

    service_volumes = var.service_volumes
    
    container_configurations = var.container_configurations

    ## Network Configurations
    subnets = var.subnets
    assign_public_ip = var.assign_public_ip
    security_groups = local.service_security_groups
    
    ## Load Balancer Configurations
    attach_load_balancer = var.attach_load_balancer
    load_balancer_arn    = var.attach_load_balancer ? data.aws_lb.this[0].arn : null
    
    ## Log Management
    create_log_group    = var.create_log_group
    log_group_retention         = var.log_group_retention

    ## Service Discovery
    enable_service_discovery    = var.enable_service_discovery
    namespace_id                = local.namespace_id
    routing_policy              = var.routing_policy
    ## Tags
    default_tags = var.default_tags
}