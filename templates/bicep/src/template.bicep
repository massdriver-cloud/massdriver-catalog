// Main Bicep infrastructure code
//
// Available parameters from massdriver.yaml:
//   resource_name      - string
//   location           - string
//   instance_count     - int
//   enable_monitoring  - bool
//   tags               - array
//   advanced           - object
//   md_metadata        - Massdriver metadata
//
// Connection parameters (if configured):
//   <connection_name>  - artifact data from connected bundles

@description('Resource name')
param resource_name string

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Number of instances')
param instance_count int = 1

@description('Enable monitoring')
param enable_monitoring bool = false

@description('Massdriver metadata')
param md_metadata object

// Example resource - replace with your infrastructure
// resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
//   name: '${resource_name}${uniqueString(resourceGroup().id)}'
//   location: location
//   sku: {
//     name: 'Standard_LRS'
//   }
//   kind: 'StorageV2'
//   tags: md_metadata.default_tags
//   properties: {
//     accessTier: 'Hot'
//   }
// }

// Output example - useful for debugging during development
output resourceInfo object = {
  name: resource_name
  location: location
  instanceCount: instance_count
  monitoring: enable_monitoring
}
