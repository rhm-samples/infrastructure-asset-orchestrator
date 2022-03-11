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
  echo -e "STEP $1/7: $2"
}

function validatePropertiesfile(){
  file="./backup.properties"
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
  file="./backup.properties"

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
      echoRed "Aborting creation, please set new value for the Project in the backup.properties file." 
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



function createS3Secret(){


temp_artifact_job=$(mktemp)
cat <<EOF>> $temp_artifact_job
apiVersion: v1
kind: Secret
metadata:
  name: s3-key-secret
stringData:
  s3.conf: |-
    [global]
    repo2-s3-key=${S3KEY}
    repo2-s3-key-secret=${S3KEYSECRET}
type: Opaque
EOF

oc apply -n "${projectName}" -f "${temp_artifact_job}"

}


function patchClusterCR(){

export bkpss=$(oc get -n ${projectName}  ModelbuilderAWS -o jsonpath='{.items[0].spec.postgres.backup_storage_size}')
export storagesize=$(oc get -n ${projectName}  ModelbuilderAWS -o jsonpath='{.items[0].spec.postgres.storage_size}')
export storageclass=$(oc get -n ${projectName}  ModelbuilderAWS -o jsonpath='{.items[0].spec.postgres.storage_class}')
export et=$(oc get -n ${projectName}  ModelbuilderAWS -o jsonpath='{.items[0].spec.env_type}')

replicas=1
if [[ ${et} == "prod" ]]; then
	replicas=2
fi

temp_artifact_job=$(mktemp)
cat <<EOF>> $temp_artifact_job
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PostgresCluster
metadata:
  name: modelbuilder
  namespace: ${projectName}
  finalizers:
    - postgres-operator.crunchydata.com/finalizer
spec:
  backups:
    pgbackrest:
      configuration:
        - secret:
            name: s3-key-secret
      manual:
        options:
          - '--type=full'
        repoName: repo2
      global:
        repo2-path: /pgbackrest/postgres-operator/modelbuilder-s3/repo2
      image: >-
        registry.connect.redhat.com/crunchydata/crunchy-pgbackrest@sha256:0fa5f4c6031e690838fe40eb618554f0c1878c14f1ab5d97999cc942177eb5ea
      repoHost: {}
      repos:
        - name: repo1
          volume:
            volumeClaimSpec:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: ${bkpss}
              storageClassName: ${storageclass}
        - name: repo2
          s3:
              bucket: ${S3BUCKET}
              region: ${S3REGION}
              endpoint: ${S3ENDPOINT}
  image: >-
    registry.connect.redhat.com/crunchydata/crunchy-postgres-ha@sha256:fd9a0e9ecd3913210bdcb49d51d7d225fd2920c8235d703f2a2d629634865e1e
  instances:
    - dataVolumeClaimSpec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: ${storagesize}
        storageClassName: ${storageclass}
      name: instance1
      replicas: ${replicas}
  openshift: true
  port: 5432
  postgresVersion: 13
  users:
    - databases:
        - modelbuilder
      name: modelbuilder
    - name: postgres
EOF
oc apply -n "${projectName}" -f "${temp_artifact_job}"

}

function annotateCR(){

kubectl annotate -n ${projectName} postgrescluster modelbuilder postgres-operator.crunchydata.com/pgbackrest-backup="$(date)" --overwrite
}
