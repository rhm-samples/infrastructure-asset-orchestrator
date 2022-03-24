#!/bin/bash

## This Script installs Model Builder operator using default values. 
source backup-script-functions.bash
source backup.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
ocpVersion="^\"4\.([0-9]{6,}|[6-9]|[1-9][0-9]?)?(\.[0-9]+.*)*$"
ocpVersion45="^\"4\.5\.[0-9]+.*$"

logFile="backup.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion
checkOpenshiftVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to backup data to S3 bucket."
        exit 1;
fi

displayStepHeader 1 "Create s3 secret"
createS3Secret

displayStepHeader 2 "Patch Postgres CR"
patchClusterCR

check_for_deployment_status=$(checkDeploymentStatus 2>&1)
if [[ $check_for_deployment_status -ge "1" ]]; then
	echoGreen "DB Instance up and running"
else
    echoRed "DB Instance no running"
	exit 1;
fi

displayStepHeader 3 "Annotate CR"
annotateCR