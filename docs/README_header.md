# AWS Load Balancer Terraform Module

Terraform module to provision an Amazon Web Services (AWS) Application Load Balancer (ALB) and associated resources like Listeners, Target Groups, and Routing Rules to distribute incoming application traffic.

## Permissions

To provision the AWS resources managed by this module, the IAM role or user running Terraform needs permissions such as:

- `ElasticLoadBalancingFullAccess` (or fine-grained privileges to manage Load Balancers, Listeners, Target Groups, and Listener Rules).
- Additional permissions to describe EC2 resources and subnets (e.g., `ec2:DescribeSubnets`, `ec2:DescribeVpcs`, `ec2:DescribeSecurityGroups`).
- Permissions to manage ACM certificates, Route53 DNS records, and WAFv2 Web ACL associations if enabling HTTPS endpoints, custom domain routing, or WAF integrations.

## Authentications

Authentication to AWS can be configured using one of the following methods, with preference given to OIDC and dynamic provider credentials in CI/CD environments.

### HCP Terraform / Terraform Enterprise Dynamic Credentials (OIDC)

Use dynamic provider credentials via OpenID Connect (OIDC) for secure, short-lived credentials when running in HCP Terraform or Terraform Enterprise.

- **Using environment variables (HCP Terraform Workspace)**

  - `TFC_AWS_PROVIDER_AUTH=true`
  - `TFC_AWS_RUN_ROLE_ARN=<aws-iam-role-arn>`

### OIDC with GitHub Actions

When using GitHub Actions, configure OIDC via the `aws-actions/configure-aws-credentials` action.

- **Using GitHub Actions**

  ```yaml
  - name: Configure AWS credentials
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::111122223333:role/github-actions-role
      aws-region: us-east-1
  ```

### Static Access Keys

For local development or environments not supporting OIDC, use static IAM programmatic access keys.

- **Inside the provider block**

  ```hcl
  provider "aws" {
    region     = "us-east-1"
    access_key = "<aws-access-key-id>"
    secret_key = "<aws-secret-access-key>"
  }
  ```

- **Using environment variables**

  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_DEFAULT_REGION` (optional)

Documentation:

- [AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication)
- [Dynamic Provider Credentials in HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)

## Features

- Complete foundational AWS application load balancer setup (ALB/NLB/GWLB, connection logging, access logging).
- Highly configurable Listeners (HTTP, HTTPS, standard/fixed responses, redirects, mutual TLS).
- Flexible Target Group configurations (EC2 instances, IP, Lambda functions, stickiness, health checks).
- Fully supported Listener Rules for advanced URL, path, and header-based routing.
- Integrations for AWS Certificate Manager (ACM), Route53 alias records, and WAFv2 Web ACLs.

## Usage example

### Example 1: HTTPS ALB with Automated ACM Certificate & Route53 Validation

```hcl
module "alb" {
  source  = "app.terraform.io/benoitblais-hashicorp/alb/aws"
  version = "~> 0.0"

  name               = "web-static"
  vpc_id             = "vpc-12345678"
  subnets            = ["subnet-12345678", "subnet-87654321"]
  public_hosted_zone = "example.com"
  create_certificate = true

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  listeners = {
    http-80 = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    https-443 = {
      port     = 443
      protocol = "HTTPS"
      # certificate_arn automatically defaults to the generated certificate
      forward = {
        target_group_key = "web-static-tg"
      }
    }
  }

  target_groups = {
    web-static-tg = {
      name_prefix       = "webstc"
      protocol          = "HTTP"
      port              = 8080
      target_type       = "instance"
      create_attachment = false
    }
  }

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}
```

### Example 2: HTTPS ALB with an Existing Certificate ARN

```hcl
module "alb" {
  source  = "app.terraform.io/benoitblais-hashicorp/alb/aws"
  version = "~> 0.0"

  name            = "web-static"
  vpc_id          = "vpc-12345678"
  subnets         = ["subnet-12345678", "subnet-87654321"]
  certificate_arn = "arn:aws:acm:ca-central-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

  listeners = {
    https-443 = {
      port     = 443
      protocol = "HTTPS"
      forward = {
        target_group_key = "web-static-tg"
      }
    }
  }

  target_groups = {
    web-static-tg = {
      name_prefix       = "webstc"
      protocol          = "HTTP"
      port              = 8080
      target_type       = "instance"
      create_attachment = false
    }
  }
}
```
