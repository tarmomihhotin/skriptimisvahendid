<#
.SYNOPSIS
Saadab teavituse Power Automate REST API kaudu Microsoft Teamsi kanalisse.

.DESCRIPTION
Moodul pakub funktsiooni Send-AlertMessage, mis saadab JSON-põhise
teavituse Power Automate HTTP triggerisse. Toetab logimist, veakäsitlust
ja struktureeritud severity tasemeid.

.PARAMETER Message
Teavituse sisu (kohustuslik).

.PARAMETER Severity
Teavituse tase: Info, Warning, Critical.

.PARAMETER Source
Teavituse allikas (nt skripti nimi või server).

.EXAMPLE
Send-AlertMessage -Message "Test töötab"

.EXAMPLE
Send-AlertMessage -Message "Ketas täis" -Severity Warning

.EXAMPLE
Send-AlertMessage -Message "Server maas" -Severity Critical -Source "DC01"
#>

function Send-AlertMessage {

    [CmdletBinding()]
    param(

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateSet("Info","Warning","Critical")]
        [string]$Severity = "Info",

        [Parameter()]
        [string]$Source = "PowerShellScript"
    )

    # logifail lokaalses masinas
    $logFile = "$env:TEMP\ps-alerts.log"

    try {

        # loe config.psd1 (hoiab webhook URL-i väljaspool koodi)
        $configPath = Join-Path $PSScriptRoot "config.psd1"

        if (-not (Test-Path $configPath)) {
            throw "config.psd1 puudub mooduli kaustast"
        }

        $config = Import-PowerShellDataFile $configPath

        if (-not $config.WebhookUrl) {
            throw "WebhookUrl puudub config.psd1 failist"
        }

        # ehita payload Power Automate jaoks
        $payload = @{
            message  = $Message
            severity = $Severity
            source   = $Source
        }

        $json = $payload | ConvertTo-Json -Depth 3

        # saada REST päring Power Automate'i
        Invoke-RestMethod `
            -Uri $config.WebhookUrl `
            -Method Post `
            -ContentType "application/json" `
            -Body $json `
            -ErrorAction Stop

        # logi edu
        Add-Content $logFile "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') OK - $Severity - $Message - $Source"

        Write-Verbose "Teavitus saadetud edukalt"

    }
    catch {

        # logi viga
        Add-Content $logFile "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') FAIL - $Severity - $Message - $Source - $_"

        Write-Warning "Teavituse saatmine ebaõnnestus: $_"

        # otsus: ei viska errorit üles (monitoring peab jätkuma)
    }
}

Export-ModuleMember -Function Send-AlertMessage