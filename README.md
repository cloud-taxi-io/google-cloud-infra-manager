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
   gcloud services enable config.googleapis.com compute.googleapis.com \
     cloudresourcemanager.googleapis.com iam.googleapis.com serviceusage.googleapis.com
   gcloud iam service-accounts create infra-manager
   for r in roles/config.agent roles/run.admin roles/pubsub.admin \
            roles/iam.serviceAccountAdmin roles/iam.serviceAccountUser roles/compute.admin \
            roles/artifactregistry.reader roles/identityplatform.admin roles/secretmanager.admin \
            roles/resourcemanager.projectIamAdmin roles/serviceusage.serviceUsageAdmin; do
     gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member=serviceAccount:infra-manager@$PROJECT_ID.iam.gserviceaccount.com --role=$r
   done
   ```
   Why these are needed (each one was a real failure on the first deploy):
   - `cloudresourcemanager.googleapis.com`: Terraform reads the project; without it `plan` fails with `SERVICE_DISABLED`.
   - `roles/artifactregistry.reader`: Cloud Run validates the container image with the deployer's identity; without it
     the apply fails with `artifactregistry.repositories.downloadArtifacts denied`.
2. Build the image first (see the app repo), e.g. `gcloud run deploy ... --source .`, and note its URL.
   Prefer the image digest (`...mon-service@sha256:...`) for `IMAGE`, since `source` deploys do not create a `:latest` tag.

Right after the first apply, Pub/Sub may get `403` from Cloud Run for a minute or two while the new IAM bindings propagate.
Pub/Sub retries automatically, so no message is lost.

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

## Free-tier test VM + PostgreSQL / PostGIS / TimescaleDB
`terraform/vm.tf` creates one `e2-micro` VM (Debian 12, 30 GB `pd-standard` disk) in `us-central1-a`,
matching the Compute Engine Always Free tier **if**:
- the zone is in `us-west1`, `us-central1` or `us-east1` (enforced by a variable validation; `europe-west1` is **not** free);
- it is the only e2-micro on the billing account and egress stays under 1 GB/month (North America).

**Public IP (not free)**: `vm_external_ip = true` (default) attaches an ephemeral external IPv4, about 3.65 USD/month
(0.005 USD/h, so ~0.85 USD for a 7-day test). It is required to download packages. The firewall only allows SSH from the IAP range:
```bash
gcloud compute ssh timescaledb --zone us-central1-a --tunnel-through-iap
```
Your user needs `roles/iap.tunnelResourceAccessor`. Set `vm_external_ip = false` and `install_timescaledb = false` to stay at 0 USD.

**Database**: `install_timescaledb = true` (default) runs `terraform/scripts/install-postgres-timescaledb.sh` at first boot:
PostgreSQL 18, PostGIS 3 and TimescaleDB, `timescaledb-tune`, then a database `app` with `CREATE EXTENSION timescaledb` and
`CREATE EXTENSION postgis`. PostgreSQL listens on localhost only.
- Follow the install: `gcloud compute ssh timescaledb --zone us-central1-a --tunnel-through-iap -- sudo journalctl -u google-startup-scripts -f`
- Check: `sudo -u postgres psql -d app -c "\dx"`
- The script runs once (marker `/var/lib/postgis-timescaledb-installed`); delete it and reboot to re-run.
- An `e2-micro` has 1 GB RAM: tests only.
- Copy files from your PC with `gcloud compute scp --tunnel-through-iap`.
- The `infra-manager` service account needs `roles/compute.admin`.
- Tear down everything to stop billing: `./deploy.sh delete`.

## Identity Platform (app users)
`terraform/identity.tf` enables Google Identity Platform to manage the app's users (sign-up, sign-in, password reset, tokens):
- API `identitytoolkit.googleapis.com` and the project configuration with **email/password** sign-in (duplicate emails refused, anonymous users auto-deleted).
- Optional **Sign in with Google**: create an OAuth 2.0 client in the console, then set `identity_google_client_id` / `identity_google_client_secret`.
  The secret ends up in the Terraform state; restrict access to the state bucket and never commit it.
- **Phone number + OTP** sign-up / sign-in is enabled (`sign_in.phone_number`). Users receive a 6-digit code by SMS.
  - SMS is **billed per message** and the price depends on the destination country: check the Identity Platform pricing page.
  - `identity_sms_allowed_regions` (default `["DZ", "FR"]`) limits the countries SMS can be sent to, to avoid SMS-pumping fraud and surprise bills. Adjust it to your users.
  - Test phone numbers (fixed code, no SMS, free, development only): pass them at apply time, **not in git** (the repo is public):
    `TEST_PHONE_NUMBERS_JSON='{"+33612345678":"123456"}' ./deploy.sh apply` (variable `identity_test_phone_numbers_json`; Infra Manager passes inputs as strings, hence JSON).
    Note that each `apply` replaces the inputs, so pass the variable every time or the test numbers are removed.
  - The client app must use reCAPTCHA / app verification when requesting the code (Firebase Auth SDK handles it); keep the quota low.
- Add your app domain to `identity_authorized_domains`.
- The `infra-manager` service account needs `roles/identityplatform.admin` (and `serviceusage` to enable the API).

How the app uses it: the client SDK (Firebase Auth) signs the user in and gets an **ID token (JWT)**; the backend (e.g. the Cloud Run service)
must verify that token (Firebase Admin SDK `verify_id_token`) before trusting the request. Verification is not implemented in `main.py` yet.

Cost: free up to 50,000 monthly active users, then about 0.0055 USD per MAU (tiered). Phone auth SMS are billed per message (varies by country). Check the pricing page.

## VTC API (Cloud Run, us-central1)

`terraform/main.tf` deploys the API from [google-cloud-pubsub-run](https://github.com/cloud-taxi-io/google-cloud-pubsub-run):

```
App ─► Cloud Run vtc-api (us-central1, public) ──Direct VPC egress──► PostgreSQL on VM timescaledb (10.128.0.2)
            │ publish                                   ▲
            ▼                                           │ write
   Pub/Sub driver-locations ──push (OIDC)──► /pubsub/push
            └─ after 10 failed deliveries ─► driver-locations-dlq (+ pull subscription, 7 days)
```

- Runtime service account `vtc-api` with least privilege: read the `DATABASE_URL` secret, publish to `driver-locations`, `firebaseauth.viewer`.
- **Public** service (`allUsers` invoker): the mobile app sends a Firebase ID token; security relies on JWT verification + PostgreSQL RBAC. `/pubsub/push` checks the OIDC token (fixed audience `vtc-api-pubsub-push`, service account `pubsub-invoker`).
- Cloud Run job `vtc-api-migrate` runs `alembic upgrade head`.
- The old `mon-service` (europe-west1), `mon-topic` and `ma-sub` are removed.

### One-time setup
1. **Database on the VM**: create the `app` user and listen on the internal IP for the Cloud Run subnet only (`scripts/configure-db-network.sh`, password on stdin).
   Port 5432 is reachable only from inside the VPC (`default-allow-internal`); `pg_hba.conf` only allows `10.128.0.0/20`.
2. **Secret** (outside Terraform, so the password never enters the state):
   ```bash
   gcloud secrets create vtc-database-url --replication-policy=automatic
   printf 'postgresql+psycopg://app:%s@10.128.0.2:5432/app' "$(cat password-file)" | gcloud secrets versions add vtc-database-url --data-file=-
   ```
3. `infra-manager` needs `roles/secretmanager.admin` (to grant the API access to the secret).

### Deploy a new version
```bash
export PROJECT_ID=gen-lang-client-0031150958
export IMAGE=europe-west1-docker.pkg.dev/$PROJECT_ID/cloud-run-source-deploy/vtc-api:<tag>
./deploy.sh apply     # updates the service and the migration job image
./deploy.sh migrate   # alembic upgrade head
```
First admin: `DATABASE_URL=... python -m app.cli grant-role <firebase_uid> admin --create` (run as a one-off job or through an SSH tunnel).
