# Harjutus: ID-tarkvara versiooni automaatne kontroll

**Kursus:** KIT-24
**Õpetaja:** Toivo Pärnpuu
**Keel:** PowerShell (Windows)
**Moodul:** `Microsoft.PowerShell.Utility` (kaasas) + eelmise tunni `Saada-Teavitus.psm1`

---

## Eesmärk

Eelmises harjutuses ehitasid teavituste mooduli. Selles harjutuses teed sellest päris tööriista: skripti, mis **jälgib ID-tarkvara uuenduste ilmumist** Riigi Infosüsteemi Ameti serveris, võrdleb seda sinu arvutisse paigaldatud versiooniga ja saadab teate, kui uus versioon on ootel.

Õpid, kuidas:

- pärida HTTPS-päringuga veebilehe sisu (`Invoke-WebRequest`)
- eraldada regulaaravaldise abil mustrile vastav info
- võrrelda versiooninumbreid **õigesti** (mitte stringidena — see on vigade allikas!)
- lugeda Windowsi registrist paigaldatud tarkvara andmeid
- taaskasutada eelmises harjutuses tehtud moodulit

Paigaldamisega **me selles harjutuses ei tegele** — skript annab ainult märku, et uuendus on vajalik. Kasutaja otsustab ise, kas paigaldada.

---

## Stsenaarium

Oled Techno-TLN laborite haldur. Tudengid kasutavad ID-kaarti e-õppekeskkonnas sisselogimiseks ja digiallkirjade andmiseks. Kui RIA avaldab ID-tarkvara uue versiooni ning laborite arvutid jäävad vanemaga, hakkavad esimesena purunema üliõpilaste eksamipäevad. Sa tahad teada **kohe**, kui uus versioon tuleb — mitte järgmisel nädalal üliõpilaste vihaste kirjade kaudu.

---

## Tulemus

Skript `kontrolli-id-tarkvara.ps1` töötab käsurealt nii:

```powershell
.\kontrolli-id-tarkvara.ps1
```

Ja annab umbes sellise väljundi:

```
Kontrollin ID-tarkvara versiooni...
  Kohalik versioon:     25.6.9.8395
  Uusim saadaval:       25.10.23.8403
  Staatus:              AEGUNUD — uuendus soovitatav

[Warning teavitus saadetud kanalisse]
```

Kui versioonid on samad, kirjutab skript "OK" ja ei saada midagi (või saadab Info — disainiotsus sulle).

---

## Nõuded

- Skript pärib uusima versiooni `https://installer.id.ee/media/win/` lehelt
- Kohalik versioon tuvastatakse Windowsi registrist
- Versioonide võrdlus on **tüübitud** (`[Version]`), mitte stringina
- Kõik neli olekut on käsitletud:
  1. Pole paigaldatud → Warning (või Critical)
  2. Paigaldatud, ajakohane → OK (võib saata Info)
  3. Paigaldatud, vananenud → Warning
  4. Paigaldatud, palju vanem (üle 2 peaversiooni) → Critical
- Teavitused käivad eelmise tunni `Saada-Teavitus` mooduli kaudu
- Võrgutõrke korral skript **ei jookse kokku**, vaid logib vea

---

## Hea tava — checklist

- [ ] **Ei hardkoodi uusimat versiooni** — see pärivad alati veebist
- [ ] **Versioonide võrdlus `[Version]` tüübiga**, mitte stringina
- [ ] **Regex on piisavalt täpne** — ei püüa `-plugins.exe` ega `_x86.exe` variante
- [ ] **`try/catch` iga võrgupäringu ümber**
- [ ] **Konstandid ülal** — URL, paketi nime muster, kriitilisuse lävi peaversioonides
- [ ] **`[CmdletBinding()]`** ja `param()` blokk — skript on parameetriseeritav
- [ ] **Kommentaaripõhine abi** (`<# .SYNOPSIS ... #>`) skripti ülaosas
- [ ] **Kõik neli olekut** (pole paigaldatud / ajakohane / aegunud / palju vanem) käsitletud
- [ ] **Teavituste moodul on sõltuvus, mitte kopeeritud kood** — taaskasutus töötab

---

## Ettevalmistus

1. Veendu, et eelmise tunni moodul `Saada-Teavitus.psm1` on olemas ja seadistatud (testimiseks käivita `Send-AlertMessage -Message "Test"`).
2. Kontrolli oma arvutis, kuidas Open-EID registris paistab:

   ```powershell
   Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
       -ErrorAction SilentlyContinue |
       Where-Object DisplayName -match "EID|Estonian ID" |
       Select-Object DisplayName, DisplayVersion, Publisher
   ```

   Pea meeles, mis `DisplayName` ja `DisplayVersion` sulle tagastab — seda läheb sammus 3 vaja.

3. Vaata veebilehte `https://installer.id.ee/media/win/` oma brauseris. Näed suurt failide nimekirja. Skript peab sealt leidma `Open-EID-<versioon>.exe` mustri uusima kirje.

---

## Skript samm-sammult

Iga samm on iseseisev — proovi kõigepealt ise lahendada, ava vihje alles siis, kui jääd toppama. Dokumentatsiooni lugemine on osa harjutusest.

---

### Samm 1 — lae alla SK veebilehe sisu

**Mida vajad:** `Invoke-WebRequest`, URL konstandina muutujas.

<details>
<summary>Vihje</summary>

```powershell
$SK_URL = "https://installer.id.ee/media/win/"

$leht = Invoke-WebRequest -Uri $SK_URL -UseBasicParsing

$leht.Content | Select-String "Open-EID" | Select-Object -First 5
```

`-UseBasicParsing` on oluline vanema PowerShell 5.1-ga — ilma selleta proovib PS kasutada Internet Explorerit, mida pole installitud. PS 7-l pole seda vaja, aga kahjuks ei tee.

Vaata, mida väljund näitab — näed tervet HTML-i. Sealt pead välja noppima failinimed.

</details>

---

### Samm 2 — leia kõik Open-EID versioonid regex'iga

Lehel on palju versioone (vanast `18.2.0.1777` kuni uusimani). Meid huvitab **ainult** põhi-installer, mitte `-plugins.exe` ega `_x86.exe` variandid.

**Mida vajad:** `[regex]::Matches()`, `[Version]` tüüp, `Sort-Object -Descending`.

<details>
<summary>Vihje — regex</summary>

```powershell
$muster = 'Open-EID-(\d+\.\d+\.\d+\.\d+)\.exe'

$vasted = [regex]::Matches($leht.Content, $muster)

foreach ($v in $vasted) {
    $v.Groups[1].Value
}
```

Regex seletus:
- `Open-EID-` — fikseeritud algus
- `(\d+\.\d+\.\d+\.\d+)` — püüab neli punktiga eraldatud numbrit (versioonistring), `Groups[1]` on see osa
- `\.exe` — just `.exe` lõpus, MITTE `-plugins.exe` ega `_x86.exe` (sest nende eel ei ole `.`)

Võrdle, kas tulemus sisaldab kirjeid nagu `18.2.0.1777-plugins` — ei tohiks.

</details>

<details>
<summary>Vihje — versioonide sorteerimine ÕIGESTI</summary>

**Siin on klassikaline viga:** kui sorteerid versioone stringina, saad vale vastuse:

```powershell
# VALE — stringidena
"25.10" -gt "25.6"     # tagastab $false (sest "1" < "6" tähestikuliselt)

# ÕIGE — [Version] tüübina
[Version]"25.10" -gt [Version]"25.6"     # tagastab $true
```

Nii et:

```powershell
$versioonid = $vasted | ForEach-Object { [Version]$_.Groups[1].Value } |
              Sort-Object -Descending

$uusim = $versioonid[0]
Write-Host "Uusim saadaval: $uusim"
```

`[Version]` on .NET-i tüüp, mis teab, et `25.10 > 25.6`. See töötab kuni 4 komponendini (Major.Minor.Build.Revision) — täpselt ID-tarkvara formaat.

</details>

---

### Samm 3 — leia kohalik paigaldatud versioon registrist

Windows hoiab paigaldatud programmide nimekirja registris. Kaks asukohta — üks 64-bitise, teine 32-bitise tarkvara jaoks. Pead mõlemat kontrollima.

**Mida vajad:** `Get-ItemProperty`, `Where-Object`, `Select-Object -First 1`.

<details>
<summary>Vihje</summary>

```powershell
$uninstallTeed = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$paigaldatud = Get-ItemProperty $uninstallTeed -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -match "Open-EID|Estonian ID" } |
               Select-Object -First 1

if ($paigaldatud) {
    $kohalik = [Version]$paigaldatud.DisplayVersion
    Write-Host "Kohalik versioon: $kohalik"
} else {
    $kohalik = $null
    Write-Host "Open-EID pole paigaldatud"
}
```

**Miks kaks teed?** `HKLM:\Software\...` sisaldab 64-bitist tarkvara, `WOW6432Node` sisaldab 32-bitist. Kui keegi on paigaldanud x86 versiooni 64-bitisele Windowsile, on see teises kohas.

**Miks `-match "Open-EID|Estonian ID"`?** Sest ei tea täpselt, mis nime alla installer end registreerib — võib olla kas "Open-EID", "Estonian ID Card software" vms. Kaitseme end mõlema vastu.

</details>

---

### Samm 4 — määra staatus ja koosta teate tekst

Nüüd sul on olemas `$kohalik` ja `$uusim` (mõlemad `[Version]` tüüpi). Vaja otsustada:

| Olukord | Staatus | Teavitus |
|---|---|---|
| Pole paigaldatud | `POLE_PAIGALDATUD` | Warning |
| Versioonid võrdsed | `OK` | (mitte midagi või Info) |
| Uuem olemas, sama peaversioon | `AEGUNUD` | Warning |
| Üle 2 peaversiooni vanem | `PALJU_VANEM` | Critical |

**Mida vajad:** `if/elseif/else`, `[Version]` omaduste lugemine (`.Major`).

<details>
<summary>Vihje</summary>

```powershell
if (-not $kohalik) {
    $staatus   = "POLE_PAIGALDATUD"
    $severity  = "Warning"
    $sõnum     = "Open-EID pole paigaldatud. Uusim saadaval: $uusim"
}
elseif ($kohalik -eq $uusim) {
    $staatus   = "OK"
    $severity  = "Info"
    $sõnum     = "Open-EID $kohalik on ajakohane"
}
elseif (($uusim.Major - $kohalik.Major) -ge 2) {
    $staatus   = "PALJU_VANEM"
    $severity  = "Critical"
    $sõnum     = "Open-EID $kohalik on oluliselt vananenud. Uusim: $uusim. Uuenda kiiresti!"
}
else {
    $staatus   = "AEGUNUD"
    $severity  = "Warning"
    $sõnum     = "Open-EID uuendus saadaval: $kohalik → $uusim"
}

Write-Host "Staatus: $staatus"
```

**Mõtle ise läbi:** kas "OK" juhtumil tahad üldse teavitust saata? Kui jah — inimene näeb iga päev "tarkvara on ajakohane", mis on müra. Kui ei — inimene ei tea, kas skript üldse jooksis. **Kesktee:** saada Info ainult esmaspäeviti (eelvaade ajastamise harjutuseks), muidu vaiki.

</details>

---

### Samm 5 — integreeri teavituste mooduliga

Lae eelmise tunni moodul ja kasuta `Send-AlertMessage`-i.

<details>
<summary>Vihje</summary>

```powershell
# Kas moodul on samas kaustas?
$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"

if (-not (Test-Path $moodul)) {
    Write-Error "Saada-Teavitus.psm1 pole leitud kaustast $PSScriptRoot"
    exit 1
}

Import-Module $moodul -Force

# Saada ainult siis, kui on tegelikult midagi teatada
if ($staatus -ne "OK") {
    Send-AlertMessage -Message $sõnum -Severity $severity -Source "ID-tarkvara monitor"
}
```

**Miks `-Source "ID-tarkvara monitor"`, mitte vaike (arvuti nimi)?** Sellepärast, et kui paljudest arvutitest tulevad samad teated, tahad kanalis näha, **millest** jutt käib, mitte ainult kust see tuli. Siin eristame teate konteksti.

</details>

---

### Samm 6 — paki kõik skripti kokku

Pane kõik sammud ühte `.ps1` faili. Skript peab olema **parameetriseeritav** — et hiljem saaks ajastatuna käivitades muuta näiteks kriitilisuse läve.

<details>
<summary>Vihje — skripti skelett</summary>

```powershell
<#
.SYNOPSIS
    Kontrollib ID-tarkvara uuendusi ja teavitab, kui uus versioon on saadaval.

.DESCRIPTION
    Pärib uusima versiooni installer.id.ee veebilehelt, võrdleb Windowsi
    registris oleva paigaldatud versiooniga ja saadab teate eelmise tunni
    Saada-Teavitus mooduli kaudu, kui uuendus on vajalik.

.PARAMETER KriitilineErinevus
    Mitme peaversiooni erinevuse korral saadetakse Critical, mitte Warning.
    Vaikimisi 2.

.PARAMETER TeataAjakohasusest
    Kui määratud, saadab Info-teate ka siis, kui tarkvara on ajakohane.
    Muidu vaikib.

.EXAMPLE
    .\kontrolli-id-tarkvara.ps1

.EXAMPLE
    .\kontrolli-id-tarkvara.ps1 -TeataAjakohasusest -Verbose
#>
[CmdletBinding()]
param(
    [int]   $KriitilineErinevus  = 2,
    [switch]$TeataAjakohasusest
)

# --- konstandid --------------------------------------------------
$SK_URL  = "https://installer.id.ee/media/win/"
$MUSTER  = 'Open-EID-(\d+\.\d+\.\d+\.\d+)\.exe'

# --- lae moodul --------------------------------------------------
$moodul = Join-Path $PSScriptRoot "Saada-Teavitus.psm1"
if (-not (Test-Path $moodul)) { throw "Saada-Teavitus.psm1 puudub" }
Import-Module $moodul -Force

# --- 1. uusim versioon SK-st -------------------------------------
try {
    $leht = Invoke-WebRequest -Uri $SK_URL -UseBasicParsing -ErrorAction Stop
}
catch {
    # Võrk maas? Anname teada, aga ei kokku jooksе.
    Send-AlertMessage `
        -Message "ID-tarkvara kontroll: ei õnnestunud päringut teha ($($_.Exception.Message))" `
        -Severity Warning -Source "ID-tarkvara monitor"
    exit 1
}

$versioonid = [regex]::Matches($leht.Content, $MUSTER) |
              ForEach-Object { [Version]$_.Groups[1].Value } |
              Sort-Object -Descending

if (-not $versioonid) { throw "SK lehelt ei leitud ühtegi Open-EID versiooni — kas muster muutus?" }

$uusim = $versioonid[0]

# --- 2. kohalik versioon registrist -----------------------------
# ... (sinu kood sammust 3)

# --- 3. staatus -------------------------------------------------
# ... (sinu kood sammust 4)

# --- 4. teavita -------------------------------------------------
# ... (sinu kood sammust 5)
```

Täida tühikud oma varem testitud koodiga. Testi käivitades mitme variandiga:
- tavaline käivitus
- `-Verbose` (näitab rohkem detaile)
- katkesta võrguühendus ja käivita uuesti — kas skript käitub viisakalt?

</details>

---

## Mida sa õppisid

| Mõiste / käsk | Tähendus |
|---|---|
| `Invoke-WebRequest -UseBasicParsing` | HTTP GET päring, ilma IE sõltuvuseta |
| `[regex]::Matches(tekst, muster)` | Kõigi vastete leidmine regex'iga |
| `$match.Groups[1].Value` | Regex'i sulgudes olnud osa väärtus |
| `[Version]"25.10"` | Tüübiga versiooninumber — võrdleb õigesti |
| `HKLM:\...\Uninstall\*` | Registri koht, kus on kõik paigaldatud programmid |
| `WOW6432Node` | 32-bitise tarkvara register 64-bitises Windowsis |
| `Get-ItemProperty` | Registri väärtuste lugemine |
| `-match "A\|B"` | OR-tingimus `Where-Object`-is |
| `$PSScriptRoot` | Kaust, milles käesolev skript asub |
| `[CmdletBinding()]` + `[switch]` | Standardsed parameetrid, boolean-lülitid |

---

## Lisaküsimused (valikuline)

1. **Ka Web-eID versioon.** Brauseri laiendus on eraldi pakett (vaata `https://installer.id.ee/media/web-eid/`). Lisa selle kontroll eraldi funktsioonina, et sama skript teaks mõlemat.

2. **Ajastatud käivitus.** Kuidas panna see skript iga päev kell 7 hommikul jooksma? Uuri `Register-ScheduledTask` cmdlet-i. Tähelepanu: `$env:ALERT_WEBHOOK` keskkonnamuutuja peab olema saadaval ka ajastatud tööle, mitte ainult su interaktiivsele seansile. See on järgmise tunni teema — aga proovi ette lugeda.

3. **Cache.** Kui skript jookseb iga tund, on RIA serverile 24 päringut päevas tervelt ilma põhjuseta. Kuidas vältida päringut, kui viimasest edukast kontrollist on alla 6 tunni? Uuri, kuidas hoida lihtsat olekut failis (`Get-Content` + JSON).

4. **Teistmoodi ka ID-kaardi registri info kasutamine.** Vaata `Get-ChildItem Cert:\CurrentUser\My` — seal on sinu ID-kaardi sertifikaadid (kui kaart on lugejas). Kuidas kontrollida, millal sertifikaat aegub, ja teavitada 30 päeva enne?

---

## Tulemuse esitamine — Pull Request

Loo oma kausta järgnev struktuur:

```
tulemused/Eesnimi_P/
├── Saada-Teavitus.psm1          <- eelmise harjutuse moodul
├── config.example.psd1          <- eelmise harjutuse näidiskonfig
├── .gitignore
├── kontrolli-id-tarkvara.ps1    <- selle harjutuse skript
└── README.md                    <- uuenda, et kajastaks ka uut skripti
```

Märkus: kui `Saada-Teavitus.psm1` on juba eelmise PR-iga Gitis, pole vaja seda uuesti commitida — võid lihtsalt viidata sellele README-s.

```bash
git checkout -b harjutus-id-kontroll-Eesnimi
git add tulemused/Eesnimi_P/kontrolli-id-tarkvara.ps1
git add tulemused/Eesnimi_P/README.md
git commit -m "Lisa ID-tarkvara versiooni kontroll — Eesnimi P"
git push -u origin harjutus-id-kontroll-Eesnimi
```

Ava GitHubis **Compare & pull request** ja loo PR pealkirjaga:

```
ID-tarkvara versiooni kontroll — Eesnimi P
```

**PR kirjeldusse lisa:**

- Screenshot käivitatud skriptist, mis näitab staatust ja saadab teate
- Screenshot Teamsi/Discordi kanalist saadud teatega (katkesta webhook URL!)
- Lühike mõttekäik: mille üle sa kõige rohkem kõhklesid? (Versiooni võrdluse viga? Regex'i täpsus? Mis sai puhtaks alles testides?)
- Millise olekuga sa **ei saanud** testida, kuna sul pole seda arvutis? (Näiteks "pole paigaldatud" stsenaarium — kuidas siiski veendusid, et see haru töötab?)

---

*Kui SK serveri URL või kataloogi struktuur on muutunud, kontrolli `https://installer.id.ee/media/win/` brauseris — võib-olla mustrit tuleb kohendada. Reaalsetes tingimustes skriptid vananevad siis, kui välised teenused muutuvad, ja õpilane peab olema valmis koodi kohandama. See on osa tööst.*