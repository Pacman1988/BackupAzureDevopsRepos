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

    ./backup-azure-devops-repository.ps1 -Organization 'DEVOPS_ORG_URL' -PAT DEVOPS_PAT -BackupDir 'BACKUP_DIRECTORY' -DryRun $true 

    Parameters:
       -o | -Organization: 
            The azure devops organisation URL (eg: https://dev.azure.com/my-company)
       -d | -BackupDir: 
            The directory where to store the backup archive.
       -p | -PAT: The Personnal Access Token (PAT) that you need to generate for your Azure Devops Account
       -x | -DryRun: true/false - If you want to create a dummy file instead of cloning the repositories
       -r | -RetentionDays 7 - Retention in days
