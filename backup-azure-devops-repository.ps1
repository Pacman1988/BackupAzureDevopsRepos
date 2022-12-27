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
   [Parameter(Mandatory, HelpMessage="The azure devops organisation URL (eg: https://dev.azure.com/my-company)")]
   [Alias('o')]
   [string]$Organization,

   [Parameter(Mandatory, HelpMessage="The directory where to store the backup archive. eg: C:/Backup/")]
   [Alias('d')]
   [string]$BackupDir,

   [Parameter(Mandatory, HelpMessage="The Personal Access Token (PAT) that you need to generate for your Azure Devops Account")]
   [Alias('p')]
   [string]$PAT,

   [Parameter()]
   [Alias('r')]
   [int]$RetentionDays,

   [Parameter(HelpMessage="If you want to create a dummy file instead of cloning the repositories")]
   [Alias('x')]
   [bool]$DryRun = $false
)

Write-Host "=== Script parameters"
Write-Host "ORGANIZATION_URL  = $Organization"
Write-Host "BACKUP_ROOT_PATH  = $BackupDir"
Write-Host "RETENTION_DAYS    = $RetentionDays"
Write-Host "DRY_RUN           = $DryRun"

#Store script start time
$startTime = Get-Date

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
$backupDirectory="$BackupDir$backupFolder"
New-Item -Path $backupDirectory -ItemType Directory
Set-Location $backupDirectory
Write-Host "=== Backup folder created [${backupDirectory}]"

#Initialize counters
$projectCounter=0
$repoCounter=0

foreach ($project in $projectList) {


   Write-Host "==> Backup project [${projectCounter}] [$($project.name)] [$($project.id)]"

   #Get current project name
   $currentProjectName=$($project.name)
   New-Item -Path "$backupDirectory/$currentProjectName" -ItemType Directory
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
         git -c http.extraHeader="Authorization: Basic $B64Pat" clone $($repo.webUrl) $currentRepoDirectory
      }

      $repoCounter++
   }

   $projectCounter++
}

#Backup summary
$endTime= Get-Date
$elapsed=$endTime-$startTime
$backupSizeUncompressed= "{0:N2}" -f ((Get-ChildItem -path $backupDirectory -recurse | Measure-Object -property length -sum ).sum /1MB) + "MB"

Set-Location $backupDirectory
Write-Host "=== Compress folder"
Compress-Archive -Path . -DestinationPath "$backupFolder.zip" -CompressionLevel Optimal
$backupSizeCompressed="{0:N2}" -f ((Get-ChildItem $backupFolder.zip | Measure-Object -property length -sum ).sum /1MB) + "MB"
Write-Host "=== Remove raw data in folder"
Get-ChildItem -Directory | Remove-Item -Force -Recurse

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
   Get-ChildItem "$BackupDir\*.zip" -Recurse -Force | Where-Object { !$_.PSIsContainer -and $_.CreationTime -lt $RetentionDays } | Remove-Item -Force
}