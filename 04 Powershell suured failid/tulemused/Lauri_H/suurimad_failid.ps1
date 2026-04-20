# Määra kasutaja kodukaust
$homePath = $env:USERPROFILE

# Leia kõik failid rekursiivselt ja sorteeri suuruse järgi
$files = Get-ChildItem -Path $homePath -Recurse -File -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 10

# Funktsioon suuruse teisendamiseks
function Convert-Size {
    param ([long]$bytes)

    if ($bytes -ge 1GB) {
        return "{0:N1} GB" -f ($bytes / 1GB)
    }
    elseif ($bytes -ge 1MB) {
        return "{0:N1} MB" -f ($bytes / 1MB)
    }
    elseif ($bytes -ge 1KB) {
        return "{0:N1} KB" -f ($bytes / 1KB)
    }
    else {
        return "$bytes B"
    }
}

# Töötle tulemused
$result = $files | ForEach-Object {
    [PSCustomObject]@{
        Tee    = $_.FullName
        Nimi   = $_.Name
        Suurus = Convert-Size $_.Length
    }
}

# Salvesta CSV skripti kausta
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputFile = Join-Path $scriptPath "suurimad_failid.csv"

$result | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "Valmis! Fail salvestatud: $outputFile"