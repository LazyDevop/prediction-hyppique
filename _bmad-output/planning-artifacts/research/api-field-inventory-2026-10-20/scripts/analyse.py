"""Analyse de l'échantillon collecté : catalogue des champs, taux de
remplissage par discipline et par période, horodatage des cotes, couverture et
sémantique d'open-pmu. Sortie JSON (pour le rapport) + résumé texte."""

import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import median

RAW = Path(sys.argv[1])
OUT = Path(sys.argv[2])


def load(p):
    try:
        d = json.loads(p.read_text(encoding="utf-8"))
    except Exception:  # noqa: BLE001
        return None
    return None if isinstance(d, dict) and "_http_status" in d else d


def vide(v):
    return v is None or v == "" or v == [] or v == {}


def aplatir(obj, prefix=""):
    """Yield (chemin, valeur) pour chaque feuille ; les listes de dicts sont
    notées [] et explorées élément par élément."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from aplatir(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(obj, list) and obj and all(isinstance(x, dict) for x in obj):
        for x in obj:
            yield from aplatir(x, prefix + "[]")
    else:
        yield prefix, obj


def periode(y):
    return "2014-17" if y <= 2017 else "2018-21" if y <= 2021 else "2022-24" if y <= 2024 else "2025-26"


def dt(ms):
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


class Compteur:
    """Pour chaque champ : nb d'objets où la clé existe / est non vide, par strate."""

    def __init__(self):
        self.total = defaultdict(int)                     # strate -> nb objets
        self.present = defaultdict(lambda: defaultdict(int))
        self.rempli = defaultdict(lambda: defaultdict(int))
        self.exemples = {}
        self.types = defaultdict(set)

    def ajouter(self, obj, strates):
        champs = {}
        for chemin, v in aplatir(obj):
            champs.setdefault(chemin, []).append(v)
        for s in strates:
            self.total[s] += 1
        for chemin, vals in champs.items():
            non_vides = [v for v in vals if not vide(v)]
            for s in strates:
                self.present[chemin][s] += 1
                if non_vides:
                    self.rempli[chemin][s] += 1
            for v in vals:
                self.types[chemin].add(type(v).__name__)
            if non_vides and chemin not in self.exemples:
                ex = non_vides[0]
                self.exemples[chemin] = ex if not isinstance(ex, (list, dict)) or len(json.dumps(ex)) < 80 else str(ex)[:80]

    def table(self, strates):
        lignes = []
        for chemin in sorted(self.present):
            l = {"champ": chemin, "types": sorted(self.types[chemin]), "exemple": self.exemples.get(chemin)}
            for s in strates:
                t = self.total.get(s, 0)
                l[s] = None if not t else round(100 * self.rempli[chemin][s] / t)
            lignes.append(l)
        return lignes


DISC = {"ATTELE": "trot_attele", "MONTE": "trot_monte", "PLAT": "plat", "HAIE": "obstacle", "STEEPLECHASE": "obstacle", "CROSS": "obstacle"}

# --- Programme : niveau course -------------------------------------------
courses_info = {}   # (ds, R, C) -> dict(discipline, heureDepart, annee)
cpt_course = Compteur()
progs = sorted(RAW.glob("prog_*.json"))
for p in progs:
    ds = p.stem.split("_")[1]
    annee = int(ds[4:])
    data = load(p)
    if not data:
        continue
    for reu in data.get("programme", {}).get("reunions", []):
        if (reu.get("pays") or {}).get("code") != "FRA":
            continue
        for c in reu.get("courses", []):
            disc = DISC.get(c.get("discipline"), c.get("discipline"))
            courses_info[(ds, reu.get("numOfficiel"), c.get("numOrdre"))] = {
                "discipline": disc, "heureDepart": c.get("heureDepart"), "annee": annee,
                "rc": f"R{reu.get('numOfficiel')}/C{c.get('numOrdre')}",
            }
            c2 = {k: v for k, v in c.items() if k not in ("paris",)}
            cpt_course.ajouter(c2, ["ALL", disc, periode(annee)])

# --- Participants -----------------------------------------------------------
cpt_part = Compteur()
cotes = []  # (ds, rc, num, ref, direct, ref_ts_min, direct_ts_min, discipline, annee)
nb_part_courses = 0
for p in sorted(RAW.glob("part_*.json")):
    _, ds, rc = p.stem.split("_")
    r, c = map(int, re.match(r"R(\d+)C(\d+)", rc).groups())
    info = courses_info.get((ds, r, c), {})
    data = load(p)
    if not data:
        continue
    nb_part_courses += 1
    disc = info.get("discipline", "?")
    annee = int(ds[4:])
    depart = info.get("heureDepart")
    for h in data.get("participants", []):
        cpt_part.ajouter(h, ["ALL", disc, periode(annee)])
        ref = h.get("dernierRapportReference") or {}
        dire = h.get("dernierRapportDirect") or {}
        cotes.append({
            "ds": ds, "rc": f"R{r}/C{c}", "num": h.get("numPmu"), "disc": disc, "annee": annee,
            "ref": ref.get("rapport"), "direct": dire.get("rapport"),
            "ref_min": None if not (ref.get("dateRapport") and depart) else round((ref["dateRapport"] - depart) / 60000),
            "direct_min": None if not (dire.get("dateRapport") and depart) else round((dire["dateRapport"] - depart) / 60000),
            "arrivee": h.get("ordreArrivee"), "statut": h.get("statut"),
        })

# --- Performances détaillées -------------------------------------------------
cpt_perf_cheval = Compteur()
cpt_perf_course = Compteur()
profondeurs = []
for p in sorted(RAW.glob("perf_*.json")):
    ds = p.stem.split("_")[1]
    annee = int(ds[4:])
    data = load(p)
    if not data:
        continue
    for h in data.get("participants", []):
        cc = h.get("coursesCourues", []) or []
        profondeurs.append(len(cc))
        cpt_perf_cheval.ajouter({k: v for k, v in h.items() if k != "coursesCourues"}, ["ALL", periode(annee)])
        for course in cc:
            course2 = dict(course)
            parts = course2.pop("participants", []) or []
            lui = next((x for x in parts if x.get("itsHim")), None)
            if lui:
                course2["_lui"] = lui
            course2["_nb_participants_listes"] = len(parts)
            cpt_perf_course.ajouter(course2, ["ALL", periode(annee)])

# --- open-pmu ---------------------------------------------------------------
cpt_open_course = Compteur()
cpt_open_cheval = Compteur()
couverture = []      # (partants, details)
appariement = {"cotes0=ref": 0, "cotes0=direct": 0, "cotes1=ref": 0, "cotes1=direct": 0,
               "cotes2=ref": 0, "cotes2=direct": 0, "compares": 0}
idx_cotes = {(x["ds"], x["rc"], x["num"]): x for x in cotes}
courses_open = 0
open_vides = []
for p in sorted(RAW.glob("open_*.json")):
    ds = p.stem.split("_")[1]
    annee = int(ds[4:])
    data = load(p)
    msg = (data or {}).get("message") if isinstance(data, dict) else None
    if not isinstance(msg, list) or not msg:
        open_vides.append(ds)
        continue
    for c in msg:
        courses_open += 1
        det = c.get("arrivee_details") or {}
        cpt_open_course.ajouter({k: v for k, v in c.items() if k != "arrivee_details"}, ["ALL", periode(annee)])
        partants = c.get("partants")
        try:
            couverture.append((int(partants), len(det)))
        except (TypeError, ValueError):
            pass
        for num, h in det.items():
            cpt_open_cheval.ajouter(h, ["ALL", periode(annee)])
            ref = idx_cotes.get((ds, c.get("r/c"), int(num)))
            cs = h.get("cotes") or []
            if ref and len(cs) == 3:
                appariement["compares"] += 1
                for i in range(3):
                    try:
                        v = float(cs[i])
                    except (TypeError, ValueError):
                        continue
                    if ref["ref"] is not None and abs(v - ref["ref"]) < 0.051:
                        appariement[f"cotes{i}=ref"] += 1
                    if ref["direct"] is not None and abs(v - ref["direct"]) < 0.051:
                        appariement[f"cotes{i}=direct"] += 1

# --- online vs offline --------------------------------------------------------
parite = []
for p in sorted(RAW.glob("online_*.json")):
    on = load(p)
    off = load(RAW / p.name.replace("online_", "part_"))
    if not on or not off:
        parite.append({"fichier": p.stem, "online_ok": bool(on), "offline_ok": bool(off)})
        continue
    k_on = {k for h in on.get("participants", []) for k, _ in aplatir(h)}
    k_off = {k for h in off.get("participants", []) for k, _ in aplatir(h)}
    parite.append({"fichier": p.stem, "online_seul": sorted(k_on - k_off), "offline_seul": sorted(k_off - k_on)})

# --- synthèse cotes -----------------------------------------------------------
def distrib(vals):
    vals = sorted(v for v in vals if v is not None)
    if not vals:
        return None
    q = lambda f: vals[min(len(vals) - 1, int(f * len(vals)))]
    return {"n": len(vals), "min": vals[0], "p10": q(0.1), "median": median(vals), "p90": q(0.9), "max": vals[-1]}

partants_cotes = [x for x in cotes if x["statut"] == "PARTANT"]
cotes_par_periode = {}
for per in ["2014-17", "2018-21", "2022-24", "2025-26"]:
    xs = [x for x in partants_cotes if periode(x["annee"]) == per]
    if xs:
        cotes_par_periode[per] = {
            "partants": len(xs),
            "ref_%": round(100 * sum(x["ref"] is not None for x in xs) / len(xs)),
            "direct_%": round(100 * sum(x["direct"] is not None for x in xs) / len(xs)),
            "direct_minutes_vs_depart": distrib([x["direct_min"] for x in xs]),
            "ref_minutes_vs_depart": distrib([x["ref_min"] for x in xs]),
        }

# Le favori à la cote "direct" gagne-t-il ~30 % ? (contrôle de vraisemblance)
fav = defaultdict(lambda: [0, 0])
par_course = defaultdict(list)
for x in partants_cotes:
    par_course[(x["ds"], x["rc"])].append(x)
for k, xs in par_course.items():
    for cle in ("ref", "direct"):
        ok = [x for x in xs if x[cle]]
        if len(ok) == len(xs) and any(x["arrivee"] == 1 for x in xs):
            f = min(ok, key=lambda x: x[cle])
            fav[cle][0] += 1
            fav[cle][1] += f["arrivee"] == 1

strates_disc = ["ALL", "plat", "trot_attele", "trot_monte", "obstacle"]
strates_per = ["2014-17", "2018-21", "2022-24", "2025-26"]
res = {
    "echantillon": {
        "dates": len(progs), "courses_FRA_programme": len(courses_info), "courses_participants": nb_part_courses,
        "partants": cpt_part.total.get("ALL", 0), "fichiers_perf": len(list(RAW.glob("perf_*.json"))),
        "chevaux_perf": len(profondeurs), "courses_open": courses_open, "dates_open_vides": open_vides,
        "objets_par_strate_participants": dict(cpt_part.total), "objets_par_strate_course": dict(cpt_course.total),
    },
    "course": cpt_course.table(strates_disc + strates_per),
    "participants": cpt_part.table(strates_disc + strates_per),
    "perf_cheval": cpt_perf_cheval.table(["ALL"] + strates_per),
    "perf_course_passee": cpt_perf_course.table(["ALL"] + strates_per),
    "profondeur_historique": distrib(profondeurs),
    "open_course": cpt_open_course.table(["ALL"] + strates_per),
    "open_cheval": cpt_open_cheval.table(["ALL"] + strates_per),
    "open_couverture": {
        "courses": len(couverture),
        "details_sur_partants_%": round(100 * sum(d for _, d in couverture) / max(1, sum(p for p, _ in couverture))),
        "details_par_course": distrib([d for _, d in couverture]),
        "partants_par_course": distrib([p for p, _ in couverture]),
    },
    "open_cotes_appariement": appariement,
    "cotes_pmu": cotes_par_periode,
    "favori_gagne": {k: {"courses": v[0], "taux_%": round(100 * v[1] / v[0]) if v[0] else None} for k, v in fav.items()},
    "parite_online_offline": parite,
}
OUT.write_text(json.dumps(res, ensure_ascii=False, indent=1, default=str), encoding="utf-8")
print(json.dumps(res["echantillon"], indent=1))
print("cotes", json.dumps(res["cotes_pmu"], indent=1))
print("favori", res["favori_gagne"])
print("open couverture", res["open_couverture"], res["open_cotes_appariement"])
print("parite", res["parite_online_offline"])
print("profondeur", res["profondeur_historique"])
