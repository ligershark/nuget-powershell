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
    
    Import-Module $modulePath -PassThru -DisableNameChecking | Out-Null
}
else{
    throw ('Unable to find module at [{0}]' -f $modulePath )
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
            Remove-Item $newToolsDir -Recurse -Force | out-null  
        }
    }

    It 'Returns path' {
        $pkgPath = (Get-NuGetPackage -name psbuild)
        $pkgPath | Should Exist
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