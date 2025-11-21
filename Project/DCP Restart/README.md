# DCP Restart Tool - User Guide

## Version 2.0.0 - PowerShell Edition

---

## Overview

The **DCP Restart Tool** is designed to automate the restart cycle of the **Dualog Core Pro (duacorepro)** Windows service. It starts the service, waits for a specified period, then stops the service.

---

## What's New in Version 2.0.0

### Major Improvements:

**Automatic Administrator Elevation**
- Script automatically requests administrator privileges if needed
- No need to manually "Run as Administrator"

**Service Validation**
- Verifies service exists before attempting operations
- Shows clear error messages if service is not found

**Real-time Status Monitoring**
- Displays service status before, during, and after operations
- Color-coded status indicators (Green=Running, Red=Stopped)
- Periodic health checks during wait period

**Visual Progress Tracking**
- Progress bar during wait period
- Shows elapsed time and remaining time
- Displays start and end timestamps

**Interactive Wait Time Prompt**
- Prompts user for wait time in minutes before each run
- Shows common options (1, 5, 10, 15 minutes)
- Validates input with helpful error messages
- Supports decimal values (e.g., 2.5 minutes)
- Uses default (8.33 minutes) if no input provided

**Comprehensive Logging**
- Automatic log file generation with timestamps
- Records all operations and errors
- Can be enabled/disabled by editing the script

**Better Error Handling**
- Detailed error messages
- Graceful handling of service failures
- Validates service state transitions

---

## Quick Start

### Basic Usage:

1. Right-click `DCPRestart.ps1`
2. Select **"Run with PowerShell"**
3. Click **"Yes"** on UAC prompt (if shown)
4. Enter desired wait time in minutes (or press Enter for default)
5. Wait for the process to complete

---

## Files Included

| File | Description |
|------|-------------|
| `DCPRestart.ps1` | Main PowerShell script |
| `DCPRestart.bat` | Legacy batch script (original) |
| `README.md` | This user guide |
| `DCPRestart.log` | Log file (auto-generated) |

---

## Configuration

### Default Settings

The script uses these built-in defaults:

- **Service Name**: `duacorepro` (Dualog Core Pro)
- **Default Wait Time**: 8.33 minutes (500 seconds)
- **Logging**: Enabled
- **Log File**: `DCPRestart.log` (in script directory)

### Wait Time Options

You'll be prompted each time you run the script. Common options:

| Minutes | Use Case |
|---------|----------|
| 1 | Quick test/restart |
| 5 | Short maintenance window |
| 8.33 | Default setting |
| 10 | Standard restart cycle |
| 15 | Extended warm-up period |
| 30 | Long-running process |

### Customizing Service Name

To use this script for a different Windows service, edit the script (line 30):

```powershell
$serviceName = "duacorepro"  # Change to your service name
```

---

## How It Works

### Process Flow:

**1. Administrator Check**
   - Verifies script is running with admin rights
   - Auto-elevates if necessary

**2. User Input - Wait Time**
   - Prompts user for wait time in minutes
   - Shows common options (1, 5, 10, 15 minutes)
   - Validates input is a valid number between 0 and 1440 (24 hours)
   - Uses default (8.33 minutes) if user presses Enter
   - Supports decimal values (e.g., 2.5 for 2 minutes 30 seconds)
   - Converts minutes to seconds for processing

**3. Service Validation**
   - Checks if "duacorepro" service exists
   - Shows error if service not found

**4. Initial Status Check**
   - Displays current service status
   - Logs initial state

**5. Start Service (Step 1)**
   - Starts the service if not already running
   - Waits 3 seconds for service to initialize
   - Verifies service started successfully
   - Logs the operation

**6. Wait Period (Step 2)**
   - Waits for user-specified time
   - Shows progress bar with countdown
   - Performs health checks every 60 seconds
   - Alerts if service stops unexpectedly
   - Logs the wait period

**7. Stop Service (Step 3)**
   - Stops the service using force flag
   - Waits 3 seconds for service to stop
   - Verifies service stopped successfully
   - Logs the operation

**8. Summary**
   - Displays final service status
   - Shows log file location
   - Completes with success message

---

## Sample Output

```
==============================================================================================
Dualog Core Pro (DCP) Service Restart Tool - Version 2.0.0
PowerShell Edition - Running as Administrator
==============================================================================================

==============================================================================================
Wait Time Configuration
==============================================================================================

How long should the service run before stopping?

Common options:
  1 minute   - Quick test
  5 minutes  - Short maintenance
  10 minutes - Standard restart
  15 minutes - Extended warm-up

Enter wait time in minutes [Default: 8.33]: 10
Using: 10 minutes

Service Name: duacorepro
Wait Time: 600 seconds (10 minutes)

Checking if service exists...
Service found successfully.

Current Service Status: Running

==============================================================================================
STEP 1: Starting Service
==============================================================================================

Service is already running. No action needed.
[2024-10-29 14:30:00] Service was already running

==============================================================================================
STEP 2: Wait Period
==============================================================================================

Waiting for 500 seconds before stopping the service...
Start Time: 14:30:00

[Progress bar displays here with countdown]

Wait period completed.
End Time: 14:38:20

==============================================================================================
STEP 3: Stopping Service
==============================================================================================

Stopping service 'duacorepro'...
Service stop command issued successfully.
Service Status: Stopped
[2024-10-29 14:38:23] Service status after stop: Stopped

==============================================================================================
OPERATION COMPLETED
==============================================================================================

Final Service Status: Stopped

Log file saved to: E:\...\DCP Restart\DCPRestart.log

[2024-10-29 14:38:23] Script completed successfully
Press any key to continue . . .
```

---

## Prerequisites

### System Requirements:
- **Operating System**: Windows Server 2012 or later / Windows 10 or later
- **PowerShell**: Version 5.1 or later (built into Windows)
- **Permissions**: Administrator privileges
- **Service**: Dualog Core Pro (duacorepro) must be installed

### Service Requirements:
- Service name: `duacorepro`
- Service must be installed and registered with Windows

---

## Troubleshooting

### Error: "Service 'duacorepro' was not found"

**Problem:** The Dualog Core Pro service is not installed or has a different name

**Solutions:**
1. Verify Dualog Core Pro is installed on this machine
2. Check Windows Services (services.msc) for the exact service name
3. Edit the script (line 30) to update the service name if needed
4. Ensure you're running on the correct server

---

### Error: "Failed to start service"

**Problem:** Service cannot be started

**Possible Causes:**
- Service is disabled
- Service dependencies are not running
- Application files are missing or corrupted
- Insufficient permissions

**Solutions:**
1. Check service status in Windows Services (services.msc)
2. Verify service startup type is not "Disabled"
3. Check Windows Event Viewer for detailed error messages
4. Review service dependencies
5. Verify Dualog Core Pro installation

---

### Error: "Failed to stop service"

**Problem:** Service cannot be stopped

**Possible Causes:**
- Service is hung or not responding
- Service is locked by another process
- Insufficient permissions

**Solutions:**
1. Wait a few moments and try again
2. Check Windows Task Manager for related processes
3. Review service dependencies
4. Check Windows Event Viewer for errors
5. Contact Dualog support if issue persists

---

### Warning: "Service stopped unexpectedly during wait period"

**Problem:** Service crashed or was stopped by another process during the wait period

**What Happened:**
- The script detected the service is no longer running
- Another process or user may have stopped it
- The service may have crashed

**Solutions:**
1. Check Windows Event Viewer for crash details
2. Review Dualog Core Pro application logs
3. Verify no other scripts or users are managing the service
4. Contact Dualog support if crashes persist

---

### Script Closes Immediately

**Problem:** PowerShell window closes without showing output

**Solutions:**
- Right-click script and select "Run with PowerShell" (not "Run")
- Or manually open PowerShell, navigate to folder, run: `.\DCPRestart.ps1`
- Check PowerShell execution policy: `Get-ExecutionPolicy`

---

### UAC Prompt Doesn't Appear

**Problem:** Script doesn't request administrator privileges

**Solutions:**
- Manually right-click script → "Run as Administrator"
- Check if UAC is disabled in Windows settings
- Verify you're logged in with an account that can elevate

---

## Advanced Usage

### Running from Command Line

```powershell
# Run the script
.\DCPRestart.ps1
# You will be prompted to enter wait time each time
```

### Scheduled Task

To run this script on a schedule:

1. Open **Task Scheduler**
2. Create new task
3. Set trigger (e.g., daily at 3:00 AM)
4. Set action:
   - **Program**: `powershell.exe`
   - **Arguments**: `-NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\DCPRestart.ps1"`
   - **Run with highest privileges**: Checked
5. Save the task

### Customizing for Different Services

To use this script for other Windows services:

1. Open `DCPRestart.ps1` in a text editor
2. Edit line 30 to change the `$serviceName` variable
3. Save the file
4. Run the script (you can still set wait time interactively)

---

## Logging

### Log File Format:

```
[2024-10-29 14:30:00] Service was already running
[2024-10-29 14:30:00] Starting wait period of 500 seconds
[2024-10-29 14:38:20] Wait period completed
[2024-10-29 14:38:20] Attempting to stop service 'duacorepro'
[2024-10-29 14:38:23] Service stop command successful
[2024-10-29 14:38:23] Service status after stop: Stopped
[2024-10-29 14:38:23] Script completed successfully
```

### Log Retention:

- Logs are appended to the same file
- File grows with each execution
- Manually delete or archive old logs as needed

### Disabling Logging:

To disable logging, edit `DCPRestart.ps1` (line 32):
```powershell
$enableLogging = $false  # Change from $true to $false
```

---

## Comparison: Old vs. New

| Feature | Original (BAT) | New (PS1) |
|---------|---------------|-----------|
| Administrator Check | No | Yes (auto-elevate) |
| Interactive User Prompt | No | Yes (wait time) |
| Service Validation | No | Yes |
| Status Monitoring | No | Yes (real-time) |
| Progress Indicator | No | Yes (progress bar) |
| Error Handling | Basic | Comprehensive |
| Logging | No | Yes (optional) |
| Color Output | No | Yes |
| Service Health Checks | No | Yes |
| Input Validation | No | Yes |
| Customizable | No | Yes (edit script) |

---

## Safety Notes

**Administrator Privileges**
- This script requires admin rights to control Windows services
- Only run on authorized systems
- Verify you're on the correct server before running

**Service Dependencies**
- Stopping DCP may affect dependent services or applications
- Ensure no critical operations are running before executing
- Coordinate with other administrators

**Production Systems**
- Test on non-production systems first
- Schedule during maintenance windows
- Have a rollback plan

**Monitoring**
- Monitor service startup after script completes
- Check application logs for errors
- Verify normal operation after restart

---

## Support

For issues or questions:
- Review this documentation
- Check Windows Event Viewer for detailed errors
- Review Dualog Core Pro application logs
- Contact your Dualog administrator
- Contact Dualog technical support

---

## Version History

**Version 2.0.0** (PowerShell Edition)
- Complete rewrite in PowerShell
- Added administrator privilege auto-elevation
- Added interactive user prompt for wait time
- Added input validation for user inputs
- Added service validation and error handling
- Added real-time status monitoring
- Added progress tracking with visual feedback
- Added comprehensive logging system
- Added color-coded output
- Added periodic health checks
- Improved user experience

**Version 1.0.0** (Legacy Batch)
- Original batch script
- Basic start/wait/stop functionality
- Fixed 500-second timeout

---

**End of User Guide**
