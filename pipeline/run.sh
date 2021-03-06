#!/usr/bin/env bash

# create namespace if doesn't exist
kubectl create namespace news-demo-dev 2>/dev/null || true

# install tasks for pipeline
kubectl apply -n news-demo-dev -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.5/git-clone.yaml
kubectl apply -n news-demo-dev -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/buildah/0.3/buildah.yaml
kubectl apply -n news-demo-dev -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/kubernetes-actions/0.2/kubernetes-actions.yaml
kubectl apply -n news-demo-dev -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/github-open-pr/0.2/github-open-pr.yaml
kubectl apply -n news-demo-dev -f ./pipeline/git-update-deployment-task.yaml

# secret to push image to registry
# TODO: add you credentials in below command
kubectl -n news-demo-dev create secret generic registry-secret \
      --type="kubernetes.io/basic-auth" \
      --from-literal=username="<add-your-username-here>" \
      --from-literal=password="<add-your-password-here>"

# annotating registry name to secret
# TODO: change your image registry if different from quay.io
kubectl -n news-demo-dev annotate secret registry-secret tekton.dev/docker-0=quay.io

# secret to create pull request to the configuration repo
# TODO: create a github personal access token and add below
# this is required for creating a pull request on the staging repository
kubectl -n news-demo-dev create secret generic github --from-literal token="<add-your-github-token>"

# required role for service account to create/get/patch deployment
kubectl -n news-demo-dev create role news-demo-dev-access \
    --resource=deployment\
    --verb=create,patch,get,list

# create a serviceAccount
cat <<EOF | kubectl -n news-demo-dev create -f-
apiVersion: v1
kind: ServiceAccount
metadata:
  name: news-demo-dev
  namespace: news-demo-dev
secrets:
  - name: registry-secret
EOF

# role binding to attach role to serviceAccount
kubectl -n news-demo-dev create rolebinding news-demo-dev \
    --serviceaccount=news-demo-dev:news-demo-dev \
    --role=news-demo-dev-access

# create pipeline
kubectl create -n news-demo-dev -f ./pipeline/01-pipeline.yaml

# create pipelineRun
# kubectl create -n news-demo-dev -f ./pipeline/02-pipelinerun.yaml
