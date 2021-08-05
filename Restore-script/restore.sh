#!/bin/bash

## This Script installs Modelbuilder operator using default values. 
source restore-script-functions.bash
source restore.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
ocpVersion="^\"4\.([0-9]{6,}|[6-9]?)?(\.[0-9]+.*)*$"
ocpVersion45="^\"4\.5\.[0-9]+.*$"

logFile="restore.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion
checkOpenshiftVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to restore data from S3 bucket."
        exit 1;
fi

displayStepHeader 1 "Create a new project"
createProject

displayStepHeader 2 "Create a secret named modelbuilder-db-credentials"

oc create secret generic modelbuilder-db-credentials --from-literal=username=${username} --from-literal=password=${password} -n "${projectName}" &>>"${logFile}"

displayStepHeader 3 "Create a secret named realm-mbadmin-credentials"

oc create secret generic realm-mbadmin-credentials --from-literal=REALM_PASSWORD=${REALM_PASSWORD} -n "${projectName}" &>>"${logFile}"

displayStepHeader 4 "Create a secret named realm-ibmuser-credentials"

oc create secret generic realm-ibmuser-credentials --from-literal=realmUser_email=${realmUser_email} --from-literal=realmUser_name=${realmUser_name} --from-literal=realmUser_password=${realmUser_password} -n "${projectName}" &>>"${logFile}"

displayStepHeader 5 "Create a secret named keycloak-client-secret-api-client"

oc create secret generic keycloak-client-secret-api-client --from-literal=CLIENT_ID=${API_CLIENT_ID} --from-literal=CLIENT_SECRET=${API_CLIENT_SECRET} -n "${projectName}" &>>"${logFile}"

displayStepHeader 6 "Create a secret named keycloak-client-secret-springboot-keycloak"

oc create secret generic keycloak-client-secret-springboot-keycloak --from-literal=CLIENT_ID=${SPRINGBOOT_CLIENT_ID} --from-literal=CLIENT_SECRET=${SPRINGBOOT_CLIENT_SECRET} -n "${projectName}" &>>"${logFile}"