function Login {
    $context = Get-AzContext

    if (!$context) {
        Connect-AzAccount
    } 
    else {
        Write-Host "Already connected to Azure AD"
    }
}

function Format-PropagateTagsToChildren {
    #first we need params
    param (
        [Parameter(Mandatory = $true)] #will get the name of the targeted subscription/group/resource
        [string] $resourceId,
        [Parameter()] #will ask if you want to append new tags
        [Switch] $appendTags,
        [Parameter()] #will ask if you want to overwrite new tags
        [Switch] $overwriteTags,
        [Parameter()] #will ask if you want to skip subscription tags
        [Switch] $skipTags
    )

    Login

    #put alerts at beginning of command
    if ($appendTags) {
        Write-Host "WARNING: appending tags is enabled" -ForegroundColor Yellow
    }

    if ($overwriteTags) {
        Write-Host "WARNING: overwriting tags is enabled" -ForegroundColor Red
    }

    #stats
    $tagsAdded = 0
    $tagsModified = 0
    $errors = 0

    #see if given resource is a subscription AND has tags
    if ($null -ne (Get-AzSubscription -SubscriptionId $resourceId -ErrorAction SilentlyContinue) -and $null -eq (Get-AzTag -ResourceId /subscriptions/$resourceId).Properties.TagsProperty -and $skipTags) {
        #is is a sub and it has no tags BUT that skip tags flag is on
        $output = -join ((Get-AzSubscription -SubscriptionId $resourceId).Name, " (", 0, " tags)")
        Write-Host $output -ForegroundColor Cyan
        Write-Host "|"

        #set context to only get child groups
        Set-AzContext $resourceId | Out-Null

        #now loop through all of its children
        $parentTags = $tags
        $resources = Get-AzResourceGroup

        foreach ($r in $resources) {
            #for each child 
            $childTags = (Get-AzTag -ResourceId $r.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
            $output = -join ("$([char]0x251C) ", $r.ResourceGroupName, " (", $childTags.Count, " tags)")
            Write-Host $output

            #now propagte to the grandchildren
            $grandchildren = Get-AzResource -ResourceGroupName $r.ResourceGroupName

            #propagates properly now
            $updatedParentTags = (Get-AzTag -ResourceId (Get-AzResourceGroup -Name $r.ResourceGroupName).ResourceId).Properties.TagsProperty

            foreach ($g in $grandchildren) {
                #for each child 
                $grandchildTags = (Get-AzTag -ResourceId $g.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
                $output = -join ("$([char]0x251C) ", $g.Name, " (", $grandchildTags.Count, " tags)")
                Write-Host "|       " -NoNewline
                Write-Host $output
    
                if ($grandchildTags) {
                    foreach ($key in $chigrandchildTagsldTags.Keys) {
                        if (-not($updatedParentTags.ContainsKey($key))) {
                            #these are existing tags that are not to be updated
                            $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                            Write-Host "|       |   " -NoNewline
                            Write-Host $output -ForegroundColor Green
                        }
                    }
                    foreach ($key in $updatedParentTags.Keys) {
                        if (-not($grandchildTags.ContainsKey($key)) -and $appendTags) {
                            #add these tags only if we are appending
                            $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                            Write-Host "|       |   " -NoNewline
                            Write-Host $output -ForegroundColor Yellow
                            $grandchildTags.Add($key, $updatedParentTags[$key])
                            $tagsAdded++
                        }
                        else {
                            if ($grandchildTags[$key] -eq $updatedParentTags[$key]) {
                                #this key is up-to-date do nothing
                                $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                                Write-Host "|       |   " -NoNewline
                                Write-Host $output -ForegroundColor Blue
                            }
                            elseif (-not($grandchildTags[$key] -eq $updatedParentTags[$key]) -and $overwriteTags) {
                                #overwite exising tag with new value
                                $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                                Write-Host "|       |   " -NoNewline
                                Write-Host $output -ForegroundColor Magenta
                                $grandchildTags.Remove($key) | Out-Null
                                $grandchildTags.Add($key, $updatedParentTags[$key]) | Out-Null
                                $tagsModified++
                            }
                        }
                    }
                }
            
                try {
                    New-AzTag -ResourceId $g.ResourceId -Tag $grandchildTags -ErrorAction Stop | Out-Null
                    Write-Host "|       |   " -NoNewline
                    Write-Host "$([char]0x231E) Tags propogated succesfully" -ForegroundColor Cyan
                }
                catch {
                    Write-Host "|       |   " -NoNewline
                    Write-Host "$([char]0x231E) Error tags could not be updated" -ForegroundColor Red
                    $errors++
                }
                Write-Host "|       |   "
            }

            Write-Host "|"
        }

        Write-Host "Propagation complete" -ForegroundColor Cyan

    }
    elseif ($null -ne (Get-AzSubscription -SubscriptionId $resourceId -ErrorAction SilentlyContinue) -and $null -ne (Get-AzTag -ResourceId /subscriptions/$resourceId).Properties.TagsProperty) {
        #if it is a subscritption and it does have tags
        $tags = (Get-AzTag -ResourceId /subscriptions/$resourceId).Properties.TagsProperty
        $output = -join ((Get-AzSubscription -SubscriptionId $resourceId).Name, " (", $tags.Count, " tags)")
        Write-Host $output -ForegroundColor Cyan
        Write-Host "|"

        #set context to only get child groups
        Set-AzContext $resourceId | Out-Null

        #now loop through all of its children
        $parentTags = $tags
        $resources = Get-AzResourceGroup

        foreach ($r in $resources) {
            #for each child 
            $childTags = (Get-AzTag -ResourceId $r.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
            $output = -join ("$([char]0x251C) ", $r.ResourceGroupName, " (", $childTags.Count, " tags)")
            Write-Host $output

            if ($childTags) {
                foreach ($key in $childTags.Keys) {
                    if (-not($parentTags.ContainsKey($key))) {
                        #these are existing tags that are not to be updated
                        $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                        Write-Host "|   " -NoNewline
                        Write-Host $output -ForegroundColor Green
                    }
                }
                foreach ($key in $parentTags.Keys) {
                    if (-not($childTags.ContainsKey($key)) -and $appendTags) {
                        #add these tags only if we are appending
                        $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                        Write-Host "|   " -NoNewline
                        Write-Host $output -ForegroundColor Yellow
                        $childTags.Add($key, $parentTags[$key])
                        $tagsAdded++
                    }
                    else {
                        if ($childTags[$key] -eq $parentTags[$key]) {
                            #this key is up-to-date do nothing
                            $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                            Write-Host "|   " -NoNewline
                            Write-Host $output -ForegroundColor Blue
                        }
                        elseif (-not($childTags[$key] -eq $parentTags[$key]) -and $overwriteTags) {
                            #overwite exising tag with new value
                            $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                            Write-Host "|   " -NoNewline
                            Write-Host $output -ForegroundColor Magenta
                            $childTags.Remove($key) | Out-Null
                            $childTags.Add($key, $parentTags[$key]) | Out-Null
                            $tagsModified++
                        }
                    }
                }
            }
        
            try {
                New-AzTag -ResourceId $r.ResourceId -Tag $childTags -ErrorAction Stop | Out-Null
                Write-Host "|   " -NoNewline
                Write-Host "$([char]0x231E) Tags propogated succesfully" -ForegroundColor Cyan
            }
            catch {
                Write-Host "|   " -NoNewline
                Write-Host "$([char]0x231E) Error tags could not be updated" -ForegroundColor Red
                $errors++
            }

            #now propagte to the grandchildren
            $grandchildren = Get-AzResource -ResourceGroupName $r.ResourceGroupName

            #propagates properly now
            $updatedParentTags = (Get-AzTag -ResourceId (Get-AzResourceGroup -Name $r.ResourceGroupName).ResourceId).Properties.TagsProperty

            foreach ($g in $grandchildren) {
                #for each child 
                $grandchildTags = (Get-AzTag -ResourceId $g.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
                $output = -join ("$([char]0x251C) ", $g.Name, " (", $grandchildTags.Count, " tags)")
                Write-Host "|       " -NoNewline
                Write-Host $output
    
                if ($grandchildTags) {
                    foreach ($key in $chigrandchildTagsldTags.Keys) {
                        if (-not($updatedParentTags.ContainsKey($key))) {
                            #these are existing tags that are not to be updated
                            $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                            Write-Host "|       |   " -NoNewline
                            Write-Host $output -ForegroundColor Green
                        }
                    }
                    foreach ($key in $updatedParentTags.Keys) {
                        if (-not($grandchildTags.ContainsKey($key)) -and $appendTags) {
                            #add these tags only if we are appending
                            $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                            Write-Host "|       |   " -NoNewline
                            Write-Host $output -ForegroundColor Yellow
                            $grandchildTags.Add($key, $updatedParentTags[$key])
                            $tagsAdded++
                        }
                        else {
                            if ($grandchildTags[$key] -eq $updatedParentTags[$key]) {
                                #this key is up-to-date do nothing
                                $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                                Write-Host "|       |   " -NoNewline
                                Write-Host $output -ForegroundColor Blue
                            }
                            elseif (-not($grandchildTags[$key] -eq $updatedParentTags[$key]) -and $overwriteTags) {
                                #overwite exising tag with new value
                                $output = -join ("$([char]0x251C) ", $key, ", ", $updatedParentTags[$key])
                                Write-Host "|       |   " -NoNewline
                                Write-Host $output -ForegroundColor Magenta
                                $grandchildTags.Remove($key) | Out-Null
                                $grandchildTags.Add($key, $updatedParentTags[$key]) | Out-Null
                                $tagsModified++
                            }
                        }
                    }
                }
            
                try {
                    New-AzTag -ResourceId $g.ResourceId -Tag $grandchildTags -ErrorAction Stop | Out-Null
                    Write-Host "|       |   " -NoNewline
                    Write-Host "$([char]0x231E) Tags propogated succesfully" -ForegroundColor Cyan
                }
                catch {
                    Write-Host "|       |   " -NoNewline
                    Write-Host "$([char]0x231E) Error tags could not be updated" -ForegroundColor Red
                    $errors++
                }
                Write-Host "|       |   "
            }

            Write-Host "|"
        }

        Write-Host "Propagation complete" -ForegroundColor Cyan
    }
    #see if given resource is a group AND has tags
    elseif ($null -ne (Get-AzResourceGroup -Name $resourceId -ErrorAction SilentlyContinue) -and $null -ne (Get-AzTag -ResourceId (Get-AzResourceGroup -Name $resourceId).ResourceId).Properties.TagsProperty) {
        $tags = (Get-AzTag -ResourceId (Get-AzResourceGroup -Name $resourceId).ResourceId).Properties.TagsProperty
        #it is a resource group and it does have tags
        $output = -join ((Get-AzResourceGroup -Name $resourceId).ResourceGroupName, " (", $tags.Count, " tags)")
        Write-Host $output -ForegroundColor Cyan
        Write-Host "|"

        #now loop through all of its children
        $parentTags = $tags
        $resources = Get-AzResource -ResourceGroupName (Get-AzResourceGroup -Name $resourceId).ResourceGroupName

        foreach ($r in $resources) {
            #for each child 
            $childTags = (Get-AzTag -ResourceId $r.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
            $output = -join ("$([char]0x251C) ", $r.Name, " (", $childTags.Count, " tags)")
            Write-Host $output

            if ($childTags) {
                foreach ($key in $childTags.Keys) {
                    if (-not($parentTags.ContainsKey($key))) {
                        #these are existing tags that are not to be updated
                        $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                        Write-Host "|   " -NoNewline
                        Write-Host $output -ForegroundColor Green
                    }
                }
                foreach ($key in $parentTags.Keys) {
                    if (-not($childTags.ContainsKey($key)) -and $appendTags) {
                        #add these tags only if we are appending
                        $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                        Write-Host "|   " -NoNewline
                        Write-Host $output -ForegroundColor Yellow
                        $childTags.Add($key, $parentTags[$key])
                        $tagsAdded++
                    }
                    else {
                        if ($childTags[$key] -eq $parentTags[$key]) {
                            #this key is up-to-date do nothing
                            $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                            Write-Host "|   " -NoNewline
                            Write-Host $output -ForegroundColor Blue
                        }
                        elseif (-not($childTags[$key] -eq $parentTags[$key]) -and $overwriteTags) {
                            #overwite exising tag with new value
                            $output = -join ("$([char]0x251C) ", $key, ", ", $parentTags[$key])
                            Write-Host "|   " -NoNewline
                            Write-Host $output -ForegroundColor Magenta
                            $childTags.Remove($key) | Out-Null
                            $childTags.Add($key, $parentTags[$key]) | Out-Null
                            $tagsModified++
                        }
                    }
                }
            }
        
            try {
                New-AzTag -ResourceId $r.ResourceId -Tag $childTags -ErrorAction Stop | Out-Null
                Write-Host "|   " -NoNewline
                Write-Host "$([char]0x231E) Tags propogated succesfully" -ForegroundColor Cyan
            }
            catch {
                Write-Host "|   " -NoNewline
                Write-Host "$([char]0x231E) Error tags could not be updated" -ForegroundColor Red
                $errors++
            }
            Write-Host "|"
        }

        Write-Host "Propagation complete" -ForegroundColor Cyan
    }

    #print the stats
    Write-Host "ADDED TAGS: $tagsAdded" -ForegroundColor Yellow
    Write-Host "OVERWRITTEN TAGS: $tagsModified" -ForegroundColor Yellow
    Write-Host "ERRORS: $errors " -ForegroundColor Red
}

function Format-PropagateTagsWithInheritance {
    #first we need params
    param (
        [Parameter(Mandatory = $true)] #will get the name of the targeted subscription/group/resource
        [string] $subscriptionId,
        [Parameter()] #will ask if you want to append new tags
        [Switch] $appendTags,
        [Parameter()] #will ask if you want to overwrite new tags
        [Switch] $overwriteTags
    )

    Login

    #put alerts at beginning of command
    if ($appendTags) {
        Write-Host "WARNING: appending tags is enabled" -ForegroundColor Yellow
    }

    if ($overwriteTags) {
        Write-Host "WARNING: overwriting tags is enabled" -ForegroundColor Magenta
    }

    #stats
    $tagsAdded = 0
    $tagsModified = 0
    $errors = 0
    $errorResources = New-Object System.Collections.Generic.List[System.Object]

    #exit if we are not a subscription
    if ($null -eq (Get-AzSubscription -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue)) {
        Exit
    }

    $subTags = (Get-AzTag -ResourceId /subscriptions/$subscriptionId).Properties.TagsProperty
    $output = -join ((Get-AzSubscription -SubscriptionId $subscriptionId).Name, " (", $subTags.Count, " tags)")

    Write-Host $output -ForegroundColor Cyan

    #output each of the sub keys for kicks
    
    foreach ($key in $subTags.Keys) {
        $output = -join ("$([char]0x251C) ", $key, ", ", $subTags[$key])

        Write-Host "|   " -NoNewline
        Write-Host $output -ForegroundColor Green
    }

    Write-Host "|"

    #set context to only get child groups
    Set-AzContext $subscriptionId | Out-Null

    #now loop through all of its groups
    $resourceGroups = Get-AzResourceGroup

    foreach ($g in $resourceGroups) {
        #first get the group tags
        $groupTags = (Get-AzTag -ResourceId $g.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
        $output = -join ("$([char]0x251C) ", $g.ResourceGroupName, " (", $groupTags.Count, " tags)")

        #init countaer vars
        $addedGroupInitial = $tagsAdded
        $overwrittenGroupInitial = $tagsModified

        Write-Host $output

        if ($null -eq $groupTags) {
            $groupTags = @{"" = ""; }
        }

        #if we have a defined list
        if ($null -ne $groupTags) {
            #for all tags already in the group
            foreach ($key in $groupTags.Keys) {
                if ($null -eq $subTags -or -not($subTags.ContainsKey($key))) {
                    #if we already have these tags
                    $output = -join ("$([char]0x251C) ", $key, ", ", $groupTags[$key])

                    Write-Host "|   " -NoNewline
                    Write-Host $output -ForegroundColor Green
                }
                elseif ($subTags.ContainsKey($key) -and ($groupTags[$key] -ne $subTags[$key] -and $null -ne $groupTags[$key])) {
                    #if tag values are different
                    $output = -join ("$([char]0x251C) ", $key, ", ", $groupTags[$key])

                    Write-Host "|   " -NoNewline
                    Write-Host $output -ForegroundColor Blue
                }
            }
            #for all tags in the sub
            foreach ($key in $subTags.Keys) {
                if (-not($groupTags.ContainsKey($key)) -and $appendTags) {
                    #if we are appending and and the group does not have these tags
                    $output = -join ("$([char]0x251C) ", $key, ", ", $subTags[$key])
                    $groupTags.Add($key, $subTags[$key])
                    $tagsAdded++

                    Write-Host "|   " -NoNewline
                    Write-Host $output -ForegroundColor Yellow
                }
                else {
                    #if we are not appending OR we the group has these tags
                    if ($groupTags[$key] -eq $subTags[$key]) {
                        #if the avalues are the sme in the tag
                        $output = -join ("$([char]0x251C) ", $key, ", ", $subTags[$key])

                        Write-Host "|   " -NoNewline
                        Write-Host $output -ForegroundColor DarkGreen
                    }
                    elseif (-not($groupTags[$key] -eq $subTags[$key]) -and $overwriteTags) {
                        #else if the values are not the same and we are overwriting
                        $output = -join ("$([char]0x251C) ", $key, ", ", $subTags[$key])
                        $groupTags.Remove($key) | Out-Null
                        $groupTags.Add($key, $subTags[$key]) | Out-Null
                        $tagsModified++

                        Write-Host "|   " -NoNewline
                        Write-Host $output -ForegroundColor Magenta
                    }
                }
            }
        }
        # #we are null and can oly append
        # else {
        #     #for all tags in the sub
        #     foreach ($key in $subTags.Keys) {
        #         if ($appendTags) {
        #             #if we are appending and and the group is null
        #             $output = -join ("$([char]0x251C) ", $key, ", ", $subTags[$key])
        #             $groupTags = $subTags
        #             $tagsAdded++

        #             Write-Host "|   " -NoNewline
        #             Write-Host $output -ForegroundColor Yellow
        #         }
        #     }
        # }
        
        #check if we actually made any changes
        if ($addedGroupInitial -ne $tagsAdded -or $overwrittenGroupInitial -ne $tagsModified) {
            #try to update the tags but if we fail oh well
            try {
                New-AzTag -ResourceId $g.ResourceId -Tag $groupTags -ErrorAction Stop | Out-Null
                Write-Host "|   " -NoNewline
                Write-Host "$([char]0x231E) Tags propogated succesfully" -ForegroundColor Cyan
            }
            catch {
                Write-Host "|   " -NoNewline
                Write-Host "$([char]0x231E) Error tags could not be updated" -ForegroundColor Red
                $errors++
                $errorResources.Add($g.ResourceGroupName)
            }
        }

        #now update the tag list
        $groupTags = (Get-AzTag -ResourceId $g.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
        $resources = Get-AzResource -ResourceGroupName $g.ResourceGroupName

        #now loop through all of the groups resources
        foreach ($r in $resources) {
            #get the tags
            $resourceTags = (Get-AzTag -ResourceId $r.ResourceId -ErrorAction SilentlyContinue).Properties.TagsProperty
            $output = -join ("$([char]0x251C) ", $r.Name, " (", $resourceTags.Count, " tags)")

            #init countaer vars
            $addedResourceInitial = $tagsAdded
            $overwrittenResourceInitial = $tagsModified

            Write-Host "|       " -NoNewline
            Write-Host $output
    
            if ($null -ne $resourceTags) {
                foreach ($key in $resourceTags.Keys) {
                    if ($null -eq $groupTags -or -not($groupTags.ContainsKey($key))) {
                        #these are existing tags that are not to be updated
                        $output = -join ("$([char]0x251C) ", $key, ", ", $resourceTags[$key])

                        Write-Host "|       |   " -NoNewline
                        Write-Host $output -ForegroundColor Green
                    }
                    elseif ($groupTags.ContainsKey($key) -and ($resourceTags[$key] -ne $groupTags[$key] -and $null -ne $resourceTags[$key])) {
                        #if tag values are different
                        $output = -join ("$([char]0x251C) ", $key, ", ", $resourceTags[$key])
    
                        Write-Host "|       |   " -NoNewline
                        Write-Host $output -ForegroundColor Blue
                    }
                }
                foreach ($key in $groupTags.Keys) {
                    if (-not($resourceTags.ContainsKey($key)) -and $appendTags) {
                        #add these tags only if we are appending
                        $output = -join ("$([char]0x251C) ", $key, ", ", $groupTags[$key])
                        $resourceTags.Add($key, $groupTags[$key])
                        $tagsAdded++

                        Write-Host "|       |   " -NoNewline
                        Write-Host $output -ForegroundColor Yellow
                    }
                    else {
                        if ($resourceTags[$key] -eq $groupTags[$key]) {
                            #this key is up-to-date do nothing
                            $output = -join ("$([char]0x251C) ", $key, ", ", $groupTags[$key])

                            Write-Host "|       |   " -NoNewline
                            Write-Host $output -ForegroundColor DarkGreen
                        }
                        elseif (-not($resourceTags[$key] -eq $groupTags[$key]) -and $overwriteTags) {
                            #overwite exising tag with new value
                            $output = -join ("$([char]0x251C) ", $key, ", ", $groupTags[$key])
                            $resourceTags.Remove($key) | Out-Null
                            $resourceTags.Add($key, $groupTags[$key]) | Out-Null
                            $tagsModified++

                            Write-Host "|       |   " -NoNewline
                            Write-Host $output -ForegroundColor Magenta
                        }
                    }
                }
            }
            
            #check if we actually made any changes
            if ($addedResourceInitial -ne $tagsAdded -or $overwrittenResourceInitial -ne $tagsModified) {
                #try to update the tags but if we fail oh well
                try {
                    New-AzTag -ResourceId $r.ResourceId -Tag $resourceTags -ErrorAction Stop | Out-Null
                    Write-Host "|       |   " -NoNewline
                    Write-Host "$([char]0x231E) Tags propogated succesfully" -ForegroundColor Cyan
                }
                catch {
                    Write-Host "|       |   " -NoNewline
                    Write-Host "$([char]0x231E) Error tags could not be updated" -ForegroundColor Red
                    $errors++
                    $errorResources.Add($r.Name)
                }
            }
            
            Write-Host "|       |   "
        }

        Write-Host "|"
    }

    #print the stats
    Write-Host "Propagation complete" -ForegroundColor Cyan
    Write-Host "ADDED TAGS: $tagsAdded" -ForegroundColor Yellow
    Write-Host "OVERWRITTEN TAGS: $tagsModified" -ForegroundColor Magenta
    Write-Host "ERRORS: $errors " -ForegroundColor Red
    
    foreach ($key in $errorResources) {
        #for each error
        $output = -join ("$([char]0x251C) ", $key)

        Write-Host $output -ForegroundColor Red
    }
}

function Find-LocateOutdatedDependicies {
    #first we need params
    param (
        [Parameter(Mandatory = $true)]
        [string] $orgId,
        [switch] $results
    )

    #this will require you to log into azure devops
    Login

    #define organization base url, api version, and other vars
    $rootPath = Get-Location
    $orgUrl = "https://dev.azure.com/$orgId"
    $pat = (Get-AzAccessToken -ResourceUrl "499b84ac-1321-427f-aa17-267ca6975798").Token
    $queryString = "api-version=5.1"

    #create header with PAT
    $token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($pat)"))
    $header = @{authorization = "Basic $token" }

    #get the project
    $projectsUrl = "$orgUrl/_apis/projects?$queryString"

    try {
        $projects = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $header
    }
    catch { 
        Write-Host "Error, organization name invalid" -ForegroundColor Red
        exit 
    }
    
    Write-Host "[A] All" -ForegroundColor Yellow
    $projects.value | ForEach-Object { $i = 0 } {

        Write-Host "[$i] " -NoNewline -ForegroundColor Yellow
        Write-Host $_.name

        $i++
    } { $i-- }

    #handle the project selecton input
    function getIdChoice {
        $id = Read-Host "Select project"

        switch -Regex ($id) {
            "a" {
                return $null
            }
            "[0-$i]" {
                return $id
            }
            Default {
                #try again
                getIdChoice
            }
        }
    }

    $handledInput = getIdChoice
    $projectId = & { if ($null -ne $handledInput) { $projects.value[$handledInput].id }else { $null } };

    $reposUrl = "$orgUrl/$projectId/_apis/git/repositories?$queryString"

    #handle the local directiory selection
    function getDirectoryChoice {
        $path = Read-Host "Provide a local temp directory"
        $p = & { if (Test-Path $path) { $path }else { getDirectoryChoice } }
    
        return Resolve-Path -Path $p
    }
    
    $targetPath = getDirectoryChoice

    #install posh git just in case
    if (!(Get-Module -ListAvailable -Name "posh-git")) {
        Write-Host "posh-git not installed, installing now..." -ForegroundColor Red
        Install-Module posh-git -Scope CurrentUser -Force
        Import-Module posh-git
    } 

    $repos = Invoke-RestMethod -Uri $reposUrl -Method Get -ContentType "application/json" -Headers $header
    $repos.value | ForEach-Object { $j = 0 } {
        $repoName = $_.name
        Write-Host "Repo #${j}:" $_.project.name "  --  " $repoName -ForegroundColor Cyan

        $localPath = New-Item -Name $repoName -ItemType "directory" -Path "$targetPath" -Force
        $workingPath = New-Item -Name "WORKING_$repoName" -ItemType "directory" -Path "$targetPath" -Force

        #run the git command
        git clone $_.remoteUrl $localPath --quiet | Wait-Process

        Set-Location $localPath
        $fileArray = Get-ChildItem $localPath -Recurse -File -Include "*.csproj"
        $fileArray | ForEach-Object { Move-Item -Path $_.FullName -Destination $workingPath } | Wait-Process

        #reset and clean the local repo
        Set-Location $rootPath
        Remove-Item $localPath -Recurse -Force -Confirm:$false

        #TODO:
        #for each we should do something like 
        #git .csproj
        #check .csproj
        #mutate var


        #Remove-Item $workingPath -Recurse -Force
        $j++
    }

    #now use git to get only the certain .csproj files

    #reset the location
    Set-Location $rootPath
}


function Get-GenerateCSV {
    #this will require you to log into azure devops
    Login
    $pat = (Get-AzAccessToken).Token

    #define organization base url, api version
    $orgUrl = "https://management.azure.com"
    $queryString = "api-version=2020-01-01"
    $header = @{authorization = "Bearer $pat" }

    #defines the master list of all the tags
    $list = @{}

    #get the subs
    $subUrl = "$orgUrl/subscriptions?$queryString"
    $subResponse = Invoke-RestMethod -Uri $subUrl -Method Get -ContentType "application/json" -Headers $header

    #for each subscription
    $subResponse.value | ForEach-Object {
        #make a custom object for our tags
        $tempTags = [PSCustomObject]@{Application = $_.tags.Application; Client = $_.tags.Client; CostCenter = $_.tags.CostCenter }

        if ($null -eq $tempTags.Application ) {
            $tempTags.Application = "undefined"
        }

        if ($null -eq $tempTags.Client ) {
            $tempTags.Client = "undefined"
        }

        if ($null -eq $tempTags.CostCenter ) {
            $tempTags.CostCenter = "undefined"
        }

        #first add the tags and give us the key just in case
        $list.Add($_.id, $tempTags)
        $subKey = $_.id

        #now we get the resource groups in the sub
        $groupUrl = "$orgUrl$subkey/resourcegroups?$queryString"
        $groupResponse = Invoke-RestMethod -Uri $groupUrl -Method Get -ContentType "application/json" -Headers $header

        #for each group
        $groupResponse.value | ForEach-Object {
            #make a custom object for our tags
            $tempTagsGroup = [PSCustomObject]@{Application = $_.tags.Application; Client = $_.tags.Client; CostCenter = $_.tags.CostCenter }

            if ($null -eq $tempTagsGroup.Application ) {
                $tempTagsGroup.Application = $tempTags.Application
            }

            if ($null -eq $tempTagsGroup.Client ) {
                $tempTagsGroup.Client = $tempTags.Client
            }

            if ($null -eq $tempTagsGroup.CostCenter ) {
                $tempTagsGroup.CostCenter = $tempTags.CostCenter
            }

            #first add the tags and give us the key just in case
            $list.Add($_.id, $tempTagsGroup)
            $groupKey = $_.id

            #now we get the resources in the group
            $resUrl = "$orgUrl$groupKey/resources?$queryString"
            $resResponse = Invoke-RestMethod -Uri $resUrl -Method Get -ContentType "application/json" -Headers $header
        }
    }

    $list.GetEnumerator() | ForEach-Object { [PSCustomObject]@{key = $_.Key; value = ConvertTo-Json $_.Value } } | Export-Csv -Path .\temp\export.csv -NoTypeInformation

    print the master list
    $list.GetEnumerator() | ForEach-Object {
        Write-Host $_.Key " " -ForegroundColor Cyan -NoNewline
        Write-Host $_.Value
    }
}

Export-ModuleMember -Function Format-PropagateTagsToChildren, Format-PropagateTagsWithInheritance, Find-LocateOutdatedDependicies, Get-GenerateCSV