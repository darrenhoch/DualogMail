# Telnet Dualog Shore Gateway - User Guide

## Overview
This PowerShell script tests TCP connectivity to multiple Dualog Shore Gateway servers concurrently. It validates not only that connections can be established, but also that the servers respond with the expected protocol handshake.

## Purpose
Use this tool to verify connectivity and availability of Dualog shore-based gateway infrastructure, typically used for maritime communication systems.

## System Requirements
- Windows PowerShell 5.1 or later
- Network access to Dualog Shore Gateway servers
- No additional modules required

## How to Run the Script

### Method 1: Right-click and Run
1. Navigate to the script location
2. Right-click on `telnetDualogShoreGateway.ps1`
3. Select "Run with PowerShell"

### Method 2: PowerShell Command Line
1. Open PowerShell
2. Navigate to the script directory:
   ```powershell
   cd "E:\OneDrive\OneDrive - Dualog AS\Claude\Project\Telnet Dualog Tool"
   ```
3. Run the script:
   ```powershell
   .\telnetDualogShoreGateway.ps1
   ```

### Execution Policy Note
If you encounter an error about execution policy, run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Target Servers
The script tests connectivity to the following Dualog Shore Gateway servers:

| Server IP       | Port  | Description |
|----------------|-------|-------------|
| 93.188.232.240 | 4550  | Gateway Server 1 |
| 93.188.232.39  | 109   | Gateway Server 2 |
| 93.188.232.40  | 110   | Gateway Server 3 |
| 93.188.232.38  | 80    | Gateway Server 4 |
| 93.188.232.45  | 50100 | Gateway Server 5 |

## Understanding the Output

### Initial Phase
```
=====================================
STARTING CONNECTION TESTS
=====================================
Testing connections to the following servers:
  - 93.188.232.240:4550
  - 93.188.232.39:109
  ...
```
Shows which servers will be tested.

### Testing Phase
```
[→] Initiating test for 93.188.232.240:4550...
[→] Initiating test for 93.188.232.39:109...
```
Indicates when each connection test begins.

### Progress Bar
```
Testing TCP Connections
3 of 5 completed - 2 in progress
[████████████░░░░░░░░] 60%
```
Shows real-time progress of all connection tests.

### Results Display
As each test completes, you'll see:

**Successful Connection:**
```
[✓] 93.188.232.240:4550 - PASS
```
Green text indicates the server is reachable and responding correctly.

**Failed Connection:**
```
[✗] 93.188.232.39:109 - FAIL
```
Red text indicates the server is unreachable or not responding as expected.

### Final Summary
```
=====================================
SUMMARY OF CONNECTION TESTS
=====================================
93.188.232.240:4550 - PASS
93.188.232.39:109 - FAIL
...

Total Hosts Tested : 5
Passed              : 3
Failed              : 2
=====================================

Press Enter to exit
```

## Connection Test Details

### What the Script Tests
1. **TCP Connection**: Can the server be reached on the specified port?
2. **Response Timeout**: Does the server respond within 20 seconds?
3. **Protocol Validation**: Does the server send the expected "USR" handshake?

### Test Criteria
- **PASS**: Connection established AND "USR" response received
- **FAIL**: Connection timeout, connection refused, or no "USR" response
- **ERROR**: Network error or unexpected exception

## Troubleshooting

### All Tests Fail
- Check your internet connection
- Verify firewall settings allow outbound connections
- Confirm VPN connection if required

### Some Tests Fail
- Note which specific servers fail
- Failed tests may indicate:
  - Server maintenance
  - Network routing issues
  - Specific firewall rules blocking certain ports

### Script Window Closes Immediately
- The script now includes a pause at the end
- If it still closes, run from PowerShell command line to see error messages

### Timeout Issues
- Default timeout is 20 seconds per server
- All tests run concurrently (simultaneously)
- Total script runtime should be approximately 20-25 seconds maximum

## Customization

### Changing Target Servers
Edit the `$targets` array at the beginning of the script (lines 6-12):
```powershell
$targets = @(
    @{ Server = "YOUR.IP.ADDRESS"; Port = PORT_NUMBER },
    ...
)
```

### Adjusting Timeout
Modify the `$maxWaitSeconds` variable (line 14):
```powershell
$maxWaitSeconds = 30  # Change from 20 to 30 seconds
```

### Changing Expected Response
Modify the protocol check (lines 55-56, 66):
```powershell
if ($chunk -match "(?i)USR") {  # Change "USR" to expected response
```

## Best Practices
- Run the script before attempting to use Dualog services
- Document failed connections and report to IT/Network team
- Run periodically to establish baseline connectivity
- Keep a log of results for troubleshooting patterns

## Support
For issues with:
- **Script functionality**: Contact your IT department
- **Network connectivity**: Contact your network administrator
- **Dualog services**: Contact Dualog support

## Version History
- **Current Version**: Enhanced with progress indicators and detailed output
- Supports PowerShell 5.1+
- Concurrent testing with real-time feedback
