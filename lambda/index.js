const AWS = require("aws-sdk");
const logger = require('./logger');

exports.handler = async (event) => {
  const REGION = event.region || 'us-east-1';
  const REBOOT_OPTION = event.reboot_option || "NoReboot";
  const TARGET_EC2_TAG_NAME = event.target_ec2_tag_name;
  const TARGET_EC2_TAG_VALUE = event.target_ec2_tag_value;
  const VULNERABILITY_SEVERITIES = (event.vulnerability_severities 
        && event.vulnerability_severities?.split(',')?.map(a => a.trim().toUpperCase())) || [];
  const OVERRIDE_FINDINGS_FOR_TARGET_INSTANCES_IDS = (event.override_findings_for_target_instances_ids 
        && event.override_findings_for_target_instances_ids?.split(',')?.map(a => a.trim())) || [];

  logger.info("Region is ", REGION);
  logger.info("Reboot option is ", REBOOT_OPTION);
  logger.info("Target EC2 tag name is ", TARGET_EC2_TAG_NAME);
  logger.info("Target EC2 tag value is ", TARGET_EC2_TAG_VALUE);
  logger.info("Vulnerability severities are ", VULNERABILITY_SEVERITIES);
  logger.info("Override findings for target instances IDs are ", OVERRIDE_FINDINGS_FOR_TARGET_INSTANCES_IDS);

  try {
    let ecsManagedInstanceIds = [];
    if (OVERRIDE_FINDINGS_FOR_TARGET_INSTANCES_IDS && OVERRIDE_FINDINGS_FOR_TARGET_INSTANCES_IDS.length > 0) {
      ecsManagedInstanceIds = OVERRIDE_FINDINGS_FOR_TARGET_INSTANCES_IDS;
    } else {
      ecsManagedInstanceIds = await getECSManagedInstances(REGION, TARGET_EC2_TAG_NAME, TARGET_EC2_TAG_VALUE);
    }

    const { targetInstances, totalFindings } = await manageInstanceFindings(ecsManagedInstanceIds, REGION, VULNERABILITY_SEVERITIES);

    if (!targetInstances.length) {
      return {
        status: "No Finding of the set severity found.",
        patchedInstances: 0,
        statusCode: 200,
      };
    }

    const ssm = new AWS.SSM({ region: REGION });
    const logConfig = process.env.LAMBDA_LOG_GROUP ? {
      CloudWatchOutputConfig: {
        CloudWatchLogGroupName: process.env.LAMBDA_LOG_GROUP,
        CloudWatchOutputEnabled: true
      }
    } : {};
    const patchResult = await ssm
      .sendCommand({
        ...logConfig,
        Comment: 'Lambda function trigger operation for inspector finding auto-remediation',
        DocumentName: "AWS-RunPatchBaseline",
        DocumentVersion: "1",
        MaxConcurrency: `${targetInstances.length}`,
        MaxErrors: "0",
        OutputS3Region: "us-east-1",
        Parameters: {
          Operation: ["Install"],
          RebootOption: [REBOOT_OPTION]
        },
        Targets: [
          {
            Key: "InstanceIds",
            Values: targetInstances
          }
        ],
        TimeoutSeconds: 600
      })
      .promise();

    logger.info(
      `Remediation started for instances ${targetInstances.join(',')} with command ID: ${patchResult.Command.CommandId}
        and total findings of ${totalFindings}.`
    );

    return {
      status: "Success",
      patchedInstances: targetInstances,
      statusCode: 200,
    };
  } catch (error) {
    logger.error("Error during remediation:", error);
    throw error;
  }
};

async function getECSManagedInstances(region, tagName, tagValue) {
  const params = {
    Filters: [
      {
        Name: `tag:${tagName}`,
        Values: [tagValue],
      },
    ],
  };

  const ec2 = new AWS.EC2({ region });

  let instanceIds = [];
  let data;
  do {
    data = await ec2.describeInstances(params).promise();
    for (const reservation of data.Reservations) {
      for (const instance of reservation.Instances) {
        instanceIds.push(instance.InstanceId);
      }
    }
    params.NextToken = data.NextToken;
  } while (params.NextToken);

  return instanceIds;
}

async function getInstanceInspectorFindings(instanceId, region, severities) {
  const inspector2 = new AWS.Inspector2({ region });

  const params = {
    sortCriteria: {
      sortOrder: "DESC",
      field: "SEVERITY",
    },
    maxResults: 100,
    filterCriteria: {
      severity: severities.map(severity => ({ comparison: "EQUALS", value: severity })),
      resourceId: [{ comparison: "EQUALS", value: instanceId }],
      findingStatus: [{ comparison: "EQUALS", value: "ACTIVE" }],
    },
  };

  const data = await inspector2.listFindings(params).promise();
  return data.findings;
}

async function manageInstanceFindings(ecsManagedInstanceIds, region, severities) {
  const targetInstances = [];
  let totalFindings = 0;

  for (const instanceId of ecsManagedInstanceIds) {
    logger.info("instanceId...", instanceId);
    let findings = await getInstanceInspectorFindings(instanceId, region, severities);
    if (!findings.length) {
      continue;
    }
    logger.info('Total findings for instanceID ' + instanceId + ' is ' + findings.length);

    const skippingTitles = ["Unsupported Operating System or Version",  "No potential security issues found"];
    findings = findings.filter((finding) => !(skippingTitles.includes(finding.title)))
    logger.info('Total findings for instanceID ' + instanceId + ' after title check is ' + findings.length);

    
    const resource = findings[0].resources[0];
    
    // Check resource type to match expected remediation action:
    if (resource.type === "AWS_EC2_INSTANCE") {
      totalFindings = totalFindings += findings.length;
      targetInstances.push(instanceId);
    }
  }


  return { targetInstances, totalFindings }
}
