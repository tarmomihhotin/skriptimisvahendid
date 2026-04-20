param(
    [string]$Otsingukaust = [Environment]::GetFolderPath("UserProfile")  # vaikimisi kodukaust
)
# Samm 1 — leia kõik failid kodukaustas ja välista AppData
$failid = Get-ChildItem -Path $Otsingukaust -Recurse -File -ErrorAction SilentlyContinue |
          Where-Object { $_.FullName -notmatch "\\AppData\\" }

# Samm 2 — sorteeri suuruse järgi ja võta 10 esimest
$suuredFailid = $failid | Sort-Object Length -Descending | Select-Object -First 10

# Samm 3 — teisenda baidid loetavasse ühikusse

function Convert-Size {
    param($bytes)
    if ($bytes -ge 1GB) { "{0:N1} GB" -f ($bytes/1GB) }
    elseif ($bytes -ge 1MB) { "{0:N1} MB" -f ($bytes/1MB) }
    elseif ($bytes -ge 1KB) { "{0:N1} KB" -f ($bytes/1KB) }
    else { "$bytes B" }
}

# Samm 4 — ehita iga faili kohta objekt

$tulemused = $suuredFailid | ForEach-Object {
    [PSCustomObject]@{
        Tee      = $_.FullName
        Nimi     = $_.Name
        Suurus   = Convert-Size $_.Length
        Muudetud = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Samm 5 — salvesta CSV-faili
$väljundfail = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "suurimad_failid.csv"
$tulemused | Export-Csv -Path $väljundfail -NoTypeInformation -Encoding UTF8

Write-Host "Tulemus salvestatud: $väljundfail"

Import-Module .\Saada-Teavitus.psm1 -Force

foreach ($fail in $tulemused) {

    $baite = (Get-Item $fail.Tee -ErrorAction SilentlyContinue).Length

    if ($baite -ge 5GB) {
        Send-AlertMessage -Message "Väga suur fail: $($fail.Nimi) ($($fail.Suurus))" -Severity Critical
    }
    elseif ($baite -ge 1GB) {
        Send-AlertMessage -Message "Suur fail: $($fail.Nimi) ($($fail.Suurus))" -Severity Warning
    }
}