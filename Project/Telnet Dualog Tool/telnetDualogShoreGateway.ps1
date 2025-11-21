# ==========================================
# Multi-host TCP connection test (PowerShell 5.1 compatible)
# Concurrent using Start-Job with Progress Bar
# ==========================================

$targets = @(
    @{ Server = "93.188.232.240"; Port = 4550 },
    @{ Server = "93.188.232.39";  Port = 109  },
    @{ Server = "93.188.232.40";  Port = 110  },
    @{ Server = "93.188.232.38";  Port = 80   },
    @{ Server = "93.188.232.45";  Port = 50100 }
)

$maxWaitSeconds = 20
$jobs = @()

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "STARTING CONNECTION TESTS" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Testing connections to the following servers:" -ForegroundColor Yellow
foreach ($target in $targets) {
    Write-Host "  - $($target.Server):$($target.Port)" -ForegroundColor White
}
Write-Host ""

# Start a job for each host
foreach ($target in $targets) {
    Write-Host "[→] Initiating test for $($target.Server):$($target.Port)..." -ForegroundColor Cyan
    $jobs += Start-Job -ArgumentList $target, $maxWaitSeconds -ScriptBlock {
        param($target, $maxWaitSeconds)

        $server = $target.Server
        $port = $target.Port
        $status = "FAIL"
        $responseText = ""

        Write-Host "`nTesting ${server}:${port} ..."

        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $async = $client.BeginConnect($server, $port, $null, $null)

            if (-not $async.AsyncWaitHandle.WaitOne($maxWaitSeconds * 1000)) {
                Write-Host "Connection timeout: ${server}:${port}" -ForegroundColor Red
                return [PSCustomObject]@{ Server=$server; Port=$port; Result="FAIL - Timeout" }
            }

            $client.EndConnect($async)
            $stream = $client.GetStream()
            $stream.ReadTimeout = 1000

            $buffer = New-Object byte[] 1024
            $responseBuilder = New-Object System.Text.StringBuilder
            $foundUSR = $false

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            while ($stopwatch.Elapsed.TotalSeconds -lt $maxWaitSeconds) {
                if ($stream.DataAvailable) {
                    try {
                        $read = $stream.Read($buffer, 0, $buffer.Length)
                        if ($read -le 0) { break }
                        $chunk = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read)
                        $responseBuilder.Append($chunk) | Out-Null
                        if ($chunk -match "(?i)USR") {
                            $foundUSR = $true
                            break
                        }
                    } catch { break }
                }
                Start-Sleep -Milliseconds 200
            }

            $responseText = $responseBuilder.ToString().Trim()

            if ($foundUSR -or ($responseText -match "(?i)USR")) {
                Write-Host "PASS - Connection to ${server}:${port} successful" -ForegroundColor Green
                $status = "PASS"
            } else {
                Write-Host "FAIL - Connection to ${server}:${port} failed" -ForegroundColor Red
            }

            return [PSCustomObject]@{ Server=$server; Port=$port; Result=$status }

        } catch {
            Write-Host "ERROR - ${server}:${port} - $($_.Exception.Message)" -ForegroundColor Yellow
            return [PSCustomObject]@{ Server=$server; Port=$port; Result="FAIL - Error" }
        } finally {
            if ($client -and $client.Connected) { $client.Close() }
        }
    }
}

# ==========================================
# Progress Monitoring Section
# ==========================================
Write-Host "`nMonitoring connection tests..." -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan

$results = @()
$completed = 0
$total = $jobs.Count
$processedJobOutput = @{}

while ($jobs.Count -gt 0) {
    $runningJobs = $jobs | Where-Object { $_.State -eq 'Running' }
    $completed = $total - $runningJobs.Count

    # Update progress bar
    $percentComplete = [math]::Round(($completed / $total) * 100)
    Write-Progress -Activity "Testing TCP Connections" `
                   -Status "$completed of $total completed - $($runningJobs.Count) in progress" `
                   -PercentComplete $percentComplete

    # Show real-time output from running jobs
    foreach ($job in $jobs) {
        if (-not $processedJobOutput.ContainsKey($job.Id)) {
            $processedJobOutput[$job.Id] = $true
        }

        # Get any output from the job (even if still running)
        $output = Receive-Job -Job $job -Keep
        if ($output -and $job.State -ne 'Completed') {
            # Job is still running, just showing it's active
            # The actual output will be shown when complete
        }
    }

    # Check for completed jobs
    $finishedJobs = $jobs | Where-Object { $_.State -eq 'Completed' }
    foreach ($job in $finishedJobs) {
        $result = Receive-Job -Job $job
        if ($result) {
            $results += $result
            # Show result immediately
            if ($result.Result -match "PASS") {
                Write-Host "[✓] $($result.Server):$($result.Port) - PASS" -ForegroundColor Green
            } else {
                Write-Host "[✗] $($result.Server):$($result.Port) - FAIL" -ForegroundColor Red
            }
        }
        Remove-Job -Job $job
        $jobs = $jobs | Where-Object { $_.Id -ne $job.Id }
    }

    Start-Sleep -Milliseconds 500
}

Write-Progress -Activity "Testing TCP Connections" -Completed

# ==========================================
# Summary Section
# ==========================================
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "SUMMARY OF CONNECTION TESTS"
Write-Host "=====================================" -ForegroundColor Cyan

foreach ($r in $results) {
    if ($r.Result -match "PASS") {
        Write-Host ("{0}:{1} - PASS" -f $r.Server, $r.Port) -ForegroundColor Green
    } else {
        Write-Host ("{0}:{1} - FAIL" -f $r.Server, $r.Port) -ForegroundColor Red
    }
}

$total = $results.Count
$pass = ($results | Where-Object { $_.Result -match "PASS" }).Count
$fail = $total - $pass

Write-Host "`nTotal Hosts Tested : $total"
Write-Host "Passed              : $pass" -ForegroundColor Green
Write-Host "Failed              : $fail" -ForegroundColor Red
Write-Host "=====================================`n" -ForegroundColor Cyan

# Keep window open to view results
Read-Host -Prompt "Press Enter to exit"