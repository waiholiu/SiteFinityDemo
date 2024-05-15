param projectname string = 'sitefinity8'
param location string = 'australiaeast'
var currentStack = 'dotnet'
var netFrameworkVersion = 'v4.0'
var sqlUsername = 'devuser'
var sqlPassword = 'Password1234!'

// generate a web app
resource webSite 'Microsoft.Web/sites@2022-03-01' = {
  name: '${projectname}-web'
  location: location
  properties: {
    name: '${projectname}-web'
    siteConfig: {
      appSettings: []
      metadata: [
        {
          name: 'CURRENT_STACK'
          value: currentStack
        }
      ]
      netFrameworkVersion: netFrameworkVersion
      alwaysOn: true
      ftpsState: 'FtpsOnly'
    }
    serverFarmId: serverFarm.id
    clientAffinityEnabled: true
    virtualNetworkSubnetId: '${vnet.id}/subnets/subnet-webapp'
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    vnetRouteAllEnabled: true
  }
}

resource basicPublish_setting 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  parent: webSite
  name: 'scm'
  properties: {
    allow: true
  }
}

resource ftp_setting 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  parent: webSite
  name: 'ftp'
  properties: {
    allow: true
  }
}

// generate a asp
resource serverFarm 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${projectname}-asp'
  location: location
  properties: {
    name: '${projectname}-asp'
    workerSize: 18
    workerSizeId: 18
    numberOfWorkers: 1
    zoneRedundant: false
  }
  sku: {
    tier: 'GP_Gen5_2'
    name: 'P0V3'
  }
}

// generate a vnet
resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
  name: '${projectname}-vnet'
  location: 'australiaeast'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-webapp'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
      {
        name: 'subnet-outbound'
        properties: {
          delegations: []
          serviceEndpoints: []
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}


// resource vnet 'Microsoft.Network/virtualNetworks@2020-07-01' = {
//   name: '${projectname}-vnet'
//   location: 'australiaeast'
//   properties: {
//     addressSpace: {
//       addressPrefixes: [
//         '10.0.0.0/16'
//       ]
//     }
//     subnets: []
//   }
// }

// // create a subnet with service endpoints for storage and delegation for web app
// resource outboundSubnetDeployment 'Microsoft.Resources/deployments@2020-07-01' = {
//   name: 'outboundSubnetDeployment'
//   properties: {
//     mode: 'Incremental'
//     template: {
//       '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
//       contentVersion: '1.0.0.0'
//       parameters: {}
//       variables: {}
//       resources: [
//         {
//           type: 'Microsoft.Network/virtualNetworks/subnets'
//           apiVersion: '2020-07-01'
//           name: '${projectname}-vnet/subnet-webapp'
//           properties: {
//             delegations: [
//               {
//                 name: 'delegation'
//                 properties: {
//                   serviceName: 'Microsoft.Web/serverfarms'
//                 }
//               }
//             ]
//             serviceEndpoints: [
//               {
//                 service: 'Microsoft.Storage'
//               }
//             ]
//             addressPrefix: '10.0.1.0/24'
//           }
//         }
//       ]
//     }
//   }
//   dependsOn: [
//     vnet
//   ]
// }

// create sql server and database
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: '${projectname}-sqlserver'
  location: location
  properties: {
    administratorLogin: 'devuser'
    administratorLoginPassword: 'Password1234!'
    version: '12.0'
  }

  // resource sqlDatabase 'databases@2023-05-01-preview' = {
  //   name: '${projectname}-db'
  //   location: location
  //   properties: {
  //     collation: 'SQL_Latin1_General_CP1_CI_AS'
  //     autoPauseDelay: 60
  //   }
  //   sku: {
  //     name: 'GP_S_Gen5_1'
  //     tier: 'GeneralPurpose'
  //   }
  // }
}

// create a private dns zone 
resource DbPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.database.windows.net'
  location: 'global'
}

// link it to the VNET
resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: 'virtualLinkName'
  parent: DbPrivateDnsZone
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: 'endpoint-sqlserver'
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/subnet-outbound'
    }
    privateLinkServiceConnections: [
      {
        name: '${projectname}-endpoint'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: DbPrivateDnsZone.name
        properties: {
          privateDnsZoneId: DbPrivateDnsZone.id
        }
      }
    ]
  }
}

resource cache 'Microsoft.Cache/Redis@2022-06-01' = {
  name: '${projectname}-cache'
  location: location
  properties: {
    sku: {
      name: 'Standard'
      family: 'C'
      capacity: '1'
    }
    redisConfiguration: {}
    enableNonSslPort: false
    redisVersion: '6'
    publicNetworkAccess: 'Disabled'
  }
}

resource redisPrivateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  properties: {}
  dependsOn: []
}

resource redisPrivateDnsZoneName_redisVirtualLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  parent: redisPrivateDnsZone
  name: 'redisVirtualLinkName'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }

}

resource redisPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: 'endpoint-redis'
  location: location
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/subnet-outbound'
    }
    privateLinkServiceConnections: [
      {
        name: '${projectname}-endpoint'
        properties: {
          privateLinkServiceId: cache.id
          groupIds: [
            'redisCache'
          ]
        }
      }
    ]
  }
}

resource redisDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  parent: redisPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: redisPrivateDnsZone.name
        properties: {
          privateDnsZoneId: redisPrivateDnsZone.id
        }
      }
    ]
  }
}


