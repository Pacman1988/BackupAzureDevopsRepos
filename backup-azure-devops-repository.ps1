#Requires -Version 5.1

<#
.Synopsis
   Backup for Azure DevOps Repositories
.DESCRIPTION
   Backup for Azure DevOps Repositories
   Microsoft don't provide any built-in solution to backup Azure Devops Services.
.EXAMPLE
   ./backup-azure-devops-repository.ps1 -Organization 'DEVOPS_ORG_URL' -PAT DEVOPS_PAT -BackupDir 'BACKUP_DIRECTORY' -DryRun $true 
.NOTES
   Requires:
      * Git for Windows
      * Azure CLI
      * Azure CLI - Devops Extension
.FUNCTIONALITY
   Connects to Azure DevOps with PAT and downloads every Repo and compress it to one file.
#>

param(
   [Parameter(HelpMessage="The azure devops organisation URL (eg: https://dev.azure.com/my-company)")]
   [ValidateNotNullOrEmpty()]
   [Alias('o')]
   [string]$Organization='',

   [Parameter(HelpMessage="The directory where to store the backup archive. eg: C:/Backup/")]
   [ValidateNotNullOrEmpty()]
   [Alias('d')]
   [string]$BackupDir='',

   [Parameter(Mandatory, HelpMessage="The Personal Access Token (PAT) that you need to generate for your Azure Devops Account")]
   [Alias('p')]
   [string]$PAT,

   [Parameter(HelpMessage="Include only repositories matching the filter")]
   [Alias('f')]
   [string]$RepoFilter='*',

   [Parameter(HelpMessage="Writes an transcript log to given file")]
   [Alias('l')]
   [string]$LogFile,

   [Parameter(HelpMessage="What tool to use to compress the result (7z/zip)")]
   [Alias('c')]
   [ValidateSet('7z', 'zip')]
   [string]$CompressMethod='7z',

   [Parameter(HelpMessage="How many days to keep the backup archives before deleting them (0=never)")]
   [Alias('r')]
   [int]$RetentionDays,

   [Parameter(HelpMessage="If you want to create a dummy file instead of cloning the repositories")]
   [Alias('x')]
   [switch]$DryRun = $false
)

#Skip repositories that are disabled (and will likely fail), set to $false to try to include
$SkipDisabledRepos=$true
#Location of the 7z.exe file
$7zexe='C:\Program Files\7-Zip\7z.exe'

if ($logfile) { Start-Transcript $LogFile}

Write-Host "=== Script parameters"
Write-Host "ORGANIZATION_URL  = $Organization"
Write-Host "BACKUP_ROOT_PATH  = $BackupDir"
Write-Host "RETENTION_DAYS    = $RetentionDays"
Write-Host "DRY_RUN           = $DryRun"

#Store script start time and current folder
$startTime = Get-Date
$curdir=Get-Location

#Test if 7z is available, fallback to zip if not
if ($CompressMethod -ieq '7z') {
   if (!(Test-Path -Path  $7zexe -PathType Leaf)) {
      Write-Warning "$7zexe could not be located! If installed at a different location adjust in the code.`nTo install 7zip run 'winget install 7zip.7zip'"
      Write-Output 'Using build-in zip compression instead'
      $CompressMethod='zip'
   }
}

#Install Azure CLI on Windows
#Write-Host "=== Install Azure CLI"
#$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi

#Install the Devops extension
#Write-Host "=== Install DevOps Extension"
az extension add --name 'azure-devops'

#Set this environment variable with a PAT will 'auto login' when using 'az devops' commands
$env:AZURE_DEVOPS_EXT_PAT = $PAT
$B64Pat = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("`:$PAT"))

Write-Host "=== Get project list"
$projectList = az devops project list --organization $Organization --query 'value[]' | ConvertFrom-Json

#Create backup folder with current time as name
$backupFolder= Get-Date -Format "yyyyMMddHHmm"
$backupName = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupDirectory= Join-Path -Path $BackupDir -ChildPath $backupFolder
New-Item -Path $backupDirectory -ItemType Directory | Out-Null
Set-Location $backupDirectory
Write-Host "=== Backup folder created [${backupDirectory}]"

#Initialize counters
$projectCounter=0
$repoCounter=0

foreach ($project in ($projectList | Where-Object {$_.Name -ilike $RepoFilter})) {


   Write-Host "==> Backup project [${projectCounter}] [$($project.name)] [$($project.id)]"

   #Get current project name
   $currentProjectName=$($project.name)
   New-Item -Path "$backupDirectory/$currentProjectName" -ItemType Directory | Out-Null
   Set-Location "$backupDirectory/$currentProjectName"
   Get-Location

   #Get Repository list for current project id.
   $repoList=az repos list --organization $Organization --project $($project.id) | ConvertFrom-Json  

   foreach ($repo in $repoList) {
      if ($repo.size -eq 0) {continue}
      Write-Host "====> Backup repo [$repoCounter][$($repo.name)] [$($repo.id)] [$($repo.url)]"

      #Get current repo name
      $currentRepoName=$($repo.name)
      $currentRepoDirectory="$backupDirectory/$currentProjectName/$currentRepoName"

      if ($DryRun) {
         Write-Host "Simulate git clone $currentRepoName"
         $repo | ConvertTo-Json >> "$currentRepoName-definition.json"
      }
      else {
         if ($repo.isDisabled -and $SkipDisabledRepos) {
            Write-Host "====> Skipping disabled repo: [$($repo.name)]"
         } else {
            git -c http.extraHeader="Authorization: Basic $B64Pat" clone $($repo.webUrl) $currentRepoDirectory
         }
      }

      $repoCounter++
   }

   $projectCounter++
}

#Backup summary
$endTime= Get-Date
$elapsed=$endTime-$startTime
$backupSizeUncompressed= "{0:N2}" -f ((Get-ChildItem -path $backupDirectory -Recurse -Force | Measure-Object -property length -sum ).sum /1MB) + "MB"

Set-Location $backupDirectory
Write-Host "=== Compress folder"
if ($CompressMethod -ieq '7z') {
   # Use 7-zip to compress the files when available
   & $7zexe a -r -sdel -mx9 -y "$backupName.7z"  .
   $backupSizeCompressed="{0:N2}" -f ((Get-ChildItem "$backupName.7z" | Measure-Object -property length -sum ).sum /1MB) + "MB"
} else {
   # Use default builtin command. First unhide all hidden files/folders so they will be included as well.
   Get-ChildItem -Path . -Recurse -Hidden -Force | ForEach-Object { $_.Attributes -= 'Hidden' }
   Compress-Archive -Path . -DestinationPath "$backupName.zip" -CompressionLevel Optimal
   $backupSizeCompressed="{0:N2}" -f ((Get-ChildItem $backupName.zip | Measure-Object -property length -sum ).sum /1MB) + "MB"
   Write-Host "=== Remove raw data in folder"
   Get-ChildItem -Directory | Remove-Item -Force -Recurse
}

Write-Host "=== Backup completed ==="
Write-Host  "Projects : $projectCounter"
Write-Host  "Repositories : $repoCounter"

Write-Host "Size : $backupSizeUncompressed (uncompressed) - $backupSizeCompressed (compressed)"
Write-Host "Elapsed time: $($elapsed.Days) days $($elapsed.Hours) hr $($elapsed.Minutes) min $($elapsed.Seconds) sec"

if ($RetentionDays -eq 0) {
   Write-Host "=== No retention policy"
}
else 
{
   Write-Host "=== Apply retention policy ($RetentionDays days)"
   Get-ChildItem $BackupDir -Recurse -Force -Directory  | Where-Object {$_.CreationTime -le $(get-date).Adddays(-$RetentionDays)} | Remove-Item -Force -Recurse
}
if ($logfile) { Stop-Transcript }
Set-Location $curdir