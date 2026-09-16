# How far back to check
$Since = (Get-Date).AddDays(-1)

# Get only custom scheduled tasks
# Excludes Microsoft, Windows built-in tasks, and designated excluded tasks
$Tasks = Get-ScheduledTask | Where-Object {
    $_.State -ne "Disabled" -and
    $_.TaskPath -notlike "\Microsoft\*" -and
    $_.TaskPath -notlike "\Windows\*" -and
    $_.TaskName -ne "<EXCLUDED_TASK_1>" -and
    $_.TaskName -ne "<EXCLUDED_TASK_2>"
}

# Store task results
$FailedTasks = @()
$SuccessfulTasks = @()

foreach ($Task in $Tasks)
{
    try
    {
        $Info = Get-ScheduledTaskInfo `
            -TaskName $Task.TaskName `
            -TaskPath $Task.TaskPath

        # Only evaluate tasks that actually ran during the last 24 hours
        if ($Info.LastRunTime -ge $Since)
        {
            if ($Info.LastTaskResult -eq 0)
            {
                $SuccessfulTasks += [PSCustomObject]@{
                    TaskName = $Task.TaskName
                    Path     = $Task.TaskPath
                    LastRun  = $Info.LastRunTime
                }
            }
            else
            {
                $FailedTasks += [PSCustomObject]@{
                    TaskName = $Task.TaskName
                    Path     = $Task.TaskPath
                    LastRun  = $Info.LastRunTime
                    Result   = $Info.LastTaskResult
                }
            }
        }
    }
    catch
    {
        # Ignore tasks that cannot be queried
    }
}


# Build email report
$Body = "Scheduled Task Daily Health Report`r`n"
$Body += "================================`r`n`r`n"

$Body += "Computer Name: $env:COMPUTERNAME`r`n"
$Body += "Report Generated: $(Get-Date)`r`n"
$Body += "Review Period: Last 24 Hours`r`n`r`n"


# Failed Tasks Section
if ($FailedTasks.Count -gt 0)
{
    $Body += "STATUS: FAILED TASKS DETECTED`r`n"
    $Body += "Total Failed Tasks: $($FailedTasks.Count)`r`n`r`n"

    foreach ($Task in $FailedTasks)
    {
        # Find matching Task Scheduler event
        $TaskEvent = Get-WinEvent -FilterHashtable @{
            LogName   = "Microsoft-Windows-TaskScheduler/Operational"
            StartTime = $Since
        } -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Message -like "*$($Task.TaskName)*" -and
            $_.Id -in 103,111,118,202,203
        } |
        Select-Object -First 1


        $Body += "Task Name: $($Task.TaskName)`r`n"
        $Body += "Last Run: $($Task.LastRun)`r`n"
        $Body += "Result Code: $($Task.Result)`r`n"


        if ($TaskEvent)
        {
            $Body += "Event ID: $($TaskEvent.Id)`r`n"
            $Body += "Event Time: $($TaskEvent.TimeCreated)`r`n"
        }
        else
        {
            $Body += "Event ID: No matching failure event found`r`n"
        }

        $Body += "`r`n"
    }


    # Event ID Reference
    $Body += "TASK SCHEDULER EVENT ID REFERENCE`r`n"
    $Body += "--------------------------------`r`n"
    $Body += "103 - Task failed to start because Task Scheduler was unable to launch the task.`r`n"
    $Body += "111 - Task was terminated before completion due to an unexpected interruption.`r`n"
    $Body += "118 - Task did not start at its scheduled time and was considered missed.`r`n"
    $Body += "202 - Task Scheduler was unable to launch the configured action or program.`r`n"
    $Body += "203 - Task action started but returned a failure status code.`r`n`r`n"
}
else
{
    $Body += "STATUS: SUCCESS`r`n"
    $Body += "No failed custom scheduled tasks were detected.`r`n`r`n"
}


# Successful Tasks Section
$Body += "SUCCESSFUL TASKS`r`n"
$Body += "--------------------------------`r`n"


if ($SuccessfulTasks.Count -gt 0)
{
    $Body += "Total Successful Tasks: $($SuccessfulTasks.Count)`r`n`r`n"

    foreach ($Task in $SuccessfulTasks)
    {
        $Body += "Task Name: $($Task.TaskName)`r`n"
        $Body += "Last Run: $($Task.LastRun)`r`n"
        $Body += "`r`n"
    }
}
else
{
    $Body += "No successful custom scheduled tasks were detected during this period.`r`n"
}


# Determine email subject
if ($FailedTasks.Count -gt 0)
{
    $Subject = "ALERT - Scheduled Task Health Report"
}
else
{
    $Subject = "SUCCESS - Scheduled Task Health Report"
}


# Send email using Blat
& "<BLAT_EXECUTABLE_PATH>\blat.exe" `
    -to "<RECIPIENT_EMAIL>" `
    -subject "$Subject" `
    -body "$Body" `
    -f "<SENDER_EMAIL>"