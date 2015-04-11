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
        $nugetPath = (Get-Nuget -nugetDownloadUrl http://nuget.org/nuget.exe)
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
        $pkgPath1 = (Get-NuGetPackage -name publish-module -prerelease -noexpansion)
        $pkgPath1 | Should Exist
    }

    
    It 'Folder contains .nupkg file'{
        $nugetPkgInstallPath1 = (Get-NuGetPackage -name publish-module -prerelease -noexpansion)

        $items = (Get-ChildItem -Path $nugetPkgInstallPath1 * -Recurse)
        'files'|Write-Host 
        Get-ChildItem -Path $nugetPkgInstallPath1 * -Recurse| % {$_.FullName | Write-Host}
        #'files: [{0}]' -f (Get-ChildItem -Path $pkgPath * -Recurse) | Write-Host
        [System.IO.FileInfo]$result=(Get-ChildItem $nugetPkgInstallPath1 *.nupkg)
        $result | Should Not Be $null
        $result.Exists | Should Be $true
    }
    
    <#
    It 'Can use specified url' {
        $repodir = (join-path $TestDrive 'nugetrepo01\')
        mkdir $repodir
        $repodir = ((Get-Item $repodir).FullName)

        # get a nuget pkg
        $nupkgPath = (Get-NuGetPackage -name publish-module -prerelease)
        Get-ChildItem $nupkgPath *.nupkg | % {Copy-Item $_.FullName -Destination $repodir}

       'files:'|Write-host
        get-childitem $repodir * -Recurse | Write-Host

        $newPkgPath = (Get-NuGetPackage -name publish-module -nugetUrl "$repodir" -prerelease)
        $newPkgPath | Should Exist
    }
    #>
    It 'Returns path when already downloaded' {
        $pkgPath2 = (Get-NuGetPackage -name publish-module -prerelease -noexpansion)
        $pkgPath2 | Should Exist
        $pkgPath2 = (Get-NuGetPackage -name publish-module -prerelease -noexpansion)
        $pkgPath2 | Should Exist
    }

    It 'Can pass in a specific version' {
        $pkgPath3 = (Get-NuGetPackage -name publish-module -version 1.0.1-beta1 -noexpansion)
        $pkgPath3 | Should Exist
    }

    It 'Can pass in prerelase' {
        $pkgPath4 = (Get-NuGetPackage -name publish-module -prerelease -noexpansion)
        $pkgPath4 | Should Exist
    }

    It 'Can pass in force without passing version' {
        $pkgPath5 = (Get-NuGetPackage -name publish-module -prerelease -force -noexpansion)
        $pkgPath5 | Should Exist
    }

    It 'Can pass in force with passing version' {
        $pkgPath6 = (Get-NuGetPackage -name publish-module -version 1.0.1-beta1 -force -noexpansion)
        $pkgPath6 | Should Exist
    }

    It 'Can install azureimageoptimizer' {
        $pkgPath7 = (Get-NuGetPackage -name AzureImageOptimizer -prerelease -noexpansion)
        $pkgPath7 | Should Exist
    }

    It 'Can install using expansion' {
        $pkgPath8 = (Get-NuGetPackage -name SlowCheetah.Xdt -prerelease)
        $pkgPath8 | Should Exist
        (Join-Path $pkgPath8 'bin') | Should Exist
    }

    It 'Can install using expansion using force' {
        $pkgPath8 = (Get-NuGetPackage -name SlowCheetah.Xdt -prerelease -force)
        $pkgPath8 | Should Exist
        (Join-Path $pkgPath8 'bin') | Should Exist

        $pkgPath8 = (Get-NuGetPackage -name SlowCheetah.Xdt -prerelease -force)
        $pkgPath8 | Should Exist
        (Join-Path $pkgPath8 'bin') | Should Exist
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
