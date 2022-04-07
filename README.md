# Tekton & ArgoCD

### Prerequisite

* A Kubernetes Cluster

### Installation

* **Tekton** 
  * You can install tekton projects using tekton operator. To install Tekton Operator you can find the latest release yaml [here](https://github.com/tektoncd/operator/releases).
  * While writing this, the latest version is v0.55.1.
  * The Operator will install Tekton Pipelines, Tekton Triggers and Tekton Dashboard.
  ```yaml
    kubectl apply -f https://storage.googleapis.com/tekton-releases/operator/previous/v0.55.1/release.yaml
  ```
  This release of operator comes with
  ```yaml
    Tekton Pipeline : v0.33.2
    Tekton Triggers : v0.19.0
    Tekton Dashboard : v0.24.1
  ```

* **ArgoCD**
  * You can install argo cd using release yaml. You can find the latest release yaml [here](https://github.com/argoproj/argo-cd/releases).
  * While writing this, the latest version is v2.3.3
  ```yaml
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.3.3/manifests/ha/install.yaml
  ```

* **Ingress Controller**
  * You need to install ingress to expose EventListener to configure with GitHub. Also, Tekton Dashboard if you like.
  * You can find the installation steps [here](https://kubernetes.github.io/ingress-nginx/deploy/) based on your cluster type.
  ```yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.3/deploy/static/provider/cloud/deploy.yaml
  ```

### Configuring Ingress 

* Before creating ingress, we need to create an ingress class
  ```yaml
    kubectl apply -f ingress/ingress-class.yaml
  ```

* Now, we can create an ingress for Tekton Dashboard
  ```yaml
    kubectl apply -f ingress/dashboard.yaml 
  ```
  You can look for ingress as below
  ```yaml
    kubectl get ingress -n tekton-pipelines 
    NAME               CLASS   HOSTS   ADDRESS         PORTS   AGE
    tekton-dashboard   nginx   *       34.136.183.32   80      5m20s
  ```
  You can use the address and access in your browser _http://34.136.183.32/dashboard_

### Installing Pipelines & Setting up Triggers

* We will be using [news-demo](https://github.com/sm43/news-demo) app for the demo.
* All the code for app resides in [news-demo](https://github.com/sm43/news-demo) repo but all configuration for CI/CD are in [tekton-argocd](https://github.com/sm43/tekton-argocd).

#### App Prerequisites

* We need a API key which you can get by signing up for News API account [here](https://newsapi.org/register) for free.
 
#### Installing Application on the cluster

* You can add the API key you have created in last step in the configmap [./k8s-dev/01-configmap.yaml](./k8s-dev/01-configmap.yaml) 
* Now, you can apply on the cluster
  ```yaml
    kubectl apply -f k8s-dev/
  ```
  Now, you wait for pod to come up, and you can get ingress by
  ```yaml
    kubectl get ingress -n news-demo-dev 
    NAME            CLASS   HOSTS   ADDRESS         PORTS   AGE
    news-demo-dev   nginx   *       34.136.183.32   80      8m56s
  ```
  Access the application using _http://34.136.183.32/app_.

#### Setting up pipeline

* To install the required tasks, pipelines and the required resources we have a script [pipeline/run.sh](./pipeline/run.sh)
* Before running the script, you need to edit the script and add your image registry credentials, this credentials will be used to push the image to your registry
* In the run.sh script, look from line no. 13-20 where you need to add your credentials and change image registry if it's different from quay.

Once you are done updating, you can the script
* this will install all the required Tekton Tasks for our pipeline
* create registry secret which will be used to push the image
* service account for the pipeline
* create required rbac
* finally, install the pipeline and start the pipeline by creating a pipelinerun

you can look for your pipeline using
```yaml
  kubectl get pipelinerun -n news-demo-dev
  NAME                         SUCCEEDED   REASON    STARTTIME   COMPLETIONTIME
  news-demo-dev-deploy-bxgnd   Unknown     Running   4s
```
To follow the logs for your pipeline run Tekton CLI is very useful
```yaml
  tkn pipelinerun -n news-demo-dev logs -f news-demo-dev-deploy-bxgnd
```
We have set up our pipeline, the next thing will be to set up trigger so that on GitHub events our pipeline starts automatically.

