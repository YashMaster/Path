#Adapted from: https://gallery.technet.microsoft.com/scriptcenter/a-GitHub-Repository-265c0b49
param( 
   [Parameter(Mandatory=$True)] 
   [string] $Author, 
   
   [Parameter(Mandatory=$True)] 
   [string] $Name, 
	
   [Parameter(Mandatory=$False)] 
   [string] $Branch = "master", 
	
   [Parameter(Mandatory=$False)] 
   [string] $GithubTokenVariableAssetName = "GithubToken" 
) 

$ZipFile = (Join-Path $pwd.Path $Name) + ".zip"
$OutputFolder = Join-Path $pwd.Path $Name 
$RepositoryZipUrl = "https://api.github.com/repos/$Author/$Name/zipball/$Branch" 

#$Token = Get-AutomationVariable -Name $GithubTokenVariableAssetName 
#if(!$Token) { 
#	throw("'$GithubTokenVariableAssetName' variable asset does not exist or is empty.") 
#} 

if(Test-Path $ZipFile) 
	{Remove-Item -Path $ZipFile -Force -Recurse}

# download the zip 
Invoke-RestMethod -Uri $RepositoryZipUrl -OutFile $ZipFile 

#Extract the zip
if(-not (Test-Path $OutputFolder))
	{New-Item -Path $OutputFolder -ItemType Directory | Out-Null}
[System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null 
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $OutputFolder) 

#Remove zip 
Remove-Item -Path $ZipFile -Force -Recurse
 
#path to the downloaded repository 
$extractedDir = (ls $OutputFolder)[0].FullName 

#Move all stuff from output folder up one level
Move-Item -Force (Join-Path $extractedDir "*") $OutputFolder 
Remove-Item -Force $extractedDir

