module "labels" {
  source      = "git::git@github.com:shanav-tech/terraform-aws-labels.git?ref=v1.0.0"
  name        = var.name
  environment = var.environment
  managedby   = var.managedby
  label_order = var.label_order
  repository  = var.repository
}

resource "aws_acm_certificate" "import-cert" {
  count             = var.enable && var.import_certificate ? 1 : 0
  private_key       = file(var.private_key)
  certificate_body  = file(var.certificate_body)
  certificate_chain = file(var.certificate_chain)
  tags              = module.labels.tags

  dynamic "validation_option" {
    for_each = var.validation_option
    content {
      domain_name       = try(validation_option.value["domain_name"], validation_option.key)
      validation_domain = validation_option.value["validation_domain"]
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "cert" {
  count             = var.enable && var.enable_aws_certificate ? 1 : 0
  private_key       = file("${path.module}/private-key.pem")
  certificate_body  = file("${path.module}/certificate.pem")
  certificate_chain = file("${path.module}/certificate-chain.pem")


  tags = module.labels.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert" {
  count                   = var.enable && var.validate_certificate ? 1 : 0
  certificate_arn         = join("", aws_acm_certificate.cert[*].arn)
  validation_record_fqdns = flatten([aws_route53_record.default[*].fqdn, var.validation_record_fqdns])
}

data "aws_route53_zone" "default" {
  count = var.enable && var.enable_dns_validation ? 1 : 0

  name         = var.domain_name
  private_zone = var.private_zone
}

resource "aws_route53_record" "default" {
  count = var.enable && var.enable_dns_validation ? 1 : 0

  zone_id         = join("", data.aws_route53_zone.default[*].zone_id)
  ttl             = var.ttl
  allow_overwrite = var.allow_overwrite
  name            = join("", aws_acm_certificate.cert[*].domain_validation_options[*].resource_record_name)
  type            = join("", aws_acm_certificate.cert[*].domain_validation_options[*].resource_record_type)
  records         = [join("", aws_acm_certificate.cert[*].domain_validation_options[*].resource_record_value)]
}

resource "aws_acm_certificate_validation" "default" {
  count = var.enable && var.enable_dns_validation ? 1 : 0

  certificate_arn         = join("", aws_acm_certificate.cert[*].arn)
  validation_record_fqdns = aws_route53_record.default[*].fqdn
}
