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
            roles/iam.serviceAccountAdmin roles/iam.serviceAccountUser roles/compute.admin \
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

## Free-tier test VM (0 USD/month)
`terraform/vm.tf` creates one `e2-micro` VM with a 30 GB `pd-standard` disk in `us-central1-a`.
This matches the Compute Engine Always Free tier, **if** these conditions hold:
- The zone is in `us-west1`, `us-central1` or `us-east1` (enforced by a variable validation). `europe-west1` is **not** free.
- Only one such VM runs per billing account; any other e2-micro is billed.
- No external IPv4 (it costs about 3-4 USD/month). The VM has no public IP, so SSH goes through IAP:
  ```bash
  gcloud compute ssh test-vm --zone us-central1-a --tunnel-through-iap
  ```
  Your user needs `roles/iap.tunnelResourceAccessor`. Without a public IP or Cloud NAT (paid) the VM cannot reach the internet.
- Outbound traffic stays under 1 GB/month from North America.

The VM is in a different region from the rest of the infra (`europe-west1`), which is fine for a test.
The `infra-manager` service account also needs `roles/compute.admin`.
