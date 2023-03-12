#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets Google Cloud Aliases
# License: MIT
# Script: gcloud.aliases.sh
# Version: 0.2.463
# Website: https://dotfiles.io

if command -v 'gcloud' >/dev/null; then

  # Authenticate and authorize
  alias gcaasa='gcloud auth activate-service-account' # gcaasa: Like gcloud auth login but with service account credentials.
  alias gcacd='gcloud auth configure-docker'          # gcacd: Configure Docker to use gcloud as a credential helper.
  alias gcal='gcloud auth list'                       # gcal: List the accounts you are logged in with.
  alias gcapat='gcloud auth print-access-token'       # gcapat: Print the access token for the current active account.
  alias gcar='gcloud auth revoke'                     # gcar: Revoke credentials for the current active account.

  # App Engine
  alias gcapb='gcloud app browse'        # gcapb: Open the App Engine app in your default browser.
  alias gcapc='gcloud app create'        # gcapc: Create a new App Engine app.
  alias gcapd='gcloud app deploy'        # gcapd: Deploy an App Engine app.
  alias gcapl='gcloud app logs read'     # gcapl: Read the logs for an App Engine app.
  alias gcapv='gcloud app versions list' # gcapv: List the versions of an App Engine app.

  # Cloud SDK configuration and management
  alias gccca='gcloud config configurations activate' # gccca: Switch to an existing named configuration.
  alias gcccc='gcloud config configurations create'   # gcccc: Create a new named configuration.
  alias gcccl='gcloud config configurations list'     # gcccl: Display a list of all available configurations.
  alias gccl='gcloud config list'                     # gccl:Display all the properties for the current configuration.
  alias gccgv='gcloud config get-value'               # gccgv: Fetch value of a Cloud SDK property.
  alias gccs='gcloud config set'                      # gccs: Define a property (like compute/zone) for the current configuration.
  alias gccsp='gcloud config set project'             # gccsp: Set a default Google Cloud project to work on.
  alias gccu='gcloud components update'               # gccu: Update your Cloud SDK to the latest version.
  alias gci='gcloud init'                             # gci: Initialize, authorize, and configure the gcloud tool.
  alias gcinf='gcloud info'                           # gcinf: Display current gcloud tool environment details.
  alias gciov='gcloud io verify-email'                # gciov: Verify your email address for Google Cloud.

  # Container
  alias gcccc='gcloud container clusters create'          # gcccc: Create a cluster to run GKE containers.
  alias gcccg='gcloud container clusters get-credentials' # gcccg: Update kubeconfig to get kubectl to use a GKE cluster.
  alias gcccl='gcloud container clusters list'            # gcccl: List clusters for running GKE containers.
  alias gccil='gcloud container images list-tags'         # gccil: List tag and digest metadata for a container image.
  alias gcd='gcloud container'                            # gcd: A convenience command group for all container-related commands.

  # IAM
  alias gciamk='gcloud iam service-accounts keys list'                  # gciamk: List a service account's keys.
  alias gciaml='gcloud iam list-grantable-roles'                        # gciaml: List IAM grantable roles for a resource.
  alias gciamp='gcloud iam service-accounts add-iam-policy-binding'     # gciamp: Add an IAM policy binding to a service account.
  alias gciamr='gcloud iam roles create'                                # gciamr: Create a custom role for a project or org
  alias gciamd='gcloud iam roles delete'                                # gciamd: Delete a custom role for a project or org.
  alias gciampd='gcloud iam service-accounts remove-iam-policy-binding' # gciampd: Remove an IAM policy binding from a service account.
  alias gciamro='gcloud iam roles describe'                             # gciamro: Describe a custom role for a project or org.
  alias gciamsp='gcloud iam service-accounts set-iam-policy'            # gciamsp: Replace the IAM policy of a service account.
  alias gciamu='gcloud iam roles undelete'                              # gciamu: Undelete a custom role for a project or org.
  alias gciamup='gcloud iam service-accounts update'                    # gciamup: Update a service account.
  alias gcimp='gcloud organizations list'                               # gcimp: List available Cloud Identity domains.
  alias gcimpe='gcloud organizations add-iam-policy-binding'            # gcimpe: Add an IAM policy binding to a Cloud Identity domain.
  alias gcimpr='gcloud organizations remove-iam-policy-binding'         # gcimpr: Remove an IAM policy binding from a Cloud Identity domain.
  alias gcsac='gcloud auth application-default login'                   # gcsac: Obtain an access token for the Google Cloud APIs.

  # Compute
  alias gcc='gcloud compute'                          # gcc: A convenience command group for all compute-related commands.
  alias gcpa='gcloud projects add-iam-policy-binding' # gcpa: Add an IAM policy binding to a specified project.
  alias gcpc='gcloud compute copy-files'              # gcpc: Copy files.
  alias gcpd='gcloud projects describe'               # gcpd: Display metadata for a project (including its ID).
  alias gcpdown='gcloud compute instances stop'       # gcpdown: Stop instance.
  alias gcpds='gcloud compute disks snapshot'         # gcpds: Create snapshot of persistent disks.
  alias gcpid='gcloud compute instances describe'     # gcpid: Display a VM instance's details.
  alias gcpil='gcloud compute instances list'         # gcpil: List all VM instances in a project.
  alias gcprm='gcloud compute instances delete'       # gcprm: Delete instance.
  alias gcpsk='gcloud compute snapshots delete'       # gcpsk: Delete a snapshot.
  alias gcpssh='gcloud compute ssh'                   # gcpssh: Connect to a VM instance by using SSH.
  alias gcpup='gcloud compute instances start'        # gcpup: Start instance.
  alias gcpzl='gcloud compute zones list'             # gcpzl:List Compute Engine zones.

  # Deployment Manager
  alias gcdm='gcloud deployment-manager'                       # gcdm: A convenience command group for all deployment-manager-related commands.
  alias gcdma='gcloud deployment-manager deployments create'   # gcdma: Create a new deployment.
  alias gcdmd='gcloud deployment-manager deployments delete'   # gcdmd: Delete a deployment.
  alias gcdmg='gcloud deployment-manager deployments describe' # gcdmg: Describe a deployment.
  alias gcdml='gcloud deployment-manager deployments list'     # gcdml: List all deployments.
  alias gcdmu='gcloud deployment-manager deployments update'   # gcdmu: Update a deployment.

  # DNS
  alias gcdns='gcloud dns'                                  # gcdns: A convenience command group for all dns-related commands.
  alias gcdnsz='gcloud dns managed-zones'                   # gcdnsz: List managed DNS zones.
  alias gcdnsc='gcloud dns record-sets changes'             # gcdnsc: List or apply DNS record sets changes.
  alias gcdnsd='gcloud dns managed-zones delete'            # gcdnsd: Delete a managed DNS zone.
  alias gcdnsi='gcloud dns managed-zones create'            # gcdnsi: Create a new managed DNS zone.
  alias gcdnsk='gcloud dns dns-keys'                        # gcdnsk: List and manage DNSSEC keys for a zone.
  alias gcdnsl='gcloud dns record-sets list'                # gcdnsl: List record sets in a managed zone.
  alias gcdnsr='gcloud dns record-sets transaction start'   # gcdnsr: Start a transaction to add, update, or remove record sets.
  alias gcdnss='gcloud dns record-sets transaction execute' # gcdnss: Execute a transaction to add, update, or remove record sets.
  alias gcdnst='gcloud dns record-sets transaction abort'   # gcdnst: Abort a transaction to add, update, or remove record sets.

  # Functions
  alias gcf='gcloud functions' # gcf: A convenience command group for all functions-related commands.

  # Cloud Build

  alias gcb='gcloud builds'         # gcb: A convenience command group for all Cloud Build-related commands.
  alias gcbh='gcloud builds list'   # gcbh: List all builds in a project.
  alias gcbb='gcloud builds submit' # gcbb: Submit a build to Cloud Build.

  # Cloud Run

  alias gcr='gcloud run'           # gcr: A convenience command group for all Cloud Run-related commands.
  alias gcrd='gcloud run deploy'   # gcrd: Deploy a container to Cloud Run.
  alias gcrs='gcloud run services' # gcrs: List, describe, and manage services on Cloud Run.
  alias gcru='gcloud run update'   # gcru: Update an existing Cloud Run service.
  alias gcrf='gcloud run logs'     # gcrf: Display logs for a Cloud Run service.

  # Cloud Storage

  alias gcs='gsutil'           # gcs: A convenience command group for all Cloud Storage-related commands.
  alias gcsc='gsutil cp'       # gcsc: Copy files and objects to/from Cloud Storage.
  alias gcscp='gsutil -m cp'   # gcscp: Copy files and objects to/from Cloud Storage using parallel processing.
  alias gcsd='gsutil du'       # gcsd: Display the total size of a bucket or object.
  alias gcsl='gsutil ls'       # gcsl:List contents of a bucket or folder.
  alias gcspm='gsutil setmeta' # gcspm: Set metadata for objects in Cloud Storage.

  # BigQuery

  alias gcbq='bq'        # gcbq:  A convenience command group for all BigQuery-related commands.
  alias gcbql='bq ls'    # gcbql: List all datasets in a project.
  alias gcbqs='bq show'  # gcbqs: Show details about a specific dataset or table.
  alias gcbqd='bq rm'    # gcbqd: Delete a dataset or table.
  alias gcbqc='bq query' # gcbqc: Run a BigQuery SQL query.

  # Cloud SQL

  alias gcsql='gcloud sql'                     # gcsql: A convenience command group for all Cloud SQL-related commands.
  alias gcsqlc='gcloud sql connect'            # gcsqlc: Connect to a Cloud SQL instance.
  alias gcsqlc='gcloud sql instances create'   # gcsqlc: Create a new Cloud SQL instance.
  alias gcsqlr='gcloud sql instances describe' # gcsqlr: Describe a Cloud SQL instance.
  alias gcsqlu='gcloud sql users set-password' # gcsqlu: Update the password for a Cloud SQL user.

  # Pub/Sub

  alias gcps='gcloud pubsub'                # gcps: A convenience command group for all Pub/Sub-related commands.
  alias gcpsp='gcloud pubsub topics'        # gcpsp: List, create, and manage Pub/Sub topics.
  alias gcpss='gcloud pubsub subscriptions' # gcpss: List, create, and manage Pub/Sub subscriptions.
  alias gcpsp='gcloud pubsub publish'       # gcpsp: Publish a message to a Pub/Sub topic.

fi
