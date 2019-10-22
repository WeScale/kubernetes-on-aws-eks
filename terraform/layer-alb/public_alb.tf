resource "aws_lb" "public_alb" {
  name               = "public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.allow_https.id}"]
  subnets            = [
      "${data.terraform_remote_state.layer-base.outputs.sn_public_a_id}",
      "${data.terraform_remote_state.layer-base.outputs.sn_public_b_id}",
      "${data.terraform_remote_state.layer-base.outputs.sn_public_c_id}"
    ]

  enable_deletion_protection = false

  tags = {
    Environment = "test"
  }
}

resource "aws_route53_record" "public_alb_dns" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "public.${var.public_dns}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_lb.public_alb.dns_name}"]
}

resource "aws_acm_certificate" "public_alb" {
  domain_name       = "public.${var.public_dns}"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }
}

resource "aws_route53_record" "public_alb_cert_validation" {
  name    = "${aws_acm_certificate.public_alb.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.public_alb.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  records = ["${aws_acm_certificate.public_alb.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "public_alb_cert_validation" {
  certificate_arn         = "${aws_acm_certificate.public_alb.arn}"
  validation_record_fqdns = ["${aws_route53_record.public_alb_cert_validation.fqdn}"]
}

resource "aws_lb_listener" "public_alb" {
  load_balancer_arn = "${aws_lb.public_alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_acm_certificate_validation.public_alb_cert_validation.certificate_arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${data.terraform_remote_state.layer-eks.outputs.public-target-group}"
  }
}