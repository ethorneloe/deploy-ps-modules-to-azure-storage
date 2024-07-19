param (
    # The full path to the function we are testing
    [Parameter(Mandatory = $true)]
    [string]$functionFullName
)

$function = $functionFullName | get-item | Select-Object -ExpandProperty BaseName
$functionName = $function | Select-Object -ExpandProperty Name

BeforeAll {

    # Setup test environment
    $now = Get-Date
    $dateTimeString = $now.ToString("yyyy-MM-dd-HH-mm-ss-fff")
    $baseName = $function | Select-Object -ExpandProperty BaseName
    $tempFolderName = "$($baseName)_$($dateTimeString)"
    $tempBasePath = [System.IO.Path]::GetTempPath()
    $tempTestPath = [System.IO.Path]::Combine($tempBasePath, $tempFolderName)
    New-Item -Path $tempTestPath -type Directory | Out-Null
    $tempModuleSourcePath = "$tempTestPath\Modules"
    $tempOutputPath = "$tempTestPath\Output"
    New-item -Path $tempModuleSourcePath -type Directory | Out-Null
    New-item -Path $tempOutputPath -type Directory | Out-Null

    # Dot source in the function
    . $functionFullName

    # Params for the script executions
    $script:params = @{
        moduleSourcePath            = $tempModuleSourcePath
        outputPath                  = $tempOutputPath
        storageAccountContainerName = 'psmodules'
        storageAccountName          = 'examplestorage'
        tenantId                    = 'test'
        overwrite                   = $false
    }
}

Describe "Test Function $functionName" {

    BeforeEach {

        # Clear the temp test path containing the modules and archives created in each test
        if (Test-Path $tempModuleSourcePath ) { Get-ChildItem $tempModuleSourcePath | Remove-Item -Recurse -Force -Confirm:$false }
        if (Test-Path $tempOutputPath ) { Get-ChildItem $tempOutputPath | Remove-Item -Recurse -Force -Confirm:$false }
    }

    It "should throw an error if there are no valid module folders" {

        # Create module folder with only .psm1
        $onlyPsm1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "OnlyPsm1Module"
        New-Item -Path $onlyPsm1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $onlyPsm1ModulePath -ChildPath "OnlyPsm1Module.psm1") -ItemType File -Force | Out-Null

        { Deploy-PsModulesToAzure @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"

        # Create module folder with only .psd1
        $onlyPsd1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "OnlyPsd1Module"
        New-Item -Path $onlyPsd1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $onlyPsd1ModulePath -ChildPath "OnlyPsd1Module.psd1") -ItemType File -Force -Value "ModuleVersion = '1.1.0'" | Out-Null

        { Deploy-PsModulesToAzure @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"

        Remove-Item -Path "$tempModuleSourcePath/*" -Recurse -Force -Confirm:$false
        { Deploy-PsModulesToAzure @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"
    }

    It "should throw an error if a module does not contain a valid module version key/value pair in the .psd1 file" {

        # Create invalid .psd1 file without ModuleVersion
        $invalidPsd1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "InvalidPsd1Module"
        New-Item -Path $invalidPsd1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psd1") -ItemType File -Force -Value "NoVersionInfo = '1.1.0'" | Out-Null
        New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psm1") -ItemType File -Force | Out-Null

        { Deploy-PsModulesToAzure @params -WhatIf } | Should -Throw "Unable to complete deployment for module InvalidPsd1Module. ModuleVersion is not present or not set correctly in the .psd1 file.  Expected format is ModuleVersion = 'x.y.z'"
    }

    It "should read module version from .psd1 file and create zip archive" {

        if (Test-Path $tempModuleSourcePath ) { Get-ChildItem $tempModuleSourcePath | Remove-Item -Recurse -Force -Confirm:$false }
        if (Test-Path $tempOutputPath ) { Get-ChildItem $tempOutputPath | Remove-Item -Recurse -Force -Confirm:$false }

        #Create a valid module
        $validModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "ValidModule"
        New-Item -Path $validModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $validModulePath -ChildPath "ValidModule.psd1") -ItemType File -Force -Value "ModuleVersion = '1.1.0'" | Out-Null
        New-Item -Path (Join-Path -Path $validModulePath -ChildPath "ValidModule.psm1") -ItemType File -Force | Out-Null

        Deploy-PsModulesToAzure @params -WhatIf
        $zipFiles = Get-ChildItem -Path $tempOutputPath -recurse -Filter *.zip
        $zipFiles | Measure-Object | Select-Object -ExpandProperty Count | Should -BeGreaterThan 0
        foreach ($zipfile in $zipFiles) {
            $zipFile | Select-Object -ExpandProperty BaseName | Select-String -Pattern "\d+\.\d+\.\d+" | Should -Not -Be $null
        }
    }
}

AfterAll {
    Remove-Item -Path $tempTestPath -Recurse -Confirm:$false -Force -ErrorAction Stop
}
