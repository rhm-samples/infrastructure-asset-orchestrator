#!/bin/bash

## This Script installs Model Builder operator using default values. 
source modelbuilder-script-functions.bash
source cr.properties

requiredVersion="^.*4\.([0-9]{3,}|[3-9]?)?(\.[0-9]+.*)*$"
requiredServerVersion="^.*1\.([0-9]{16,}|[3-9]?)?(\.[0-9]+)*$"
ocpVersion="^\"4\.([0-9]{6,}|[6-9]?)?(\.[0-9]+.*)*$"
ocpVersion45="^\"4\.5\.[0-9]+.*$"
modebuilderVersion=v1.0.0

logFile="modelbuilder-installation.log"
touch "${logFile}"

validatePropertiesfile

checkPropertyValuesprompt
checkOCClientVersion
checkOpenshiftVersion

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue IBM Model Builder for Vision Operator installation."
        exit 1;
fi

displayStepHeader 1 "Create a new project"
createProject

displayStepHeader 2 "Create a OperatorGroup object YAML file"

cat <<EOF>modelbuilder-og.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: modelbuilder-operator-group
  namespace: "${projectName}" 
spec: 
  targetNamespaces:
  - "${projectName}"
EOF


displayStepHeader 3 "Create OperatorGroup object"

oc create -f modelbuilder-og.yaml &>>"${logFile}"

displayStepHeader 4 "Create a Subscription object YAML file to subscribe a Namespace"

cat <<EOF>modelbuilder-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: model-builder-operator-postgres
  namespace: "${projectName}"
spec:
  channel: stable
  installPlanApproval: Automatic
  name: model-builder-for-vision
  source: ibm-modelbuilder-for-vision
  sourceNamespace: openshift-marketplace
  startingCSV: ibm-modelbuilder-for-vision.${modebuilderVersion}
EOF


displayStepHeader 5 "Create Subscription object"

oc create -f modelbuilder-subscription.yaml &>>"${logFile}"


displayStepHeader 6 "Verify the Operator installation"
#There should be ibm-modelbuilder-for-vision.v1.0.0.

check_for_csv_success=$(checkClusterServiceVersionSucceeded 2>&1)

if [[ "${check_for_csv_success}" == "Succeeded" ]]; then
        echoGreen "IBM Model Builder for Vision Operator installed"
else
    echoRed "Something wrong with Model Builder Deployment setup. Please try again after some time."
        exit 1;
fi

displayStepHeader 7 "Create a secret named model-builder-configuration-secret for IBM Model Builder for Vision Operator"

oc create secret generic model-builder-configuration-secret --from-literal=IBM_CLOUD_APIKEY=${cloudAPIKey} -n "${projectName}" &>>"${logFile}"


displayStepHeader 8 "Create the yaml for Deploy-Modelbuilder instance."


cat <<EOF>deploy-modelbuilder.yaml
apiVersion: modelbuilder.com/v1alpha1
kind: Modelbuilder
metadata:
  name: modelbuilder-demo
spec:
  backup_storage:
    storage_class: "${storageClassBackup}"
    storage_size: "${storageSizeBackup}"
  photo_storage:
    storage_class: "${storageClassPhoto}"
    storage_size: "${storageSizePhoto}"
  metadata_storage:
    storage_class: "${storageClassMetadata}"
    storage_size: "${storageSizeMetadata}"
  in_memory_storage:
    storage_class: "${storageClassInMemory}"
    storage_size: "${storageSizeInMemory}"
  env_type: "${envType}"
  vm_request_method: "${vmRequestMethod}"
  license:
    accept: "${licenseValue}"
EOF

displayStepHeader 9 "Install the Deployment. Please be patient as the deployment will take time"

oc create -f deploy-modelbuilder.yaml &>>"${logFile}"

#Sleep for 4 mins
sleep 240

check_for_deployment_status=$(checkDeploymentStatus 2>&1)
echoGreen "status: $check_for_deployment_status"
if [[ "${check_for_deployment_status}" == "Ready" ]]; then
        echoGreen "Modelbuilder Deployment setup ready"
else
    echoYellow "Something wrong with Model Builder Deployment setup. Please try again after some time."
        exit 1;
fi

#Get the URLS
export url=$(oc describe modelbuilder -n ${projectName} | grep -m 1 -oP "URL:\K[^,]+")
export workbench_url=$(oc describe modelbuilder -n ${projectName} | grep -m 1 -oP "Workbench URL:\K[^,]+")
export username=`oc describe modelbuilder -n ${projectName} | awk -v FS="Username:" 'NF>1{print $2}'`
export password_cmd=`oc get secret credential-modelbuilder-mbadmin-${projectName} -n ${projectName} --template={{.data.password}} | base64 -d`

displayStepHeader 10 "Get the URLs and Login Details"
echo "=========== User Management Console URL =============="
echoYellow "User Management Console: $url" | xargs
echo "=========== User Management Console Username =============="
echoYellow "Username: $username" | xargs
echo "=========== User Management Console Password =============="
echoYellow "Password: $password_cmd" | xargs
echo "=========== Workbench URL =============="
echoYellow "Workbench URL: $workbench_url" | xargs

