# Tekton & ArgoCD

### Introduction

![flow diagram](./images/flow.png)


* We have a Kubernetes clusters 
* Tekton Pipeline and ArgoCD is set up on the cluster
* We will have the app deployed in both the namespaces but in different ways
  * We will deploy in dev namespace by Tekton Pipelines
  * Once it is deployed we will test the changes, and approve the changes for staging instance
  * Once the changes are approved, ArgoCD will deploy the changes to stage namespace
* We have 2 Repositories:
  * sm43/news-demo: this is where our app code is.
  * sm43/tekton-argocd: this is our configuration for staging cluster is.
  * NOTE: it is not required to necessary to have 2 repositories, you can merge them together and work
* Tekton will be installed and configured with our code repository
  * When a pull request is merged in `main` branch or a commit is pushed in `main` branch, a Tekton Pipeline will be started
  * There is a Tekton Triggers EventListener which will be set up on the cluster, listening to GitHub events.
  * It will process the event, and start the Pipeline
  * The pipeline does the following tasks:
    * It clones the repository
    * Build a new image and push it to remote image registry which we will configure
    * Deploy the image on the dev instance
    * Creates a pull request to the staging configuration repository (sm43/tekton-argocd)
    * And the pipeline, ends.
* Now, the application is deployed in dev namespace, we can access it and test it if the changes are fine.
* Once we are ready, we will merge the pull request `tekton-argocd` repository
* This means we are ready to deploy the changes to stage instance
* ArgoCD is also installed on the cluster
  * We configure argocd to watch our app configuration in `tekton-argocd` repository
  * Whenever there is a change in configuration, argocd watches that and reflect that on the cluster
  * So when we merge the pull request on config repo, argocd will know something is changed in application manifest
  * It will reapply the changes on the cluster, and we will be able to see the changes.


### Prerequisite

* Kubernetes Clusters

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
  
### Setting up Pipelines & Triggers

* We will be using [news-demo](https://github.com/sm43/news-demo) app for the demo.
* All the code for app resides in [news-demo](https://github.com/sm43/news-demo) repo but all configuration for CI/CD are in [tekton-argocd](https://github.com/sm43/tekton-argocd).

#### App Prerequisites

* We need an API key which you can get by signing up for News API account [here](https://newsapi.org/register) for free.
 
#### Installing Application on the cluster

* You can add the API key you have created in last step in the configmap [./k8s-dev/01-configmap.yaml](./k8s-dev/01-configmap.yaml) 
* Now, you can apply on the cluster
  ```yaml
    kubectl apply -f k8s-dev/
  ```
  Now, you wait for pod to come up, and you can get route by
  ```yaml
    kubectl get route -n news-demo-dev 
  ```
  This repo is using openshift route, but if you don't have a openshift cluster, you can expose the service using ingress. 

#### Setting up pipeline

* To install the required tasks, pipelines and the required resources we have a script [pipeline/run.sh](./pipeline/run.sh)
* Before running the script, you need to edit the script and add your image registry credentials, these credentials will be used to push the image to your registry

Once you are done updating, you can the script
* this will install all the required Tekton Tasks for our pipeline
* create registry secret which will be used to push the image
* service account for the pipeline
* create required rbac
* finally, install the pipeline.

Now, pipeline is installed but not started, you can start by creating a pipelinerun manually.

before applying pipelinerun, 
* You need to fork both the repos
* edit [./pipeline/02-pipelinerun.yaml](./pipeline/02-pipelinerun.yaml) and add your token and replace your repository url by
* replace image registry with yours
* add GitHub personal access token for GIT_PASSWORD and replace git username
* then you can apply the pipelinerun

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
We have set up our pipeline, but we have started it manually the next thing will be to set up trigger so that on GitHub events our pipeline starts automatically.

NOTE: when the pipeline is triggered manually and by triggers, it also creates a pull request on configuration repository, but we haven't set up
argocd, so it will not have any effect even if we merge it.

#### Setting up triggers

To set up triggers, you need to apply resources in [trigger](./trigger)

Before applying edit [./trigger/00-triggertemplate.yaml](./trigger/00-triggertemplate.yaml) and replace the values which
you have used in the pipelinerun previously.
So, whenever an event is received this templated is used to create pipelinerun.
```yaml
  kubectl apply -f trigger/
```
This will
* create an EventListener which will listening for GitHub Events
* trigger binding where we define which values do we want to take from incoming event and use in our pipeline
* trigger template where we define our pipelinerun which will be created and here we use the variables we define in binding
* ingress to configure our event listener with GitHub

You can look for event listener route using
```yaml
  kubectl get route news-demo-dev-eventlistener -n news-demo-dev
```
You can configure route with GitHub now.

Next step would be configuring the Event listener with GitHub
* You can fork https://github.com/sm43/news-demo, and you can set up a webhook for the repository.
* Go to setting of your repository -> Webhooks -> Add Webhook 
* Add your route url in Payload URL
* Content Type as application/json
* You can add a secret and use it for validation while setting up triggers, in this demo we are skipping this.
* Select `Just the push event`. 
* Add Webhook

Now, you are ready to trigger your pipeline. Push a commit to `main` branch and the pipeline with trigger.

NOTE: when the pipeline is triggered manually and by triggers, it also creates a pull request on configuration repository, but we haven't set up
argocd, so it will not have any effect even if we merge it.

### Setting up Application

* We will configure ArgoCD to watch our application manifests in a git repository
* Whenever there will be a change in manifests, argocd will notice that and reflect the changes on the cluster
* So when we merge the pull request, it will update the image in main branch and argocd will notice that and apply on cluster

#### Creating Application CR

* To configure application manifest with argocd, we need to create a Application Custom Resource with repository details
* This can be created using the ArgoCD dashboard, CLI or applying the yaml.

```yaml
  kubectl apply -f argocd/
```

Now, if you go to argocd dashboard and sync our application then you will find the deployed application in `news-demo-stage`
namespace and using the route you can access it.


> The Docs is not perfect please feel free to create a pull request or creating an issue to improve it.


