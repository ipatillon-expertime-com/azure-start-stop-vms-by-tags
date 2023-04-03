<#
    .DESCRIPTION
        Runbook to Start / Stop VMs in a ResourceGroup using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Ivan PATILLON - Oceanet Technology
        LASTEDIT: 19 March 2020

        MUST BE CALLED WITH PARAMETER ResourceGroupList containing list of ResourceGroups to search VMs with Tags
        example : ["my-rg1","my-rg2"]

        Tags needed :
            StartAt (hour time between 0 to 23)
                example : 7
            StopAt (hour time between 0 to 23)
                example : 20
            StartStopDays (8 bits number with higher bit to 0 or 1 for all days)
                example : "111110" or "00111110" for dimanche 0 lundi 1 mardi 1 mercredi 1 jeudi 1 vendredi 1 samedi 0 Everyday 0
                example : "110000" or "00110000" for dimanche 0 lundi 0 mardi 0 mercredi 0 jeudi 1 vendredi 1 samedi 0 Everyday 0
                example : "10000000"             for dimanche 0 lundi 0 mardi 0 mercredi 0 jeudi 0 vendredi 0 samedi 0 Everyday 1
#>

Param 
(    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]  [string[]] $ResourceGroupList=$null
) 

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$days = @("0000001","00000010","00000100","00001000","00010000","00100000","01000000")
$wdays = @("dimanche","lundi","mardi","mercredi","jeudi","vendredi","samedi")

$alldays = "10000000"

"Param : $ResourceGroupList"
if ($null -ne $ResourceGroupList) {
    foreach ($rg in $ResourceGroupList) {
        "rg : $rg"
        $VMList = Get-AzureRmVM -ResourcegroupName $rg -Status
        foreach ($vm in $VMList) {
            $VMStatus = $vm.PowerState
            #"Name : $($vm.name)   -   Status : $($vmStatus)"
            if ( ($vm.tags.keys -contains "StartAt") -and ($vm.tags.keys -contains "StopAt") -and ($vm.tags.keys -contains "StartStopDays")) {
                $StartAt = [int]$VM.Tags.StartAt
                $StopAt = [int]$VM.Tags.StopAt
                $StartStopDays = [string]$VM.Tags.StartStopDays
                # if Tag StartStopDays not defined sets to AllDays
                if ( ( $null -eq $StartStopDays) -or ($StartStopDays -eq "") ) {
                    $StartStopDays=$alldays
                }
                # GMT+1
                #$hour24 = [int](Get-Date -Format "HH")+1
                $hour24 = [int](get-date( [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Romance Standard Time') ) -format HH)
                # 0->dimanche .. 7->samedi
                # get-date Time from Paris Timezone
                $curDay = ([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId( (Get-Date), 'Romance Standard Time')).DayOfWeek.value__
                "VM: $($vm.name)     StartAt: $StartAt     StopAt: $StopAt     CurrentHour: $hour24     StartStopDays: $StartStopDays     CurrentDay: $($days[$curDay])     CurrentWeekDay: $($wdays[$curDay])"
                # if we are matching days
                if ( ([Convert]::ToInt32($days[$curDay],2) -band [Convert]::ToInt32($StartStopDays,2)) -or ([Convert]::ToInt32($allDays,2) -band [Convert]::ToInt32($StartStopDays,2))) {
                    "Days are Matching ! Checking Hours"
                    if ($hour24 -ge $startAt) {
                        if ($startAt -lt $stopAt) {
                            if ($hour24 -lt $stopAt) {
                                if ($vmStatus -notmatch "running") { "<$($vm.name)> Stopped => Starting" ; $vm | Start-AzureRmVM } else { "<$($vm.name)> Already Running"}
                            } else {
                                if ($vmStatus -match "running") { "<$($vm.name)> Running => Stopping" ; $vm | Stop-AzureRmVM -force} else {"<$($vm.name)> Already Stopped" ; }
                            }
                        } else {
                            if ($vmStatus -notmatch "running") { "<$($vm.name)> Stopped => Starting" ; $vm | Start-AzureRmVM } else { "<$($vm.name)> Already Running"}
                        }
                    } else {
                        if ($startAt -lt $stopAt) {
                            if ($vmStatus -match "running") { "<$($vm.name)> Running => Stopping" ; $vm | Stop-AzureRmVM -force} else {"<$($vm.name)> Already Stopped" ; }
                        } else {
                            if ($hour24 -lt $stopAt) {
                                if ($vmStatus -notmatch "running") { "<$($vm.name)> Stopped => Starting" ; $vm | Start-AzureRmVM } else { "<$($vm.name)> Already Running"}
                            } else {
                                if ($vmStatus -match "running") { "<$($vm.name)> Running => Stopping" ; $vm | Stop-AzureRmVM -force} else {"<$($vm.name)> Already Stopped" ; }
                            }
                        }
                    }
                } else { "Days are not Matching ... Nothing to do Today"}
            } else { "<$($vm.name)> not having (StartAt, StopAt) Tags => ignoring VM" }
        }
    }
}
