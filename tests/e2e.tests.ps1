[cmdletbinding()]
param()

function Get-ScriptDirectory
{
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
}

$scriptDir = ((Get-ScriptDirectory) + "\")
$moduleName = 'nuget-powershell'
$modulePath = (Join-Path $scriptDir ('..\{0}.psm1' -f $moduleName))

$env:IsDeveloperMachine = $true

if(Test-Path $modulePath){
    'Importing module from [{0}]' -f $modulePath | Write-Verbose

    if((Get-Module $moduleName)){ Remove-Module $moduleName -Force }
    
    Import-Module $modulePath -PassThru -DisableNameChecking -Force | Out-Null
}
else{
    throw ('Unable to find module at [{0}]' -f $modulePath )
}

Describe 'get-nuget tests' {   
    It 'Returns path' {
        $nugetPath = (Get-Nuget)
        $nugetPath | Should exist
    }
     
    It 'Can use specified url' {
        $nugetPath = (Get-Nuget)
        Remove-Item $nugetPath | out-null
        $nugetPath = (Get-Nuget -nugetDownloadUrl http://staging.nuget.org/nuget.exe)
        $nugetPath | Should Exist
    }

    It 'Can use custom tools folder' {
        $newToolsDir = (join-path $TestDrive 'get-nuget\custom-tools\')
        $nugetPath = (Get-Nuget -toolsDir $newToolsDir)
        $nugetPath | Should Exist
    }
}

Describe 'update-nuget tests'{
    It 'Returns path' {
        $nugetPath = (Update-NuGet)
        $nugetPath | Should Exist
    }
}

Describe 'get-nugetpackage tests' {
    $oldToolsDir = $Global:NuGetPowerShellSettings.toolsDir
    $newToolsDir = (Join-Path $TestDrive 'get-nupkg\newtools\')
    if(!(Test-Path $newToolsDir)){
        New-Item $newToolsDir -ItemType Directory | out-null
    }
    $newToolsDir = ((Get-Item $newToolsDir).FullName)
    $Global:NuGetPowerShellSettings.toolsDir = $newToolsDir

    BeforeEach {
        if(Test-Path $newToolsDir){
            Remove-Item $newToolsDir -Recurse -Force -ErrorAction SilentlyContinue | out-null
        }
    }

    It 'Returns path' {
        $pkgPath = (Get-NuGetPackage -name psbuild)
        $pkgPath | Should Exist
    }

    It 'Folder contains .nupkg file'{
        $pkgPath = (Get-NuGetPackage -name psbuild -prerelease)
        [System.IO.FileInfo]$result=(Get-ChildItem $pkgPath psbuild*.nupkg)
        $result | Should Not Be $null
        $result.Exists | Should Be $true
    }

    It 'Can use specified url' {
        $tempDir = (join-path $TestDrive 'nugetrepo01\')
        mkdir $tempDir
        $tempDir = ((Get-Item $tempDir).FullName)

        # get a nuget pkg
        $pkgPath = (Get-NuGetPackage -name psbuild)
        Get-ChildItem $pkgPath *.nupkg | % {Copy-Item $_.FullName -Destination $tempDir}

       'files:'|Write-host
        get-childitem $tempDir * -Recurse | Write-Host

        $newPkgPath = (Get-NuGetPackage -name psbuild -nugetUrl "$tempDir")
        $newPkgPath | Should Exist
    }

    It 'Returns path when already downloaded' {
        $pkgPath = (Get-NuGetPackage -name psbuild)
        $pkgPath | Should Exist
        $pkgPath = (Get-NuGetPackage -name psbuild)
        $pkgPath | Should Exist
    }

    It 'Can pass in a specific version' {
        $pkgPath = (Get-NuGetPackage -name psbuild -version 0.0.1)
        $pkgPath | Should Exist
    }

    It 'Can pass in prerelase' {
        $pkgPath = (Get-NuGetPackage -name psbuild -prerelease)
        $pkgPath | Should Exist
    }

    It 'Can pass in force without passing version' {
        $pkgPath = (Get-NuGetPackage -name psbuild -force)
        $pkgPath | Should Exist
    }

    It 'Can pass in force with passing version' {
        $pkgPath = (Get-NuGetPackage -name psbuild -version 0.0.1 -force)
        $pkgPath | Should Exist
    }

    $Global:NuGetPowerShellSettings.toolsDir = $oldToolsDir
}

Describe 'Load-ModuleFromNuGetPackage tests'{
    It 'Can load module1' {
        if(Get-Module publish-module){
            Remove-Module publish-module -force
        }
        Load-ModuleFromNuGetPackage -name publish-module -prerelease
        $result = (Get-Module publish-module)
        [string]::IsNullOrWhiteSpace($result) | Should Be $false

        if(Get-Module publish-module){
            Remove-Module publish-module -force
        }
    }
}