# One-time GCP bootstrap

Run these commands as an administrator from Cloud Shell or a terminal with `gcloud` authenticated. Replace `HARNESS_ACCOUNT_ID` and verify the issuer hostname in Harness Account Settings > Account Details.

```bash
export PROJECT_ID="project-b21965c0-60b2-4525-a12"
export REGION="us-central1"
export POOL_ID="harness-pool"
export PROVIDER_ID="harness-oidc-provider"
export HARNESS_ACCOUNT_ID="REPLACE_WITH_HARNESS_ACCOUNT_ID"
export OIDC_HOST="app.harness.io"  # verify for your Harness cluster
export TF_STATE_BUCKET="${PROJECT_ID}-tfstate-CHANGE-ME"
export PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"
export ISSUER="https://${OIDC_HOST}/ng/api/oidc/account/${HARNESS_ACCOUNT_ID}"
export AUDIENCE="https://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com \
  cloudresourcemanager.googleapis.com serviceusage.googleapis.com \
  artifactregistry.googleapis.com container.googleapis.com compute.googleapis.com \
  --project="$PROJECT_ID"

# Create a private state bucket. Bucket names are globally unique; change the name if it already exists.
gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
  --project="$PROJECT_ID" --location="$REGION" --uniform-bucket-level-access
gcloud storage buckets update "gs://${TF_STATE_BUCKET}" --versioning

# Create WIF pool and OIDC provider.
gcloud iam workload-identity-pools create "$POOL_ID" \
  --project="$PROJECT_ID" --location="global" \
  --display-name="Harness CI/CD"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project="$PROJECT_ID" --location="global" --workload-identity-pool="$POOL_ID" \
  --display-name="Harness OIDC" \
  --issuer-uri="$ISSUER" \
  --allowed-audiences="$AUDIENCE" \
  --attribute-mapping="google.subject=assertion.sub,attribute.account_id=assertion.account_id" \
  --attribute-condition="assertion.account_id == '${HARNESS_ACCOUNT_ID}'"

# Create separate service accounts.
for SA in harness-terraform harness-image-builder harness-deployer; do
  gcloud iam service-accounts create "$SA" --project="$PROJECT_ID" \
    --display-name="Harness ${SA}"
done

# Trust only tokens from the configured Harness account.
for SA in harness-terraform harness-image-builder harness-deployer; do
  gcloud iam service-accounts add-iam-policy-binding \
    "${SA}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="$PROJECT_ID" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.account_id/${HARNESS_ACCOUNT_ID}"
done

# Terraform identity: these are broad enough for the starter infra, but not Owner.
# Review permissions and replace with a custom role where your organization requires stricter least privilege.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:harness-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.admin"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:harness-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/compute.networkAdmin"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:harness-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:harness-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.admin"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:harness-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"
gcloud storage buckets add-iam-policy-binding "gs://${TF_STATE_BUCKET}" \
  --member="serviceAccount:harness-terraform@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Do NOT grant project-wide Artifact Registry Writer here.
# After Terraform creates the repository, grant writer on that repository only (see below).

# Deployer: permissions needed for GKE credentials; Kubernetes RBAC must also allow namespace deployments.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:harness-deployer@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/container.clusterViewer"

echo "Project number: ${PROJECT_NUMBER}"
echo "WIF pool: ${POOL_ID}"
echo "WIF provider: ${PROVIDER_ID}"
echo "Audience: ${AUDIENCE}"
echo "State bucket: gs://${TF_STATE_BUCKET}"
echo "Service accounts: harness-terraform / harness-image-builder / harness-deployer"
```

## Important

- Verify the Harness issuer hostname for your account's cluster; do not assume `app.harness.io` if your account is hosted elsewhere.
- The provider condition restricts tokens to the Harness account ID. Keep this condition and further restrict attributes/claims if your Harness account supports finer-grained claim conditions.
- `roles/container.clusterViewer` alone does not grant Kubernetes permissions to deploy. Configure the Harness GKE/Kubernetes connector and namespace RBAC for the deployment identity.
- The Terraform IAM set above is a practical starter, not a universal minimal custom role. GKE creation requirements depend on the project, network, and service-account setup.

## After the infrastructure pipeline creates Artifact Registry

Grant the image builder access only to the `harness-app` repository:

```bash
gcloud artifacts repositories add-iam-policy-binding harness-app \
  --project="project-b21965c0-60b2-4525-a12" \
  --location="us-central1" \
  --member="serviceAccount:harness-image-builder@project-b21965c0-60b2-4525-a12.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

For a strict least-privilege production implementation, review the Terraform service account's project-level roles and replace broad predefined roles with a reviewed custom role or resource-scoped grants where supported.
