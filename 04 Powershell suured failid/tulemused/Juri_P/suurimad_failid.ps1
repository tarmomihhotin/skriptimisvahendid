# Import moodul
Import-Module .\Saada-Teavitus.psm1 -Force

param(
    [string]$Path = $HOME
)

$failid = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue

$top10 = $failid | Sort-Object Length -Descending | Select-Object -First 10

$tulemus = foreach ($fail in $top10) {

    $baite = $fail.Length

    if ($baite -ge 1GB) {
        $suurus = "{0:N1} GB" -f ($baite / 1GB)
    }
    elseif ($baite -ge 1MB) {
        $suurus = "{0:N1} MB" -f ($baite / 1MB)
    }
    else {
        $suurus = "{0:N1} KB" -f ($baite / 1KB)
    }

    [PSCustomObject]@{
        Tee      = $fail.FullName
        Nimi     = $fail.Name
        Suurus   = $suurus
        Baitides = $baite
    }
}

$tulemus | Export-Csv -Path "suurimad_failid.csv" -NoTypeInformation -Encoding UTF8

foreach ($fail in $tulemus) {

    if ($fail.Baitides -ge 5GB) {
        Send-AlertMessage `
            -Message "Väga suur fail: $($fail.Nimi) ($($fail.Suurus))" `
            -Severity Critical
    }
    elseif ($fail.Baitides -ge 1GB) {
        Send-AlertMessage `
            -Message "Suur fail: $($fail.Nimi) ($($fail.Suurus))" `
            -Severity Warning
    }
}