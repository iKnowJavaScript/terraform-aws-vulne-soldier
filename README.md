# vulne-soldier: A Modern Day AWS EC2 Vulnerability Remediation Tool

[![Terraform registry](https://img.shields.io/badge/Terraform_Registry-0.0.2-blue)](https://registry.terraform.io/modules/iKnowJavaScript/vulne-soldier/aws/latest)
[![Terraform](https://img.shields.io/badge/Terraform-0.0.2-623CE4)](https://www.terraform.io)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

This Terraform module consists of the configuration for automating the remediation of AWS EC2 vulnerabilities using AWS Inspector findings. It provisions essential resources such as an SSM document, Lambda function, and CloudWatch event rules for automated vulnerability management.

## Description

This Terraform module sets up an automated vulnerability remediation environment optimized for production use. By creating an SSM document to define the remediation steps, setting up a Lambda function to execute the remediation, and establishing CloudWatch event rules to trigger the process based on AWS Inspector findings, the module offers a straightforward approach to managing EC2 vulnerabilities on AWS.

This module provisions:

- AWS SSM documents
- AWS Lambda functions
- AWS CloudWatch event rules
- IAM roles and policies


![Architecture](assets/component-overview.png)

## Usage

### Setup terraform module

#### Download lambda

To apply the terraform module, the compiled lambdas (.zip files) need to be available locally. They can either be downloaded from the GitHub release page or built locally.

The lambdas can be downloaded manually from the [release page](https://github.com/iKnowJavaScript/terraform-aws-vulne-soldier/releases) or by building the Lambda folder using Node.

For local development you can build the lambdas at once using `/lambda` or individually using `npm zip`.

### Example Configuration

To deploy the `vulne-soldier` module, you can use the following configuration in your Terraform setup:

```hcl
module "remediation" {
  source = "../../"

  name             = "vulne-soldier-compliance-remediate"
  environment      = "dev"
  aws_region       = "us-east-1"
  account_id       = "2123232323"
  lambda_log_group = "/aws/lambda/vulne-soldier-compliance-remediate"
  lambda_zip       = "./lambda.zip"
  remediation_options = {
    region                                     = "us-east-1"
    reboot_option                              = "NoReboot"
    target_ec2_tag_name                        = "AmazonECSManaged"
    target_ec2_tag_value                       = "true"
    vulnerability_severities                   = ["CRITICAL, HIGH"]
    override_findings_for_target_instances_ids = []
  }
}

provider "aws" {
  region = "us-east-1"
}
```

## Inputs

| Name                                     | Description                                                                 | Type          | Default                                    | Required |
|------------------------------------------|-----------------------------------------------------------------------------|---------------|--------------------------------------------|:--------:|
| `name`                                   | Name of the application                                                     | `string`      | n/a                                        | yes      |
| `environment`                            | Name of the environment                                                     | `string`      | n/a                                        | yes      |
| `aws_region`                             | AWS region where the resources will be created                              | `string`      | n/a                                        | yes      |
| `account_id`                             | AWS account ID                                                              | `string`      | n/a                                        | yes      |
| `lambda_log_group`                       | Name of the CloudWatch Log Group for the Lambda function                    | `string`      | n/a                                        | yes      |
| `lambda_zip`                             | File location of the lambda zip file for remediation                                                              | `string`      | `lambda.zip`                                        | yes      |
| `remediation_options`                    | Options for the remediation document                                        | `object`      | n/a                                        | yes      |
| `remediation_options.region`             | The region to use                                                           | `string`      | `us-east-1`                                | no       |
| `remediation_options.reboot_option`      | Reboot option for patching                                                  | `string`      | `NoReboot`                                 | no       |
| `remediation_options.target_ec2_tag_name`| The tag name to filter EC2 instances                                        | `string`      | `AmazonECSManaged`                         | no       |
| `remediation_options.target_ec2_tag_value`| The tag value to filter EC2 instances                                       | `string`      | `true`                                     | no       |
| `remediation_options.vulnerability_severities`| Comma separated list of vulnerability severities to filter findings                        | `string`| `"CRITICAL, HIGH"`                       | no       |
| `remediation_options.override_findings_for_target_instances_ids`| Comma separated list of instance IDs to override findings for target instances              | `string`| `""`                                       | no       |

## Outputs

| Name                  | Description                  | Sensitive |
|-----------------------|------------------------------|:---------:|
| `lambda_function_arn` | Lambda function ARN          | No        |
| `lambda_function_name`| Lambda function name         | No        |
| `ssm_document_name`   | SSM document name            | No        |

To retrieve outputs, use the `terraform output` command, for example: `terraform output lambda_function_arn`.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.