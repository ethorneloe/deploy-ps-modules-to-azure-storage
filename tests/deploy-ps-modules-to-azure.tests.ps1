BeforeAll {

    # Setup test environment
    $now = Get-Date
    $dateTimeString = $now.ToString("yyyy-MM-dd-HH-mm-ss-fff")
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
    $tempFolderName = "$($scriptNameWithoutExtension)_$($dateTimeString)"
    $tempBasePath = [System.IO.Path]::GetTempPath()
    $uniqueTempPath = [System.IO.Path]::Combine($tempBasePath, $tempFolderName)
    New-Item -Path $uniqueTempPath -type Directory | Out-Null

    # Create valid module folder
    $validModulePath = Join-Path -Path $testModulePath -ChildPath "ValidModule"
    New-Item -Path $validModulePath -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path -Path $validModulePath -ChildPath "ValidModule.psd1") -ItemType File -Force -Value "ModuleVersion = '1.1.0'" | Out-Null
    New-Item -Path (Join-Path -Path $validModulePath -ChildPath "ValidModule.psm1") -ItemType File -Force | Out-Null

    # Create module folder with only .psm1
    $onlyPsm1ModulePath = Join-Path -Path $testModulePath -ChildPath "OnlyPsm1Module"
    New-Item -Path $onlyPsm1ModulePath -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path -Path $onlyPsm1ModulePath -ChildPath "OnlyPsm1Module.psm1") -ItemType File -Force | Out-Null

    # Create module folder with only .psd1
    $onlyPsd1ModulePath = Join-Path -Path $testModulePath -ChildPath "OnlyPsd1Module"
    New-Item -Path $onlyPsd1ModulePath -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path -Path $onlyPsd1ModulePath -ChildPath "OnlyPsd1Module.psd1") -ItemType File -Force -Value "ModuleVersion = '1.1.0'" | Out-Null

    # Create invalid .psd1 file without ModuleVersion
    $invalidPsd1ModulePath = Join-Path -Path $testModulePath -ChildPath "InvalidPsd1Module"
    New-Item -Path $invalidPsd1ModulePath -ItemType Directory -Force | Out-Null
    New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psd1") -ItemType File -Force -Value "NoVersionInfo = '1.1.0'" | Out-Null
    New-Item -Path (Join-Path -Path $invalidPsd1ModulePath -ChildPath "InvalidPsd1Module.psm1") -ItemType File -Force | Out-Null
}

Describe "deploy-ps-modules-to-azure.ps1" {
    $params = @{
        moduleSourcePath            = $testModulePath
        outputPath                  = 'C:\temp\deploy-ps-modules-to-azure'
        storageAccountContainerName = 'psmodules'
        storageAccountName          = 'examplestorage'
        tenantId                    = 'your-tenant-id'
        overwrite                   = 'false'
    }

    BeforeEach {
        # Mocking commands to simulate their behavior without actual execution
        Mock -CommandName Write-Host
        Mock -CommandName New-Item
        Mock -CommandName Get-Content
        Mock -CommandName Select-String
        Mock -CommandName Compress-Archive
        Mock -CommandName azcopy
    }

    It "should set overwrite to false if null or empty" {
        $params.overwrite = ''
        .\scripts\deploy-ps-modules-to-azure.ps1 @params
        (Get-Variable overwrite -ValueOnly) | Should -Be 'false'
    }

    It "should throw an error if overwrite is not 'true' or 'false'" {
        $params.overwrite = 'invalid'
        { .\scripts\deploy-ps-modules-to-azure.ps1 @params } | Should -Throw "The overwrite input when set must be configured as 'true' or 'false' (default is 'false')"
    }

    It "should find only valid module folders with both .psd1 and .psm1 files" {
        .\scripts\deploy-ps-modules-to-azure.ps1 @params
        (Get-Variable moduleFolders -ValueOnly).Count | Should -Be 1
        (Get-Variable moduleFolders -ValueOnly)[0] | Should -Be $validModulePath
    }

    It "should skip folders with only .psm1 or only .psd1" {
        .\scripts\deploy-ps-modules-to-azure.ps1 @params
        (Get-Variable moduleFolders -ValueOnly).Count | Should -Be 1
        (Get-Variable moduleFolders -ValueOnly)[0] | Should -Be $validModulePath
    }

    It "should throw an error if no valid modules are found" {
        Remove-Item -Path "$testModulePath\ValidModule" -Recurse -Force
        { .\scripts\deploy-ps-modules-to-azure.ps1 @params } | Should -Throw "No valid powershell modules found in this repo. Module folders need to contain .psm1 and .psd1 files"
    }

    It "should read module version from .psd1 file and create zip archive" {
        .\scripts\deploy-ps-modules-to-azure.ps1 @params
        Assert-MockCalled -CommandName Compress-Archive -Exactly -Times 1
    }

    It "should configure and call azcopy to upload files" {
        .\scripts\deploy-ps-modules-to-azure.ps1 @params
        Assert-MockCalled -CommandName azcopy -Exactly -Times 1
        Assert-MockCalled -CommandName Compress-Archive -Exactly -Times 1
    }
}

AfterAll {
    Remove-Item -Path $uniqueTempPath -Recurse -Confirm:$false -Force -ErrorAction Stop
}
