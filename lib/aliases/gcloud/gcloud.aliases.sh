#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT
# Script: gcloud.aliases.sh
# Version: 0.2.470
# Website: https://dotfiles.io

# 🅶🅲🅻🅾🆄🅳 🅰🅻🅸🅰🆂🅴🆂 - Google Cloud aliases.
if command -v gcloud &>/dev/null; then
  # Sections:
  #
  #      1.0 Google Cloud Aliases.
  #      1.1 Aliases to get going with the gcloud command-line tool.
  #      1.2 Aliases to make the Cloud SDK your own; personalize your
  #          configuration with properties.
  #      1.3 Aliases to grant and revoke authorization to Cloud SDK.
  #      1.4 Aliases to configuring Cloud Identity & Access Management
  #          (IAM) preferences and service accounts.
  #      1.5 Aliases to manage project access policies.
  #      1.6 Aliases to manage containerized applications on Kubernetes.
  #      1.7 Aliases to create, run, and manage VMs on Google
  #          infrastructure.
  #      1.8 Aliases to build highly scalable applications on a fully
  #          managed serverless platform.
  #      1.9 Aliases to commands that might come in handy.
  #      1.10 Additional Google Cloud Aliases.

  ##  ------------------------------------------------------------------
  ##  1.0 Google Cloud Aliases
  ##  ------------------------------------------------------------------
  ##  ------------------------------------------------------------------
  ##  1.1 Aliases to get going with the gcloud command-line tool.
  ##  ------------------------------------------------------------------

  # Install specific components.
  alias gcci='gcloud components install'

  # Set a default Google Cloud project to work on.
  alias gccsp='gcloud config set project'

  # Update your Cloud SDK to the latest version.
  alias gccu='gcloud components update'

  # Initialize, authorize, and configure the gcloud tool.
  alias gci='gcloud init'

  # Display current gcloud tool environment details.
  alias gcinf='gcloud info'

  # Display version and installed components.
  alias gcv='gcloud version'

  ##  ------------------------------------------------------------------
  ##  1.2 Aliases to make the Cloud SDK your own; personalize your
  ##      configuration with properties.
  ##  ------------------------------------------------------------------

  # Switch to an existing named configuration.
  alias gccca='gcloud config configurations activate'

  # Create a new named configuration.
  alias gcccc='gcloud config configurations create'

  # Display a list of all available configurations.
  alias gcccl='gcloud config configurations list'

  # Fetch value of a Cloud SDK property.
  alias gccgv='gcloud config get-value'

  # Display all the properties for the current configuration.
  alias gccl='gcloud config list'

  # Define a property (like compute/zone) for the current configuration.
  alias gccs='gcloud config set'

  ##  ------------------------------------------------------------------
  ##  1.3 Aliases to grant and revoke authorization to Cloud SDK
  ##  ------------------------------------------------------------------

  # Like gcloud auth login but with service account credentials.
  alias gcaasa='gcloud auth activate-service-account'

  # Register the gcloud tool as a Docker credential helper.
  alias gcacd='gcloud auth configure-docker'

  # List all credentialed accounts.
  alias gcal='gcloud auth list'

  # Authorize Google Cloud access for the gcloud tool with Google user
  # credentials and set current account as active.
  alias gcal='gcloud auth login'

  # Display the current account's access token.
  alias gcapat='gcloud auth print-access-token'

  # Remove access credentials for an account.
  alias gcar='gcloud auth revoke'

  ##  ------------------------------------------------------------------
  ##  1.4 Aliases to configuring Cloud Identity & Access Management
  ##      (IAM) preferences and service accounts.
  ##  ------------------------------------------------------------------

  # List a service account's keys.
  alias gciamk='gcloud iam service-accounts keys list'

  # List IAM grantable roles for a resource.
  alias gciaml='gcloud iam list-grantable-roles'

  # Add an IAM policy binding to a service account.
  alias gciamp='gcloud iam service-accounts add-iam-policy-binding'

  # Create a custom role for a project or org.
  alias gciamr='gcloud iam roles create'

  # Replace existing IAM policy binding.
  alias gciams='gcloud iam service-accounts set-iam-policy'

  # Create a service account for a project.
  alias gciamv='gcloud iam service-accounts create'

  ##  ------------------------------------------------------------------
  ##  1.5 Aliases to manage project access policies
  ##  ------------------------------------------------------------------

  # Add an IAM policy binding to a specified project.
  alias gcpa='gcloud projects add-iam-policy-binding'

  # Display metadata for a project (including its ID).
  alias gcpd='gcloud projects describe'

  ## -------------------------------------------------------------------
  ## 1.6 Aliases to manage containerized applications on Kubernetes
  ## -------------------------------------------------------------------

  # Create a cluster to run GKE containers.
  alias gcccc='gcloud container clusters create'

  # Update kubeconfig to get kubectl to use a GKE cluster.
  alias gcccg='gcloud container clusters get-credentials'

  # List clusters for running GKE containers.
  alias gcccl='gcloud container clusters list'

  # List tag and digest metadata for a container image.
  alias gccil='gcloud container images list-tags'

  ## -------------------------------------------------------------------
  ## 1.7 Aliases to create, run, and manage VMs on
  ##     Google infrastructure.
  ## -------------------------------------------------------------------

  # Copy files
  alias gcpc='gcloud compute copy-files'

  # Stop instance
  alias gcpdown='gcloud compute instances stop'

  # Create snapshot of persistent disks.
  alias gcpds='gcloud compute disks snapshot'

  # Display a VM instance's details.
  alias gcpid='gcloud compute instances describe'

  # List all VM instances in a project.
  alias gcpil='gcloud compute instances list'

  # Delete instance
  alias gcprm='gcloud compute instances delete'

  # Delete a snapshot.
  alias gcpsk='gcloud compute snapshots delete'

  # Connect to a VM instance by using SSH.
  alias gcpssh='gcloud compute ssh'

  # Start instance.
  alias gcpup='gcloud compute instances start'

  # List Compute Engine zones.
  alias gcpzl='gcloud compute zones list'

  ## -------------------------------------------------------------------
  ## 1.8 Aliases to build highly scalable applications on a fully
  ##     managed serverless platform.
  ## -------------------------------------------------------------------

  # Open the current app in a web browser.
  alias gcapb='gcloud app browse'

  # Create an App Engine app within your current project.
  alias gcapc='gcloud app create'

  # Deploy your app's code and configuration to the App Engine server.
  alias gcapd='gcloud app deploy'

  # Display the latest App Engine app logs.
  alias gcapl='gcloud app logs read'

  # List all versions of all services deployed to the App Engine server.
  alias gcapv='gcloud app versions list'

  ## -------------------------------------------------------------------
  ## 1.9 Aliases to commands that might come in handy
  ## -------------------------------------------------------------------

  # Decrypt ciphertext (to a plaintext file) using a Cloud Key
  # Management Service (Cloud KMS) key.
  alias gckmsd='gcloud kms decrypt'

  # List your project's logs.
  alias gclll='gcloud logging logs list'

  # Display info about a Cloud SQL instance backup.
  alias gcsqlb='gcloud sql backups describe'

  # Export data from a Cloud SQL instance to a SQL file.
  alias gcsqle='gcloud sql export sql'

  ## -------------------------------------------------------------------
  ## 1.10 Aliases to commands that might come in handy
  ## -------------------------------------------------------------------

  # Authenticate with Google Cloud.
  alias gca='gcloud auth'

  # Access to beta commands.
  alias gcb='gcloud beta'

  # Manage Google Cloud Build.
  alias gcb='gcloud builds'

  # Manage Compute Engine IP addresses.
  alias gcca='gcloud compute addresses'

  # Create a new virtual machine instance.
  alias gccc='gcloud compute instances create'

  # Connect to a virtual machine instance by using SSH.
  alias gcco='gcloud compute ssh'

  # Set default project to current directory name.
  alias gcd='gcloud config set project $(gcloud projects list --format="value(projectId)" --filter="name:${PWD##\*/}")'

  # Manage Google Cloud Datastore.
  alias gcdb='gcloud datastore'

  # Manage Google Cloud Dataproc.
  alias gcdp='gcloud dataproc'

  # Manage Google Cloud Endpoints.
  alias gce='gcloud endpoints'

  # Manage Google Cloud Eventarc.
  alias gcem='gcloud eventarc'

  # Manage Google Cloud Functions.
  alias gcf='gcloud functions'

  # Manage Google Cloud Compute Engine instances.
  alias gci='gcloud compute instances'

  # Manage Google Cloud Identity and Access Management.
  alias gcic='gcloud iam'

  # Manage Google Cloud IoT Core.
  alias gcir='gcloud iot'

  # List all configurations.
  alias gck='gcloud config configurations list'

  # Manage Google Cloud KMS.
  alias gcki='gcloud kms'

  # Manage Google Cloud Logging.
  alias gcla='gcloud logging'

  # Manage Google Cloud Monitoring.
  alias gcma='gcloud monitoring'

  # Manage Google Cloud Networks.
  alias gcn='gcloud networks'

  # Manage Google Cloud projects.
  alias gcp='gcloud projects'

  # Delete a Google Cloud project.
  alias gcpd='gcloud projects delete'

  # Display details for a Compute Engine IP address.
  alias gcpha='gcloud compute addresses describe'

  # Manage Google Cloud Pub/Sub.
  alias gcps='gcloud pubsub'

  # Delete a container image from Google Container Registry
  alias gcr='gcloud container images delete'

  # Manage Google Cloud resources.
  alias gcrm='gcloud resource-manager'

  # Manage Google Cloud Run.
  alias gcro='gcloud run'

  # Manage Google Cloud Kubernetes Engine clusters.
  alias gcs='gcloud container clusters'

  # Set the account for the current configuration.
  alias gcsa='gcloud config set account'

  # Manage Google Cloud Source Repositories.
  alias gcsc='gcloud source'

  # Open the Google Cloud Console for the current project.
  alias gcso='gcloud organizations'

  # Manage Google Cloud SQL.
  alias gcsq='gcloud sql'

  # Manage Google Cloud Storage.
  alias gcss='gcloud storage'

  # Enable or disable Google Cloud services.
  alias gcst='gcloud services'

  # Manage Google Cloud Tasks.
  alias gct='gcloud tasks'

  # Manage Google Cloud App Engine.
  alias gcu='gcloud app'

fi
