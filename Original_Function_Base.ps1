<#
        Source
        https://old.reddit.com/r/PowerShell/comments/wdfp5m/what_have_you_done_with_powershell_this_month/ikwp043/?context=3

        https://old.reddit.com/u/89netraM
 
        I've written a script that helps me track the time I've worked. I'm terrible at "time math". 
        Unless I arrive exactly on the hour and take exactly one hour lunch break I'll be hours off 
        when figuring out when to go home.

        With my new script I'll write "Enter-Work" when I arrive, "Start-Break" and "Stop-Break" for breaks, 
        and "Get-WorkExit" to calculate the time I can go home. I've also added "Exit-Work" so I can keep 
        track of if I work too long/short in the long run.
#>

### Common path tp work day JSON
$script:File_Workday = '~/work-time.json'
Function Enter-Work {
    <#
            .SYNOPSIS
            Start your day.
            .DESCRIPTION
            Starts your workday Clock to track hours.
            .PARAMETER Start
            [DateTime] Value for time to start - not required.
            .EXAMPLE
            Enter-Work
            Starts your workday clock
            .INPUTS
            DateTime
    #>
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$false,Position=0)][DateTime]$Start)

    If ($null -eq $Start) {$Start = Get-Date}
    $workTime = Get-Content -Path $File_Workday | ConvertFrom-Json -NoEnumerate

    ForEach ($day in $workTime) {
        $dayStart = Get-Date -Date $day.start
        If ($Start.Date -eq $dayStart.Date) {
            Write-Error -Message 'You have already started today'
            return
        }
    }

    $workTime += @{start = $Start.ToString('yyyy-MM-dd HH:mm:ss')}
    ConvertTo-Json -InputObject $workTime -Depth 4 | Set-Content -Path $File_Workday
    Write-Host ('Working 7.5h with a 1h break means you can go home at {0}' -f $Start.AddHours(8.5).ToString('HH:mm'))
}

Function Start-Break {
    <#
            .SYNOPSIS
            Start a break time.
            .DESCRIPTION
            Takes note of when you start a break time.
            .PARAMETER Start
            (Optional) Specify the [DateTime] you started your break.
            .EXAMPLE
            Start-Break
            .INPUTS
            [DateTime]
    #>


    [CmdletBinding()]
    Param ([Parameter(Mandatory=$false,Position=0)][DateTime]$Start)

    If ($null -eq $Start) {$Start = Get-Date}
    $workTime = Get-Content -Path $File_Workday | ConvertFrom-Json -NoEnumerate

    If ($null -eq $workTime[-1].breaks) {$workTime[-1] | Add-Member -MemberType NoteProperty -Name 'breaks' -Value @()}

    If ($workTime[-1].breaks.Count -gt 0 -and $workTime[-1].breaks[-1].Count -eq 1) {
        Write-Error -Message 'You are currently on break'
        return
    }

    $workTime[-1].breaks += , @($Start.ToString('yyyy-MM-dd HH:mm:ss'))
    ConvertTo-Json -InputObject $workTime -Depth 4 | Set-Content -Path $File_Workday
    Write-Host ('Break started at {0}' -f $Start.ToString('HH:mm'))
}

Function Stop-Break {
    <#
            .SYNOPSIS
            End your Break.
            .DESCRIPTION
            Takes note of when you end a break time.
            .PARAMETER End
            (Optional) Describe parameter -End.
            .EXAMPLE
            Stop-Break
            .INPUTS
            [DateTime]
    #>
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$false,Position=0)][DateTime]$End)

    $Hm = 'HH:mm'
    If ($null -eq $End) {$End = Get-Date}
    $workTime = Get-Content -Path $File_Workday | ConvertFrom-Json -NoEnumerate

    If ($null -eq $workTime[-1].breaks -or $workTime[-1].breaks -eq 0 -or $workTime[-1].breaks[-1].Count -eq 2) {
        Write-Error -Message "You haven't started any breaks yet"
        return
    }

    $workTime[-1].breaks[-1] += $End.ToString('yyyy-MM-dd HH:mm:ss')
    ConvertTo-Json -InputObject $workTime -Depth 4 | Set-Content -Path $File_Workday
    $breakTime = (Get-Date -Date $workTime[-1].breaks[-1][1]) - (Get-Date -Date $workTime[-1].breaks[-1][0])
    Write-Host ('Break ended at {0} after {1} minutes' -f $End.ToString($Hm), [Math]::Floor($breakTime.TotalMinutes))

    $workEnd = (Get-Date -Date $workTime[-1].start).AddHours(7.5)
    ForEach ($break in $workTime[-1].breaks) {
        $workEnd += (Get-Date -Date $break[1]) - (Get-Date -Date $break[0])
    }
    Write-Host ('With no further breaks you can go home at {0}' -f $workEnd.ToString($Hm))
}

Function Exit-Work {
    <#
            .SYNOPSIS
            Work day has ended.
            .DESCRIPTION
            Make a note that your workday has ended.
            .PARAMETER End
            (Optional) Specify [DateTime] your workday ended.
            .EXAMPLE
            Exit-Work
            .INPUTS
            [DateTime]
    #>
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$false,Position=0)][DateTime]$End)

    If ($null -eq $End) {$End = Get-Date}
    $workTime = Get-Content -Path $File_Workday | ConvertFrom-Json -NoEnumerate

    If ($workTime.Count -eq 0 -or (Get-Date -Date $workTime[-1].start).Date -ne $End.Date) {
        Write-Error -Message "You haven't started working today"
        return
    }
    If ($null -ne $workTime[-1].end) {
        Write-Error -Message "You've already left work today"
        return
    }

    $workTime[-1] | Add-Member -MemberType NoteProperty -Name 'end' -Value $End.ToString('yyyy-MM-dd HH:mm:ss')
    ConvertTo-Json -InputObject $workTime -Depth 4 | Set-Content -Path $File_Workday

    $workEnd = (Get-Date -Date $workTime[-1].start).AddHours(7.5)
    ForEach ($break in $workTime[-1].breaks) {
        $workEnd += (Get-Date -Date $break[1]) - (Get-Date -Date $break[0])
    }
    If ($End -lt $workEnd.AddMinutes(-2.5)) {
        $left = [Math]::Floor(($workEnd - $End).TotalMinutes)
        Write-Host ("You've got {0} minutes left to do today! Better work extra hard tomorrow." -f ($left))
    } ElseIf ($End -ge $workEnd.AddMinutes(2.5)) {
        $extra = [Math]::Floor(($End - $workEnd).TotalMinutes)
        Write-Host ("You've worked {0} minutes too long today! Take it easy tomorrow." -f ($extra))
    } Else {
        Write-Host "You've worked 7.5h today. Good job!"
    }
}

Function Get-WorkEnter {
    $now      = Get-Date
    $workTime = Get-Content -Path $File_Workday | ConvertFrom-Json -NoEnumerate

    If ($workTime.Count -eq 0 -or (Get-Date -Date $workTime[-1].start).Date -ne $now.Date) {
        Write-Error -Message "You haven't started working today"
        return
    }
    If ($null -ne $workTime[-1].end) {Write-Error -Message "You've already left work today"}

    return Get-Date -Date $workTime[-1].start
}

Function Get-WorkExit {
    [CmdletBinding()]
    Param ([Parameter(Mandatory=$false)][Switch]$PrettyPrint)

    $now      = Get-Date
    $workTime = Get-Content -Path $File_Workday | ConvertFrom-Json -NoEnumerate

    If ($workTime.Count -eq 0 -or (Get-Date -Date $workTime[-1].start).Date -ne $now.Date) {
        Write-Error -Message "You haven't started working today"
        return
    }
    If ($null -ne $workTime[-1].end) {
        Write-Error -Message "You've already left work today"
        return $workTime[-1].end
    }

    $workEnd = (Get-Date -Date $workTime[-1].start).AddHours(7.5)
    If ($null -eq $workTime[-1].breaks -or $workTime[-1].breaks.Count -eq 0) {
        $workEnd = $workEnd.AddHours(1)
    } Else {
        ForEach ($break in $workTime[-1].breaks) {
            If ($break.Count -eq 2) {
                $workEnd += (Get-Date -Date $break[1]) - (Get-Date -Date $break[0])
            } Else {
                $workEnd += $now - (Get-Date -Date $break[0])
            }
        }
    }

    If ($PrettyPrint) {
        $timeLeft = $workEnd - $now
        ### Strings
        $TLH_A = (' {0} hours'   -f $timeLeft.Hours)
        $TLM_A = (' {0} minutes' -f $timeLeft.Minutes)
        $TLH_B = (' {0} hours'   -f (-$timeLeft.Hours))
        $TLM_B = (' {0} minutes' -f (-$timeLeft.Minutes))
        $Ye = @{
            ForegroundColor = 'Yellow'
            NoNewLine       = $true
        }
        $Re = @{
            ForegroundColor = 'Red'
            NoNewLine       = $true
        }
        
        If ($now -lt $workEnd.AddMinutes(-2.5)) {
            Write-Host 'You can go home in' -NoNewline
            If ($timeLeft.Hours -gt 0)   {Write-Host $TLH_A @Ye}
            If ($timeLeft.Minutes -gt 0) {Write-Host $TLM_A @Ye}
            Write-Host
        } ElseIf ($now -ge $workEnd.AddMinutes(2.5)) {
            Write-Host 'You should have gone home' -NoNewline
            If ($timeLeft.Hours -lt 0)   {Write-Host $TLH_B @Re}
            If ($timeLeft.Minutes -lt 0) {Write-Host $TLM_B @Re}
            Write-Host ' ago'
        } Else {
            Write-Host 'You can go home now' -NoNewline
        }
    }

    return $workEnd
}
