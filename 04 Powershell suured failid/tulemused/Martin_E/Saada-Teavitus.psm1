function Send-AlertMessage {
<#
.SYNOPSIS
Saadab teavituse Discordi webhooki kaudu.

.DESCRIPTION
Send-AlertMessage saadab REST API kaudu embed-teate Discordi.
Webhook URL loetakse keskkonnamuutujast ALERT_WEBHOOK.

.PARAMETER Message
Teate tekst.

.PARAMETER Severity
Info, Warning või Critical.

.PARAMETER Source
Serveri või arvuti nimi. Vaikimisi kasutab kohaliku arvuti nime.

.EXAMPLE
Send-AlertMessage -Message "Ketas täis" -Severity Warning
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [string]$Source = $env:COMPUTERNAME
    )

    # --- Loe URL keskkonnamuutujast ---
    $url = $env:ALERT_WEBHOOK
    if (-not $url) {
        throw "Keskkonnamuutuja ALERT_WEBHOOK puudub. Lisa see käsuga:`n`n[Environment]::SetEnvironmentVariable('ALERT_WEBHOOK','SINU_URL','User')"
    }

    # --- Severity värvid ---
    $color = switch ($Severity) {
        "Info"     { 3447003 }     # sinine
        "Warning"  { 16776960 }    # kollane
        "Critical" { 15158332 }    # punane
    }

    # --- Discord embed payload ---
    $payload = @{
        username = "PS-Monitor"
        embeds = @(
            @{
                title       = "[$Severity] $Source"
                description = $Message
                color       = $color
                timestamp   = (Get-Date).ToString("o")
            }
        )
    }

    $json = $payload | ConvertTo-Json -Depth 4

    # --- Logifail ---
    $logPath = Join-Path $env:TEMP "ps-alerts.log"
    $aeg = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # --- REST päring ---
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $json -ContentType "application/json" -ErrorAction Stop
        Add-Content -Path $logPath -Value "$aeg [OK] $Severity | $Source | $Message"
    }
    catch {
        Add-Content -Path $logPath -Value "$aeg [FAIL] $Severity | $Source | $Message | $($_.Exception.Message)"
        Write-Warning "Teavituse saatmine ebaõnnestus: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Send-AlertMessage