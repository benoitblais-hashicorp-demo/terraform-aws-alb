mock_provider "aws" {}

variables {
  name    = "test-alb"
  subnets = ["subnet-11111111", "subnet-22222222"]
}

run "validate_public_hosted_zone_required_when_create_certificate_true" {
  command = plan

  variables {
    create_certificate = true
    certificate_arn    = null
    public_hosted_zone = null
  }

  expect_failures = [
    var.public_hosted_zone,
  ]
}

run "validate_public_hosted_zone_not_required_when_certificate_arn_provided" {
  command = plan

  variables {
    create_certificate = true
    certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/test-cert-id"
    public_hosted_zone = null
  }
}
