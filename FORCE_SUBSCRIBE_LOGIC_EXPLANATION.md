# Force-Subscribe for GREYED OUT Folder - Complete Logic Explanation

## Table of Contents
1. [Overview](#overview)
2. [What Are Greyed Out Folders](#what-are-greyed-out-folders)
3. [Complete Execution Flow](#complete-execution-flow)
4. [Phase 1: Database Connection](#phase-1-database-connection)
5. [Phase 2: Scanning Query](#phase-2-scanning-query)
6. [Phase 3: Parse Results](#phase-3-parse-results)
7. [Phase 4: User Selection](#phase-4-user-selection)
8. [Phase 5: Update Query](#phase-5-update-query)
9. [Phase 6: Error Handling & Summary](#phase-6-error-handling--summary)
10. [Real-World Example](#real-world-example)

---

## Overview

The **Force-Subscribe for GREYED OUT Folder** script is designed to enable (un-grey) IMAP folders that are marked as non-selectable in the Dualog webmail system.

**Problem**: Users cannot access certain email folders because they appear greyed out/disabled in their IMAP client.

**Solution**: This script sets the `IMF_NOSELECT` column to NULL, which re-enables the folders.

---

## CRITICAL CONCEPT: Dynamic User Input

### The WHERE Clause is NOT Hardcoded

The SQL query you see in examples uses a **placeholder variable `$userEmail`** that gets replaced with whatever the user types:

```powershell
# PowerShell code:
$userEmail = Read-Host "Enter the user email address"  # User types: john@company.com

# Then this SQL template:
WHERE usr.USR_EMAIL = '$userEmail'

# Becomes this actual SQL:
WHERE usr.USR_EMAIL = 'john@company.com'
```

### Different Users = Different Queries

| Scenario | User Input | Generated SQL |
|----------|-----------|---------------|
| Scenario 1 | `john@company.com` | `WHERE usr.USR_EMAIL = 'john@company.com'` |
| Scenario 2 | `mary@domain.org` | `WHERE usr.USR_EMAIL = 'mary@domain.org'` |
| Scenario 3 | `capt.dutchemerald@ship.essberger.biz` | `WHERE usr.USR_EMAIL = 'capt.dutchemerald@ship.essberger.biz'` |

**Each user gets their own folders queried!** The script is designed to work with ANY email address, not just one hardcoded email.

### How PowerShell String Interpolation Works

In PowerShell, the **`$variable` inside a string is automatically replaced** with its value:

```powershell
# Step 1: User provides input
$userEmail = Read-Host "Enter the user email address"
# User types and presses Enter: john@company.com
# $userEmail now contains: "john@company.com"

# Step 2: Create SQL with variable inside double quotes
$sqlQuery = @"
SELECT * FROM DV_IMAPFOLDER
WHERE usr.USR_EMAIL = '$userEmail'
"@

# Step 3: PowerShell automatically replaces $userEmail
# $sqlQuery now contains the actual text:
# SELECT * FROM DV_IMAPFOLDER
# WHERE usr.USR_EMAIL = 'john@company.com'

# Step 4: This query is sent to Oracle
$output = & sqlplus -S "$username/$password" "@$sqlFile" 2>&1
```

**This is called "String Interpolation"** - the variable gets replaced with its value when the string is created.

### Visual Flow: String Interpolation

```
┌─────────────────────────────────────────────────────────┐
│ User runs script and sees prompt:                       │
│ Enter the user email address: _                         │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ User types: john@company.com                            │
│ Press Enter                                             │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ PowerShell Variable Assignment:                         │
│ $userEmail = "john@company.com"                         │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ PowerShell Code:                                        │
│ $sqlQuery = @"                                          │
│ SELECT * FROM DV_IMAPFOLDER                            │
│ WHERE usr.USR_EMAIL = '$userEmail'                      │
│ "@                                                      │
└─────────────────────────────────────────────────────────┘
                         │
          ┌──────────────┤ String Interpolation Happens
          │              │ (PowerShell replaces $userEmail)
          ▼              ▼
┌─────────────────────────────────────────────────────────┐
│ Actual SQL Query Created:                               │
│ SELECT * FROM DV_IMAPFOLDER                            │
│ WHERE usr.USR_EMAIL = 'john@company.com'               │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Query sent to Oracle Database                           │
│ Executed via sqlplus command                            │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│ Oracle returns:                                         │
│ 12345|Inbox                                             │
│ 67890|Drafts                                            │
│ (Only for user john@company.com)                        │
└─────────────────────────────────────────────────────────┘
```

### Key Points About Dynamic Queries

1. **Variable Substitution Happens in PowerShell, NOT Oracle**
   - PowerShell replaces `$userEmail` BEFORE sending to Oracle
   - Oracle never sees the variable name, only the actual email

2. **Each Script Execution = Different Query**
   - First run: User types `john@company.com` → Query searches for john's folders
   - Second run: User types `mary@company.com` → Query searches for mary's folders
   - Same script, different results!

3. **The Actual SQL Sent to Oracle**
   - Run 1: `WHERE usr.USR_EMAIL = 'john@company.com'`
   - Run 2: `WHERE usr.USR_EMAIL = 'mary@company.com'`
   - Run 3: `WHERE usr.USR_EMAIL = 'capt.dutchemerald@ship.essberger.biz'`

---

## What Are Greyed Out Folders?

In IMAP terminology:
- **Selectable Folder**: User can open and read emails (IMF_NOSELECT = NULL)
- **Non-Selectable (Greyed Out)**: User cannot access, appears disabled (IMF_NOSELECT = some value like 1)

In the database:
- `IMF_NOSELECT = NULL` → Normal folder (enabled)
- `IMF_NOSELECT = 1` or any value → Greyed out (disabled)

---

## Complete Execution Flow

```
┌─────────────────────────────────────────────┐
│  Start: Force-Subscribe Function Called     │
└────────────────┬────────────────────────────┘
                 │
                 ▼
        ┌───────────────────┐
        │ Display Intro &   │
        │ Instructions      │
        └────────┬──────────┘
                 │
                 ▼
        ┌──────────────────────────────┐
        │ Get DB Password from Registry│  ← Retrieves from Windows Registry
        │ (Dualog\DGS\DatabasePassword)│
        └────────┬─────────────────────┘
                 │
                 ▼
        ┌──────────────────────────────┐
        │ Test Database Connection     │  ← Test with g4vessel user
        │ (SELECT 1 FROM DUAL)         │
        └────────┬─────────────────────┘
                 │
                 ▼
        ┌──────────────────────────────┐
        │ Prompt User for Email Address│  ← User inputs: user@company.com
        └────────┬─────────────────────┘
                 │
                 ▼
    ╔════════════════════════════════════╗
    ║ PHASE 1: SCAN DATABASE             ║
    ║ Find all greyed out folders        ║
    ║ for this specific user             ║
    ╚────────┬─────────────────────────────╝
             │
             ▼
    ┌────────────────────────────────────┐
    │ Execute SELECT query               │
    │ Search: WHERE                      │
    │ - Email = user input              │
    │ - IMF_NOSELECT IS NOT NULL        │
    └────────┬───────────────────────────┘
             │
             ▼
    ┌────────────────────────────────────┐
    │ Receive results from Oracle        │
    │ Format: ID|FolderName              │
    │ Example:                           │
    │ 12345|Inbox                        │
    │ 67890|Drafts                       │
    └────────┬───────────────────────────┘
             │
             ▼
    ╔════════════════════════════════════╗
    ║ PHASE 2: PARSE RESULTS             ║
    ║ Convert SQL output to PowerShell   ║
    ║ objects for easier handling        ║
    ╚────────┬─────────────────────────────╝
             │
             ▼
    ┌────────────────────────────────────┐
    │ Check if any folders found        │
    └────┬──────────────┬────────────────┘
         │ Found        │ Not Found
         │              │
         ▼              ▼
    [Continue]    [Show message & Exit]
         │
         │
    ╔════════════════════════════════════╗
    ║ PHASE 3: SHOW RESULTS              ║
    ║ Display all greyed out folders    ║
    ║ with numbers (1, 2, 3...)        ║
    ╚────────┬─────────────────────────────╝
             │
             ▼
    ╔════════════════════════════════════╗
    ║ PHASE 4: SELECTION MENU            ║
    ║ Ask user what to do               ║
    ╚────┬───────┬───────┬───────────────╝
         │       │       │
    Option1  Option2  Option3
         │       │       │
    [ALL]    [SELECT]  [CANCEL]
         │       │       │
         └───┬───┘       │
             │           │
             ▼           ▼
    ┌──────────────┐  [Exit & Return
    │ Get Selected │   to Menu]
    │ Folder List  │
    └──────┬───────┘
           │
    ╔════════════════════════════════════╗
    ║ PHASE 5: UPDATE FOLDERS            ║
    ║ For each selected folder:          ║
    ║ - Execute UPDATE query             ║
    ║ - Set IMF_NOSELECT = NULL          ║
    ║ - COMMIT changes                   ║
    ╚────────┬─────────────────────────────╝
             │
         ┌───┴────────────────────────┐
         │ Loop through each folder   │
         └───┬────────────────────────┘
             │
             ├─► Folder 1: UPDATE... → Success ✓ or Fail ✗
             │
             ├─► Folder 2: UPDATE... → Success ✓ or Fail ✗
             │
             └─► Folder 3: UPDATE... → Success ✓ or Fail ✗

    ╔════════════════════════════════════╗
    ║ PHASE 6: SHOW SUMMARY              ║
    ║ Display:                           ║
    ║ - X folders successfully enabled   ║
    ║ - Y folders failed                 ║
    ╚────────┬─────────────────────────────╝
             │
             ▼
    ┌──────────────────────────────────┐
    │ Return to IMAP Repair Menu        │
    └──────────────────────────────────┘
```

---

## Phase 1: Database Connection

### Code Location: Lines 620-641

### Step 1A: Get Database Credentials
```powershell
$username = "g4vessel"
$password = Get-DatabasePasswordFromRegistry
```

**What happens:**
- Hardcodes username as `g4vessel` (Dualog service account)
- Calls `Get-DatabasePasswordFromRegistry` function to retrieve encrypted password from Windows Registry
- Registry location: `HKLM:\SOFTWARE\Wow6432Node\Dualog\DGS\DatabasePassword`

**Why this matters:**
- Security: Password stored in registry, not hardcoded in script
- Consistency: Same account used for all database operations

### Step 1B: Validate Password Retrieved
```powershell
if ($null -eq $password) {
    Write-Log "Cannot proceed without database password" "ERROR"
    $null = Read-Host "Press Enter to return to main menu"
    return
}
```

**Checks:**
- If password is NULL (empty), script cannot proceed
- Logs error and exits gracefully

### Step 1C: Test Database Connection
```powershell
$connectionTest = Test-DatabaseConnection -Username $username -Password $password

if (-not $connectionTest) {
    Write-Log "Cannot proceed without a valid database connection" "ERROR"
    return
}
```

**What it does:**
- Executes: `SELECT 1 FROM DUAL;`
- Tests if credentials are valid
- Checks if Oracle is accessible
- Exits if connection fails

---

## Phase 2: Scanning Query

### Code Location: Lines 643-689

### Step 2A: Get User Email Input
```powershell
$userEmail = Read-Host "Enter the user email address"

if ([string]::IsNullOrWhiteSpace($userEmail)) {
    Write-Log "No email address provided" "WARNING"
    Write-Host "Email address cannot be empty!" -ForegroundColor Red
    return
}
```

**Validation:**
- Requires non-empty email address
- Exits if user provides blank input
- Example input: `capt.dutchemerald@ship.essberger.biz`

### Step 2B: Build SQL Scan Query

```sql
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF COLSEP '|'
SET LINESIZE 32767
SELECT
    imf.IMF_IMAPFOLDERID || '|' ||
    imf.IMF_FOLDERNAME
FROM DV_IMAPFOLDER imf
INNER JOIN DV_USER usr ON imf.USR_USERID = usr.USR_USERID
WHERE usr.USR_EMAIL = '$userEmail'
AND imf.IMF_NOSELECT IS NOT NULL
ORDER BY imf.IMF_FOLDERNAME;
EXIT;
```

**IMPORTANT NOTE:** The email address in the WHERE clause is **DYNAMIC** and comes from user input!
- `'$userEmail'` is replaced by PowerShell with the actual email user typed
- Example: If user types `capt.dutchemerald@ship.essberger.biz`, the query becomes:
  ```sql
  WHERE usr.USR_EMAIL = 'capt.dutchemerald@ship.essberger.biz'
  ```

### SQL Breakdown:

#### Oracle Settings (Configuration)
```sql
SET PAGESIZE 0           -- No page breaks
SET FEEDBACK OFF         -- Hide "X rows selected"
SET VERIFY OFF           -- Hide old/new values
SET HEADING OFF          -- Hide column names
SET ECHO OFF             -- Hide command echo
SET COLSEP '|'           -- Use | as separator
SET LINESIZE 32767       -- Allow very long lines
```

**Why these settings?**
- Simplifies output parsing in PowerShell
- Each line = clean data without headers or formatting
- Pipe separator makes splitting easy

#### SELECT Statement (What to Retrieve)
```sql
SELECT
    imf.IMF_IMAPFOLDERID || '|' ||
    imf.IMF_FOLDERNAME
```

**Components:**
- `imf.IMF_IMAPFOLDERID` = Unique folder ID (integer)
- `||` = Oracle string concatenation operator
- `'|'` = Literal pipe character
- `imf.IMF_FOLDERNAME` = User-friendly folder name (string)

**Example Output:**
```
12345|Inbox
67890|Drafts
11111|Sent Items
```

#### FROM Clause (Which Tables)
```sql
FROM DV_IMAPFOLDER imf
INNER JOIN DV_USER usr ON imf.USR_USERID = usr.USR_USERID
```

**Tables Involved:**

| Table | Alias | Contents |
|-------|-------|----------|
| DV_IMAPFOLDER | imf | All IMAP folders with properties |
| DV_USER | usr | All users with email addresses |

**INNER JOIN Explanation:**
- Connects folders to users via `USR_USERID`
- Only returns rows where BOTH tables have matching user
- Ensures we find folders belonging to the specific user

**Visual Representation:**
```
DV_IMAPFOLDER          DV_USER
─────────────          ───────
IMF_ID   USER_ID       USER_ID  EMAIL
12345    101    ──┐    ┌──  101  user@company.com
67890    101    ──┼────┤
11111    102    ──┤    └──  102  other@company.com
            │
            └─────→ INNER JOIN connects on matching USER_ID
```

#### WHERE Clause (Filtering)
```sql
WHERE usr.USR_EMAIL = '$userEmail'
AND imf.IMF_NOSELECT IS NOT NULL
```

**Two Conditions (AND = both must be true):**

1. **`usr.USR_EMAIL = '$userEmail'`** ← **DYNAMIC VALUE**
   - Replaced by the email address the user typed
   - Only get folders for THIS specific user
   - Not other users' folders
   - **Example transformations:**
     - User types: `john@company.com` → Query has: `WHERE usr.USR_EMAIL = 'john@company.com'`
     - User types: `mary@domain.org` → Query has: `WHERE usr.USR_EMAIL = 'mary@domain.org'`

2. **`imf.IMF_NOSELECT IS NOT NULL`**
   - Only get GREYED OUT folders
   - `NULL` = selectable (normal folder)
   - `NOT NULL` = non-selectable (greyed out folder)

**Truth Table:**
```
IMF_NOSELECT Value  | Folder Status    | Included in Results?
─────────────────────────────────────────────────────────────
NULL                | Selectable       | NO
1                   | Greyed out       | YES
'Y'                 | Greyed out       | YES
ANY VALUE           | Greyed out       | YES
```

#### ORDER BY (Sorting)
```sql
ORDER BY imf.IMF_FOLDERNAME
```

**Effect:**
- Sorts results alphabetically by folder name
- Example order:
  ```
  12345|Drafts
  10000|Inbox
  11111|Junk
  11222|Sent Items
  ```

---

## Phase 3: Parse Results

### Code Location: Lines 691-704

### Process Diagram:
```
SQL Output (Raw Text)              Parse Loop              PowerShell Objects
──────────────────────             ──────────────          ───────────────────

"12345|Inbox"                      foreach loop
"67890|Drafts"    ──────────────→  Split on |    ────────→ @{
"11111|Sent"                       Trim          ┌──→ FolderID="12345"
                                   Add to array  │    FolderName="Inbox"
                                                 │  }
                                                 │
                                                 ├──→ @{
                                                 │    FolderID="67890"
                                                 │    FolderName="Drafts"
                                                 │  }
                                                 │
                                                 └──→ @{
                                                      FolderID="11111"
                                                      FolderName="Sent"
                                                    }
```

### Code Walkthrough:

```powershell
$greyedFolders = @()  # Create empty array to store results
```

**Purpose:** Initialize storage for folder objects

```powershell
foreach ($line in $output) {  # Loop through each line from Oracle
```

**Iterates through:**
```
"12345|Inbox"
"67890|Drafts"
"11111|Sent Items"
"" (empty lines)
```

```powershell
if (-not [string]::IsNullOrWhiteSpace($line)) {  # Skip empty/whitespace lines
```

**Logic:**
- `-not` = negation (NOT)
- `[string]::IsNullOrWhiteSpace($line)` = checks if line is empty
- Combined = "if line is NOT empty"

**Effect:**
```
Input: "12345|Inbox"        → Process
Input: ""                   → Skip
Input: "   "                → Skip
```

```powershell
$fields = $line -split '\|'  # Split on pipe character
```

**Splits:**
```
"12345|Inbox"  →  @("12345", "Inbox")
$fields[0]     →  "12345"
$fields[1]     →  "Inbox"
```

```powershell
if ($fields.Count -ge 2) {  # Ensure we got both ID and Name
```

**Validation:** Only process if line had at least 2 fields separated by pipe

```powershell
$greyedFolders += [PSCustomObject]@{
    FolderID = $fields[0].Trim()      # Remove leading/trailing spaces
    FolderName = $fields[1].Trim()
    Selected = $false
}
```

**Creates PowerShell object:**
```powershell
[PSCustomObject]@{
    FolderID = "12345"
    FolderName = "Inbox"
    Selected = $false
}
```

**Result:**
```powershell
$greyedFolders now contains:
[
  @{ FolderID = "12345"; FolderName = "Inbox"; Selected = $false },
  @{ FolderID = "67890"; FolderName = "Drafts"; Selected = $false },
  @{ FolderID = "11111"; FolderName = "Sent Items"; Selected = $false }
]
```

---

## Phase 4: User Selection

### Code Location: Lines 706-750

### Step 4A: Check if Any Folders Found

```powershell
if ($greyedFolders.Count -eq 0) {
    Write-Host "`nNo greyed out folders found for user: $userEmail" -ForegroundColor Green
    return  # Exit function
} else {
    # Continue with results...
}
```

**If no results:** Exit gracefully
**If results exist:** Display them

### Step 4B: Display Folders with Numbers

```powershell
for ($i = 0; $i -lt $greyedFolders.Count; $i++) {
    $folder = $greyedFolders[$i]
    Write-Host "  $($i + 1). Folder ID: $($folder.FolderID) | Name: $($folder.FolderName)"
}
```

**Display:**
```
Found 3 greyed out folder(s):

  1. Folder ID: 12345 | Name: Inbox
  2. Folder ID: 67890 | Name: Drafts
  3. Folder ID: 11111 | Name: Sent Items
```

**Note:** `$i + 1` because:
- Array is 0-indexed (0, 1, 2)
- User-friendly numbering (1, 2, 3)

### Step 4C: Selection Menu

```powershell
Write-Host "=== Selection Options ==="
Write-Host "1. Force-subscribe ALL greyed out folders"
Write-Host "2. Select individual folders to force-subscribe"
Write-Host "3. Cancel and return to menu"

$selectionChoice = Read-Host "Choose an option [1-3]"
```

**User sees:**
```
=== Selection Options ===
1. Force-subscribe ALL greyed out folders
2. Select individual folders to force-subscribe
3. Cancel and return to menu

Choose an option [1-3]: _
```

### Option 1: Subscribe ALL Folders

```powershell
switch ($selectionChoice) {
    "1" {
        Write-Log "User chose to force-subscribe ALL folders" "INFO"
        Force-SubscribeFolders -Username $username -Password $password `
                              -Folders $greyedFolders -Email $userEmail
    }
}
```

**Action:**
- Pass entire `$greyedFolders` array to update function
- Updates all folders

### Option 2: Select Individual Folders (Lines 769-803)

**Function: `Select-FoldersForSubscribe`**

```powershell
$selection = Read-Host "Enter your selection"
```

**User can input:**
- `ALL` → Select all folders
- `1,3,5` → Select specific folder numbers
- `2` → Select single folder

#### Case A: User Types "ALL"

```powershell
if ($selection.ToUpper() -eq "ALL") {
    $selectedFolders = $Folders  # Simple assignment
}
```

**Result:**
```
$selectedFolders = @(
  @{ FolderID = "12345"; FolderName = "Inbox" },
  @{ FolderID = "67890"; FolderName = "Drafts" },
  @{ FolderID = "11111"; FolderName = "Sent Items" }
)
```

#### Case B: User Types "1,3,5"

```powershell
else {
    # Split "1,3,5" into ["1", "3", "5"]
    $selections = $selection -split ',' | ForEach-Object { $_.Trim() }

    foreach ($sel in $selections) {
        # Convert string to integer
        if ([int]::TryParse($sel, [ref]$index)) {
            $index = $index - 1  # Convert from 1-based to 0-based

            # Verify index is valid (between 0 and count-1)
            if ($index -ge 0 -and $index -lt $Folders.Count) {
                $selectedFolders += $Folders[$index]  # Add to results
            }
        }
    }
}
```

**Execution Trace (Input: "1,3"):**

```
Step 1: $selection = "1,3"
Step 2: -split ',' → ["1", "3"]
Step 3: ForEach Trim → ["1", "3"]

Step 4: foreach $sel in ["1", "3"]
        Iteration 1: $sel = "1"
        │ [int]::TryParse("1", [ref]$index)
        │ $index = 1
        │ $index = 1 - 1 = 0  ← Convert to 0-based
        │ Check: 0 >= 0 AND 0 < 3 ✓ VALID
        │ $selectedFolders += $Folders[0]  ← Add "Inbox"
        │
        Iteration 2: $sel = "3"
        │ [int]::TryParse("3", [ref]$index)
        │ $index = 3
        │ $index = 3 - 1 = 2  ← Convert to 0-based
        │ Check: 2 >= 0 AND 2 < 3 ✓ VALID
        │ $selectedFolders += $Folders[2]  ← Add "Sent Items"
        │
Step 5: Result: ["Inbox", "Sent Items"]
```

**Why convert from 1-based to 0-based?**
```
User sees (1-based):          Array index (0-based):
1. Inbox               ─────→ [0] Inbox
2. Drafts              ─────→ [1] Drafts
3. Sent Items          ─────→ [2] Sent Items

User selects "1" → We need index 0
User selects "3" → We need index 2
```

#### Validation: [int]::TryParse

```powershell
[int]::TryParse($sel, [ref]$index)
```

**What it does:**
- Attempts to convert string to integer
- Returns TRUE if successful
- Returns FALSE if string is not a number
- Stores result in `$index` variable

**Example:**
```
TryParse("1", $index)      → Returns TRUE, $index = 1
TryParse("abc", $index)    → Returns FALSE, $index = unchanged
TryParse("3.5", $index)    → Returns FALSE (not a whole number)
```

#### Summary Display

```powershell
Write-Host "`nSelected $($selectedFolders.Count) folder(s)" -ForegroundColor Green
foreach ($folder in $selectedFolders) {
    Write-Host "  - $($folder.FolderName)" -ForegroundColor White
}
```

**Output:**
```
Selected 2 folder(s)
  - Inbox
  - Sent Items
```

### Option 3: Cancel

```powershell
"3" {
    Write-Log "User cancelled operation" "INFO"
    Write-Host "Operation cancelled." -ForegroundColor Yellow
}
```

**Result:** Function returns, menu reappears

---

## Phase 5: Update Query

### Code Location: Lines 805-884

### Step 5A: Confirmation Dialog

```powershell
Write-Host "`n=== Force-Subscribe Folders ===" -ForegroundColor Yellow
Write-Host "Total folders to enable: $($Folders.Count)" -ForegroundColor Yellow

foreach ($folder in $Folders) {
    Write-Host "  - $($folder.FolderName)" -ForegroundColor White
}

$confirm = Read-Host "Type 'YES' to confirm"

if ($confirm -ne "YES") {
    Write-Log "User did not confirm" "WARNING"
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    return
}
```

**Safety Check:**
- Shows what will be updated
- Requires exact text "YES" (not "yes" or "y")
- Prevents accidental updates

**Display:**
```
=== Force-Subscribe Folders ===
Total folders to enable: 2
  - Inbox
  - Sent Items

Type 'YES' to confirm: _
```

### Step 5B: Loop Through Each Folder

```powershell
$successCount = 0
$failCount = 0

foreach ($folder in $Folders) {
    try {
        $folderID = $folder.FolderID
        $folderName = $folder.FolderName

        # Execute UPDATE for this specific folder...
        # If success: $successCount++
        # If fail: $failCount++
    } catch {
        $failCount++
    }
}
```

**For each folder:**
1. Extract ID and name
2. Execute UPDATE query
3. Track success/failure
4. Continue to next folder

### Step 5C: Build UPDATE Query

```sql
SET PAGESIZE 0 FEEDBACK ON VERIFY OFF HEADING OFF ECHO OFF
UPDATE DV_IMAPFOLDER
SET IMF_NOSELECT = NULL
WHERE IMF_IMAPFOLDERID = 12345;
COMMIT;
EXIT;
```

**Components:**

| Part | Purpose |
|------|---------|
| `SET PAGESIZE 0 FEEDBACK ON` | Show feedback (rows affected) |
| `UPDATE DV_IMAPFOLDER` | Which table to modify |
| `SET IMF_NOSELECT = NULL` | The change (enable folder) |
| `WHERE IMF_IMAPFOLDERID = 12345` | Which row to update |
| `COMMIT;` | Save permanently |
| `EXIT;` | Close connection |

### Step 5D: Execute UPDATE

```powershell
$sqlFile = Join-Path $env:TEMP "subscribe_folder_$folderID.sql"
$sqlQuery | Out-File $sqlFile -Encoding ASCII

Write-Host "Updating folder: $folderName..." -ForegroundColor Cyan
$output = & sqlplus -S "$Username/$Password" "@$sqlFile" 2>&1 | Out-String

Remove-Item $sqlFile -Force -ErrorAction SilentlyContinue
```

**Process:**
1. **Create file:** Write SQL to temp file
   - Location: `C:\Users\[User]\AppData\Local\Temp\subscribe_folder_12345.sql`
   - Name includes folder ID to avoid conflicts

2. **Execute:** Run sqlplus with credentials
   - `-S` flag = Silent mode (no banner)
   - `@$sqlFile` = Execute SQL from file
   - `2>&1` = Capture both stdout and stderr
   - `| Out-String` = Convert output to string

3. **Cleanup:** Delete SQL file after execution

### Step 5E: Error Checking

```powershell
if ($output -match "ORA-" -or $output -match "ERROR") {
    Write-Log "Error updating folder $folderID ($folderName): $output" "ERROR"
    Write-Host "  [FAILED] $folderName - Error during update" -ForegroundColor Red
    $failCount++
} else {
    Write-Log "Successfully force-subscribed folder: $folderName ($folderID)" "SUCCESS"
    Write-Host "  [SUCCESS] $folderName - Now enabled" -ForegroundColor Green
    $successCount++
}
```

**Check for errors:**
- `ORA-` prefix = Oracle error code (ORA-123456)
- `ERROR` keyword = Any other error

**Examples:**
```
Output: "1 row updated."                → SUCCESS ✓
Output: "ORA-00000: normal, successful completion"  → SUCCESS ✓
Output: "ORA-01843: not a valid month"  → FAIL ✗
Output: "ERROR: Invalid folder ID"      → FAIL ✗
```

---

## Phase 6: Error Handling & Summary

### Code Location: Lines 876-883

### Summary Display

```powershell
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Force-Subscribe Summary:" -ForegroundColor Cyan
Write-Host "  Successfully enabled: $successCount folder(s)" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  Failed: $failCount folder(s)" -ForegroundColor Red
}
Write-Log "Force-subscribe complete: $successCount successful, $failCount failed" "INFO"
```

**Display:**
```
========================================
Force-Subscribe Summary:
  Successfully enabled: 2 folder(s)
  Failed: 0 folder(s)
```

### Logging

**Every operation is logged to:** `C:\WebmailLogs\WebmailFix_YYYYMMDD_HHMMSS.log`

**Examples:**
```
2025-01-15 14:30:45 [INFO] User selected IMAP Option 2: Force-Subscribe for GREYED OUT Folder
2025-01-15 14:30:50 [INFO] Searching for greyed out folders for user: capt.dutchemerald@ship.essberger.biz
2025-01-15 14:30:55 [INFO] Found 3 greyed out folders
2025-01-15 14:31:00 [INFO] User chose to select individual folders
2025-01-15 14:31:05 [INFO] Starting force-subscribe operation for user: capt.dutchemerald@ship.essberger.biz
2025-01-15 14:31:10 [SUCCESS] Successfully force-subscribed folder: Inbox (12345)
2025-01-15 14:31:15 [SUCCESS] Successfully force-subscribed folder: Sent Items (11111)
2025-01-15 14:31:20 [INFO] Force-subscribe complete: 2 successful, 0 failed
```

---

## Real-World Example

### Scenario

User `capt.dutchemerald@ship.essberger.biz` cannot access their "Inbox" and "Sent Items" folders in Outlook. They appear greyed out.

### Step-by-Step Execution

#### 1. User Runs Script
```
Script starts...
Shows introduction
```

#### 2. Database Connection
```
Gets password from registry: ✓ Found
Tests connection: ✓ Connected
```

#### 3. User Input
```
Enter the user email address: capt.dutchemerald@ship.essberger.biz
```

#### 4. Database Scan
```sql
SELECT
    imf.IMF_IMAPFOLDERID || '|' ||
    imf.IMF_FOLDERNAME
FROM DV_IMAPFOLDER imf
INNER JOIN DV_USER usr ON imf.USR_USERID = usr.USR_USERID
WHERE usr.USR_EMAIL = 'capt.dutchemerald@ship.essberger.biz'
AND imf.IMF_NOSELECT IS NOT NULL
ORDER BY imf.IMF_FOLDERNAME;
```

**Note:** The email `'capt.dutchemerald@ship.essberger.biz'` in this query is what the user typed in Step 3. If user had typed a different email, it would be different here.

**Database State BEFORE:**
```
USER: capt.dutchemerald@ship.essberger.biz (USR_USERID = 42)

IMF_IMAPFOLDERID  IMF_FOLDERNAME  IMF_NOSELECT  USR_USERID
────────────────  ──────────────  ────────────  ──────────
12345             Inbox           1             42          ← GREYED OUT
67890             Drafts          NULL          42          ← Normal
11111             Sent Items      1             42          ← GREYED OUT
22222             Junk            NULL          42          ← Normal
```

**Query Result:**
```
12345|Inbox
11111|Sent Items
```

#### 5. Parse Results
```powershell
$greyedFolders = @(
  @{ FolderID="12345"; FolderName="Inbox"; Selected=$false },
  @{ FolderID="11111"; FolderName="Sent Items"; Selected=$false }
)
```

#### 6. Display to User
```
Found 2 greyed out folder(s):

  1. Folder ID: 12345 | Name: Inbox
  2. Folder ID: 11111 | Name: Sent Items

=== Selection Options ===
1. Force-subscribe ALL greyed out folders
2. Select individual folders to force-subscribe
3. Cancel and return to menu

Choose an option [1-3]: 2
```

#### 7. User Selects Individual Folders
```
Enter folder numbers separated by commas (e.g., 1,3,5)
Or type 'ALL' to select all folders

Enter your selection: 1

Selected 1 folder(s)
  - Inbox
```

#### 8. Confirmation
```
=== Force-Subscribe Folders ===
Total folders to enable: 1
  - Inbox

Type 'YES' to confirm: YES
```

#### 9. Database Update Executes

**SQL for Inbox (ID 12345):**
```sql
UPDATE DV_IMAPFOLDER
SET IMF_NOSELECT = NULL
WHERE IMF_IMAPFOLDERID = 12345;
COMMIT;
```

**Database State AFTER:**
```
IMF_IMAPFOLDERID  IMF_FOLDERNAME  IMF_NOSELECT  USR_USERID
────────────────  ──────────────  ────────────  ──────────
12345             Inbox           NULL          42          ← NOW ENABLED ✓
67890             Drafts          NULL          42
11111             Sent Items      1             42
22222             Junk            NULL          42
```

#### 10. Summary
```
========================================
Force-Subscribe Summary:
  Successfully enabled: 1 folder(s)
```

#### 11. User Syncs Outlook

- Outlook refreshes IMAP folders
- Reads IMF_NOSELECT = NULL
- Shows Inbox as selectable
- User can now access emails

---

## Key Points to Remember

### What Gets Changed
- **Only:** `IMF_NOSELECT` column set to `NULL`
- **Not changed:** Email data, folder names, user settings

### Database Tables Involved
| Table | Purpose |
|-------|---------|
| DV_IMAPFOLDER | Stores folder configuration (greyed out status) |
| DV_USER | Links users to their email addresses |

### Critical Fields
| Field | Meaning |
|-------|---------|
| `IMF_IMAPFOLDERID` | Unique folder identifier |
| `IMF_NOSELECT` | Greyed out status (NULL = selectable) |
| `USR_EMAIL` | User's email address |
| `USR_USERID` | User identifier (joins tables) |

### Error Prevention
1. **Password validation** - Must exist in registry
2. **Connection test** - Verify Oracle accessible
3. **Email validation** - Cannot be empty
4. **User confirmation** - Must type "YES"
5. **Individual folder updates** - Failures don't stop others
6. **Comprehensive logging** - All actions recorded

---

## Common Errors & Solutions

### Error: "Could not retrieve database password from registry"
**Cause:** Dualog not installed or password not stored
**Solution:** Install Dualog or manually set registry value

### Error: "Database connection failed"
**Cause:** Oracle client not installed or credentials invalid
**Solution:** Install Oracle Client, verify credentials

### Error: "No greyed out folders found"
**Cause:** User has no disabled folders
**Solution:** This is not an error - all folders are already accessible

### Error: "Invalid selection"
**Cause:** User typed folder number that doesn't exist
**Solution:** Script ignores invalid numbers, only processes valid ones

---

## SQL Command Reference

### Scan Query
```sql
-- Find all greyed out folders for a user
SELECT imf.IMF_IMAPFOLDERID, imf.IMF_FOLDERNAME
FROM DV_IMAPFOLDER imf
INNER JOIN DV_USER usr ON imf.USR_USERID = usr.USR_USERID
WHERE usr.USR_EMAIL = 'user@example.com'
AND imf.IMF_NOSELECT IS NOT NULL;
```

### Update Query
```sql
-- Enable a greyed out folder
UPDATE DV_IMAPFOLDER
SET IMF_NOSELECT = NULL
WHERE IMF_IMAPFOLDERID = 12345;
COMMIT;
```

### Check Folder Status
```sql
-- Verify folder is now selectable
SELECT IMF_IMAPFOLDERID, IMF_FOLDERNAME, IMF_NOSELECT
FROM DV_IMAPFOLDER
WHERE IMF_IMAPFOLDERID = 12345;
```

---

## End of Document

For questions or issues, check the log file at: `C:\WebmailLogs\WebmailFix_[timestamp].log`
