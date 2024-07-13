<#
.SYNOPSIS
    Deploys PowerShell modules as zip files to Azure Storage.

.DESCRIPTION
    This script zips each PowerShell module located in a specified repository path,
    then uploads the zip files to a specified Azure Storage container. It checks each module
    for valid .psd1 and .psm1 files and reads version information from the .psd1 file for naming the zip files.

.PARAMETER sourcePath
    Path within the Git repository containing the PowerShell module folders.

.PARAMETER storageAccountContainerName
    Name of the Azure Storage container where the zipped modules will be stored.

.PARAMETER storageAccountName
    Name of the Azure Storage account.

.PARAMETER tenantId
    Azure tenant ID used for AzCopy authentication.

.PARAMETER overwrite
    Specifies whether to overwrite existing files in Azure Storage. Accepted values: 'true', 'false'.

.EXAMPLE
    .\deploy-ps-modules-to-azure.ps1 -sourcePath './modules' -storageAccountContainerName 'psmodules' -storageAccountName 'examplestorage' -tenantId 'your-tenant-id' -overwrite 'false'
    Deploys all PowerShell modules from the './modules' directory to the 'psmodules' container in the 'examplestorage' Azure Storage account.

.NOTES
    Ensure that Azure CLI and AzCopy are present.

    This script is intended to be used as part of a GitHub composite action.  It is designed to execute after the actions/checkout and azure/login
    GitHub actions have been executed as it leverages the repo structure and the existing Azure CLI logon context.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$sourcePath,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountContainerName,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$tenantId,

    [Parameter(Mandatory = $false)]
    [string]$overwrite = 'false'
)

Write-Output "Using module source path: $sourcePath"

# Check the overwrite param for true/false and set to false if null or empty
if ([string]::IsNullOrEmpty($overwrite)) { $overwrite = 'false' }
$overwrite = ($overwrite.toLower()).trim()
if ( ($overwrite -ne 'true') -and ($overwrite -ne 'false') ) {
    throw "The overwrite input when set must be configured as 'true' or 'false' (default is 'false')"
}

# Initialize an ArrayList to store module folders
$moduleFolders = [System.Collections.ArrayList]@()

# Get all directories recursively
$directories = Get-ChildItem -Path $sourcePath -Directory -Recurse

# Check for folders that contain .psd1 and .psm1 files as a basic module check
foreach ($directory in $directories) {

    $psd1File = Get-ChildItem -Path $directory.FullName -Filter *.psd1 -ErrorAction SilentlyContinue
    $psm1File = Get-ChildItem -Path $directory.FullName -Filter *.psm1 -ErrorAction SilentlyContinue

    if ($psd1File -and $psm1File) {
        # Add the directory to the ArrayList
        [void]$moduleFolders.Add($directory.FullName)
    }
}

if ($moduleFolders.count -eq 0) {
    throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"
}

Write-Output "Found module folders:"
Write-Output $moduleFolders

# Configure a unique temp directory for holding zip files
$now = Get-Date
$dateTimeString = $now.ToString("yyyy-MM-dd-HH-mm-ss-fff")
$scriptPath = $MyInvocation.MyCommand.Path
$scriptNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
$tempFolderName = "$($scriptNameWithoutExtension)_$($dateTimeString)"
$tempBasePath = [System.IO.Path]::GetTempPath()
$uniqueTempPath = [System.IO.Path]::Combine($tempBasePath, $tempFolderName)

Write-Output "Using temp path: $uniqueTempPath"

New-Item -Path $uniqueTempPath -type Directory | Out-Null

# Check each module for a .psd1 file that contains a version number and if so versioned zip to temp path
foreach ($moduleFolder in $moduleFolders) {
    try {

        # Find the .psd1 file in the module directory.
        $psd1File = Get-ChildItem -Path $moduleFolder | Where-Object { $_.extension -eq '.psd1' }
        if ($null -eq $psd1File) {
            throw "No .psd1 file found in $module"
        }

        # Read the module version from the .psd1 file. Fail here if not found.
        $content = Get-Content -Path $psd1File.FullName
        $versionLine = $content | Select-String -Pattern "ModuleVersion\s*=\s*'(\d+\.\d+\.\d+)'"
        if ($null -eq $versionLine) {
            throw "ModuleVersion is not present or not set correctly in $($psd1File.FullName).  Expected format is ModuleVersion = x.y.z"
        }

        # Extract the version number from the psd1 file
        $moduleVersion = $versionLine.Matches.Groups[1].Value.Trim()

        # Configure filenames and paths for compression
        $moduleName = $psd1File.BaseName
        $zipFileName = "$moduleName-v$moduleVersion.zip"
        $zipFilePath = "$uniqueTempPath/$zipFileName"

        Write-Output "Found $moduleName version $moduleVersion"

        Write-Output "Creating zip archive: $zipFilePath"

        # Create zip archive in temp folder
        Compress-Archive -Path "$moduleFolder/*" -DestinationPath $zipFilePath -Force
    }
    catch {
        throw "Unable to complete deployment for module $moduleName - $_"
    }
}

# Copy the versioned zip files to Azure
Write-Output "Copying zip acrhives from $uniqueTempPath to Azure storage"
$Env:AZCOPY_AUTO_LOGIN_TYPE = "AZCLI"
$Env:AZCOPY_TENANT_ID = $tenantId
azcopy copy $uniqueTempPath "https://$storageAccountName.blob.core.windows.net/$storageAccountContainerName" --overwrite=false --recursive=true

# Clean up the temp folder
Write-Output "Deleting $uniqueTempPath"
Remove-Item -Path $uniqueTempPath -Recurse -Confirm:$false -Force
