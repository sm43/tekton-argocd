#!/usr/bin/env bash

GIT_PASSWORD=$(pass github/token)

cat <<EOF | kubectl -n news-demo-dev create -f-
$(sed "s/<>/${GIT_PASSWORD}/" ./trigger/00-triggertemplate.yaml)
EOF
kubectl apply -n news-demo-dev -f ./trigger/00-rbac.yaml
kubectl apply -n news-demo-dev -f ./trigger/01-triggerbinding.yaml
kubectl apply -n news-demo-dev -f ./trigger/02-eventlistener.yaml
kubectl apply -n news-demo-dev -f ./trigger/03-route.yaml
