"""Story 7.8 — verrou d'accès restreint (`app.api.acces_restreint`) et
pare-feu hôte (`deploy/firewall/acces_restreint.sh`).

Chaque ligne de la matrice I/O du spec est jouée sur une petite app FastAPI
montée avec `installer`, dans le même ordre que `app.main` (verrou, puis
CORS). Le câblage RÉEL de `app.main` est vérifié dans un interpréteur neuf
(sous-processus) pour ne jamais fuir `os.environ` ni le module importé vers
les autres tests. Le script pare-feu tourne contre un faux `iptables` qui
garde un état et journalise ses appels."""

import base64
import logging
import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import pytest
from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
from starlette.websockets import WebSocketDisconnect

from app.api.acces_restreint import installer, secret_valide

SECRET = "s3cret-de-test-7-8-assez-long"
BACKEND = Path(__file__).resolve().parent.parent
FIREWALL = BACKEND.parent / "deploy" / "firewall"


def _app(secret: str = SECRET, app_env: str = "") -> FastAPI:
    app = FastAPI()
    installer(app, secret, app_env)
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.post("/health")
    def health_post():
        return {"status": "ok"}

    @app.get("/dashboard/data")
    def donnees():
        return {"ok": True}

    @app.post("/pronostics")
    def pronostic():
        return {"enregistre": True}

    @app.options("/pronostics")
    def options_pronostics():
        return {"options": True}

    @app.websocket("/ws")
    async def ws(websocket: WebSocket):
        await websocket.accept()
        await websocket.send_text("bonjour")
        await websocket.close()

    return app


def _basic(utilisateur: str, mot_de_passe: str) -> str:
    return "Basic " + base64.b64encode(f"{utilisateur}:{mot_de_passe}".encode()).decode()


def _refus(response) -> None:
    assert response.status_code == 401
    assert response.headers["www-authenticate"] == 'Basic realm="prediction-hyppique"'
    assert response.content == b""


@pytest.fixture
def client():
    return TestClient(_app())


# --- Matrice I/O du spec -------------------------------------------------


def test_bearer_ok(client):
    response = client.get("/dashboard/data", headers={"Authorization": f"Bearer {SECRET}"})
    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_basic_ok_utilisateur_quelconque(client):
    for utilisateur in ("x", "proprietaire", ""):
        response = client.post("/pronostics", headers={"Authorization": _basic(utilisateur, SECRET)})
        assert response.status_code == 200, utilisateur
        assert response.json() == {"enregistre": True}


@pytest.mark.parametrize("headers", [
    {},
    {"Authorization": "Bearer mauvais"},
    {"Authorization": "Bearer "},
    {"Authorization": f"Token {SECRET}"},
    {"Authorization": _basic("x", "mauvais")},
    {"Authorization": "Basic !!!pas-du-base64!!!"},
    {"Authorization": "Basic " + base64.b64encode(SECRET.encode()).decode()},  # sans ':'
    {"Authorization": "Basic " + base64.b64encode(b"x:\xff\xfe").decode()},  # pas UTF-8
    {"Authorization": SECRET},
])
def test_absent_ou_faux_401_jamais_500(client, headers):
    _refus(client.get("/dashboard/data", headers=headers))
    _refus(client.post("/pronostics", headers=headers, json={}))


def test_route_inconnue_aussi_refusee(client):
    _refus(client.get("/docs"))
    _refus(client.get("/openapi.json"))


def test_health_exempte(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    # HEAD passe le verrou (la route GET n'accepte pas HEAD : 405, pas 401).
    assert client.head("/health").status_code != 401


def test_preflight_cors_sans_401(client):
    response = client.options("/dashboard/data", headers={
        "Origin": "http://localhost:5000",
        "Access-Control-Request-Method": "GET",
        "Access-Control-Request-Headers": "authorization",
    })
    assert response.status_code == 200
    assert "access-control-allow-origin" in response.headers


def test_sans_secret_en_dev_tout_ouvert():
    client = TestClient(_app(secret="", app_env=""))
    assert client.get("/dashboard/data").status_code == 200
    assert client.post("/pronostics").status_code == 200


def test_sans_secret_en_production_refuse_de_demarrer():
    with pytest.raises(RuntimeError) as erreur:
        _app(secret="", app_env="production")
    assert "ACCES_RESTREINT_SECRET" in str(erreur.value)


# --- Cas adjacents (revue du patch) -------------------------------------


def test_websocket_refuse_sans_secret(client):
    with pytest.raises(WebSocketDisconnect) as fermeture:
        with client.websocket_connect("/ws") as ws:
            ws.receive_text()
    assert fermeture.value.code == 1008


def test_websocket_accepte_avec_secret(client):
    with client.websocket_connect("/ws", headers={"Authorization": f"Bearer {SECRET}"}) as ws:
        assert ws.receive_text() == "bonjour"


@pytest.mark.parametrize("headers", [
    {},
    {"Origin": "http://localhost:5000"},
    {"Access-Control-Request-Method": "POST"},
])
def test_options_hors_preflight_refuse(client, headers):
    _refus(client.options("/pronostics", headers=headers))


def test_post_health_refuse(client):
    _refus(client.post("/health"))


def test_secret_avec_retour_chariot_windows_fonctionne():
    client = TestClient(_app(secret=SECRET + "\r", app_env="production"))
    response = client.get("/dashboard/data", headers={"Authorization": f"Bearer {SECRET}"})
    assert response.status_code == 200


def test_secret_court_en_production_refuse():
    with pytest.raises(RuntimeError) as erreur:
        _app(secret="court", app_env="production")
    assert "ACCES_RESTREINT_SECRET" in str(erreur.value)
    assert "court" not in str(erreur.value).replace("trop court", "")


def test_secret_court_hors_production_accepte():
    client = TestClient(_app(secret="court", app_env=""))
    assert client.get("/dashboard/data", headers={"Authorization": "Bearer court"}).status_code == 200


def test_secret_non_ascii_refuse():
    with pytest.raises(RuntimeError) as erreur:
        _app(secret="sécret-non-ascii-assez-long", app_env="")
    assert "ACCES_RESTREINT_SECRET" in str(erreur.value)
    assert "sécret" not in str(erreur.value)


@pytest.mark.parametrize("app_env", [" Production ", "PROD", "prod\r", None])
def test_app_env_normalise(app_env):
    if app_env is None:
        TestClient(_app(secret="", app_env=None))  # absent = dev, pas d'erreur
        return
    with pytest.raises(RuntimeError):
        _app(secret="", app_env=app_env)


def test_secret_valide_pur():
    assert secret_valide(f"Bearer {SECRET}", SECRET)
    assert secret_valide(f"bearer {SECRET}", SECRET)
    assert secret_valide(_basic("x", SECRET), SECRET)
    assert not secret_valide(None, SECRET)
    assert not secret_valide(f"Bearer {SECRET}", "")
    assert not secret_valide(f"Bearer {SECRET}x", SECRET)


def test_le_secret_n_apparait_dans_aucun_log(client, caplog):
    caplog.set_level(logging.DEBUG)
    client.get("/dashboard/data", headers={"Authorization": f"Bearer {SECRET}"})
    client.get("/dashboard/data", headers={"Authorization": "Bearer mauvais"})
    client.get("/dashboard/data", headers={"Authorization": _basic("x", SECRET)})
    with pytest.raises(RuntimeError):
        _app(secret="court", app_env="production")
    messages = "\n".join(record.getMessage() for record in caplog.records)
    assert SECRET not in messages
    assert SECRET not in caplog.text


# --- Câblage réel de app.main (interpréteur neuf) ------------------------


_SCRIPT_CABLAGE = textwrap.dedent("""
    import sys
    from fastapi.testclient import TestClient
    from app.main import app

    secret = sys.argv[1]
    client = TestClient(app)
    preflight = client.options("/courses", headers={
        "Origin": "http://localhost:5000",
        "Access-Control-Request-Method": "GET",
    })
    print(client.get("/dashboard/data").status_code)
    print(client.get("/dashboard/data", headers={"Authorization": "Bearer " + secret}).status_code)
    print(client.get("/health").status_code)
    print(preflight.status_code)
""")


def _env_sous_processus(tmp_path: Path, **variables: str) -> dict[str, str]:
    env = {k: v for k, v in os.environ.items() if k not in ("ACCES_RESTREINT_SECRET", "APP_ENV")}
    env["DATABASE_URL"] = f"sqlite:///{(tmp_path / 'cablage.db').as_posix()}"
    env["PYTHONPATH"] = str(BACKEND)
    env.update(variables)
    return env


def test_app_main_cablage_reel_avec_secret(tmp_path):
    resultat = subprocess.run(
        [sys.executable, "-c", _SCRIPT_CABLAGE, SECRET],
        cwd=BACKEND, env=_env_sous_processus(tmp_path, ACCES_RESTREINT_SECRET=SECRET, APP_ENV="production"),
        capture_output=True, text=True, timeout=120,
    )
    assert resultat.returncode == 0, resultat.stderr[-2000:]
    sans, avec, health, preflight = resultat.stdout.split()
    assert (sans, avec, health) == ("401", "200", "200")
    assert preflight != "401"
    assert SECRET not in resultat.stderr


def test_app_main_production_sans_secret_refuse_de_demarrer(tmp_path):
    resultat = subprocess.run(
        [sys.executable, "-c", "import app.main"],
        cwd=BACKEND, env=_env_sous_processus(tmp_path, APP_ENV="production"),
        capture_output=True, text=True, timeout=120,
    )
    assert resultat.returncode != 0
    assert "RuntimeError" in resultat.stderr
    assert "ACCES_RESTREINT_SECRET" in resultat.stderr


# --- Script pare-feu contre un faux iptables -----------------------------


_FAUX_IPTABLES = r"""#!/usr/bin/env bash
# Faux iptables : état "CHAINE<TAB>règle" et "#CHAINE" (existence) ; chaque
# appel est journalisé dans ./appels.
T=$'\t'
D="$(cd "$(dirname "$0")" && pwd)"
ST="$D/etat"; LOG="$D/appels"
touch "$ST"
echo "$*" >> "$LOG"
[[ "$1" == "-w" ]] && shift
op="$1"; ch="${2:-}"; shift 2 2>/dev/null || shift $#
existe() { grep -qxF "#$1" "$ST"; }
case "$op" in
  -N) existe "$ch" && exit 1; echo "#$ch" >> "$ST" ;;
  -X) existe "$ch" || exit 1; grep -vxF "#$ch" "$ST" > "$ST.t"; mv "$ST.t" "$ST" ;;
  -F) existe "$ch" || exit 1; grep -v "^$ch$T" "$ST" > "$ST.t"; mv "$ST.t" "$ST" ;;
  -A) existe "$ch" || exit 1; echo "$ch$T$*" >> "$ST" ;;
  -I) existe "$ch" || exit 1; shift; { echo "$ch$T$*"; cat "$ST"; } > "$ST.t"; mv "$ST.t" "$ST" ;;
  -C) grep -qxF "$ch$T$*" "$ST" ;;
  -D) grep -qxF "$ch$T$*" "$ST" || exit 1
      awk -v l="$ch$T$*" '!fait && $0 == l { fait = 1; next } { print }' "$ST" > "$ST.t"; mv "$ST.t" "$ST" ;;
  -E) nouveau="$1"; existe "$ch" || exit 1
      sed -e "s/^#$ch\$/#$nouveau/" -e "s/^$ch$T/$nouveau$T/" -e "s/-j $ch\$/-j $nouveau/" "$ST" > "$ST.t"
      mv "$ST.t" "$ST" ;;
  *) exit 2 ;;
esac
"""

BASH = shutil.which("bash")
pytestmark_firewall = pytest.mark.skipif(BASH is None, reason="bash introuvable : test du script pare-feu ignoré")


@pytest.fixture
def pare_feu(tmp_path):
    """Copie du script et de la liste versionnée dans un dossier temporaire,
    plus le faux iptables ; tous les chemins passés à bash sont relatifs."""
    for nom in ("acces_restreint.sh", "ips_autorisees.conf"):
        (tmp_path / nom).write_bytes((FIREWALL / nom).read_bytes())
    (tmp_path / "faux_iptables.sh").write_bytes(_FAUX_IPTABLES.encode())

    def lancer(*arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [BASH, "acces_restreint.sh", *arguments],
            cwd=tmp_path, env={**os.environ, "IPTABLES": "./faux_iptables.sh"},
            capture_output=True, text=True, timeout=60,
        )

    def regles(chaine: str) -> list[str]:
        etat = tmp_path / "etat"
        if not etat.exists():
            return []
        return [l.split("\t", 1)[1] for l in etat.read_text().splitlines() if l.startswith(chaine + "\t")]

    def chaines() -> set[str]:
        etat = tmp_path / "etat"
        return {l[1:] for l in etat.read_text().splitlines() if l.startswith("#")} if etat.exists() else set()

    def appels() -> list[str]:
        journal = tmp_path / "appels"
        return journal.read_text().splitlines() if journal.exists() else []

    lancer.dossier, lancer.regles, lancer.chaines, lancer.appels = tmp_path, regles, chaines, appels
    return lancer


@pytestmark_firewall
def test_pare_feu_syntaxe_bash():
    resultat = subprocess.run([BASH, "-n", str(FIREWALL / "acces_restreint.sh")], capture_output=True, text=True)
    assert resultat.returncode == 0, resultat.stderr
    assert resultat.stdout == resultat.stderr == ""


@pytestmark_firewall
def test_pare_feu_liste_versionnee_commentee_refusee(pare_feu):
    resultat = pare_feu()
    assert resultat.returncode == 1
    assert pare_feu.appels() == []


@pytestmark_firewall
def test_pare_feu_liste_vide_refusee(pare_feu):
    (pare_feu.dossier / "vide.conf").write_text("\n   \n# rien\n")
    assert pare_feu("vide.conf").returncode == 1
    assert pare_feu.appels() == []


@pytestmark_firewall
@pytest.mark.parametrize("entree", ["999.1.1.1", "10.0.0.0/0", "10.0.0.0/33", "1.2.3", "pas-une-ip", "1.2.3.4/abc"])
def test_pare_feu_entree_invalide_aucun_appel(pare_feu, entree):
    # Une chaîne en place ne doit pas être vidée par une liste fautive.
    (pare_feu.dossier / "ok.conf").write_text("203.0.113.10\n")
    assert pare_feu("ok.conf").returncode == 0
    avant = len(pare_feu.appels())
    (pare_feu.dossier / "faux.conf").write_text(f"203.0.113.10\n{entree}\n")
    resultat = pare_feu("faux.conf")
    assert resultat.returncode == 1
    assert pare_feu.appels()[avant:] == []
    assert pare_feu.regles("ACCES_RESTREINT")[-2:] == ["-s 203.0.113.10 -j RETURN", "-j DROP"]


@pytestmark_firewall
def test_pare_feu_liste_valide_puis_idempotent(pare_feu):
    (pare_feu.dossier / "ips.conf").write_text("# commentaire\n\n203.0.113.10  # bureau\n198.51.100.0/24\r\n")
    assert pare_feu("ips.conf").returncode == 0
    attendu = [
        "-m conntrack --ctstate ESTABLISHED,RELATED -j RETURN",
        "-s 203.0.113.10 -j RETURN",
        "-s 198.51.100.0/24 -j RETURN",
        "-j DROP",
    ]
    saut = "-p tcp -m conntrack --ctstate DNAT --ctorigdstport 8000 --ctdir ORIGINAL -j ACCES_RESTREINT"
    assert pare_feu.regles("ACCES_RESTREINT") == attendu
    assert pare_feu.regles("DOCKER-USER") == [saut]

    debut_second = len(pare_feu.appels())
    assert pare_feu("ips.conf").returncode == 0
    assert pare_feu.regles("ACCES_RESTREINT") == attendu
    assert pare_feu.regles("DOCKER-USER") == [saut]
    assert "ACCES_RESTREINT_NEW" not in pare_feu.chaines()

    # Fermé en cas d'échec : le saut vers la nouvelle chaîne est inséré
    # AVANT le retrait de l'ancien saut.
    second = pare_feu.appels()[debut_second:]
    insertion = next(i for i, a in enumerate(second) if a.startswith("-w -I DOCKER-USER") and a.endswith("ACCES_RESTREINT_NEW"))
    retrait = next(i for i, a in enumerate(second) if a.startswith("-w -D DOCKER-USER") and a.endswith("-j ACCES_RESTREINT"))
    assert insertion < retrait


@pytestmark_firewall
def test_pare_feu_surcharge_locale_prioritaire(pare_feu):
    (pare_feu.dossier / "ips_autorisees.local.conf").write_text("192.0.2.7\n")
    assert pare_feu().returncode == 0
    assert "-s 192.0.2.7 -j RETURN" in pare_feu.regles("ACCES_RESTREINT")


@pytestmark_firewall
def test_pare_feu_retirer(pare_feu):
    (pare_feu.dossier / "ips.conf").write_text("203.0.113.10\n")
    assert pare_feu("ips.conf").returncode == 0
    assert pare_feu("--retirer").returncode == 0
    assert pare_feu.regles("DOCKER-USER") == []
    assert {"ACCES_RESTREINT", "ACCES_RESTREINT_NEW"}.isdisjoint(pare_feu.chaines())
    assert pare_feu("--retirer").returncode == 0  # idempotent
