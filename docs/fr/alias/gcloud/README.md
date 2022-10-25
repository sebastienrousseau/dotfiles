# Google Cloud Aliases

The `gcloud.aliases.zsh` file creates helpful shortcut aliases for many commonly
[Google Cloud](https://cloud.google.com/) commands.

## Command-line tool

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcci | `gcloud components install` | Install specific components. |
| gccsp | `gcloud config set project` | Set a default Google Cloud project to work on. |
| gccu | `gcloud components update` | Update your Cloud SDK to the latest version. |
| gci  | `gcloud init` | Initialize, authorize, and configure the gcloud tool. |
| gcinf | `gcloud info` | Display current gcloud tool environment details. |
| gcv  | `gcloud version` | Display version and installed components. |

## Custom

| Alias | Command | Description |
| ----- | ----- | ----- |
| gccca | `gcloud config configurations activate` | Switch to an existing named configuration. |
| gcccc | `gcloud config configurations create` | Create a new named configuration. |
| gcccl | `gcloud config configurations list` | Display a list of all available configurations. |
| gccgv | `gcloud config get-value` | Fetch value of a Cloud SDK property. |
| gccl | `gcloud config list` | Display all the properties for the current configuration. |
| gccs | `gcloud config set` | Define a property (like compute/zone) for the current configuration. |

## Authorization

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcaasa | `gcloud auth activate-service-account` | Like gcloud auth login but with service account credentials. |
| gcacd | `gcloud auth configure-docker` | Register the gcloud tool as a Docker credential helper. |
| gcal  | `gcloud auth list` | List all credentialed accounts. |
| gcal  | `gcloud auth login` | Authorize Google Cloud access for the gcloud tool with Google user credentials and set current account as active. |
| gcapat | `gcloud auth print-access-token` | Display the current account's access token. |
| gcar  | `gcloud auth revoke` | Remove access credentials for an account. |

## Cloud Identity & Access Management (IAM)

| Alias | Command | Description |
| ----- | ----- | ----- |
| gciamk | `gcloud iam service-accounts keys list` | List a service account's keys. |
| gciaml | `gcloud iam list-grantable-roles` | List IAM grantable roles for a resource. |
| gciamp | `gcloud iam service-accounts add-iam-policy-binding` | Add an IAM policy binding to a service account. |
| gciamr | `gcloud iam roles create` | Create a custom role for a project or org. |
| gciams | `gcloud iam service-accounts set-iam-policy` | Replace existing IAM policy binding. |
| gciamv | `gcloud iam service-accounts create` | Create a service account for a project. |

## Access policies

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcpa | `gcloud projects add-iam-policy-binding` | Add an IAM policy binding to a specified project. |
| gcpd | `gcloud projects describe` | Display metadata for a project (including its ID). |

## Kubernetes

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcccc | `gcloud container clusters create` | Create a cluster to run GKE containers. |
| gcccg | `gcloud container clusters get-credentials` | Update kubeconfig to get kubectl to use a GKE cluster. |
| gcccl | `gcloud container clusters list` | List clusters for running GKE containers. |
| gccil | `gcloud container images list-tags` | List tag and digest metadata for a container image. |

## VMs

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcpc    | `gcloud compute copy-files` | Copy files |
| gcpdown | `gcloud compute instances stop` | Stop instance |
| gcpds   | `gcloud compute disks snapshot` | Create snapshot of persistent disks. |
| gcpid   | `gcloud compute instances describe` | Display a VM instance's details. |
| gcpil   | `gcloud compute instances list` | List all VM instances in a project. |
| gcprm   | `gcloud compute instances delete` | Delete instance |
| gcpsk   | `gcloud compute snapshots delete` | Delete a snapshot. |
| gcpssh  | `gcloud compute ssh` | Connect to a VM instance by using SSH. |
| gcpup   | `gcloud compute instances start` | Start instance. |
| gcpzl   | `gcloud compute zones list` | List Compute Engine zones. |

## gcloud aliases to build highly scalable applications on a fully managed serverless platform

| Alias | Command | Description |
| ----- | ----- | ----- |
| gcapb | `gcloud app browse` | Open the current app in a web browser. |
| gcapc | `gcloud app create` | Create an App Engine app within your current project. |
| gcapd | `gcloud app deploy` | Deploy your app's code and configuration to the App Engine server. |
| gcapl | `gcloud app logs read` | Display the latest App Engine app logs. |
| gcapv | `gcloud app versions list` | List all versions of all services deployed to the App Engine server. |

## gcloud aliases to commands that might come in handy

| Alias | Command | Description |
| ----- | ----- | ----- |
| gckmsd | `gcloud kms decrypt` | Decrypt ciphertext (to a plaintext file) using a Cloud Key Management Service (Cloud KMS) key. |
| gclll  | `gcloud logging logs list` | List your project's logs. |
| gcsqlb | `gcloud sql backups describe` | Display info about a Cloud SQL instance backup. |
| gcsqle | `gcloud sql export sql` | Export data from a Cloud SQL instance to a SQL file. |
