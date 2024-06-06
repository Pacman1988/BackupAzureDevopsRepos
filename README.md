# azure-devops-repository-powershell-backup

## Introduction

Microsoft don't provide any built-in solution to backup Azure Devops Services.

They ask them to thrust the process as described in the [Data Protection Overview](https://docs.microsoft.com/en-us/azure/devops/organizations/security/data-protection?view=azure-devops) page.

However most companies want to keep an **on-premise** backup of their code repositories in case of Disaster Recovery Plan (DRP).

## Project 

This project provides a Powershell script to backup all azure devops repositories of an Azure Devops Organization.
The original bash script can be found [here](https://github.com/lionelpere/azure-devops-repository-backup/).

## Powershell Script

### Prerequisite 

* Git for Windows: [Downloads](https://git-scm.com/download/win)
* Azure CLI: [Installation guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* Azure CLI - Devops Extension: [Installation guide](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops)

Interaction with the Azure DevOps API requires a [personal access token](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops).

For this backup script you'll only need to generate a PAT with read access on Code

### Launch script

    ./backup-azure-devops-repository.ps1 -Organization 'DEVOPS_ORG_URL' -PAT DEVOPS_PAT -BackupDir 'BACKUP_DIRECTORY' -DryRun 

    Parameters:
       -o | -Organization: 
            The azure devops organisation URL (eg: https://dev.azure.com/my-company)
            If you only have one location you can set it as default for the parameter
       -d | -BackupDir: 
            The directory where to store the backup archive.
            You can specify a default for this parameter in the code
       -p | -PAT: The Personnal Access Token (PAT) that you need to generate for your Azure Devops Account
       -f | -RepoFilter: Specify a name filter to include only matching repositories (default = *)
       -l | -LogFile: specify a transcript log file. Path based on current folder
            fe: -LogFile "C:\Temp\DevopsBackup_$(Get-Date -f 'yyyyMMdd_HHmm').log"
       -c | -CompressMethod: Specify to use 7z or builtin zip compression (default = 7z)
            If 7z is installed at non standard location update the location in the code. To install run 'winget install 7zip.7zip'
            if 7z is specified but not found internal zip is used. (Be aware the buildin zip only supports archives up to 2Gb.)
       -x | -DryRun - If you want to create a dummy file instead of cloning the repositories specify -DryRun
       -r | -RetentionDays 7 - Retention in days before archives are removed. (0=never)
