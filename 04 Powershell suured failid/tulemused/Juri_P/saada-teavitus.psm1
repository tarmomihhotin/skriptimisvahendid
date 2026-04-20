<#
.SYNOPSIS
Discord

.DESCRIPTION
HTTP POST

.PARAMETER Message


.PARAMETER Severity


.PARAMETER Source


.EXAMPLE


.EXAMPLE


.NOTES

#>

function Send-AlertMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [string]$Source = $env:COMPUTERNAME
    )

    
    $url = $env:ALERT_WEBHOOK

    
    if (-not $url) {
        
        $moduleDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
        $configPath = Join-Path $moduleDir "config.psd1"

        if (Test-Path $configPath) {
            try {
                $cfg = Import-PowerShellDataFile -Path $configPath
                if ($null -ne $cfg -and $cfg.ContainsKey("AlertWebhook") -and $cfg.AlertWebhook) {
                    $url = $cfg.AlertWebhook
                }
            }
            catch {
                Write-Verbose "Couldn't read file config.psd1: $($_.Exception.Message)"
            }
        }
    }

    # url is not found
    if (-not $url) {
        Write-Error "ALERT_WEBHOOK is not setup."
        return
    }


    $color = switch ($Severity) {
        "Info"     { 3447003 }   # sinine
        "Warning"  { 16776960 }  # kollane 
        "Critical" { 15158332 }  # punane
    }

    
    $payloadObject = @{
        username = "PS-Monitor"
        embeds   = @(
            @{
                title       = "[$Severity] $Source"
                description = $Message
                color       = $color
                timestamp   = (Get-Date).ToString("o")
            }
        )
    }

    
    $json = $payloadObject | ConvertTo-Json -Depth 4

    
    $logPath = Join-Path $env:TEMP "ps-alerts.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $json -ContentType "application/json" -ErrorAction Stop
        Write-Verbose "Message delivered: $Message"
        Add-Content -Path $logPath -Value "$timestamp [OK] $Severity | $Source | $Message"
    }
    catch {
        Write-Warning "Message delivering error: $($_.Exception.Message)"
        Add-Content -Path $logPath -Value "$timestamp [FAIL] $Severity | $Source | $Message | $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Send-AlertMessage