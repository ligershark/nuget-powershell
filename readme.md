This project aims to simplify consuming NuGet packages in PowerShell. More info coming soon...

### Build status
[![Build status](https://ci.appveyor.com/api/projects/status/yv76i6yybh5pv3kd?svg=true)](https://ci.appveyor.com/project/sayedihashimi/nuget-powershell)

### Getting started
<code style="background-color:grey">(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/nuget-powershell/master/get-nugetps.ps1") | iex</code>

### Examples

#### How to read a .json file with comments

```powershell
(new-object Net.WebClient).DownloadString("https://raw.githubusercontent.com/ligershark/nuget-powershell/master/get-nugetps.ps1") | iex

$jsonnetpath = (Get-NuGetPackage Newtonsoft.Json -prerelease -binpath)
Add-Type -Path (Join-Path $jsonnetpath 'Newtonsoft.Json.dll')
# now we can call apis from json.net
$jsonString = @"
{
    /* Click to learn more about project.json  http://go.microsoft.com/fwlink/?LinkID=517074 */
    "webroot": "wwwroot",
    "version": "1.0.0-*",
    "dependencies": {
        "EntityFramework.SqlServer": "7.0.0-beta3",
        "Microsoft.VisualStudio.Web.BrowserLink.Loader": "14.0.0-beta3"
    },
    "commands": {
        /* Change the port number when you are self hosting this application */
        "web": "Microsoft.AspNet.Hosting --server Microsoft.AspNet.Server.WebListener --server.urls http://localhost:5000",
        "gen": "Microsoft.Framework.CodeGeneration"
    }
}
"@

'webroot: "{0}"' -f [Newtonsoft.Json.JsonConvert]::DeserializeObject($jsonString)['webroot'].value

```

#### How to optimize images in a folder

```powershell
$imgOptExe = (Join-Path (Get-NuGetPackage AzureImageOptimizer -prerelease -binpath) 'ImageCompressor.Job.exe')
&$imgOptExe /d c:\temp\images\to-optimize --force --noreport

```

### How to minifiy css files in a folder

```
if(Test-Path "$pwd\sample-style.css"){Remove-Item "$pwd\sample-style.css"}

(New-Object System.Net.WebClient).DownloadFile('http://www.csszengarden.com/examples/style.css', "$(pwd)\sample-style.css")

& "$(Get-NuGetPackage -name AzureMinifier -prerelease -binpath)TextMinifier.job.exe" /d $pwd --noreport

```
#### How to transform an XML file using XDT

```powershell
# get sample files from gist
(new-object Net.WebClient).DownloadString("https://gist.githubusercontent.com/sayedihashimi/581878c375db22eabd22/raw/eb4e4d5e0c66448f6aed1c898ea0c7991bd970c8/sample.config") | Set-Content .\sample.config
(new-object Net.WebClient).DownloadString("https://gist.githubusercontent.com/sayedihashimi/581878c375db22eabd22/raw/b54d648ed5e316801b8323da91506ff9d3a136a7/sample.transform.config") | Set-Content .\sample.transform.config

if((Test-Path .\final.config)){
    Remove-Item .\final.config
}

$xdtexe = (join-path (Get-NuGetPackage SlowCheetah.Xdt -prerelease -binpath) SlowCheetah.Xdt.exe)

# invoke SlowCheetah.Xdt.exe
&($xdtexe) .\sample.config .\sample.transform.config .\final.config

```


### Release Notes

 - When calling ```Get-NuGetPackage``` the folder where items are expanded is now called ```__bin``` instead of ```bin```. ***This is a breaking change and scripts will need to be updated.*** https://github.com/ligershark/nuget-powershell/issues/5
 - Added a module manifest to enable versioning the PowerShell module. https://github.com/ligershark/nuget-powershell/issues/4
