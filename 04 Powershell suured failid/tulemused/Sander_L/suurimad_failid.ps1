Import-Module .\Saada-Teavitus.psm1 -Force

# Samm 1: leia kõik failid kodukaustas
$failid = Get-ChildItem -Path $HOME -Recurse -File -ErrorAction SilentlyContinue |
# Samm 2: sorteeri ja võta 10 suurimat
    Sort-Object -Property Length -Descending |
    Select-Object -First 10

# Samm 3-4: teisenda suurus ja ehita objektid
$tulemus = foreach ($fail in $failid) {
    $baite = $fail.Length

    if ($baite -ge 1GB) {
        $suurus = "{0:N1} GB" -f ($baite / 1GB)
    } elseif ($baite -ge 1MB) {
        $suurus = "{0:N1} MB" -f ($baite / 1MB)
    } else {
        $suurus = "{0:N1} KB" -f ($baite / 1KB)
    }

    [PSCustomObject]@{
        Tee    = $fail.FullName
        Nimi   = $fail.Name
        Suurus = $suurus
    }
}

# Samm 5: salvesta CSV
$tulemus | Export-Csv -Path "tulemused/Sander_L/suurimad_failid.csv" -NoTypeInformation -Encoding UTF8

Write-Host "Salvestatud: tulemused/Sander_L/suurimad_failid.csv"
Write-Host "Leitud $($tulemus.Count) faili."