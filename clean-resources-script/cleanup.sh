#!/bin/bash

## This script cleans up the Modelbuilder operator resources using default values. 
source cleanup-script-functions.bash

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
ocpVersion="^\"4\.([0-9]{6,}|[6-9]?)?(\.[0-9]+.*)*$"
ocpVersion45="^\"4\.5\.[0-9]+.*$"

logFile="cleanup.log"
touch "${logFile}"

namespace=$1

checkNamespace
checkOCClientVersion
checkOpenshiftVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to restore data from S3 bucket."
        exit 1;
fi

displayStepHeader 1 "Delete Modelbuilder cluster"
deleteModelbuilderCluster
deleteModelbuilderClusterJobs
deleteModelbuilderClusterServices
deleteModelbuilderClusterPVCs

displayStepHeader 2 "Delete postgres operator deployment"
deletePostgresDeployment

displayStepHeader 3 "Delete service accounts created by postgres"
deleteServiceAccounts

displayStepHeader 4 "Delete Keycloak resources"
deleteKeycloakResources

displayStepHeader 5 "Uninstall the Infrastructure Asset Orchestrator operator"
deleteSubscription infrastructure-asset-orchestrator-certified

displayStepHeader 6 "Uninstall the RHSSO operator"
deleteSubscription rhsso-operator


