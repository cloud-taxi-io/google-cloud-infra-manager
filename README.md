# google-cloud-infra-manager

Infrastructure as code (Terraform) deployed with **Google Cloud Infrastructure Manager** for the
Pub/Sub -> Cloud Run pipeline of [google-cloud-pubsub-run](https://github.com/cloud-taxi-io/google-cloud-pubsub-run).

```
Pub/Sub topic -> push subscription (OIDC) -> Cloud Run (private)
```

## Resources created
- APIs: Cloud Run, Pub/Sub, Cloud Build, Artifact Registry
- Pub/Sub topic `mon-topic` and push subscription `ma-sub`
- Service account `pubsub-invoker` (+ `run.invoker` on the service, `serviceAccountTokenCreator` for the Pub/Sub agent)
- Cloud Run service `mon-service` (private)

## Prerequisites
1. Enable Infra Manager and create its service account:
   ```bash
   gcloud services enable config.googleapis.com
   gcloud iam service-accounts create infra-manager
   for r in roles/config.agent roles/run.admin roles/pubsub.admin \
            roles/iam.serviceAccountAdmin roles/iam.serviceAccountUser roles/cloudsql.admin roles/secretmanager.admin \
            roles/resourcemanager.projectIamAdmin roles/serviceusage.serviceUsageAdmin; do
     gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member=serviceAccount:infra-manager@$PROJECT_ID.iam.gserviceaccount.com --role=$r
   done
   ```
2. Build the image first (see the app repo), e.g. `gcloud run deploy ... --source .`, and note its URL.

## Deploy
```bash
export PROJECT_ID=gen-lang-client-0031150958
export IMAGE=europe-west1-docker.pkg.dev/$PROJECT_ID/cloud-run-source-deploy/mon-service:latest
./deploy.sh preview   # dry run
./deploy.sh apply
./deploy.sh delete    # tear down
```

## Existing resources
The resources already exist (created with gcloud). Before the first `apply`, either delete them
or import them into the deployment state, otherwise Terraform will fail with "already exists".

## Cloud SQL PostgreSQL + PostGIS
`terraform/cloudsql.tf` creates:
- a Cloud SQL for PostgreSQL 16 instance (`postgis-db`, Enterprise edition, SSL only, backups + PITR, deletion protection on)
- a database `app` and a user `app` with a generated password stored in Secret Manager (`postgis-db-app-password`)

PostGIS is available on Cloud SQL but must be enabled per database with `CREATE EXTENSION`,
which Terraform's Google provider cannot do. After the first `apply`:
```bash
PROJECT_ID=gen-lang-client-0031150958 ./enable-postgis.sh
```
Notes:
- The generated password is also kept in the Terraform state; protect access to the Infra Manager state bucket.
- No authorized networks are configured. Connect with the Cloud SQL Auth Proxy / connector.
  To let Cloud Run connect, grant its service account `roles/cloudsql.client`.
- The `infra-manager` service account also needs `roles/cloudsql.admin` and `roles/secretmanager.admin`.
- Cost: a `db-custom-1-3840` instance is roughly 50-60 USD/month plus storage and backups; check the pricing calculator.
