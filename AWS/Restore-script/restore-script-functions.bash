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

function displayStepHeaderRestore() {
  stepHeader=$(stepLog "$1" "$2")
  echoBlue "$stepHeader"
}

function stepLogRestore() {
  echo -e "STEP $1/7: $2"
}

function validatePropertiesfile(){
  file="./restore.properties"
  if [ -f "$file" ]
  then
    echo "$file found."
    while IFS='=' read -r key value
    do
      key_name=$(echo $key | grep -v '^#')

      if [[ -z "$key_name" || "$key_name" == " " || $key_name == " " || $key_name == "cloudAPIKey" ]];then
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

KEYCLOAK_URL=https://$(oc get routes keycloak -n "${projectName}" | awk 'NR==2 {print $2}')

ADMIN_PASSWORD=${ADMIN_PASSWORD}
result=$(curl -X POST $KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token -d 'username='$ADMIN_USERNAME'&password='$ADMIN_PASSWORD'&grant_type=password&client_id=admin-cli')
  
access_token=$(jq -r ".access_token" <<<"$result")
echo "==========================================="
echo $access_token
echo "==========================================="

user_result=$(curl -k -X GET $KEYCLOAK_URL/auth/admin/realms/master/users?search=admin \
 -H 'accept: application/json' \
 -H 'content-type: application/json' \
 -H "Authorization: Bearer ${access_token}")

admin_id=$(jq -r ".[].id" <<<"$user_result")

reset_password=`oc get secret credential-keycloak -n ${projectName} --template={{.data.ADMIN_PASSWORD}} | base64 -d`

result=$(curl -v --location --request PUT $KEYCLOAK_URL/auth/admin/realms/master/users/${admin_id}/reset-password \
 --header "Authorization: Bearer ${access_token}" \
 --header 'Content-Type: application/json' \
 -d '{"type":"password","value":"'"${reset_password}"'","temporary":false}')

 echo $result
}

function deleteRealmModelbuilder(){
KEYCLOAK_URL=https://$(oc get routes keycloak -n "${projectName}" | awk 'NR==2 {print $2}')
pwd=`oc get secret credential-keycloak -n ${projectName} --template={{.data.ADMIN_PASSWORD}} | base64 -d`

access_token=$(curl  -X POST "${KEYCLOAK_URL}/auth/realms/master/protocol/openid-connect/token" \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "username=${ADMIN_USERNAME}" \
 -d "password=${pwd}" \
 -d 'grant_type=password' \
 -d 'client_id=admin-cli' \
 | jq -r ".access_token")

echo "==========================================="
echo $access_token
echo "==========================================="

del_realm=$(curl -X -v DELETE $KEYCLOAK_URL/auth/admin/realms/modelbuilder \
 -H 'accept: application/json' \
 -H 'content-type: application/json' \
 -H "Authorization: Bearer ${access_token}")

  echo $del_realm

}

function postRestoreDisplayStepHeader() {
  stepHeader=$(postRestoreStepLog "$1" "$2")
  echoBlue "$stepHeader"
}

function postRestoreStepLog() {
  echo -e "STEP $1/1: $2"
}

function resetPostgresPassword(){
export oldpwd=${password}
export new_pass=$(oc get secret postgres-db-password-credentials -o jsonpath='{.data.db_password}'|base64 -d)
temp_artifact_job=$(mktemp)
cat <<EOF>> $temp_artifact_job
apiVersion: batch/v1
kind: Job
metadata:
  name: "restore-reset-db-password"
  namespace: ${projectName}
  labels:
    app: "restore-reset-db-password"
spec:
  backoffLimit: 0
  restartPolicy: Never
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        app: "restore-reset-db-password"
    spec:
      serviceAccountName: "modelbuilder"
      restartPolicy: Never
      volumes:
      - name: pgo-root-cacert
        secret:
          secretName: pgo-root-cacert
          items:
          - key: root.crt
            path: root.crt
      containers:
      - name: database
        image: registry.redhat.io/rhel8/postgresql-12:latest
        imagePullPolicy: Always
        volumeMounts:
        - name: pgo-root-cacert
          mountPath: /usr/local/postgres-cert/ 
        command:
          - /bin/sh
          - -c
          - |
            
            PGPASSWORD=${oldpwd} PGSSLMODE=verify-ca PGSSLROOTCERT=/usr/local/postgres-cert/root.crt psql -h modelbuilder-primary.${projectName}.svc -U postgres -c "alter user postgres with password '${new_pass}';"
            PGPASSWORD=${new_pass} PGSSLMODE=verify-ca PGSSLROOTCERT=/usr/local/postgres-cert/root.crt psql -h modelbuilder-primary.${projectName}.svc -U postgres -c "alter user modelbuilder with password '${new_pass}';"
            echo "password reset done"
            PGPASSWORD=${new_pass} PGSSLMODE=verify-ca PGSSLROOTCERT=/usr/local/postgres-cert/root.crt psql -h modelbuilder-primary.${projectName}.svc -d keycloak -U postgres -c "ALTER USER MAPPING FOR modelbuilder SERVER mb_server OPTIONS (SET password '${new_pass}');"

EOF

oc apply -n "${projectName}" -f "${temp_artifact_job}"

}

function restorePGO(){

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
      global:
        repo2-path: /pgbackrest/postgres-operator/modelbuilder-s3/repo2
      image: >-
        registry.connect.redhat.com/crunchydata/crunchy-pgbackrest@sha256:0fa5f4c6031e690838fe40eb618554f0c1878c14f1ab5d97999cc942177eb5ea
      repoHost: {}
      restore:
        enabled: true
        options:
          - '--type=immediate'
          - '--set="${BACKUPFILENAME}"'
        repoName: repo2
      repos:
        - name: repo1
          volume:
            volumeClaimSpec:
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 20G
              storageClassName: gp2
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
            storage: 20G
        storageClassName: gp2
      name: instance1
      replicas: 1
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

function checkDeploymentStatus() {

	retryCount=90
	retries=0
	check_for_deployment_status=$(oc get csv -n "$projectName" --ignore-not-found | awk '$1 ~ /postgresoperator.v5.0.4/ { print }' | awk -F' ' '{print $NF}')
	until [[ $retries -eq $retryCount || $check_for_deployment_status -ge "1" ]]; do
		sleep 15
		check_for_deployment_status=$(oc get PostgresCluster modelbuilder --output="jsonpath={.status.instances[0].readyReplicas}")
		retries=$((retries + 1))
	done
	echo "$check_for_deployment_status"
}
