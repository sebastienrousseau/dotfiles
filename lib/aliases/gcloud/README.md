# Google Cloud Aliases

These aliases provide shortcuts for common Google Cloud commands. To use them, add the following lines to your `.bashrc` or `.bash_profile` file.

## Aliases

### Authenticate and authorize

- `gcaasa`: Like gcloud auth login but with service account credentials.
- `gcacd`: Configure Docker to use gcloud as a credential helper.
- `gcal`: List the accounts you are logged in with.
- `gcapat`: Print the access token for the current active account.
- `gcar`: Revoke credentials for the current active account.

### App Engine

- `gcapb`: Open the App Engine app in your default browser.
- `gcapc`: Create a new App Engine app.
- `gcapd`: Deploy an App Engine app.
- `gcapl`: Read the logs for an App Engine app.
- `gcapv`: List the versions of an App Engine app.

### Cloud SDK configuration and management

- `gccca`: Switch to an existing named configuration.
- `gcccc`: Create a new named configuration.
- `gcccl`: Display a list of all available configurations.
- `gccl`:Display all the properties for the current configuration.
- `gccgv`: Fetch value of a Cloud SDK property.
- `gccs`: Define a property (like compute/zone) for the current configuration.
- `gccsp`: Set a default Google Cloud project to work on.
- `gccu`: Update your Cloud SDK to the latest version.
- `gci`: Initialize, authorize, and configure the gcloud tool.
- `gcinf`: Display current gcloud tool environment details.
- `gciov`: Verify your email address for Google Cloud.

### Container

- `gcccc`: Create a cluster to run GKE containers.
- `gcccg`: Update kubeconfig to get kubectl to use a GKE cluster.
- `gcccl`: List clusters for running GKE containers.
- `gccil`: List tag and digest metadata for a container image.
- `gcd`: A convenience command group for all container-related commands.

### IAM

- `gciamk`: List a service account's keys.
- `gciaml`: List IAM grantable roles for a resource.
- `gciamp`: Add an IAM policy binding to a service account.
- `gciamr`: Create a custom role for a project or org
- `gciamd`: Delete a custom role for a project or org.
- `gciampd`: Remove an IAM policy binding from a service account.
- `gciamro`: Describe a custom role for a project or org.
- `gciamsp`: Replace the IAM policy of a service account.
- `gciamu`: Undelete a custom role for a project or org.
- `gciamup`: Update a service account.
- `gcimp`: List available Cloud Identity domains.
- `gcimpe`: Add an IAM policy binding to a Cloud Identity domain.
- `gcimpr`: Remove an IAM policy binding from a Cloud Identity domain.
- `gcsac`: Obtain an access token for the Google Cloud APIs.

### Compute

- `gcc`: A convenience command group for all compute-related commands.
- `gcpa`: Add an IAM policy binding to a specified project.
- `gcpc`: Copy files.
- `gcpd`: Display metadata for a project (including its ID).
- `gcpdown`: Stop instance.
- `gcpds`: Create snapshot of persistent disks.
- `gcpid`: Display a VM instance's details.
- `gcpil`: List all VM instances in a project.
- `gcprm`: Delete instance.
- `gcpsk`: Delete a snapshot.
- `gcpssh`: Connect to a VM instance by using SSH.
- `gcpup`: Start instance.
- `gcpzl`:List Compute Engine zones.

### Deployment Manager

- `gcdm`: A convenience command group for all deployment-manager-related commands.
- `gcdma`: Create a new deployment.
- `gcdmd`: Delete a deployment.
- `gcdmg`: Describe a deployment.
- `gcdml`: List all deployments.
- `gcdmu`: Update a deployment.

### DNS

- `gcdns`: A convenience command group for all dns-related commands.
- `gcdnsz`: List managed DNS zones.
- `gcdnsc`: List or apply DNS record sets changes.
- `gcdnsd`: Delete a managed DNS zone.
- `gcdnsi`: Create a new managed DNS zone.
- `gcdnsk`: List and manage DNSSEC keys for a zone.
- `gcdnsl`: List record sets in a managed zone.
- `gcdnsr`: Start a transaction to add, update, or remove record sets.
- `gcdnss`: Execute a transaction to add, update, or remove record sets.
- `gcdnst`: Abort a transaction to add, update, or remove record sets.

### Functions

- `gcf`: A convenience command group for all functions-related commands.

### Cloud Build

- `gcb`: A convenience command group for all Cloud Build-related commands.
- `gcbh`: List all builds in a project.
- `gcbb`: Submit a build to Cloud Build.

### Cloud Run

- `gcr`: A convenience command group for all Cloud Run-related commands.
- `gcrd`: Deploy a container to Cloud Run.
- `gcrs`: List, describe, and manage services on Cloud Run.
- `gcru`: Update an existing Cloud Run service.
- `gcrf`: Display logs for a Cloud Run service.

### Cloud Storage

- `gcs`: A convenience command group for all Cloud Storage-related commands.
- `gcsc`: Copy files and objects to/from Cloud Storage.
- `gcscp`: Copy files and objects to/from Cloud Storage using parallel processing.
- `gcsd`: Display the total size of a bucket or object.
- `gcsl`:List contents of a bucket or folder.
- `gcspm`: Set metadata for objects in Cloud Storage.

### BigQuery

- `gcbq`: A convenience command group for all BigQuery-related commands.
- `gcbql`: List all datasets in a project.
- `gcbqs`: Show details about a specific dataset or table.
- `gcbqd`: Delete a dataset or table.
- `gcbqc`: Run a BigQuery SQL query.

### Cloud SQL

- `gcsql`: A convenience command group for all Cloud SQL-related commands.
- `gcsqlc`: Connect to a Cloud SQL instance.
- `gcsqlc`: Create a new Cloud SQL instance.
- `gcsqlr`: Describe a Cloud SQL instance.
- `gcsqlu`: Update the password for a Cloud SQL user.

### Pub/Sub

- `gcps`: A convenience command group for all Pub/Sub-related commands.
- `gcpsp`: List, create, and manage Pub/Sub topics.
- `gcpss`: List, create, and manage Pub/Sub subscriptions.
- `gcpsp`: Publish a message to a Pub/Sub topic.
