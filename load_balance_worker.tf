

resource "aws_lb" "k8_workers_lb" {
    name        = "k8-workers-lb"
    internal    = false
    load_balancer_type = "application"
    #subnets = module.vpc.private_subnets #[for subnet in module.vpc.private_subnets : subnet.id]
    subnets = module.vpc.public_subnets
    security_groups = [aws_security_group.k8_alb_workers.id]
    tags = {
      Terraform = "true"
      Environment = "dev"
  }
}

# target_type instance not working well when we bound this LB as a control-plane-endpoint. hence had to use IP target_type
#https://stackoverflow.com/questions/56768956/how-to-use-kubeadm-init-configuration-parameter-controlplaneendpoint/70799078#70799078

resource "aws_lb_target_group" "k8_workers_api" {
    name = "k8-workers-api"
    port = 31292
    protocol = "HTTP"
    vpc_id = module.vpc.vpc_id
    target_type = "ip"

    health_check {
      port      = 31292
      protocol  = "HTTP"
      interval  = 20
      healthy_threshold = 2
      unhealthy_threshold = 2
    }
}

resource "aws_lb_listener" "k8_workers_lb_listener" {
    load_balancer_arn = aws_lb.k8_workers_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
        target_group_arn = aws_lb_target_group.k8_workers_api.id
        type = "forward"
    }
}

# attach the workers ec2 instances to the target group 
resource "aws_lb_target_group_attachment" "k8_workers_attachment" {
    count = length(aws_instance.workers.*.id)
    target_group_arn = aws_lb_target_group.k8_workers_api.arn
    target_id = aws_instance.workers.*.private_ip[count.index]
}
