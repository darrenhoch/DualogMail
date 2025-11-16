# Dualog Webmail Super Script - User Guide

**Version:** 1.0
**Purpose:** Comprehensive tool for fixing webmail database issues and managing Dualog IMAP server operations

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [System Requirements](#system-requirements)
3. [Main Menu Overview](#main-menu-overview)
4. [Feature Guide](#feature-guide)
5. [Troubleshooting](#troubleshooting)
6. [Log Files](#log-files)

---

## Getting Started

### Running the Script

1. Open **PowerShell as Administrator**
2. Navigate to the script directory:
   ```powershell
   cd "E:\OneDrive - Dualog AS\Claude\Project\Webmail - Super script"
   ```
3. Execute the script:
   ```powershell
   .\WebmailSuperScript.ps1
   ```

**Important:** The script must run with administrator privileges to function properly.

---

## System Requirements

- **Operating System:** Windows (with PowerShell 3.0+)
- **Privileges:** Administrator access required
- **Dualog Installation:** Dualog DGS must be installed and configured
- **Database:** Oracle database (for database operations)
- **Optional:** Telnet client (can be enabled via the script)

### Prerequisites

Before running the script, ensure:
- Dualog DGS is properly installed on the system
- Database credentials are stored in Windows Registry at:
  - `HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS\DatabasePassword` (32-bit on 64-bit Windows)
  - `HKLM:\SOFTWARE\Dualog\DGS\DatabasePassword` (standard path)

---

## Main Menu Overview

When you launch the script, you'll see the main menu with the following options:

```
============================================================
         Dualog Webmail Super Script v1.0
         Database Integrity and Maintenance Tool
============================================================

  1. Dualog IMAP Repair script
  2. Dualog IMAP Server Tool
  3. Enable Telnet Client
  4. [Reserved for future option]

  Q. Quit
```

### Menu Options

| Option | Description |
|--------|-------------|
| **1** | Access tools for fixing webmail database issues |
| **2** | Manage IMAP server operations and diagnostics |
| **3** | Enable Windows Telnet client feature |
| **Q** | Exit the script |

---

## Feature Guide

### Option 1: Dualog IMAP Repair Script

Fixes common IMAP-related database issues. Access this menu to:

#### 1.1 Fix Multiple Body Parts Point to Single Mail

**Problem:** Emails have multiple body parts (content, attachments) pointing to a single mail message in the database, causing inconsistencies.

**What it does:**
- Identifies emails with this issue
- Fixes duplicate body part references
- Cleans up orphaned body parts
- Exports a report of all fixed issues

**How to use:**
1. Select option **1** from the main menu
2. Select option **1** from the IMAP Repair menu
3. Wait for the script to identify and fix issues
4. Review the exported report (if generated)

**Notes:**
- Database password is automatically retrieved from registry
- All changes are logged
- An export report is generated for documentation

#### 1.2 Force-Subscribe for Greyed-Out Folders

**Problem:** Users cannot see or access certain email folders (greyed-out) in their mailbox.

**What it does:**
- Identifies folders that are greyed out or unavailable
- Force-subscribes user accounts to these folders
- Restores access to previously inaccessible folders

**How to use:**
1. Select option **1** from the main menu
2. Select option **2** from the IMAP Repair menu
3. Choose to apply to all folders or select specific folders
4. Confirm the operation
5. The script will force-subscribe the selected folders

**Options:**
- **Apply to All Folders:** Subscribes all greyed-out folders for all affected users
- **Select Individual Folders:** Choose specific folders to subscribe to
- The script will ask for confirmation before making changes

---

### Option 2: Dualog IMAP Server Tool

Advanced tools for IMAP server management and diagnostics.

#### 2.1 Telnet to Dualog Local IMAP/SMTP Server

**Purpose:** Test connectivity and diagnose IMAP/SMTP server issues.

**What it does:**
- Tests TCP connection to the IMAP server
- Retrieves and displays server greeting
- Validates IMAP server response
- Logs connection results

**How to use:**
1. Select option **2** from the main menu
2. Select option **1** from the IMAP Server Tool menu
3. Enter the server address (default: `localhost`)
4. Enter the port number (default: `143` for IMAP)
5. The script will test the connection and display results

**Default Settings:**
- Server: `localhost`
- Port: `143` (standard IMAP port)

**Successful Connection Indicators:**
- Green success message displayed
- Server greeting shows "* OK" and "IMAP"
- Connection logged as successful

#### 2.2 Telnet to Dualog Shore Gateway

**Purpose:** Test connectivity to the Dualog Shore Gateway for email relay and integration.

**What it does:**
- Tests TCP connection to Shore Gateway
- Validates gateway responsiveness
- Provides diagnostic information
- Logs connection results

**How to use:**
1. Select option **2** from the main menu
2. Select option **2** from the IMAP Server Tool menu
3. Enter the Shore Gateway server address
4. Enter the port number
5. Review the connection test results

**Note:** Contact Dualog support for Shore Gateway default credentials and port information.

#### 2.3 Change Dualog IMAP Log Level

**Purpose:** Adjust IMAP server logging verbosity for troubleshooting.

**What it does:**
- Changes the detail level of IMAP server logs
- Allows fine-tuned diagnostics
- Helps identify specific issues

**How to use:**
1. Select option **2** from the main menu
2. Select option **3** from the IMAP Server Tool menu
3. Choose desired log level
4. Confirm the change
5. IMAP service will update logging configuration

**Log Levels:**
- **DEBUG:** Most verbose; logs all operations
- **INFO:** Standard logging; logs important events
- **WARNING:** Only logs warnings and errors
- **ERROR:** Only logs errors

**Note:** Higher verbosity levels may impact performance.

#### 2.4 Trigger Dualog IMAP Backup *(Work in Progress)*

**Status:** Not yet fully implemented.

**Purpose:** Create a backup of IMAP mailbox data.

#### 2.5 Trigger Dualog IMAP Restore *(Work in Progress)*

**Status:** Not yet fully implemented.

**Purpose:** Restore IMAP mailbox data from a backup.

#### 2.6 Large Files & Attachments Finder

**Purpose:** Identify large files and email attachments consuming disk space.

**What it does:**
- Searches specified directories for large files
- Searches Outlook for large attachments
- Generates reports of findings
- Helps manage storage and identify potential issues

**How to use:**

**A. Search File System:**
1. Select option **2** from the main menu
2. Select option **6** from the IMAP Server Tool menu
3. Choose **File System Search**
4. Enter the directory path to search (e.g., `C:\Users` or `D:\Mailboxes`)
5. Enter minimum file size in MB (default: 30 MB)
6. Wait for scan to complete
7. Review results and storage summary

**B. Search Outlook:**
1. Select option **2** from the main menu
2. Select option **6** from the IMAP Server Tool menu
3. Choose **Outlook Search**
4. Script will search all Outlook mailboxes
5. Select storage profile if multiple profiles exist
6. Specify minimum attachment size (default: 30 MB)
7. Review results of large attachments found

**Output includes:**
- File/attachment name and size
- Location or folder path
- Total storage consumed
- Actionable recommendations

---

### Option 3: Enable Telnet Client

**Purpose:** Install Windows Telnet client for manual server diagnostics.

**What it does:**
- Enables the built-in Windows Telnet client feature
- Allows manual telnet commands from command line
- Required for some manual diagnostics

**How to use:**
1. Select option **3** from the main menu
2. Review the confirmation prompt
3. Enter **Y** to proceed
4. Script will enable Telnet Client feature
5. Confirmation message will display

**Alternative Methods (if script fails):**
1. Open **Control Panel**
2. Go to **Programs** → **Programs and Features**
3. Click **"Turn Windows features on or off"**
4. Check **"Telnet Client"** and click OK

**Or run command:**
```powershell
dism /online /Enable-Feature /FeatureName:TelnetClient
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Database password not found in registry"

**Cause:** Dualog DGS is not installed or registry keys are missing.

**Solution:**
1. Verify Dualog DGS is installed properly
2. Check registry paths:
   - `HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS\DatabasePassword`
   - `HKLM:\SOFTWARE\Dualog\DGS\DatabasePassword`
3. Contact your system administrator to verify installation
4. Reinstall Dualog DGS if necessary

#### Issue: "Script not running as Administrator"

**Cause:** PowerShell session lacks administrator privileges.

**Solution:**
1. Right-click **PowerShell**
2. Select **"Run as administrator"**
3. Re-run the script

#### Issue: "Cannot connect to IMAP server"

**Cause:** Server is down, incorrect address/port, or firewall blocking.

**Solution:**
1. Verify server is running: Check Dualog IMAP service status
2. Confirm correct server address and port
3. Check Windows Firewall settings
4. Verify network connectivity to server
5. Check server logs for errors

#### Issue: "Telnet client not available"

**Cause:** Windows Telnet feature is not installed.

**Solution:**
1. Use Option **3** from main menu to enable
2. Or manually enable via Control Panel → Programs and Features
3. May require Windows restart after enabling

#### Issue: "Large Files Finder taking too long"

**Cause:** Searching large directories or network paths.

**Solution:**
1. Specify a smaller directory to search
2. Increase minimum file size threshold
3. Exclude network paths and search local drives only
4. Run during off-hours to avoid performance impact

#### Issue: "Oracle database tools not found"

**Cause:** Oracle client or SQL*Plus not installed.

**Solution:**
1. Install Oracle Client on the server
2. Ensure SQL*Plus is in system PATH
3. Verify database connectivity manually:
   ```powershell
   sqlplus username/password@database
   ```

---

## Log Files

### Location

All script activities are logged to:
```
C:\WebmailLogs\WebmailFix_[YYYYMMDD_HHMMSS].log
```

### Log File Format

Each log entry includes:
- **Timestamp:** Date and time of operation
- **Level:** INFO, WARNING, ERROR, or SUCCESS
- **Message:** Description of action or result

**Example:**
```
2024-01-15 14:23:45 [INFO] Webmail Super Script Started
2024-01-15 14:23:46 [SUCCESS] Database password retrieved from registry
2024-01-15 14:24:12 [INFO] User selected Option 1: Dualog IMAP Repair script
2024-01-15 14:25:33 [SUCCESS] Telnet to Dualog local IMAP Server is successful
```

### Log Levels

| Level | Color | Meaning |
|-------|-------|---------|
| **INFO** | White | Informational messages about script operation |
| **SUCCESS** | Green | Operation completed successfully |
| **WARNING** | Yellow | Non-critical issues or alerts |
| **ERROR** | Red | Operation failed or critical issue |

### Viewing Logs

1. Navigate to `C:\WebmailLogs`
2. Open the most recent log file with any text editor
3. Search for ERROR or WARNING to identify issues
4. Share logs with Dualog support if needed

---

## Tips and Best Practices

### Before Running

- ✓ Ensure you have administrator privileges
- ✓ Back up important data before repairs
- ✓ Run during maintenance windows if possible
- ✓ Close any Outlook clients accessing the mailbox
- ✓ Notify users about scheduled maintenance

### During Operation

- ✓ Don't interrupt the script mid-operation
- ✓ Monitor the console output for messages
- ✓ Note any error messages for troubleshooting
- ✓ Allow operations to complete fully

### After Operation

- ✓ Review the generated log file
- ✓ Verify that issues have been resolved
- ✓ Test affected functionality
- ✓ Document any changes made
- ✓ Keep log files for audit trail

### Regular Maintenance

- Run **Option 2.6** (Large Files Finder) monthly to monitor storage
- Check logs weekly for warnings or errors
- Keep Dualog software updated
- Review greyed-out folders quarterly
- Document all repairs and their results

---

## Support and Contact

### For Issues With

- **Dualog Installation/Configuration:** Contact Dualog support
- **Database Connectivity:** Contact your DBA or Dualog support
- **IMAP/SMTP Server Problems:** Contact your email administrator
- **Script Errors:** Check logs and contact your IT department

### Information to Provide

When reporting issues, include:
1. Log file content (from `C:\WebmailLogs`)
2. Error messages seen on screen
3. Steps to reproduce the issue
4. System information (Windows version, Dualog version)
5. Network connectivity details (if applicable)

---

## Version History

- **v1.0** - Initial release
  - IMAP repair tools
  - Server diagnostics
  - Telnet client management
  - Large files finder

---

## Disclaimer

This script is designed for authorized administrators only. Ensure you have proper authorization before running repairs on production systems. Always maintain backups and test in non-production environments first.

---

*Last Updated: 2024*
*Script Version: 1.0*
