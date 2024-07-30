[![PowerShell Composite Action CI](https://github.com/ethorneloe/deploy-ps-modules-to-azure-storage/actions/workflows/ci.yml/badge.svg)](https://github.com/ethorneloe/deploy-ps-modules-to-azure-storage/actions/workflows/ci.yml)

# deploy-ps-modules-to-azure-storage
# Overview
A GitHub composite action for deploying PowerShell modules within your repo into Azure storage as versioned zip files.

# Example
```yaml
name: Test Deployment

on:
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  deploy-powershell-modules:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Authenticate to Azure
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID}}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy PowerShell Modules to Azure Storage
        uses: ethorneloe/deploy-ps-modules-to-azure-storage@v1
        with:
          storage-account-name: ${{ secrets.AZURE_STORAGE_ACCOUNT_NAME }}
          storage-account-container-name: ${{ vars.AZURE_STORAGE_ACCOUNT_CONTAINER_NAME }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          module-source-path: "./powershell/modules"
```

# Use Case
Changes to your custom Powershell script modules need to be deployed to an Azure storage blob container as .zip files based on the `ModuleVersion` set in the .psd1 files of the modules. For example, internally developed PowerShell modules that are required to be kept as internal or private repos, and these need to be available for use by other Azure resources such as Azure functions or container apps jobs on the same private vnet as the storage account.  These resources can then pull down the versioned module using a managed identity and rbac.

# Requirements
- An Azure subscription with a storage account and blob container configured.
- An app registration or identity with write access to the blob container specified.
- One or more Powershell script modules contained in a directory within your repo. Currently only script modules that are defined as folders with .psm1 and .psd1 files are supported, and the .psd1 must use valid module manifest format. More info on manifest files can be found [here](https://learn.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest?view=powershell-7.4)
- Your GitHub workflow already contains the `actions/checkout` and `azure/login` steps as shown in the example.
- If you are using a storage account with private endpoint then make sure you configure your workflow to specify an appropriate runner or runner group.

# Inputs
## storage-account-name
Your Azure storage account name
```yaml
with:
  storage-account-name: 'your storage account name'
```

## storage-account-container-name
The storage account container name used for the upload.
```yaml
with:
  storage-account-container-name: 'your-container-name'
```

## tenant-id
Your Azure tenant id.
```yaml
with:
  tenant-id: 'your-tenant-id'
```

## overwrite
An option to force files to be overwritten when they already exist in Azure storage. If unspecified the default is false.
```yaml
with:
  overwrite: true
```
```yaml
with:
  overwrite: false
```

## module-source-path
The path within your git repo containing the powershell module folder or folders. If not specified, the default is the `github.workspace` context variable.
```yaml
with:
  module-source-path: 'your/path'
```