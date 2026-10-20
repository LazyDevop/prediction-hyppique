"""Collecte brute d'un échantillon de réponses PMU (turfinfo) et open-pmu-api
pour l'inventaire empirique des champs. Écrit tout en JSON dans OUT, sans
interprétation. Relançable : les fichiers déjà présents ne sont pas refetchés."""

import json
import sys
import time
from datetime import date, timedelta
from pathlib import Path

import requests

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
UA = {"User-Agent": "prediction-hippique-backend/1.0 (personal project; field inventory)"}
PMU = "https://offline.turfinfo.api.pmu.fr/rest/client/61/programme"
PMU_ONLINE = "https://online.turfinfo.api.pmu.fr/rest/client/1/programme"
OPEN = "https://open-pmu-api.vercel.app/api/arrivees"
DELAY = 0.8
COURSES_PAR_DATE = 6
PERFS_PAR_DATE = 2
log = open(OUT / "_log.txt", "a", encoding="utf-8")


def note(msg):
    print(msg, flush=True)
    log.write(msg + "\n")
    log.flush()


def fetch(name, url, params=None):
    path = OUT / f"{name}.json"
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    try:
        r = requests.get(url, headers=UA, params=params, timeout=20)
        time.sleep(DELAY)
        if r.status_code != 200:
            note(f"HTTP {r.status_code} {name}")
            path.write_text(json.dumps({"_http_status": r.status_code}), encoding="utf-8")
            return None
        data = r.json()
    except Exception as e:  # noqa: BLE001
        note(f"ERR {name}: {e!r}")
        return None
    path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    return data


def premier(jour_semaine, annee, mois, rang=1):
    d = date(annee, mois, 1)
    while d.weekday() != jour_semaine:
        d += timedelta(days=1)
    return d + timedelta(weeks=rang - 1)


dates = []
for y in range(2014, 2027):
    dates.append(premier(6, y, 3))          # 1er dimanche de mars
    dates.append(premier(2, y, 9, 2))       # 2e mercredi de septembre
dates += [date(2026, 6, 7), date(2026, 7, 6), date(2026, 10, 18)]
dates = sorted(set(dates))

for d in dates:
    ds = d.strftime("%d%m%Y")
    prog = fetch(f"prog_{ds}", f"{PMU}/{ds}")
    fetch(f"open_{ds}", OPEN, {"date": d.strftime("%m/%d/%Y")})
    if not prog:
        continue
    par_disc = {}
    for reu in prog.get("programme", {}).get("reunions", []):
        if (reu.get("pays") or {}).get("code") != "FRA":
            continue
        for c in reu.get("courses", []):
            par_disc.setdefault(c.get("discipline"), []).append((reu.get("numOfficiel"), c.get("numOrdre")))
    choisies = []
    while len(choisies) < COURSES_PAR_DATE and any(par_disc.values()):
        for k in list(par_disc):
            if par_disc[k] and len(choisies) < COURSES_PAR_DATE:
                choisies.append(par_disc[k].pop(0))
    note(f"{d}: {sum(1 for _ in choisies)} courses retenues")
    for i, (r, c) in enumerate(choisies):
        fetch(f"part_{ds}_R{r}C{c}", f"{PMU}/{ds}/R{r}/C{c}/participants")
        if i < PERFS_PAR_DATE:
            fetch(f"perf_{ds}_R{r}C{c}", f"{PMU}/{ds}/R{r}/C{c}/performances-detaillees/pretty")
        if d.year >= 2025 and i < 2:
            fetch(f"online_{ds}_R{r}C{c}", f"{PMU_ONLINE}/{ds}/R{r}/C{c}/participants")
note("FIN")
