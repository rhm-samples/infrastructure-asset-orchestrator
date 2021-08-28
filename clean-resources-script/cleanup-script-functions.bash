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

function checkNamespace(){
  namespace=${namespace}
  echoBlue "You are about to clean up the resources on the project ${namespace}."
  echoBlue "Are you sure, you want to Continue with the cleanup? [Y/n]: "
  read -r continueInstall </dev/tty
  if [[ ! $continueInstall || $continueInstall = *[^Yy] ]]; then
    echoRed "Aborting cleanup of data"
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

function deleteModelbuilderCluster() {
  namespace=${namespace}
  modelbuilderDeployment="$(oc delete deployment --selector vendor=crunchydata,pg-cluster=modelbuilder -n ${namespace})"
  echo $modelbuilderDeployment

  sleep 5
}

function deleteModelbuilderClusterJobs() {
  namespace=${namespace}
  modelbuilderJob="$(oc delete job --selector vendor=crunchydata,pg-cluster=modelbuilder -n ${namespace})"
  echo $modelbuilderJob
}

function deleteModelbuilderClusterServices() {
  namespace=${namespace}
  modelbuilderServices="$(oc delete service --selector vendor=crunchydata,pg-cluster=modelbuilder -n ${namespace})"
  echo $modelbuilderServices
}

function deleteModelbuilderClusterPVCs() {
  namespace=${namespace}
  modelbuilderPVCs="$(oc delete pvc --selector vendor=crunchydata,pg-cluster=modelbuilder -n ${namespace})"
  echo $modelbuilderPVCs
}

function deletePostgresDeployment() {
  namespace=${namespace}
  postgresDeployment="$(oc delete deployment "postgres-operator" -n ${namespace})"
  echo $postgresDeployment
}

function deleteServiceAccounts() {
  namespace=${namespace}
  pgoBackrest="$(oc delete serviceaccount "pgo-backrest" -n ${namespace})"
  echo $pgoBackrest
  pgoDefault="$(oc delete serviceaccount "pgo-default" -n ${namespace})"
  echo $pgoDefault
  pgoPg="$(oc delete serviceaccount "pgo-pg" -n ${namespace})"
  echo $pgoPg
  pgoTarget="$(oc delete serviceaccount "pgo-target" -n ${namespace})"
  echo $pgoTarget
  postgresOperator="$(oc delete serviceaccount "postgres-operator" -n ${namespace})"
  echo $postgresOperator
}

function deleteKeycloakResources() {
  namespace=${namespace}

  apiClient="$(oc delete KeycloakClient "api-client" -n ${namespace})"
  echo $apiClient
  springbootKeycloak="$(oc delete KeycloakClient "springboot-keycloak" -n ${namespace})"
  echo $springbootKeycloak
  realmUser="$(oc delete KeycloakUser "realm-user" -n ${namespace})"
  echo $realmUser
  realmAdminUser="$(oc delete KeycloakUser "realm-admin-user" -n ${namespace})"
  echo $realmAdminUser
  keycloakRealm="$(oc delete KeycloakRealm "keycloakrealm" -n ${namespace})"
  echo $keycloakRealm
  keycloak="$(oc delete Keycloak "keycloak" -n ${namespace})"
  echo $keycloak
  
  sleep 10
}

function deleteSubscription() {
  namespace=${namespace}
  subscription_name=$1

  currentCSV="$(oc get packagemanifest $subscription_name -n ${namespace} -o json)"
  CSV_VERSION=$(jq -r ".status.channels[0].currentCSV" <<<"$currentCSV")

  subscriptionResult="$(oc delete subscription $subscription_name -n ${namespace})"
  echo $subscriptionResult

  csvResult="$(oc delete clusterserviceversion $CSV_VERSION -n ${namespace})"
  echo $csvResult
}



