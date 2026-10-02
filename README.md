<!-- BEGIN_TF_DOCS -->
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

## Documentation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.62 |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_logs"></a> [access\_logs](#input\_access\_logs) | Map containing access logging configuration for load balancer | `map(string)` | `{}` | no |
| <a name="input_additional_target_group_attachments"></a> [additional\_target\_group\_attachments](#input\_additional\_target\_group\_attachments) | Map of additional target group attachments to create. Use `target_group_key` to attach to the target group created in `target_groups` | `any` | `{}` | no |
| <a name="input_associate_web_acl"></a> [associate\_web\_acl](#input\_associate\_web\_acl) | Indicates whether a Web Application Firewall (WAF) ACL should be associated with the load balancer | `bool` | `false` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | The ARN of an existing SSL/TLS certificate to use for HTTPS listeners. If not provided and `create_certificate` is true, an ACM certificate will be requested and validated using Route53. | `string` | `null` | no |
| <a name="input_certificate_domain_name"></a> [certificate\_domain\_name](#input\_certificate\_domain\_name) | The domain name for which the ACM certificate should be issued. Defaults to `<name>.<public_hosted_zone>` if null and `public_hosted_zone` is provided. | `string` | `null` | no |
| <a name="input_certificate_subject_alternative_names"></a> [certificate\_subject\_alternative\_names](#input\_certificate\_subject\_alternative\_names) | A list of additional domain names (SANs) to include in the ACM certificate. | `list(string)` | `[]` | no |
| <a name="input_client_keep_alive"></a> [client\_keep\_alive](#input\_client\_keep\_alive) | Client keep alive value in seconds. The valid range is 60-604800 seconds. The default is 3600 seconds. | `number` | `null` | no |
| <a name="input_connection_logs"></a> [connection\_logs](#input\_connection\_logs) | Map containing access logging configuration for load balancer | `map(string)` | `{}` | no |
| <a name="input_create"></a> [create](#input\_create) | Controls if resources should be created (affects nearly all resources) | `bool` | `true` | no |
| <a name="input_create_certificate"></a> [create\_certificate](#input\_create\_certificate) | Controls whether to create and validate an ACM certificate using Route53 when `certificate_arn` is not provided. | `bool` | `false` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Determines if a security group is created | `bool` | `true` | no |
| <a name="input_customer_owned_ipv4_pool"></a> [customer\_owned\_ipv4\_pool](#input\_customer\_owned\_ipv4\_pool) | The ID of the customer owned ipv4 pool to use for this load balancer | `string` | `null` | no |
| <a name="input_default_port"></a> [default\_port](#input\_default\_port) | Default port used across the listener and target group | `number` | `80` | no |
| <a name="input_default_protocol"></a> [default\_protocol](#input\_default\_protocol) | Default protocol used across the listener and target group | `string` | `"HTTP"` | no |
| <a name="input_desync_mitigation_mode"></a> [desync\_mitigation\_mode](#input\_desync\_mitigation\_mode) | Determines how the load balancer handles requests that might pose a security risk to an application due to HTTP desync. Valid values are `monitor`, `defensive` (default), `strictest` | `string` | `null` | no |
| <a name="input_dns_record_client_routing_policy"></a> [dns\_record\_client\_routing\_policy](#input\_dns\_record\_client\_routing\_policy) | Indicates how traffic is distributed among the load balancer Availability Zones. Possible values are any\_availability\_zone (default), availability\_zone\_affinity, or partial\_availability\_zone\_affinity. Only valid for network type load balancers. | `string` | `null` | no |
| <a name="input_drop_invalid_header_fields"></a> [drop\_invalid\_header\_fields](#input\_drop\_invalid\_header\_fields) | Indicates whether HTTP headers with header fields that are not valid are removed by the load balancer (`true`) or routed to targets (`false`). The default is `true`. Elastic Load Balancing requires that message header names contain only alphanumeric characters and hyphens. Only valid for Load Balancers of type `application` | `bool` | `true` | no |
| <a name="input_enable_cross_zone_load_balancing"></a> [enable\_cross\_zone\_load\_balancing](#input\_enable\_cross\_zone\_load\_balancing) | If `true`, cross-zone load balancing of the load balancer will be enabled. For application load balancer this feature is always enabled (`true`) and cannot be disabled. Defaults to `true` | `bool` | `true` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | If `true`, deletion of the load balancer will be disabled via the AWS API. This will prevent Terraform from deleting the load balancer. Defaults to `true` | `bool` | `true` | no |
| <a name="input_enable_http2"></a> [enable\_http2](#input\_enable\_http2) | Indicates whether HTTP/2 is enabled in application load balancers. Defaults to `true` | `bool` | `null` | no |
| <a name="input_enable_tls_version_and_cipher_suite_headers"></a> [enable\_tls\_version\_and\_cipher\_suite\_headers](#input\_enable\_tls\_version\_and\_cipher\_suite\_headers) | Indicates whether the two headers (`x-amzn-tls-version` and `x-amzn-tls-cipher-suite`), which contain information about the negotiated TLS version and cipher suite, are added to the client request before sending it to the target. Only valid for Load Balancers of type `application`. Defaults to `false` | `bool` | `null` | no |
| <a name="input_enable_waf_fail_open"></a> [enable\_waf\_fail\_open](#input\_enable\_waf\_fail\_open) | Indicates whether to allow a WAF-enabled load balancer to route requests to targets if it is unable to forward the request to AWS WAF. Defaults to `false` | `bool` | `null` | no |
| <a name="input_enable_xff_client_port"></a> [enable\_xff\_client\_port](#input\_enable\_xff\_client\_port) | Indicates whether the X-Forwarded-For header should preserve the source port that the client used to connect to the load balancer in `application` load balancers. Defaults to `false` | `bool` | `null` | no |
| <a name="input_enforce_security_group_inbound_rules_on_private_link_traffic"></a> [enforce\_security\_group\_inbound\_rules\_on\_private\_link\_traffic](#input\_enforce\_security\_group\_inbound\_rules\_on\_private\_link\_traffic) | Indicates whether inbound security group rules are enforced for traffic originating from a PrivateLink. Only valid for Load Balancers of type network. The possible values are on and off. | `string` | `null` | no |
| <a name="input_idle_timeout"></a> [idle\_timeout](#input\_idle\_timeout) | The time in seconds that the connection is allowed to be idle. Only valid for Load Balancers of type `application`. Default: `60` | `number` | `null` | no |
| <a name="input_internal"></a> [internal](#input\_internal) | If true, the LB will be internal. Defaults to `false` | `bool` | `null` | no |
| <a name="input_ip_address_type"></a> [ip\_address\_type](#input\_ip\_address\_type) | The type of IP addresses used by the subnets for your load balancer. The possible values are `ipv4` and `dualstack` | `string` | `null` | no |
| <a name="input_listeners"></a> [listeners](#input\_listeners) | Map of listener configurations to create | `any` | `{}` | no |
| <a name="input_load_balancer_type"></a> [load\_balancer\_type](#input\_load\_balancer\_type) | The type of load balancer to create. Possible values are `application`, `gateway`, or `network`. The default value is `application` | `string` | `"application"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the LB. This name must be unique within your AWS account, can have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and must not begin or end with a hyphen | `string` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Creates a unique name beginning with the specified prefix. Conflicts with `name` | `string` | `null` | no |
| <a name="input_preserve_host_header"></a> [preserve\_host\_header](#input\_preserve\_host\_header) | Indicates whether the Application Load Balancer should preserve the Host header in the HTTP request and send it to the target without any change. Defaults to `false` | `bool` | `null` | no |
| <a name="input_public_hosted_zone"></a> [public\_hosted\_zone](#input\_public\_hosted\_zone) | The Route 53 public hosted zone name (e.g., 'example.com') where DNS validation records will be published. Required if `create_certificate` is true and `certificate_arn` is not provided. | `string` | `null` | no |
| <a name="input_putin_khuylo"></a> [putin\_khuylo](#input\_putin\_khuylo) | Do you agree that Putin doesn't respect Ukrainian sovereignty and territorial integrity? More info: https://en.wikipedia.org/wiki/Putin_khuylo! | `bool` | `true` | no |
| <a name="input_route53_records"></a> [route53\_records](#input\_route53\_records) | Map of Route53 records to create. Each record map should contain `zone_id`, `name`, and `type` | `any` | `{}` | no |
| <a name="input_security_group_description"></a> [security\_group\_description](#input\_security\_group\_description) | Description of the security group created | `string` | `null` | no |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | Security group egress rules to add to the security group created | `any` | `{}` | no |
| <a name="input_security_group_ingress_rules"></a> [security\_group\_ingress\_rules](#input\_security\_group\_ingress\_rules) | Security group ingress rules to add to the security group created | `any` | `{}` | no |
| <a name="input_security_group_name"></a> [security\_group\_name](#input\_security\_group\_name) | Name to use on security group created | `string` | `null` | no |
| <a name="input_security_group_tags"></a> [security\_group\_tags](#input\_security\_group\_tags) | A map of additional tags to add to the security group created | `map(string)` | `{}` | no |
| <a name="input_security_group_use_name_prefix"></a> [security\_group\_use\_name\_prefix](#input\_security\_group\_use\_name\_prefix) | Determines whether the security group name (`security_group_name`) is used as a prefix | `bool` | `true` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | A list of security group IDs to assign to the LB | `list(string)` | `[]` | no |
| <a name="input_subnet_mapping"></a> [subnet\_mapping](#input\_subnet\_mapping) | A list of subnet mapping blocks describing subnets to attach to load balancer | `list(map(string))` | `[]` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | A list of subnet IDs to attach to the LB. Subnets cannot be updated for Load Balancers of type `network`. Changing this value for load balancers of type `network` will force a recreation of the resource | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_target_groups"></a> [target\_groups](#input\_target\_groups) | Map of target group configurations to create | `any` | `{}` | no |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | Create, update, and delete timeout configurations for the load balancer | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Identifier of the VPC where the security group will be created | `string` | `null` | no |
| <a name="input_web_acl_arn"></a> [web\_acl\_arn](#input\_web\_acl\_arn) | Web Application Firewall (WAF) ARN of the resource to associate with the load balancer | `string` | `null` | no |
| <a name="input_xff_header_processing_mode"></a> [xff\_header\_processing\_mode](#input\_xff\_header\_processing\_mode) | Determines how the load balancer modifies the X-Forwarded-For header in the HTTP request before sending the request to the target. The possible values are `append`, `preserve`, and `remove`. Only valid for Load Balancers of type `application`. The default is `append` | `string` | `null` | no |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_lambda_permission.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_route53_record.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_wafv2_web_acl_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_certificate_id"></a> [acm\_certificate\_id](#output\_acm\_certificate\_id) | The ID of the ACM certificate generated by the module |
| <a name="output_acm_certificate_status"></a> [acm\_certificate\_status](#output\_acm\_certificate\_status) | The status of the ACM certificate generated by the module |
| <a name="output_arn"></a> [arn](#output\_arn) | The ID and ARN of the load balancer we created |
| <a name="output_arn_suffix"></a> [arn\_suffix](#output\_arn\_suffix) | ARN suffix of our load balancer - can be used with CloudWatch |
| <a name="output_certificate_arn"></a> [certificate\_arn](#output\_certificate\_arn) | The ARN of the certificate used by the load balancer (either provided or generated via ACM) |
| <a name="output_dns_name"></a> [dns\_name](#output\_dns\_name) | The DNS name of the load balancer |
| <a name="output_id"></a> [id](#output\_id) | The ID and ARN of the load balancer we created |
| <a name="output_listener_rules"></a> [listener\_rules](#output\_listener\_rules) | Map of listeners rules created and their attributes |
| <a name="output_listeners"></a> [listeners](#output\_listeners) | Map of listeners created and their attributes |
| <a name="output_route53_records"></a> [route53\_records](#output\_route53\_records) | The Route53 records created and attached to the load balancer |
| <a name="output_security_group_arn"></a> [security\_group\_arn](#output\_security\_group\_arn) | Amazon Resource Name (ARN) of the security group |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group |
| <a name="output_target_groups"></a> [target\_groups](#output\_target\_groups) | Map of target groups created and their attributes |
| <a name="output_zone_id"></a> [zone\_id](#output\_zone\_id) | The zone\_id of the load balancer to assist with creating DNS records |

<!-- markdownlint-enable -->
<!-- END_TF_DOCS -->