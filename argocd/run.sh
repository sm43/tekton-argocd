#!/usr/bin/env bash

API_KEY=$(pass news-demo/api-key)

kubectl create namespace news-demo-stage 2>/dev/null || true

cat <<EOF | kubectl -n news-demo-stage create -f-
$(sed "s/<>/${API_KEY}/" ./k8s-stage/01-configmap.yaml)
EOF

kubectl apply -f ./argocd/

