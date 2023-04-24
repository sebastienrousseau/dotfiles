#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.465) - https://dotfiles.io
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

# 🅶🅲🅻🅾🆄🅳 🅰🅻🅸🅰🆂🅴🆂 - Google Cloud aliases.
if command -v gcloud &>/dev/null; then
  # Sections:
  #
  #      1.0 Google Cloud Aliases.
  #      1.1 Aliases to get going with the gcloud command-line tool.
  #      1.2 Aliases to make the Cloud SDK your own; personalize your configuration with properties.
  #      1.3 Aliases to grant and revoke authorization to Cloud SDK.
  #      1.4 Aliases to configuring Cloud Identity & Access Management (IAM) preferences and service accounts.
  #      1.5 Aliases to manage project access policies.
  #      1.6 Aliases to manage containerized applications on Kubernetes.
  #      1.7 Aliases to create, run, and manage VMs on Google infrastructure.
  #      1.8 Aliases to build highly scalable applications on a fully managed serverless platform.
  #      1.9 Aliases to commands that might come in handy.
  #      1.10 Additional Google Cloud Aliases.

  ##  ------------------------------------------------------------------
  ##  1.0 Google Cloud Aliases
  ##  ------------------------------------------------------------------
  ##  ------------------------------------------------------------------
  ##  1.1 Aliases to get going with the gcloud command-line tool.
  ##  ----------------------------------------------------------------------------

  alias gcci='gcloud components install'  # Install specific components.
  alias gccsp='gcloud config set project' # Set a default Google Cloud project to work on.
  alias gccu='gcloud components update'   # Update your Cloud SDK to the latest version.
  alias gci='gcloud init'                 # Initialize, authorize, and configure the gcloud tool.
  alias gcinf='gcloud info'               # Display current gcloud tool environment details.
  alias gcv='gcloud version'              # Display version and installed components.

  ##  ----------------------------------------------------------------------------
  ##  1.2 Aliases to make the Cloud SDK your own; personalize your configuration with properties.
  ##  ----------------------------------------------------------------------------

  alias gccca='gcloud config configurations activate' # Switch to an existing named configuration.
  alias gcccc='gcloud config configurations create'   # Create a new named configuration.
  alias gcccl='gcloud config configurations list'     # Display a list of all available configurations.
  alias gccgv='gcloud config get-value'               # Fetch value of a Cloud SDK property.
  alias gccl='gcloud config list'                     # Display all the properties for the current configuration.
  alias gccs='gcloud config set'                      # Define a property (like compute/zone) for the current configuration.

  ##  ------------------------------------------------------------------
  ##  1.3 Aliases to grant and revoke authorization to Cloud SDK
  ##  ------------------------------------------------------------------

  alias gcaasa='gcloud auth activate-service-account' # Like gcloud auth login but with service account credentials.
  alias gcacd='gcloud auth configure-docker'          # Register the gcloud tool as a Docker credential helper.
  alias gcal='gcloud auth list'                       # List all credentialed accounts.
  alias gcal='gcloud auth login'                      # Authorize Google Cloud access for the gcloud tool with Google user credentials and set current account as active.
  alias gcapat='gcloud auth print-access-token'       # Display the current account's access token.
  alias gcar='gcloud auth revoke'                     # Remove access credentials for an account.

  ##  ----------------------------------------------------------------------------
  ##  1.4 Aliases to configuring Cloud Identity & Access Management (IAM) preferences and service accounts.
  ##  ----------------------------------------------------------------------------

  alias gciamk='gcloud iam service-accounts keys list'              # List a service account's keys.
  alias gciaml='gcloud iam list-grantable-roles'                    # List IAM grantable roles for a resource.
  alias gciamp='gcloud iam service-accounts add-iam-policy-binding' # Add an IAM policy binding to a service account.
  alias gciamr='gcloud iam roles create'                            # Create a custom role for a project or org.
  alias gciams='gcloud iam service-accounts set-iam-policy'         # Replace existing IAM policy binding.
  alias gciamv='gcloud iam service-accounts create'                 # Create a service account for a project.

  ##  ------------------------------------------------------------------
  ##  1.5 Aliases to manage project access policies
  ##  ------------------------------------------------------------------

  alias gcpa='gcloud projects add-iam-policy-binding' # Add an IAM policy binding to a specified project.
  alias gcpd='gcloud projects describe'               # Display metadata for a project (including its ID).

  ## -------------------------------------------------------------------
  ## 1.6 Aliases to manage containerized applications on Kubernetes
  ## -------------------------------------------------------------------

  alias gcccc='gcloud container clusters create'          # Create a cluster to run GKE containers.
  alias gcccg='gcloud container clusters get-credentials' # Update kubeconfig to get kubectl to use a GKE cluster.
  alias gcccl='gcloud container clusters list'            # List clusters for running GKE containers.
  alias gccil='gcloud container images list-tags'         # List tag and digest metadata for a container image.

  ## ----------------------------------------------------------------------------
  ## 1.7 Aliases to create, run, and manage VMs on Google infrastructure.
  ## ----------------------------------------------------------------------------

  alias gcpc='gcloud compute copy-files'          # Copy files
  alias gcpdown='gcloud compute instances stop'   # Stop instance
  alias gcpds='gcloud compute disks snapshot'     # Create snapshot of persistent disks.
  alias gcpid='gcloud compute instances describe' # Display a VM instance's details.
  alias gcpil='gcloud compute instances list'     # List all VM instances in a project.
  alias gcprm='gcloud compute instances delete'   # Delete instance
  alias gcpsk='gcloud compute snapshots delete'   # Delete a snapshot.
  alias gcpssh='gcloud compute ssh'               # Connect to a VM instance by using SSH.
  alias gcpup='gcloud compute instances start'    # Start instance.
  alias gcpzl='gcloud compute zones list'         # List Compute Engine zones.

  ## ----------------------------------------------------------------------------
  ## 1.8 Aliases to build highly scalable applications on a fully managed serverless platform.
  ## ----------------------------------------------------------------------------

  alias gcapb='gcloud app browse'        # Open the current app in a web browser.
  alias gcapc='gcloud app create'        # Create an App Engine app within your current project.
  alias gcapd='gcloud app deploy'        # Deploy your app's code and configuration to the App Engine server.
  alias gcapl='gcloud app logs read'     # Display the latest App Engine app logs.
  alias gcapv='gcloud app versions list' # List all versions of all services deployed to the App Engine server.

  ## -------------------------------------------------------------------
  ## 1.9 Aliases to commands that might come in handy
  ## -------------------------------------------------------------------

  alias gckmsd='gcloud kms decrypt'          # Decrypt ciphertext (to a plaintext file) using a Cloud Key Management Service (Cloud KMS) key.
  alias gclll='gcloud logging logs list'     # List your project's logs.
  alias gcsqlb='gcloud sql backups describe' # Display info about a Cloud SQL instance backup.
  alias gcsqle='gcloud sql export sql'       # Export data from a Cloud SQL instance to a SQL file.

  ## -------------------------------------------------------------------
  ## 1.10 Aliases to commands that might come in handy
  ## -------------------------------------------------------------------

  alias gca='gcloud auth'                                                                                              # Authenticate with Google Cloud.
  alias gcb='gcloud beta'                                                                                              # Access to beta commands.
  alias gcb='gcloud builds'                                                                                            # Manage Google Cloud Build.
  alias gcca='gcloud compute addresses'                                                                                # Manage Compute Engine IP addresses.
  alias gccc='gcloud compute instances create'                                                                         # Create a new virtual machine instance.
  alias gcco='gcloud compute ssh'                                                                                      # Connect to a virtual machine instance by using SSH.
  alias gcd='gcloud config set project $(gcloud projects list --format="value(projectId)" --filter="name:${PWD##*/}")' # Set default project to current directory name.
  alias gcdb='gcloud datastore'                                                                                        # Manage Google Cloud Datastore.
  alias gcdp='gcloud dataproc'                                                                                         # Manage Google Cloud Dataproc.
  alias gce='gcloud endpoints'                                                                                         # Manage Google Cloud Endpoints.
  alias gcem='gcloud eventarc'                                                                                         # Manage Google Cloud Eventarc.
  alias gcf='gcloud functions'                                                                                         # Manage Google Cloud Functions.
  alias gci='gcloud compute instances'                                                                                 # Manage Google Cloud Compute Engine instances.
  alias gcic='gcloud iam'                                                                                              # Manage Google Cloud Identity and Access Management.
  alias gcir='gcloud iot'                                                                                              # Manage Google Cloud IoT Core.
  alias gck='gcloud config configurations list'                                                                        # List all configurations.
  alias gcki='gcloud kms'                                                                                              # Manage Google Cloud KMS.
  alias gcla='gcloud logging'                                                                                          # Manage Google Cloud Logging.
  alias gcma='gcloud monitoring'                                                                                       # Manage Google Cloud Monitoring.
  alias gcn='gcloud networks'                                                                                          # Manage Google Cloud Networks.
  alias gcp='gcloud projects'                                                                                          # Manage Google Cloud projects.
  alias gcpd='gcloud projects delete'                                                                                  # Delete a Google Cloud project.
  alias gcpha='gcloud compute addresses describe'                                                                      # Display details for a Compute Engine IP address.
  alias gcps='gcloud pubsub'                                                                                           # Manage Google Cloud Pub/Sub.
  alias gcr='gcloud container images delete'                                                                           # Delete a container image from Google Container Registry
  alias gcrm='gcloud resource-manager'                                                                                 # Manage Google Cloud resources.
  alias gcro='gcloud run'                                                                                              # Manage Google Cloud Run.
  alias gcs='gcloud container clusters'                                                                                # Manage Google Cloud Kubernetes Engine clusters.
  alias gcsa='gcloud config set account'                                                                               # Set the account for the current configuration.
  alias gcsc='gcloud source'                                                                                           # Manage Google Cloud Source Repositories.
  alias gcso='gcloud organizations'                                                                                    # Open the Google Cloud Console for the current project.
  alias gcsq='gcloud sql'                                                                                              # Manage Google Cloud SQL.
  alias gcss='gcloud storage'                                                                                          # Manage Google Cloud Storage.
  alias gcst='gcloud services'                                                                                         # Enable or disable Google Cloud services.
  alias gct='gcloud tasks'                                                                                             # Manage Google Cloud Tasks.
  alias gcu='gcloud app'                                                                                               # Manage Google Cloud App Engine.

fi
