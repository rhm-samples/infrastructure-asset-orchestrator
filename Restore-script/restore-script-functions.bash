#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'

function echoGreen() {
  echo -e "${GREEN}$1${NC}"
}

function echoRed() {
  echo -e "${RED}$1${NC}"
}

function echoBlue() {
  echo -e "${BLUE}$1${NC}"
}

function echoYellow() {
  echo -e "${YELLOW}$1${NC}"
}

function displayStepHeader() {
  stepHeader=$(stepLog "$1" "$2")
  echoBlue "$stepHeader"
}

function stepLog() {
  echo -e "STEP $1/6: $2"
}

function validatePropertiesfile(){
  file="./restore.properties"
  if [ -f "$file" ]
  then
    echo "$file found."
    while IFS='=' read -r key value
    do
      key_name=$(echo $key | grep -v '^#')

      if [[ -z "$key_name" || "$key_name" == " " || $key_name == " " ]];then
        continue
      fi
      if [[ -z "${!key_name}" || "${!key_name}" == "" || ${!key_name} == "" ]]; then
        echoRed "$key_name is empty"
            exit 1
      fi
    done < "$file"
  else
    echoRed "$file not found."
    exit 1
  fi
}


function checkPropertyValuesprompt(){
  echoBlue "Please check below Properties values and confirm to Continue with restoration"
  file="./restore.properties"

  while IFS= read -r line
  do
    key_name=$(echo $line | grep -v '^#')

    if [[ -z "$key_name" || "$key_name" == " " || $key_name == " " ]];then
      continue
    fi
    echo "$line"
  done < "$file"

  echoBlue "Are you sure, you want to Continue with restoration? [Y/n]: "
  read -r continueInstall </dev/tty
  if [[ ! $continueInstall || $continueInstall = *[^Yy] ]]; then
    echoRed "Aborting restoration of data"
    exit 0
  fi
}

function checkOCServerVersion() {
  currentOCServerVersion="$(oc version -o json | jq .serverVersion.gitVersion)"

  if ! [[ $currentOCServerVersion =~ $requiredServerVersion ]]; then
    if [ "$currentOCServerVersion" = null ]; then
      echoRed "Unsupported OpenShift Server version detected. Supported OpenShift Server versions are 1.16 and above."
    else
      echoRed "Unsupported OpenShift Server version $currentOCServerVersion detected. Supported OpenShift versions are 1.16 and above."
    fi
    exit 1
  fi
}


function checkOCClientVersion() {
  currentClientVersion="$(oc version -o json | jq .clientVersion.gitVersion)"
  if ! [[ $currentClientVersion =~ $requiredVersion ]]; then
    echoRed "Unsupported oc cli version $currentClientVersion detected. Supported oc cli versions are 4.3 and above."
    exit 1
  fi
}


function checkOpenshiftVersion() {
  currentOpenshiftVersion="$(oc version -o json | jq .openshiftVersion)"

  if [[ $currentOpenshiftVersion =~ $ocpVersion ]]; then
    echo ""
  else
    echo "Unsupportedd Openshift version $currentOpenshiftVersion.Supported OpenShift versions are 4.5 to 4.7."
    exit 1
  fi
}


function createProject(){
  existingns=$(oc get projects | grep -w "${projectName}" | awk '{print $1}')

  if [ "${existingns}" == "${projectName}" ]; then
    echoYellow "Project ${existingns} already exists, do you want to continue in the existing project? [Y/n]: "
    read -r continueInstall </dev/tty
    if [[ ! $continueInstall || $continueInstall = *[^Yy] ]]; then
      echoRed "Aborting creation, please set new value for the Project in the restore.properties file." 
      exit 0;
    fi
  else
    oc new-project "${projectName}" &>>"${logFile}" 
      if [ $? -ne 0 ];then
        echoRed "FAILED: Project:${projectName} creation failed"
        exit 1
     fi
  fi
}

function resetPassword(){
  ADMIN_USERNAME=${username}
  ADMIN_PASSWORD=${ADMIN_PASSWORD}

  KEYCLOAK_URL=https://$(oc get routes keycloak -n "${projectName}" | awk 'NR==2 {print $2}')

  result=$(curl -v -k -X POST $KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token -d 'username='$ADMIN_USERNAME'&password='$ADMIN_PASSWORD'&grant_type=password&client_id=admin-cli')
  
  access_token=$(jq -r ".access_token" <<<"$result")
  
  user_result=$(curl -k -X GET $KEYCLOAK_URL/auth/admin/realms/master/users?search=admin -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${access_token}")
  
  admin_id=$(jq -r ".[].id" <<<"$user_result")
  
  reset_password=`oc get secret credential-keycloak -n ${projectName} --template={{.data.ADMIN_PASSWORD}} | base64 -d`
  
  result=$(curl -k -X -I PUT $KEYCLOAK_URL/auth/admin/realms/master/users/${admin_id}/reset-password -H 'accept: application/json' -H 'content-type: application/json' -H "Authorization: Bearer ${access_token}" -d '{"type": "password","temporary": false,"value": "'"${reset_password}"'"}')
  
   echo $result
}

function postRestoreDisplayStepHeader() {
  stepHeader=$(postRestoreStepLog "$1" "$2")
  echoBlue "$stepHeader"
}

function postRestoreStepLog() {
  echo -e "STEP $1/1: $2"
}