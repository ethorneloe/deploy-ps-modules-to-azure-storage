
BeforeAll {

    # Get the main function name and the directory containing valid sample modules
    $parentDirectory = Join-Path $PSScriptRoot -ChildPath ".."
    $mainFunctionDirectory = Join-Path $parentDirectory -ChildPath "functions/main/"
    $mainFunction = Get-ChildItem -Path $mainFunctionDirectory -Filter "*.ps1"
    $mainFunctionName = $mainFunction | Select-Object -ExpandProperty Name
    $testModuleDirectory = Join-Path $parentDirectory -ChildPath "modules/"

    # Setup test environment
    $now = Get-Date
    $dateTimeString = $now.ToString("yyyy-MM-dd-HH-mm-ss-fff")
    $mainFunctionBaseName = $mainFunction | Select-Object -ExpandProperty BaseName
    $tempFolderName = "$($mainFunctionBaseName)_$($dateTimeString)"
    $tempBasePath = [System.IO.Path]::GetTempPath()
    $tempTestPath = [System.IO.Path]::Combine($tempBasePath, $tempFolderName)
    New-Item -Path $tempTestPath -type Directory | Out-Null
    $tempModuleSourcePath = "$tempTestPath\Modules"
    $tempOutputPath = "$tempTestPath\Output"
    New-item -Path $tempModuleSourcePath -type Directory | Out-Null
    New-item -Path $tempOutputPath -type Directory | Out-Null

    # Dot source in the function
    . $mainFunction.FullName

    # Params for the main function calls in each test
    $params = @{
        moduleSourcePath            = $tempModuleSourcePath
        outputPath                  = $tempOutputPath
        storageAccountContainerName = 'psmodules'
        storageAccountName          = 'examplestorage'
        tenantId                    = 'test'
        overwrite                   = $false
    }
}

Describe "Test Function $mainFunctionName" {

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

        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"

        # Create module folder with only .psd1
        $onlyPsd1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "OnlyPsd1Module"
        New-Item -Path $onlyPsd1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $onlyPsd1ModulePath -ChildPath "OnlyPsd1Module.psd1") -ItemType File -Force -Value "ModuleVersion = '1.1.0'" | Out-Null

        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"

        Remove-Item -Path "$tempModuleSourcePath/*" -Recurse -Force -Confirm:$false
        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"
    }

    It "should throw an error if a module does not contain a valid manifest file" {

        # Create invalid .psd1 file without ModuleVersion
        $invalidPsd1ModulePath = Join-Path -Path $tempModuleSourcePath -ChildPath "InvalidPsd1Module"
        New-Item -Path $invalidPsd1ModulePath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psd1") -ItemType File -Force -Value "NoVersionInfo = '1.1.0'" | Out-Null
        New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psm1") -ItemType File -Force | Out-Null

        { & $mainFunctionBaseName @params -WhatIf } | Should -Throw
    }

    It "should read module version from .psd1 file and create zip archive" {

        $params['moduleSourcePath'] = $testModuleDirectory

        & $mainFunctionBaseName @params -WhatIf
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
