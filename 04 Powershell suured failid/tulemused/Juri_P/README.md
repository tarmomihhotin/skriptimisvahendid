# Saada-Teavitus

See moodul saadab PowerShelli kaudu teavitusi Discordi kanalisse webhooki abil. 

---

## Failid

- **Saada-Teavitus.psm1** - PowerShelli moodul funktsiooniga **Send-AlertMessage**  
- **config.example.psd1** - näidiskonfiguratsioon (ilma reaalse webhookita) 
- **discord-jp.png**  - Discord channeli pilt

---

## Funktsionaalsus

Funktsioon **Send-AlertMessage** toetab järgmisi parameetreid:

- **-Message** - kohustuslik teate tekst  
- **-Severity** - tähtsuse tase: `Info`, `Warning`, `Critical` (vaikimisi `Info`)  
- **-Source** - teate allikas, vaikimisi praeguse masina nimi

Käitumine:

- Loeb webhooki kas keskkonnamuutujast **ALERT_WEBHOOK** või lokaalsest `config.psd1` failist mooduli kõrval.  
- Vormib Discordi embed-sõnumi, mille värv vastab `Severity` tasemele.  
- Saadab POST-päringu webhooki kaudu `Invoke-RestMethod` abil.  
- Logib iga saatmiskatse faili **%TEMP%\ps-alerts.log** koos märgisega **[OK]** või **[FAIL]**.  
- Käsitleb vigu `try/catch` plokis ja ei katkesta kutsuva skripti tööd, kui saatmine ebaõnnestub.

---
