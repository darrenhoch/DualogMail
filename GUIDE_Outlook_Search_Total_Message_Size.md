# Outlook Search - Total Message Size Guide

**Feature:** Large Files & Attachments Finder → Outlook Search → Option 2 (Total Message Size)
**Script:** DualogMailTool.ps1
**Menu Path:** Main Menu → Option 2 (IMAP Server Tool) → Option 6 (Large Files Finder) → Option 2 (Outlook)

---

## Table of Contents

1. [Overview](#overview)
2. [When to Use This Feature](#when-to-use-this-feature)
3. [Understanding the Two Search Modes](#understanding-the-two-search-modes)
4. [Step-by-Step Guide](#step-by-step-guide)
5. [Understanding the Results](#understanding-the-results)
6. [Backup and Delete Feature](#backup-and-delete-feature)
7. [Important Notes & Best Practices](#important-notes--best-practices)
8. [Troubleshooting](#troubleshooting)
9. [Example Scenarios](#example-scenarios)

---

## Overview

The **Outlook Search** feature scans your Outlook mailboxes to identify large emails that are consuming storage space. Option 2 (**Total Message Size**) finds emails where the **entire message** (email body + all attachments combined) exceeds your specified size threshold.

### What It Does

- Scans one or all Outlook mailboxes
- Searches through all folders and subfolders recursively
- Identifies emails where total message size exceeds threshold
- Provides detailed reports with statistics
- **Optional:** Backs up large emails to a PST file and removes them from mailbox

---

## When to Use This Feature

Use **Option 2 (Total Message Size)** when you want to:

✓ Find emails that are large overall, even if no single attachment is huge
✓ Identify storage hogs regardless of how the size is distributed
✓ Clean up mailbox to reduce total mailbox size
✓ Find emails with multiple medium-sized attachments that add up
✓ Prepare for mailbox migration (identify problematic large items)
✓ Troubleshoot slow Outlook performance due to large messages

### Use Option 1 (Individual Attachment Size) instead when:

- You only care about specific large attachments (e.g., find all 50MB+ files)
- You want to identify individual files, not total email size

---

## Understanding the Two Search Modes

### Option 1: Individual Attachment Size
```
Email: "Project Files" (Total: 60 MB)
  ├─ Report.pdf (15 MB) ❌ Below 30 MB threshold
  ├─ Data.xlsx (20 MB) ❌ Below 30 MB threshold
  └─ Presentation.pptx (25 MB) ❌ Below 30 MB threshold

Result: NOT FOUND (no individual attachment > 30 MB)
```

### Option 2: Total Message Size (Recommended for cleanup)
```
Email: "Project Files" (Total: 60 MB) ✅ Above 30 MB threshold
  ├─ Report.pdf (15 MB)
  ├─ Data.xlsx (20 MB)
  └─ Presentation.pptx (25 MB)

Result: FOUND (total message size > 30 MB)
```

**Key Difference:** Option 2 finds the email because the **combined size** (60 MB) exceeds the threshold, even though no single attachment does.

---

## Step-by-Step Guide

### Step 1: Launch the Script

```powershell
# Open PowerShell as Administrator
cd "E:\OneDrive - Dualog AS\Claude\Project\Webmail - Super script"
.\DualogMailTool.ps1
```

### Step 2: Navigate to Large Files Finder

```
Main Menu:
  Select Option: 2 (Dualog IMAP Server Tool)

IMAP Server Tool Menu:
  Select Option: 6 (Large Files & Attachments Finder)
```

### Step 3: Choose Outlook Search

```
What would you like to search?
  1. File System (files > 30 MB)
  2. Outlook Emails (attachments > 30 MB)

Enter your choice: 2
```

### Step 4: Select Search Mode

```
========================================
What would you like to search for?
========================================
1. Individual attachment size (finds specific large attachments)
2. Total message size (email body + all attachments combined)

Enter your choice (1 or 2): 2
```

**Choose Option 2** for total message size search.

### Step 5: Set Size Threshold

```
Searching by TOTAL MESSAGE SIZE (body + attachments)
Enter minimum message size in MB (press Enter for default: 30 MB):
```

**Options:**
- Press **Enter** to use default (30 MB)
- Enter a custom value (e.g., `50` for 50 MB, `100` for 100 MB)

**Recommendation:** Start with 30 MB for initial scan, then adjust based on results.

### Step 6: Select Mailbox to Search

The script will display all available mailboxes:

```
Available Mailboxes:
====================
1. Mailbox - John Doe (john.doe@company.com)
2. Archive Mailbox - John Doe
3. Shared Mailbox - Support
4. Search All Mailboxes

Select a mailbox to search (1-4):
```

**Options:**
- **1-3:** Search specific mailbox only (faster)
- **4:** Search all mailboxes (comprehensive but slower)

**Recommendation:**
- For cleanup: Start with your primary mailbox (Option 1)
- For audit: Use "Search All Mailboxes" (Option 4)

### Step 7: Wait for Scan to Complete

The script will scan all folders recursively:

```
[Scanning] Folder: Inbox
  Total items in folder: 1247
  [COMPLETE] Scanned 1247 emails with 423 attachments

[Scanning] Folder: Sent Items
  Total items in folder: 856
    [FOUND] Large email: Monthly Report - January 2024 (45.32 MB total size)
            Folder: \\Mailbox - John Doe\Sent Items
  [COMPLETE] Scanned 856 emails with 312 attachments

[Scanning] Folder: Archive\2023
  Total items in folder: 3421
    [FOUND] Large email: Project Delivery Package (67.89 MB total size)
            Folder: \\Mailbox - John Doe\Archive\2023
  [COMPLETE] Scanned 3421 emails with 1205 attachments
```

**Progress Indicators:**
- **[Scanning]** - Currently processing folder
- **[FOUND]** - Large email detected
- **[COMPLETE]** - Folder scan finished

---

## Understanding the Results

### Summary Statistics

After scanning completes, you'll see:

```
========================================
SEARCH SUMMARY
========================================
Total items scanned: 5524
Total emails found: 5524
Total attachments checked: 1940
Large attachments found: 12
```

**What this means:**
- **Total items scanned:** All items checked (emails, appointments, etc.)
- **Total emails found:** Actual email messages (excludes appointments, tasks)
- **Total attachments checked:** Number of attachments examined
- **Large attachments found:** Emails exceeding your size threshold

### Detailed Results Table

```
========================================
DETAILED MATCH RESULTS
========================================

Subject                                  From                      Attachment/Message              Size (MB)  Received          Folder
-------                                  ----                      ------------------              ---------  --------          ------
Monthly Report - January 2024            finance@company.com       Total Message (3 attachment(s)) 67.89      2024-01-15 09:23  ...Sent Items
Project Delivery Package                 vendor@supplier.com       Total Message (5 attachment(s)) 45.32      2023-12-20 14:45  ...Archive\2023
Database Backup Files                    it-admin@company.com      Total Message (1 attachment(s)) 42.17      2024-02-01 08:15  ...Inbox\IT
Training Video - Safety                  hr@company.com            Total Message (2 attachment(s)) 38.56      2023-11-10 11:30  ...Archive\HR
```

**Column Descriptions:**
- **Subject:** Email subject (truncated to 40 characters)
- **From:** Sender name or email address
- **Attachment/Message:** Shows "Total Message (X attachment(s))" for Option 2
- **Size (MB):** Total message size in megabytes
- **Received:** Date and time email was received
- **Folder:** Mailbox folder location (truncated to 35 characters)

### Numbered List with Full Details

```
Found 12 attachment(s) larger than 30 MB:

1. Subject: Monthly Report - January 2024
   File: Total Message (3 attachment(s)) (67.89 MB)
   From: finance@company.com
   Folder: \\Mailbox - John Doe\Sent Items

2. Subject: Project Delivery Package
   File: Total Message (5 attachment(s)) (45.32 MB)
   From: vendor@supplier.com
   Folder: \\Mailbox - John Doe\Archive\2023

...
```

### Total Storage Summary

```
Total size of large attachments: 456.78 MB
Total emails scanned: 5524
Total attachments checked: 1940
```

**Key Metric:** "Total size of large attachments" shows how much space you can reclaim.

---

## Backup and Delete Feature

### Overview

After identifying large emails, the script offers to:
1. **Backup** all large emails to a single PST archive file
2. **Delete** the emails from your mailbox (moved to PST, not permanently deleted)

### When to Use This Feature

✓ Mailbox approaching size limit
✓ Outlook performance is slow
✓ Need to archive old large emails
✓ Preparing for mailbox migration
✓ Compliance/retention requirements

### Step-by-Step: Backup and Delete

#### Step 1: Review Delete Prompt

```
========================================
WARNING: This will permanently delete the entire messages.
A backup .pst file will be created before deletion.
========================================
Do you want to delete these messages and backup as .pst? (Y/N):
```

**Important:** Despite saying "permanently delete", the messages are **moved to a PST file**, not destroyed.

**Options:**
- **Y** - Proceed with backup and deletion
- **N** - Keep messages in mailbox (no changes)

#### Step 2: Choose Backup Location

```
Default backup location: C:\Dualog\deleteditems
Enter backup directory path (press Enter for default):
```

**Options:**
- Press **Enter** - Use default location `C:\Dualog\deleteditems`
- Enter custom path - e.g., `D:\EmailBackups` or `\\server\backups\outlook`

**Recommendation:** Use a location that is:
- On a drive with sufficient space (at least 2x the total message size)
- Regularly backed up
- Accessible for future reference

#### Step 3: PST Creation

```
[CREATING PST] Creating backup archive: DeletedMessages_20241126_143025.pst
[PST CREATED] Archive ready: DeletedMessages_20241126_143025
[PST ATTACHED] Archive is now attached to Outlook
```

**What happens:**
1. Script creates a new PST file with timestamp in filename
2. PST is automatically attached to Outlook
3. An "Archived Messages" folder is created inside the PST

#### Step 4: Message Processing

```
[PREPARING] Closing any open message windows...
  [OK] No open windows found

  [MOVING] Monthly Report - January 2024
  [OK] Moved to archive: Monthly Report - January 2024

  [MOVING] Project Delivery Package
  [OK] Moved to archive: Project Delivery Package

  [MOVING] Database Backup Files
  [RETRY] Attempt 1 failed, retrying... (The item is currently being edited)
  [OK] Moved to archive: Database Backup Files
```

**Status Indicators:**
- **[MOVING]** - Currently processing message
- **[OK]** - Successfully moved to PST
- **[RETRY]** - Temporary failure, retrying (up to 3 attempts)
- **[FAIL]** - Could not move after 3 attempts

#### Step 5: Completion Summary

```
[COMPLETE] All messages moved to archive PST
[PST LOCATION] C:\Dualog\deleteditems\DeletedMessages_20241126_143025.pst
[PST STATUS] Archive remains attached to Outlook for easy access

========================================
Deletion Summary:
  Successfully deleted: 11 message(s)
  Failed: 1 message(s)
  Backup location: C:\Dualog\deleteditems
```

### Accessing Archived Messages

After archiving, the PST file remains attached to Outlook:

1. Open **Outlook**
2. Look in the folder pane for: **DeletedMessages_20241126_143025**
3. Expand it to see: **Archived Messages** folder
4. All moved emails are inside

**To detach the PST later:**
- Right-click the PST name in Outlook
- Select **Close "DeletedMessages_..."**

**To reattach the PST later:**
- File → Open & Export → Open Outlook Data File
- Browse to `C:\Dualog\deleteditems\DeletedMessages_20241126_143025.pst`

### Failed Messages Report

If any messages fail to move, a detailed report is generated:

```
========================================
FAILED MESSAGES REPORT
========================================

Subject                          From                  SizeMB  Folder              Error
-------                          ----                  ------  ------              -----
Important Meeting Notes          boss@company.com      35.67   \\Mailbox\Inbox     The item is locked

[REPORT EXPORTED] Failed messages saved to:
  C:\Dualog\deleteditems\FailedMessages_20241126_143025.csv
```

**What to do with failed messages:**
- Close the email if it's open in Outlook
- Re-run the script to try again
- Manually move the email to the PST
- Check if email is in use by another process

---

## Important Notes & Best Practices

### Before Running

1. **Close all open emails** in Outlook to prevent lock conflicts
2. **Ensure sufficient disk space** for PST file creation
   - PST size ≈ Total size of large messages found
   - Recommended: 2x the total size for safety
3. **Close Outlook mobile/web** if accessing the same mailbox
4. **Notify users** if working on shared mailboxes
5. **Check Outlook isn't syncing** (wait for Send/Receive to finish)

### During Execution

- **Don't interrupt** the script while moving messages
- **Don't open Outlook** during the archive process
- **Don't close PowerShell** window
- **Watch for RETRY messages** - these are normal
- **Note any FAIL messages** for follow-up

### After Execution

1. **Verify PST file** was created successfully
2. **Check PST in Outlook** - ensure messages are there
3. **Review failed messages report** (if any)
4. **Keep the PST file** in a safe location
5. **Update documentation** with backup location
6. **Test access** to archived messages

### Performance Tips

- **Start with higher threshold** (e.g., 50 MB) for faster initial scan
- **Search specific mailboxes** instead of "All" when possible
- **Run during off-hours** to minimize impact
- **Close other applications** for better performance
- **Expect 1-5 minutes** per 1000 emails scanned

### Storage Management

**PST File Sizes:**
- Default Outlook 2010+: Max 50 GB per PST
- Typical large email cleanup: 200 MB - 2 GB per PST
- One PST per script execution (timestamped)

**Best Practice:**
- Keep PST files under 10 GB for best performance
- Run cleanup monthly with 30 MB threshold
- Archive PST files to network storage
- Document PST locations in log files

---

## Troubleshooting

### Issue: "Error accessing Outlook"

**Cause:** Outlook not installed or COM interface unavailable

**Solution:**
```powershell
# Verify Outlook is installed
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE

# Try closing and reopening Outlook
Get-Process outlook | Stop-Process -Force
Start-Sleep -Seconds 5
Start Outlook
```

### Issue: "Could not move message: The item is currently being edited"

**Cause:** Email is open in Outlook or another application

**Solution:**
1. Close all open email windows
2. Close Outlook completely
3. Re-run the script
4. If persistent, restart Outlook in Safe Mode:
   ```powershell
   outlook.exe /safe
   ```

### Issue: "Failed to create PST archive"

**Cause:** Insufficient permissions, disk space, or path invalid

**Solution:**
1. Check disk space: `Get-PSDrive C | Select-Object Used,Free`
2. Verify backup path exists: `Test-Path C:\Dualog\deleteditems`
3. Run PowerShell as Administrator
4. Choose a different backup location (local drive, not network)

### Issue: Scan takes very long (>30 minutes)

**Cause:** Large mailbox with many items

**Solution:**
1. Increase size threshold (try 50 MB or 100 MB)
2. Search specific folders instead of entire mailbox
3. Run during off-peak hours
4. Close other applications
5. Consider searching one mailbox at a time

### Issue: "Total items scanned" much higher than "Total emails found"

**Cause:** Mailbox contains many non-email items (calendar, tasks, contacts)

**Expected:** This is normal. The script only counts actual emails.

**Example:**
```
Total items scanned: 15000    (includes everything)
Total emails found: 8000      (actual email messages only)
```

### Issue: No large emails found, but mailbox is large

**Cause:** Many small-to-medium emails add up

**Solution:**
1. Lower the threshold (try 10 MB or 20 MB)
2. Use Option 1 (Individual Attachment) to find specific large files
3. Review mailbox by folder to identify problem areas
4. Consider archiving old emails by date instead of size

### Issue: PST file won't open

**Cause:** File corruption or Outlook version mismatch

**Solution:**
```powershell
# Repair PST using ScanPST.exe
& "C:\Program Files\Microsoft Office\root\Office16\SCANPST.EXE"

# Or repair inbox
& "C:\Program Files\Microsoft Office\root\Office16\SCANOST.EXE"
```

---

## Example Scenarios

### Scenario 1: Mailbox at 95% Capacity

**Problem:** User mailbox is almost full (47 GB / 50 GB limit)

**Solution:**
1. Run script with 30 MB threshold
2. Search primary mailbox only
3. Review results - found 85 emails totaling 3.2 GB
4. Backup and delete all large emails
5. **Result:** Freed up 3.2 GB (mailbox now at 87%)

### Scenario 2: Slow Outlook Performance

**Problem:** Outlook takes 10+ seconds to open emails

**Solution:**
1. Run script with 20 MB threshold
2. Search all mailboxes
3. Found 240 emails totaling 8.5 GB
4. Backup and delete emails older than 1 year
5. **Result:** Outlook performance significantly improved

### Scenario 3: Preparing for Mailbox Migration

**Problem:** Need to migrate mailbox to new server, but it's too large

**Solution:**
1. Run script with 10 MB threshold
2. Search all folders including archives
3. Found 450 emails totaling 15 GB
4. Backup to PST, delete from mailbox
5. Migrate mailbox (now within size limits)
6. Restore PST file on new server

### Scenario 4: Finding Space Hogs

**Problem:** Need to identify which emails consume most space

**Solution:**
1. Run script with 50 MB threshold (high threshold)
2. Review results sorted by size
3. Top email: 156 MB (video file)
4. Delete just top 10 emails
5. **Result:** Freed up 800 MB with minimal effort

### Scenario 5: Compliance Archive

**Problem:** Legal requirement to archive all emails >25 MB

**Solution:**
1. Run script monthly with 25 MB threshold
2. Search all mailboxes
3. Backup to PST with naming: `ComplianceArchive_YYYY_MM.pst`
4. Delete from mailbox after backup
5. Store PST files on secure network share
6. **Result:** Compliance maintained, mailboxes stay lean

---

## Quick Reference Card

### Navigation Path
```
Main Menu → 2 → 6 → 2 → 2
```

### Typical Thresholds
- **Aggressive cleanup:** 20 MB
- **Standard cleanup:** 30 MB (default)
- **Conservative cleanup:** 50 MB
- **Critical items only:** 100 MB

### Search Time Estimates
- 1,000 emails: 1-2 minutes
- 5,000 emails: 5-10 minutes
- 10,000 emails: 10-20 minutes
- 25,000+ emails: 30+ minutes

### Key Features
✓ Recursive folder scanning
✓ Two search modes (attachment vs total size)
✓ Multi-mailbox support
✓ Automatic PST backup
✓ Retry logic for locked messages
✓ Failed message reporting
✓ Detailed statistics
✓ Comprehensive logging

### Log File Location
```
C:\WebmailLogs\WebmailFix_YYYYMMDD_HHMMSS.log
```

### Default Backup Location
```
C:\Dualog\deleteditems\DeletedMessages_YYYYMMDD_HHMMSS.pst
```

---

## Summary

The **Outlook Search - Total Message Size** feature is a powerful tool for:

1. **Identifying** emails that consume significant storage
2. **Understanding** where mailbox space is being used
3. **Archiving** large emails to PST files
4. **Freeing up** mailbox space safely
5. **Maintaining** optimal Outlook performance

**Best Practice Workflow:**
1. Run monthly with 30 MB threshold
2. Review results and identify unnecessary large emails
3. Backup to PST with meaningful filename
4. Delete from mailbox to free space
5. Store PST in secure, backed-up location
6. Document in log files

**Remember:**
- Always backup before deleting
- Test PST file accessibility after creation
- Keep PST files in safe locations
- Review failed message reports
- Monitor mailbox size trends

---

**Version:** 1.0
**Last Updated:** 2024-11-26
**Script Version:** DualogMailTool.ps1 v1.0
**Author:** Dualog AS

For additional support, refer to the main USER_GUIDE.md or contact your system administrator.
