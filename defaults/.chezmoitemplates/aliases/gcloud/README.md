# Google Cloud Aliases

Manage Google Cloud aliases. Part of the **Universal Dotfiles** configuration.

![Dotfiles banner][banner]

## Description

These aliases are defined in `gcloud.aliases.sh`. Loaded by the lazy alias layer `~/.config/shell/91-ux-aliases-lazy.sh`. It loads after the eager layer (zsh defers it until after startup), so its definitions replace any eager alias of the same name. Skipped when `DOTFILES_ALIAS_PROFILE=minimal` at `chezmoi apply` time. Every definition below exists only when `gcloud` is on PATH.

## Aliases

| Name | Definition | Notes |
| --- | --- | --- |
| `gcci` | `gcloud components install` | Install specific components. |
| `gccsp` | `gcloud config set project` | Set a default Google Cloud project to work on. |
| `gccu` | `gcloud components update` | Update your Cloud SDK to the latest version. |
| `gcinf` | `gcloud info` | Display current gcloud tool environment details. |
| `gcv` | `gcloud version` | Display version and installed components. |
| `gccca` | `gcloud config configurations activate` | Switch to an existing named configuration. |
| `gccgv` | `gcloud config get-value` | Fetch value of a Cloud SDK property. |
| `gccl` | `gcloud config list` | Display all the properties for the current configuration. |
| `gccs` | `gcloud config set` | Define a property (like compute/zone) for the current configuration. |
| `gcaasa` | `gcloud auth activate-service-account` | Like gcloud auth login but with service account credentials. |
| `gcacd` | `gcloud auth configure-docker` | Register the gcloud tool as a Docker credential helper. |
| `gcal` | `gcloud auth list` | List all credentialed accounts. |
| `gcapat` | `gcloud auth print-access-token` | Display the current account's access token. |
| `gcar` | `gcloud auth revoke` | Remove access credentials for an account. |
| `gciamk` | `gcloud iam service-accounts keys list` | List a service account's keys. |
| `gciaml` | `gcloud iam list-grantable-roles` | List IAM grantable roles for a resource. |
| `gciamp` | `gcloud iam service-accounts add-iam-policy-binding` | Add an IAM policy binding to a service account. |
| `gciamr` | `gcloud iam roles create` | Create a custom role for a project or org. |
| `gciams` | `gcloud iam service-accounts set-iam-policy` | Replace existing IAM policy binding. |
| `gciamv` | `gcloud iam service-accounts create` | Create a service account for a project. |
| `gcpa` | `gcloud projects add-iam-policy-binding` | Add an IAM policy binding to a specified project. |
| `gcpd` | `gcloud projects describe` | Display metadata for a project (including its ID). |
| `gcccc` | `gcloud container clusters create` | Create a cluster to run GKE containers. |
| `gcccg` | `gcloud container clusters get-credentials` | Update kubeconfig to get kubectl to use a GKE cluster. |
| `gcccl` | `gcloud container clusters list` | List clusters for running GKE containers. |
| `gccil` | `gcloud container images list-tags` | List tag and digest metadata for a container image. |
| `gcpc` | `gcloud compute copy-files` |  |
| `gcpdown` | `gcloud compute instances stop` |  |
| `gcpds` | `gcloud compute disks snapshot` | Create snapshot of persistent disks. |
| `gcpid` | `gcloud compute instances describe` | Display a VM instance's details. |
| `gcpil` | `gcloud compute instances list` | List all VM instances in a project. |
| `gcprm` | `gcloud compute instances delete` |  |
| `gcpsk` | `gcloud compute snapshots delete` | Delete a snapshot. |
| `gcpssh` | `gcloud compute ssh` | Connect to a VM instance by using SSH. |
| `gcpup` | `gcloud compute instances start` | Start instance. |
| `gcpzl` | `gcloud compute zones list` | List Compute Engine zones. |
| `gcapb` | `gcloud app browse` | Open the current app in a web browser. |
| `gcapc` | `gcloud app create` | Create an App Engine app within your current project. |
| `gcapd` | `gcloud app deploy` | Deploy your app's code and configuration to the App Engine server. |
| `gcapl` | `gcloud app logs read` | Display the latest App Engine app logs. |
| `gcapv` | `gcloud app versions list` | List all versions of all services deployed to the App Engine server. |
| `gckmsd` | `gcloud kms decrypt` | Decrypt ciphertext (to a plaintext file) using a Cloud Key Management Service (Cloud KMS) key. |
| `gclll` | `gcloud logging logs list` | List your project's logs. |
| `gcsqlb` | `gcloud sql backups describe` | Display info about a Cloud SQL instance backup. |
| `gcsqle` | `gcloud sql export sql` | Export data from a Cloud SQL instance to a SQL file. |
| `gclb` | `gcloud builds` | Manage Google Cloud Build. |
| `gcca` | `gcloud compute addresses` | Manage Compute Engine IP addresses. |
| `gccc` | `gcloud compute instances create` | Create a new virtual machine instance. |
| `gcco` | `gcloud compute ssh` | Connect to a virtual machine instance by using SSH. |
| `gcd` | `gcloud config set project $(gcloud projects list --format="value(projectId)" --filter="name:${PWD##\*/}")` | Set default project to current directory name. |
| `gcdb` | `gcloud datastore` | Manage Google Cloud Datastore. |
| `gcdp` | `gcloud dataproc` | Manage Google Cloud Dataproc. |
| `gce` | `gcloud endpoints` | Manage Google Cloud Endpoints. |
| `gcem` | `gcloud eventarc` | Manage Google Cloud Eventarc. |
| `gcf` | `gcloud functions` | Manage Google Cloud Functions. |
| `gci` | `gcloud compute instances` | Manage Google Cloud Compute Engine instances. |
| `gcic` | `gcloud iam` | Manage Google Cloud Identity and Access Management. |
| `gcir` | `gcloud iot` | Manage Google Cloud IoT Core. |
| `gck` | `gcloud config configurations list` | List all configurations. |
| `gcki` | `gcloud kms` | Manage Google Cloud KMS. |
| `gcla` | `gcloud logging` | Manage Google Cloud Logging. |
| `gcma` | `gcloud monitoring` | Manage Google Cloud Monitoring. |
| `gcp` | `gcloud projects` | Manage Google Cloud projects. |
| `gcpha` | `gcloud compute addresses describe` | Display details for a Compute Engine IP address. |
| `gcps` | `gcloud pubsub` | Manage Google Cloud Pub/Sub. |
| `gcr` | `gcloud container images delete` | Delete a container image from Google Container Registry. |
| `gcrm` | `gcloud resource-manager` | Manage Google Cloud resources. |
| `gcro` | `gcloud run` | Manage Google Cloud Run. |
| `gcs` | `gcloud container clusters` | Manage Google Cloud Kubernetes Engine clusters. |
| `gcsa` | `gcloud config set account` | Set the account for the current configuration. |
| `gcsc` | `gcloud source` | Manage Google Cloud Source Repositories. |
| `gcso` | `gcloud organizations` | The `gcloud organizations` command group. |
| `gcsq` | `gcloud sql` | Manage Google Cloud SQL. |
| `gcss` | `gcloud storage` | Manage Google Cloud Storage. |
| `gcst` | `gcloud services` | Enable or disable Google Cloud services. |
| `gct` | `gcloud tasks` | Manage Google Cloud Tasks. |
| `gcu` | `gcloud app` | Manage Google Cloud App Engine. |

[banner]: https://cloudcdn.pro/dotfiles/v2/images/titles/title-dotfiles.svg

---

Made with ❤️ by [Sebastien Rousseau](https://github.com/sebastienrousseau)
