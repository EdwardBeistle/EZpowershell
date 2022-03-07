# EZ Powershell

This powershell module is for oddjobs and tasks that are to manually tedious but do not need to be fully automated.

## Current cmdlets

- Format-PropagateTagsToChildren
- Format-PropagateTagsWithInheritance
- Find-LocateOutdatedDependicies
- Get-GenerateTagCSV

## Installation

Clone this repo
Open in powershell

```sh
Import-Module ./EZpowershell.psm1
```

## Wiki

### Format-PropagateTagsToChildren

This cmd sets the tags of all children under either a subscription or a resource group in Azure.

```sh
Format-PropagateTagsToChildren resourceId -a -o -s
```

- resourceId - the string of the Azure resource to act as the root
- appendTags - flag to allow appending new tags
- overwriteTags - flag to allow overwriting of tags
- skipTags - flag to allow the root element to not have tags IF it is a subscription

### Format-PropagateTagsWithInheritance

This cmd is similiar to propagation but instead defaults to inheritance. In this case the subscription is only needed for scope.

```sh
Format-PropagateTagsWithInheritance subscriptionId -a -o
```

- subscriptionId - the string of the Azure subscription
- appendTags - flag to allow appending new tags
- overwriteTags - flag to allow overwriting of tags

### Find-LocateOutdatedDependicies

This cmd searches each scoped repo and aggragates the TargetFramework & TargetFrameworks so that developers can know if they need to update thier dependencies.

```sh
Find-LocateOutdatedDependicies ordId acceptedVersions regex -r
```

- orgId - the string of the ADO org to scope to
- acceptedVersions - an array of accepted versions, expected strings can be found [here](https://docs.microsoft.com/en-us/dotnet/standard/frameworks)
- regex - a regex statement that will be compared to every repo's name, if there is a match it will check that repo
- results - flag for exporting results to export.csv

### Get-GenerateTagCSV

This cmd grabs every tag from a scoped Azure resource and exports it to export.csv. It does inheritance.

```sh
Get-GenerateTagCSV
```
