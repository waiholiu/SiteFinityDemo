#!/bin/bash

# Default project name
defaultProjectName="sitefinity10"

# Use the first command line argument as the project name, or the default if no argument was given
projectName=${1:-$defaultProjectName}

az group create --name $projectName --location australiaeast
az deployment group create --resource-group $projectName --template-file deploy.bicep --parameters projectname=$projectName