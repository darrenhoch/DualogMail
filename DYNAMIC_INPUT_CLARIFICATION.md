# Dynamic User Input Clarification

## What Was Corrected

The documentation originally showed hardcoded email addresses in SQL examples like:

```sql
WHERE usr.USR_EMAIL = 'capt.dutchemerald@ship.essberger.biz'
```

**This was misleading!** The email address is NOT hardcoded. It comes from user input and changes every time the script runs.

---

## The Correct Understanding

### PowerShell Variables in SQL

The actual code uses a variable that gets replaced:

```powershell
# Line 646: Get user input
$userEmail = Read-Host "Enter the user email address"

# Lines 663-675: Create SQL with the variable
$sqlQuery = @"
SELECT
    imf.IMF_IMAPFOLDERID || '|' ||
    imf.IMF_FOLDERNAME
FROM DV_IMAPFOLDER imf
INNER JOIN DV_USER usr ON imf.USR_USERID = usr.USR_USERID
WHERE usr.USR_EMAIL = '$userEmail'
AND imf.IMF_NOSELECT IS NOT NULL
ORDER BY imf.IMF_FOLDERNAME;
EXIT;
"@
```

### String Interpolation

PowerShell's **string interpolation** feature (the `$` in double-quoted strings) automatically replaces the variable with its value:

```
Before interpolation:  WHERE usr.USR_EMAIL = '$userEmail'
After interpolation:   WHERE usr.USR_EMAIL = 'john@company.com'
```

---

## Real-World Examples

### Example 1: Support Rep Fixing John's Folders

```
Script execution:
  User input: john@company.com

Generated SQL:
  WHERE usr.USR_EMAIL = 'john@company.com'

Result:
  Only John's greyed out folders are found
```

### Example 2: Same Script, Different User

```
Script execution:
  User input: mary@company.com

Generated SQL:
  WHERE usr.USR_EMAIL = 'mary@company.com'

Result:
  Only Mary's greyed out folders are found
```

### Example 3: Captain's Case (From Documentation)

```
Script execution:
  User input: capt.dutchemerald@ship.essberger.biz

Generated SQL:
  WHERE usr.USR_EMAIL = 'capt.dutchemerald@ship.essberger.biz'

Result:
  Only Captain's greyed out folders are found
```

---

## Key Differences

| Aspect | Hardcoded (WRONG) | Dynamic (CORRECT) |
|--------|---|---|
| Where email comes from | Written in code | User input via Read-Host |
| Can fix different users? | No, only one email | Yes, any email |
| Script reusability | Low - must edit code | High - same code for all users |
| Security risk | Email visible in script | Email only in RAM during execution |

---

## How Script Works Flow

```
START
  ↓
Show menu
  ↓
Get database credentials from registry
  ↓
User enters email address
  ↓
PowerShell replaces $userEmail variable with typed email
  ↓
SQL query is built with that specific email
  ↓
Query is sent to Oracle
  ↓
Oracle finds that user's greyed out folders
  ↓
Results returned to script
  ↓
User selects which folders to enable
  ↓
UPDATE queries are run (again with the same email internally)
  ↓
Folders enabled
  ↓
END
```

---

## Technical Note: Variable Substitution

### When Does Substitution Happen?

In PowerShell, string interpolation happens when the string is created using double quotes:

```powershell
$userEmail = "john@company.com"

# This gets interpolated (variable replaced):
$sqlQuery = "WHERE usr.USR_EMAIL = '$userEmail'"
# Result: "WHERE usr.USR_EMAIL = 'john@company.com'"

# This does NOT get interpolated (single quotes prevent it):
$sqlQuery = 'WHERE usr.USR_EMAIL = '"'"'$userEmail'"'"''
# Result: "WHERE usr.USR_EMAIL = '$userEmail'"  (literal $userEmail text)
```

**In our script:** We use double quotes in the `@"..."@` heredoc syntax, so variables ARE interpolated.

---

## Documentation Updates

The following sections of `FORCE_SUBSCRIBE_LOGIC_EXPLANATION.md` were updated to clarify:

1. **Overview section** - Added "CRITICAL CONCEPT: Dynamic User Input"
2. **Step 2B** - Marked `$userEmail` as dynamic value
3. **WHERE Clause** - Showed how email changes per execution
4. **String Interpolation section** - Explained how PowerShell replaces variables
5. **Visual flow diagram** - Shows user input → variable → SQL replacement
6. **Real-world example** - Notes that email is from Step 3 user input

---

## Summary

The email address in the WHERE clause **depends entirely on what the user types** when prompted:

```
Prompt: "Enter the user email address: "
User input: [Whatever they type]
↓
SQL Query: WHERE usr.USR_EMAIL = '[What they typed]'
```

This is the correct and intended behavior - the script is designed to work with ANY user email, making it reusable across your organization.
