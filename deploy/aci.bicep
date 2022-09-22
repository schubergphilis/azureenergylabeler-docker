@description('Name for the container group')
param name string = 'azureenergylabeler'

@description('Name for the image')
param imageName string = 'ghcr.io/schubergphilis/azureenergylabeler:main'

@description('The number of CPU cores to allocate to the container.')
param cpuCores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memoryInGb int = 2

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Storage Account URL')
@secure()
param storageAccountUrl string

@description('Storage Account SAS token')
@secure()
param storageAccountSAS string

@description('Your customer TLA')
param tla string

param today string = utcNow('yy/MM/dd')

@description('Command to execute inside the container')
param params array = [
            '--export-metrics'
          ]

@description('Security Reader role definition')
var roleDefinitionId = resourceId('microsoft.authorization/roleDefinitions', '39bc4728-0917-49c7-9d2c-d95423bc2eb4')

var command = concat(['/venv/bin/azure-energy-labeler'], params)

var envTenantId = {
  name: 'AZURE_LABELER_TENANT_ID'
  value: tenant().tenantId
}

var envExportPath = {
  name: 'AZURE_LABELER_EXPORT_PATH'
  secureValue: '${storageAccountUrl}/${toLower(tla)}/${today}?${storageAccountSAS}'
}

@description('Assign Security Reader role to the container so it can gather security compliance of the subscription/tenant')
resource securityReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(name)
  scope: tenant()
  properties: {
    principalId: containergroup.identity.principalId
    roleDefinitionId: roleDefinitionId
  }
}

resource containergroup 'Microsoft.ContainerInstance/containerGroups@2020-11-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    restartPolicy: 'Never'
    containers: [
      {
        name: name
        properties: {
          environmentVariables: [
            envTenantId
            envExportPath
          ]
          image: imageName
          command: command
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
        }
      }
    ]
    osType: 'Linux'
  }
}
