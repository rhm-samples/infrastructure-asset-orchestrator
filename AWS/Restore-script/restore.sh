#!/bin/bash

## This Script installs Model Builder operator using default values. 
source restore-script-functions.bash
source restore.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
ocpVersion="^\"4\.([0-9]{6,}|[6-9]|[1-9][0-9]?)?(\.[0-9]+.*)*$"
ocpVersion45="^\"4\.5\.[0-9]+.*$"

logFile="restore.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion
checkOpenshiftVersion

username="admin"

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue IBM Model Builder for Vision Operator installation."
        exit 1;
fi

oc project ${projectName}
i=0

displayStepHeader $((i=i+1)) "Create S3 secret"
createS3Secret

displayStepHeader $((i=i+1)) "Patch PostgresCluster CR"
restorePGO

check_for_deployment_status=$(checkDeploymentStatus 2>&1)
if [[ $check_for_deployment_status -ge "1" ]]; then
	echoGreen "DB Instance up and running"
else
    echoRed "DB Instance no running"
	exit 1;
fi

displayStepHeader $((i=i+1)) "Annotate PostgresCluster CR"
kubectl annotate -n ${projectName} postgrescluster modelbuilder --overwrite postgres-operator.crunchydata.com/pgbackrest-restore=id1

check_for_deployment_status=$(checkDeploymentStatus 2>&1)
if [[ $check_for_deployment_status -ge "1" ]]; then
	echoGreen "DB Instance up and running"
else
    echoRed "DB Instance no running"
	exit 1;
fi

displayStepHeader $((i=i+1)) "Reset DB passwords"
resetPostgresPassword
echo "Password has been reset" &>>"${logFile}"

displayStepHeader $((i=i+1)) "Reset Keycloak password"
resetPassword

displayStepHeader $((i=i+1)) "Delete Keycloak statefulsets"
oc delete statefulsets keycloak
oc delete pods -l app=orchestrator-service
oc delete pods -l app=mb-broker-service
echoGreen "PostgresCluster successfuly restored" &>>"${logFile}"
