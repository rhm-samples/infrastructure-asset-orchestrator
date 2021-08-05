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

username="admin"

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue IBM Modelbuilder for Vision Operator installation."
        exit 1;
fi

postRestoreDisplayStepHeader 1 "Reset the passwords"

resetPassword

echo "Password has been reset" &>>"${logFile}"
