module "remediation" {
  source  = "iKnowJavaScript/vulne-soldier/aws"
  version = "2.0.0"

  name               = "vulne-soldier-compliance-remediate"
  environment        = "prod"
  aws_region         = "us-east-1"
  account_id         = "111122223333"
  lambda_log_group   = "/aws/lambda/vulne-soldier-compliance-remediate"
  path_to_lambda_zip = "../../lambda.zip"
  remediation_options = [{
    region                                     = "us-east-1"
    reboot_option                              = "NoReboot"
    target_ec2_tag_name                        = "AmazonECSManaged"
    target_ec2_tag_value                       = "true"
    vulnerability_severities                   = "CRITICAL, HIGH"
    override_findings_for_target_instances_ids = ""
  }]
  remediation_schedule_days = ["15", "L"]
  ssn_notification_topic_arn = null
}
