Project\Webmail - Super script\README.md                                                                             │
│                                                                                                                      │
│ # DualogMailTool                                                                                                     │
│                                                                                                                      │
│ A comprehensive PowerShell administration and troubleshooting tool for Dualog webmail systems. Simplify database     │
│ repairs, IMAP server management, and email diagnostics.                                                              │
│                                                                                                                      │
│ ## Features                                                                                                          │
│                                                                                                                      │
│ - **IMAP Repair** - Fix common webmail database issues including duplicate body parts and inaccessible folders       │
│ - **Server Diagnostics** - Test connectivity to IMAP, SMTP, and Shore Gateway servers                                │
│ - **Log Management** - Adjust IMAP server logging levels for troubleshooting                                         │
│ - **Storage Analysis** - Find large files and attachments consuming disk space                                       │
│ - **System Setup** - Enable Windows Telnet client for manual diagnostics                                             │
│                                                                                                                      │
│ ## Quick Start                                                                                                       │
│                                                                                                                      │
│ ### Prerequisites                                                                                                    │
│                                                                                                                      │
│ - Windows PowerShell 3.0+                                                                                            │
│ - Administrator privileges                                                                                           │
│ - Dualog DGS installed and configured                                                                                │
│ - Oracle database (for database operations)                                                                          │
│                                                                                                                      │
│ ### Running the Script                                                                                               │
│                                                                                                                      │
│ ```powershell                                                                                                        │
│ # Open PowerShell as Administrator                                                                                   │
│ # Navigate to script directory                                                                                       │
│ cd "path\to\DualogMailTool"                                                                                          │
│                                                                                                                      │
│ # Run the script                                                                                                     │
│ .\DualogMailTool.ps1                                                                                                 │
│ ```                                                                                                                  │
│                                                                                                                      │
│ ## Documentation                                                                                                     │
│                                                                                                                      │
│ - **[USER_GUIDE.md](USER_GUIDE.md)** - Detailed feature documentation and troubleshooting guide                      │
│                                                                                                                      │
│ ## Main Menu Options                                                                                                 │
│                                                                                                                      │
│ 1. **Dualog IMAP Repair Script**                                                                                     │
│    - Fix multiple body parts pointing to single mail                                                                 │
│    - Force-subscribe greyed-out folders                                                                              │
│                                                                                                                      │
│ 2. **Dualog IMAP Server Tool**                                                                                       │
│    - Test IMAP/SMTP server connectivity                                                                              │
│    - Test Shore Gateway connectivity                                                                                 │
│    - Change IMAP log levels                                                                                          │
│    - Find large files and attachments                                                                                │
│                                                                                                                      │
│ 3. **Enable Telnet Client**                                                                                          │
│    - Install Windows Telnet feature for diagnostics                                                                  │
│                                                                                                                      │
│ ## Logging                                                                                                           │
│                                                                                                                      │
│ All operations are logged to: `C:\WebmailLogs\WebmailFix_[timestamp].log`                                            │
│                                                                                                                      │
│ Logs include timestamps, operation details, and success/error messages.                                              │
│                                                                                                                      │
│ ## Requirements Met                                                                                                  │
│                                                                                                                      │
│ - ✓ Database credentials retrieved from Windows Registry                                                             │
│ - ✓ Oracle database connectivity testing                                                                             │
│ - ✓ Comprehensive error handling                                                                                     │
│ - ✓ Detailed audit logging                                                                                           │
│ - ✓ Color-coded console output                                                                                       │
│ - ✓ Interactive menu-driven interface                                                                                │
│                                                                                                                      │
│ ## Support                                                                                                           │
│                                                                                                                      │
│ For issues or questions:                                                                                             │
│ 1. Check the [USER_GUIDE.md](USER_GUIDE.md) troubleshooting section                                                  │
│ 2. Review logs in `C:\WebmailLogs`                                                                                   │
│ 3. Contact your system administrator or Dualog support                                                               │
│                                                                                                                      │
│ ## Version                                                                                                           │
│                                                                                                                      │
│ **v1.0** - Initial Release                                                                                           │
│                                                                                                                      │
│ ## License                                                                                                           │
│                                                                                                                      │
│ Internal Use Only                                                                                                    │
│                                                                                                                      │
│ ---                                                                                                                  │
│                                                                                                                      │
│ *For detailed information on each feature, see [USER_GUIDE.md](USER_GUIDE.md)*  
