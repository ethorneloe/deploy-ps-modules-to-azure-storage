[![Run Pester Tests](https://github.com/ethorneloe/deploy-ps-modules-to-azure-storage/actions/workflows/run-pester.yml/badge.svg)](https://github.com/ethorneloe/deploy-ps-modules-to-azure-storage/actions/workflows/run-pester.yml)

# deploy-ps-modules-to-azure-storage
## Overview
A composite action for deploying the script PowerShell modules (.psm1, .psd1) within your repo into Azure storage as versioned zip files.

## Use case
Changes to your custom script Powershell modules need to be deployed to an Azure storage blob container as .zip files based on the `ModuleVersion` set in the .psd1 files of the modules. For example, internally developed PowerShell modules that are required to be kept as internal or private repos, and these need to be available for use by other Azure resources such as Azure functions or container apps jobs on the same private vnet as the storage account.
