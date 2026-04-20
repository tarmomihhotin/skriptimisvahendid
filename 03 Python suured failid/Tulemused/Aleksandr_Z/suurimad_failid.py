from pathlib import Path
import tempfile
import csv

def inimloetav_suurus(byte):
    if byte >= 1024 ** 3:
        return f"{byte / (1024 ** 3):.2f} GB"
    elif byte >= 1024 ** 2:
        return f"{byte / (1024 ** 2):.2f} MB"
    elif byte >= 1024:
        return f"{byte / 1024:.2f} KB"
    return f"{byte} B"

kodu = Path.home()
temp_kaust = Path(tempfile.gettempdir()).resolve()

failid = []
for fail in kodu.rglob("*"):
    try:
        fail_resolved = fail.resolve()

        if fail_resolved == temp_kaust or temp_kaust in fail_resolved.parents:
            continue

        if fail_resolved.is_file():
            suurus = fail_resolved.stat().st_size
            failid.append((fail_resolved, suurus))

    except (PermissionError, FileNotFoundError, OSError):
        continue

print(f"Leitud faile kokku: {len(failid)}")

failid_sorditud = sorted(
    failid,
    key=lambda x: x[1],
    reverse=True
)[:10]

tulemus = []

for fail, suurus in failid_sorditud:
    tulemus.append({
        "Tee": str(fail),
        "Nimi": fail.name,
        "Suurus": inimloetav_suurus(suurus)
    })

print("\n10 kõige suuremat faili:")
for rida in tulemus:
    print(f"{rida['Nimi']} -> {rida['Suurus']}")

repo_juur = Path(__file__).resolve().parent.parent
valjund = Path("tulemused/Aleksandr_Z/suurimad_failid.csv")
valjund.parent.mkdir(parents=True, exist_ok=True)


with open(valjund, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["Tee", "Nimi", "Suurus"])
    writer.writeheader()
    writer.writerows(tulemus)

print("Valmis! Fail loodud:", valjund)