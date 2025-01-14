module "remediation" {
  source  = "iKnowJavaScript/vulne-soldier/aws"
  version = "1.0.2"

  name             = "vulne-soldier-compliance-remediate"
  environment      = "dev"
  aws_region       = "us-east-1"
  account_id       = "2132323212_dummmmy"
  lambda_log_group = "/aws/lambda/vulne-soldier-compliance-remediate"
  lambda_zip       = "../../lambda.zip"
  remediation_options = {
    region                                     = "us-east-1"
    reboot_option                              = "NoReboot"
    target_ec2_tag_name                        = "AmazonECSManaged"
    target_ec2_tag_value                       = "true"
    vulnerability_severities                   = "CRITICAL, HIGH"
    override_findings_for_target_instances_ids = ""
  }
}
