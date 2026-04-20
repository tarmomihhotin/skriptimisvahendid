<#
.SYNOPSIS
    Kontrollib ID-tarkvara versiooni ja saadab teavituse kui uuendus on saadaval.

.DESCRIPTION
    Võrdleb SK serveris olevat uusimat Open-EID versiooni lokaalselt paigaldatud versiooniga.
    Kasutab Saada-Teavitus moodulit teavituste saatmiseks.

.PARAMETER KriitilineErinevus
    Mitme peaversiooni vahe korral saadetakse Critical (vaikimisi 2)

.PARAMETER TeataAjakohasusest
    Kui määratud, saadab Info ka siis kui kõik on OK
#>

[CmdletBinding()]
param(
    [int]$KriitilineErinevus = 2,
    [switch]$TeataAjakohasusest
)

# --- KONSTANTID ---
$SK_URL = "https://installer.id.ee/media/win/"
$MUSTER = 'Open-EID-(\d+\.\d+\.\d+\.\d+)\.exe'

Write-Host "Kontrollin ID-tarkvara versiooni..."

# --- LAE MOODUL ---
$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"
if (-not (Test-Path $moodul)) {
    throw "Saada-Teavitus.psm1 puudub!"
}
Import-Module $moodul -Force

# --- 1. UUSIM VERSIOON VEebist ---
try {
    $leht = Invoke-WebRequest -Uri $SK_URL -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Warning "Veebipäring ebaõnnestus: $($_.Exception.Message)"

    Send-AlertMessage `
        -Message "ID-tarkvara kontroll ebaõnnestus: $($_.Exception.Message)" `
        -Severity Warning `
        -Source "ID-tarkvara monitor"

    exit 1
}

$versioonid = [regex]::Matches($leht.Content, $MUSTER) |
    ForEach-Object { [Version]$_.Groups[1].Value } |
    Sort-Object -Descending

if (-not $versioonid) {
    throw "Ei leidnud ühtegi versiooni SK lehelt"
}

$uusim = $versioonid[0]

# --- 2. KOHALIK VERSIOON ---
$uninstallTeed = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$paigaldatud = Get-ItemProperty $uninstallTeed -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match "Open-EID|Estonian ID" } |
    Select-Object -First 1

if ($paigaldatud) {
    $kohalik = [Version]$paigaldatud.DisplayVersion
} else {
    $kohalik = $null
}

# --- 3. STAATUS ---
if (-not $kohalik) {
    $staatus = "POLE_PAIGALDATUD"
    $severity = "Warning"
    $sonum = "Open-EID pole paigaldatud. Uusim: $uusim"
}
elseif ($kohalik -eq $uusim) {
    $staatus = "OK"
    $severity = "Info"
    $sonum = "Open-EID on ajakohane ($kohalik)"
}
elseif (($uusim.Major - $kohalik.Major) -ge $KriitilineErinevus) {
    $staatus = "PALJU_VANEM"
    $severity = "Critical"
    $sonum = "Open-EID on väga vana ($kohalik → $uusim)"
}
else {
    $staatus = "AEGUNUD"
    $severity = "Warning"
    $sonum = "Open-EID uuendus saadaval ($kohalik → $uusim)"
}

# --- 4. VÄLJUND ---
Write-Host "  Kohalik versioon: $kohalik"
Write-Host "  Uusim saadaval:   $uusim"
Write-Host "  Staatus:          $staatus"

# --- 5. TEAVITUS ---
if ($staatus -ne "OK" -or $TeataAjakohasusest) {
    Send-AlertMessage `
        -Message $sonum `
        -Severity $severity `
        -Source "ID-tarkvara monitor"
}