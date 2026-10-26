# Harness pipeline YAML

## Build pipeline

`pipeline-build-push.yaml` is the build/push pipeline template using Harness' native `BuildAndPushGAR` step. Update:
- `YOUR_HARNESS_PROJECT_ID`
- `YOUR_HARNESS_ORG_ID`
- `YOUR_GITHUB_CONNECTOR_ID`
- `gcpImageConnector` to the exact GCP connector identifier you create with OIDC/WIF.
- `repoName` to your actual GitHub repository name/format accepted by your configured GitHub connector.

The pipeline expects the Docker build context to be `app/`. If your real Python app is inside `Episode-02/python-project`, move/copy these files there and update `context`/`dockerfile`.

## Terraform pipeline stage

Use a separate Harness CI pipeline for infrastructure, with a Harness GCP OIDC connector named `gcpTerraformConnector`. Run the following commands in a CI Run step whose build image has Terraform and Google Cloud CLI installed, or use Harness' native Terraform Plan/Apply steps configured with the GCP OIDC connector and the GCS backend:
```bash
terraform -chdir=terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="prefix=harness-gke/infra"
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan \
  -var="project_id=project-b21965c0-60b2-4525-a12" \
  -var="region=us-central1" \
  -var="cluster_name=harness-gke" \
  -var="machine_type=e2-standard-2" \
  -out=tfplan
terraform -chdir=terraform apply -auto-approve tfplan
```
The step must authenticate as `harness-terraform` through the OIDC connector. Do not export or store service-account JSON keys.

## Deploy pipeline

Use a separate Harness CD Kubernetes deployment stage (or a CI Run step with a GCP OIDC-enabled Kubernetes connector). Apply `k8s/namespace.yaml`, then render the tag into the Deployment and apply it. Example deployment commands once the pipeline has authenticated to the target GKE cluster:
```bash
kubectl apply -f k8s/namespace.yaml
sed "s/REPLACE_WITH_BUILD_TAG/${IMAGE_TAG}/" k8s/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/service.yaml
kubectl -n demo rollout status deployment/python-demo --timeout=180s
kubectl -n demo get service python-demo
```
Set `IMAGE_TAG` to the same sequence ID that was pushed in the build stage. The GCP identity needs permission to obtain cluster credentials, and Kubernetes RBAC must permit deployment to namespace `demo`.
