# Scheduled Task Daily Health Report
# Scheduled Task Daily Health Report

## Prerequisites

* Windows Server/Windows environment
* PowerShell 5.1+
* Windows Task Scheduler
* Administrator or appropriate permissions to query scheduled tasks and event logs
* Blat command-line email utility
* Access to the Windows Task Scheduler Operational Event Log

---

## Tools / Software Used

| Tool                       | Purpose                                                      |
| -------------------------- | ------------------------------------------------------------ |
| **PowerShell**             | Automates scheduled task health checks and report generation |
| **Windows Task Scheduler** | Executes the monitoring script daily                         |
| **Get-ScheduledTask**      | Retrieves configured scheduled tasks                         |
| **Get-ScheduledTaskInfo**  | Retrieves task execution information                         |
| **Windows Event Viewer**   | Provides additional failure information                      |
| **Blat**                   | Sends the generated health report through email              |

---

## Purpose

This project automates the daily monitoring of administrator-created Windows Scheduled Tasks.

The PowerShell script checks scheduled tasks that **actually executed during the previous 24 hours** and determines whether they completed successfully.

The script generates a daily email report with an overall status:

* **SUCCESS** — All monitored tasks that ran during the review period completed successfully.
* **ALERT** — One or more monitored tasks failed.

The workflow also checks the **Task Scheduler Operational Event Log** for additional information when a failure is detected.

---

## Workflow with Steps

### 1. Task Scheduler Launches the Script

Windows Task Scheduler executes the PowerShell script once per day.

```text
Program:
powershell.exe

Arguments:
-ExecutionPolicy Bypass -File "<SCRIPT_FILE_PATH>\TaskHealthReport.ps1"
```

The scheduled task is configured to run at the organization's designated daily execution time.

---

### 2. Calculate the Monitoring Window

The script establishes a 24-hour monitoring window.

```powershell
$Since = (Get-Date).AddDays(-1)
```

This ensures the script only evaluates tasks that executed during the previous 24 hours.

Example:

```text
Current Time:       <CURRENT_DATE_TIME>
Review Period:      <PREVIOUS_DATE_TIME> → <CURRENT_DATE_TIME>
```

---

### 3. Retrieve Scheduled Tasks

The script retrieves enabled Windows Scheduled Tasks using:

```powershell
Get-ScheduledTask
```

System-generated tasks are filtered out so that the monitoring process focuses on administrator-created tasks.

Example exclusions:

```text
\Microsoft\*
\Windows\*
<EXCLUDED_TASK_PATH>
```

---

### 4. Evaluate Task Execution Information

Each remaining scheduled task is evaluated using:

```powershell
Get-ScheduledTaskInfo
```

The script collects:

* Task Name
* Task Path
* Last Run Time
* Last Task Result

---

### 5. Determine Whether the Task Ran

The script compares the task's last execution time against the 24-hour monitoring window.

```powershell
$Info.LastRunTime -ge $Since
```

Tasks that did not execute during the review period are ignored.

This prevents a task with a weekly or otherwise infrequent schedule from incorrectly being reported as failed simply because it did not run that day.

---

### 6. Determine Task Success or Failure

The script evaluates:

```powershell
$Info.LastTaskResult
```

A result code of:

```text
0 = Successful
```

Any other result code is treated as a failure.

Successful tasks are recorded with:

```text
Task Name
Task Path
Last Run Time
```

Failed tasks are recorded with:

```text
Task Name
Task Path
Last Run Time
Result Code
```

---

### 7. Investigate Failed Tasks

When a failed task is detected, the script searches the Windows Task Scheduler Operational Event Log for additional information.

```text
Microsoft-Windows-TaskScheduler/Operational
```

The workflow checks relevant Task Scheduler failure events, including:

| Event ID | Purpose                                    |
| -------- | ------------------------------------------ |
| 103      | Task failed to start                       |
| 111      | Task was terminated before completion      |
| 118      | Task failed to start at its scheduled time |
| 202      | Task action failed to launch               |
| 203      | Task action returned a failure result      |

Relevant event information is added to the health report.

---

### 8. Generate the Health Report

The script builds an email report containing:

**General Information**

* Computer Name
* Report Generation Time
* Review Period
* Overall Task Status

**Failed Tasks**

* Task Name
* Last Run Time
* Result Code
* Event ID
* Event Time

**Successful Tasks**

* Task Name
* Last Run Time

---

### 9. Determine Report Status

The email subject is generated based on the results.

```text
SUCCESS - Scheduled Task Health Report
```

or

```text
ALERT - Scheduled Task Health Report
```

---

### 10. Send the Report

The script launches **Blat** to send the generated report.

Sensitive configuration values should be stored outside of the public repository.

```text
Recipient: <RECIPIENT_EMAIL>
Sender:    <SENDER_EMAIL>
Subject:   <GENERATED_SUBJECT>
Body:      <GENERATED_REPORT>
```

The script then exits and waits for the next scheduled execution.

---

## Overview of Workflow

```text
Windows Task Scheduler
        |
        v
Launch PowerShell
        |
        v
Execute TaskHealthReport.ps1
        |
        v
Calculate Previous 24 Hours
        |
        v
Retrieve Scheduled Tasks
        |
        v
Filter System/Excluded Tasks
        |
        v
Check Last Run Time
        |
        v
Check Result Code
        |
        +----------------------+
        |                      |
        v                      v
    SUCCESS                 FAILURE
        |                      |
        v                      v
Add to Success List     Check Event Log
        |                      |
        +----------+-----------+
                   |
                   v
          Generate Health Report
                   |
                   v
              Launch Blat
                   |
                   v
             Send Email
                   |
                   v
              Script Ends
```

---

## Summary

This project demonstrates how PowerShell can be used to automate **Windows task monitoring, log analysis, and operational reporting**.

The workflow:

1. Runs automatically through Windows Task Scheduler.
2. Reviews the previous 24 hours of task execution history.
3. Filters out unnecessary Windows system tasks.
4. Identifies successful and failed task executions.
5. Investigates failures through Windows Event Logs.
6. Generates a structured health report.
7. Sends the report automatically through Blat.

The result is a lightweight monitoring workflow that provides administrators with **daily visibility into the health of critical scheduled tasks without requiring manual inspection of Task Scheduler or Event Viewer.**
