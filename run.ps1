# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

#we need to get all of our scopes, how do we do that?
#management API!
#flipping nope

$pat = (Get-AzAccessToken).Token

#define organization base url, api version
$orgUrl = "https://management.azure.com"
$queryString = "api-version=2020-01-01"
$header = @{authorization = "Bearer $pat" }



#get the subs
$subUrl = "$orgUrl/subscriptions/5f30ca06-045e-4a86-ae47-0bd7165be663/resourcegroups/Api-Default-North-Central-US/resources?$queryString"
$subResponse = Invoke-RestMethod -Uri $subUrl -Method Get -ContentType "application/json" -Headers $header

#for each subscription
$subResponse.value | ForEach-Object {

    Write-Host "/subscriptions/5f30ca06-045e-4a86-ae47-0bd7165be663/resourcegroups/Api-Default-North-Central-US/resources/" $_.name
}


