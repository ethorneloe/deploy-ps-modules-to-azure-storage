[![Run Pester Tests](https://github.com/ethorneloe/deploy-ps-modules-to-azure-storage/actions/workflows/run-pester.yml/badge.svg)](https://github.com/ethorneloe/deploy-ps-modules-to-azure-storage/actions/workflows/run-pester.yml)

# deploy-ps-modules-to-azure-storage
# Overview
A GitHub composite action for deploying PowerShell modules within your repo into Azure storage as versioned zip files.

# Example
```yaml
with:
  storage-account-name: 'your storage account name'
```

# Use case
Changes to your custom script Powershell modules need to be deployed to an Azure storage blob container as .zip files based on the `ModuleVersion` set in the .psd1 files of the modules. For example, internally developed PowerShell modules that are required to be kept as internal or private repos, and these need to be available for use by other Azure resources such as Azure functions or container apps jobs on the same private vnet as the storage account.

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
  # exclude one rule 
  tenant-id: 'your-tenant-id'
```

## overwrite
An option to force files to be overwritten when they already exist in Azure storage.
```yaml
with:
  overwrite: true 
```
```yaml
with:
  overwrite: false
```

## repo-powershell-module-path
The path within your git repo containing the powershell module folder or folders.
```yaml
with:
  # Include one rule
  repo-powershell-module-path: 'your/path'
```
