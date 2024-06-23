#!/bin/bash
# Define color variables

BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
WHITE=`tput setaf 7`

BG_BLACK=`tput setab 0`
BG_RED=`tput setab 1`
BG_GREEN=`tput setab 2`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_MAGENTA=`tput setab 5`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`

BOLD=`tput bold`
RESET=`tput sgr0`
#----------------------------------------------------start--------------------------------------------------#

echo "${BG_MAGENTA}${BOLD}Starting Execution${RESET}"

export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
gcloud config set compute/region $REGION

git config --global user.email "you@example.com"  
git config --global user.name "Your Name"

gcloud services enable container.googleapis.com \
    cloudbuild.googleapis.com \
    sourcerepo.googleapis.com \
    containeranalysis.googleapis.com

gcloud artifacts repositories create my-repository \
  --repository-format=docker \
  --location=$REGION

gcloud container clusters create hello-cloudbuild --num-nodes 1 --region $REGION

gcloud source repos create hello-cloudbuild-app
gcloud source repos create hello-cloudbuild-env

cd ~
git clone https://github.com/GoogleCloudPlatform/gke-gitops-tutorial-cloudbuild hello-
cloudbuild-app

cd ~/hello-cloudbuild-app
git remote add google "https://source.developers.google.com/p/${PROJECT_ID}/r/hello-cloudbuild-app"

COMMIT_ID="$(git rev-parse --short=7 HEAD)"
gcloud builds submit --tag="${REGION}-docker.pkg.dev/${PROJECT_ID}/my-repository/hello-cloudbuild:${COMMIT_ID}" .

gcloud beta builds triggers create cloud-source-repositories \
  --name="hello-cloudbuild" \
  --repo="hello-cloudbuild-app" \
  --branch-pattern=".*" \
  --build-config="cloudbuild.yaml"

git push google master

gcloud projects add-iam-policy-binding ${PROJECT_NUMBER} \
--member=serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com \
--role=roles/container.developer

cd ~
gcloud source repos clone hello-cloudbuild-env

cd ~/hello-cloudbuild-env
git checkout -b production

PROJECT_NUMBER="$(gcloud projects describe ${PROJECT_ID} \
--format='get(projectNumber)')"

cat >/tmp/hello-cloudbuild-env-policy.yaml <<EOF
bindings:
- members:
  - serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com
  role: roles/source.writer
EOF

gcloud source repos set-iam-policy \
hello-cloudbuild-env /tmp/hello-cloudbuild-env-policy.yaml

gcloud beta builds triggers create cloud-source-repositories \
  --name="hello-cloudbuild-deploy" \
  --repo="hello-cloudbuild-env" \
  --branch-pattern="^candidate$" \
  --build-config="cloudbuild.yaml"

cp cloudbuild-trigger-cd.yaml cloudbuild.yaml

git add cloudbuild.yaml
git commit -m "Trigger CD pipeline"
git push google master

echo "${BG_RED}${BOLD}Congratulations For Completing The Lab !!!${RESET}"

#-----------------------------------------------------end----------------------------------------------------------#