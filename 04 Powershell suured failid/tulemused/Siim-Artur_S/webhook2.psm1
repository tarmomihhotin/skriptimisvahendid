    function Send-AlertMessage {
        <#
        .SYNOPSIS
            Teavituse saatmine kanalisse.

        .DESCRIPTION
            Send-AlertMessage saadab REST API kaudu teate kanalisse.
            URL loetakse konfifailist, mitte koodist.

        .Parameter Message
            Teate tekst. Kohustuslik.

        .PARAMETER Severity
            Teate raskusaste: Info, Warning või Critical. Vaikimisi seadistatud.

        .PARAMETER Source
            Allika nimi - Vaikimisi arvuti nimi.

        .EXAMPLE
            Send-AlertMessage -Message "Ketas 90% täis" -Severity Warning

        .EXAMPLE
            Send-AlertMessage -Message "Teenus ei tööta" -Severity Critical -Source "DC01"     
        #>
[CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warning", "Critical")]
        [string]$Severity = "Info",
        
        [string]$Source = $env:COMPUTERNAME
    )

    # 1. Konfiguratsiooni laadimine funktsiooni SEES
    $configPath = Join-Path $PSScriptRoot "config.psd1"
    
    if (-not (Test-Path $configPath)) {
        Write-Error "Konfiguratsioonifaili ei leitud: $configPath"
        return
    }

    $config = Import-PowerShellDataFile $configPath
    $url = $config.WebhookUrl  # Veendu, et psd1 failis on täpselt see nimi

    # 2. Värvi määramine
    $color = switch ($Severity) {
        "Info"     { 3447003 }  # sinine
        "Warning"  { 16776960 } # kollane
        "Critical" { 15158332 } # punane
        Default    { 3447003 }
    }
    
    # 3. Andmete ettevalmistamine (Payload)
    $payload = @{
        username = "PS-Monitor"
        embeds = @(@{
            title       = "[$Severity] $Source"
            description = $Message
            color       = $color
            timestamp   = (Get-Date).ToString("o")
        })
    } | ConvertTo-Json -Depth 4

    # 4. Saatmise proovimine ja veahaldus
    try {
        Invoke-RestMethod -Uri $url -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
        Write-Verbose "Teavitus saadetud: $Message"
    }
    catch {
        # Logimise seaded
        $logPath = Join-Path $PSScriptRoot "webhook.log"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Veateate koostamine
        $logEntry = "[$timestamp] VIGA: $($_.Exception.Message) | Sõnum: $Message"
        
        # Kirjutamine logisse ja ekraanile
        $logEntry | Add-Content -Path $logPath
        Write-Warning "Teavituse saatmine ebaõnnestus. Logi asub: $logPath"
    }
}

function Format-FileSize {
    param ([long]$size)
    if ($size -ge 1GB) { "{0:N2} GB" -f ($size / 1GB) }
    elseif ($size -ge 1MB) { "{0:N2} MB" -f ($size / 1MB) }
    elseif ($size -ge 1KB) { "{0:N2} KB" -f ($size / 1KB) }
    else { "$size B" }
}

Write-Host "Otsin suurimaid faile, see võib võtta hetke..." -ForegroundColor Cyan

# Määrame kodukausta (nagu Pythonis home_dir)
$homeDir = [System.Environment]::GetFolderPath("UserProfile")

# Otsime faile, sorteerime suuruse järgi ja võtame top 10
$topFiles = Get-ChildItem -Path $homeDir -File -Recurse -ErrorAction SilentlyContinue | 
            Sort-Object Length -Descending | 
            Select-Object -First 10

# Koostame sõnumi teksti
$messageBody = "Siin on 10 suurimat faili:`n`n"
foreach ($file in $topFiles) {
    $formattedSize = Format-FileSize -size $file.Length
    $messageBody += " **$formattedSize** - $($file.FullName)`n"
}

# Saadame raporti Discordi
if ($topFiles) {
    Send-AlertMessage -Message $messageBody -Severity "Info"
    Write-Host "Raport saadetud Discordi!" -ForegroundColor Green
} else {
    Write-Warning "Faile ei leitud või puuduvad õigused."
}