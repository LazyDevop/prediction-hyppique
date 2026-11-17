"""Accès restreint à l'API déployée (story 7.8, AD-21, couche 2 sur 2).

Tant que les comptes et les contrôles par palier n'existent pas, toute
requête doit porter le secret partagé `ACCES_RESTREINT_SECRET`, soit en
`Authorization: Bearer <secret>`, soit en HTTP Basic (utilisateur
quelconque, mot de passe = secret) pour que `curl -u x:$SECRET` et l'invite
du navigateur fonctionnent. La couche 1 est le pare-feu hôte
(`deploy/firewall/`).

Règles :
- comparaison en temps constant (`hmac.compare_digest`) ;
- refus HTTP = 401 nu + `WWW-Authenticate: Basic realm="prediction-hyppique"`,
  jamais de détail, jamais de 500 (base64 invalide compris) ; refus
  WebSocket = fermeture 1008 ;
- seuls `GET`/`HEAD /health` et un vrai pré-vol CORS (`OPTIONS` avec
  `Origin` et `Access-Control-Request-Method`) sont exemptés ;
- seul le scope `lifespan` passe sans contrôle ;
- le secret n'est jamais journalisé ni répété dans un message d'erreur.
"""

import base64
import binascii
import hmac

from starlette.types import ASGIApp, Receive, Scope, Send

NOM_VARIABLE = "ACCES_RESTREINT_SECRET"
CHEMINS_EXEMPTES = frozenset({"/health"})
METHODES_EXEMPTEES = frozenset({"GET", "HEAD"})
LONGUEUR_MIN_PRODUCTION = 16
ENVIRONNEMENTS_PRODUCTION = frozenset({"production", "prod"})
_REALM = b'Basic realm="prediction-hyppique"'


def _egal(candidat: str, secret: str) -> bool:
    return hmac.compare_digest(candidat.encode("utf-8"), secret.encode("utf-8"))


def secret_valide(header: str | None, secret: str) -> bool:
    """Vrai si l'en-tête `Authorization` porte le secret (Bearer ou Basic)."""
    if not header or not secret:
        return False
    schema, _, valeur = header.strip().partition(" ")
    valeur = valeur.strip()
    if not valeur:
        return False
    schema = schema.lower()
    if schema == "bearer":
        return _egal(valeur, secret)
    if schema == "basic":
        try:
            decode = base64.b64decode(valeur, validate=True).decode("utf-8")
        except (binascii.Error, ValueError):
            return False
        _, separateur, mot_de_passe = decode.partition(":")
        if not separateur:
            return False
        return _egal(mot_de_passe, secret)
    return False


def _en_tetes(scope: Scope) -> dict[bytes, bytes]:
    # Premier en-tête de chaque nom (noms déjà en minuscules en ASGI).
    resultat: dict[bytes, bytes] = {}
    for nom, valeur in scope.get("headers", []):
        resultat.setdefault(nom, valeur)
    return resultat


def _est_exempte(scope: Scope, en_tetes: dict[bytes, bytes]) -> bool:
    if scope["type"] != "http":
        return False
    methode = scope.get("method")
    if scope.get("path") in CHEMINS_EXEMPTES and methode in METHODES_EXEMPTEES:
        return True
    return (
        methode == "OPTIONS"
        and b"origin" in en_tetes
        and b"access-control-request-method" in en_tetes
    )


class AccesRestreintMiddleware:
    """Middleware ASGI pur : pas de `BaseHTTPMiddleware`, pas de lecture du
    corps, aucune journalisation."""

    def __init__(self, app: ASGIApp, secret: str) -> None:
        self.app = app
        self._secret = secret

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] not in ("http", "websocket"):
            await self.app(scope, receive, send)
            return
        en_tetes = _en_tetes(scope)
        if _est_exempte(scope, en_tetes):
            await self.app(scope, receive, send)
            return
        header = en_tetes.get(b"authorization")
        if secret_valide(header.decode("latin-1") if header is not None else None, self._secret):
            await self.app(scope, receive, send)
            return
        if scope["type"] == "websocket":
            await send({"type": "websocket.close", "code": 1008})
            return
        await send({
            "type": "http.response.start",
            "status": 401,
            "headers": [
                (b"www-authenticate", _REALM),
                (b"content-length", b"0"),
            ],
        })
        await send({"type": "http.response.body", "body": b""})


def installer(app, secret: str | None, app_env: str | None) -> None:
    """Seul endroit de la règle : verrou actif ssi `secret` non vide (après
    `strip()`, pour un `.env` en fin de ligne Windows) ; production sans
    secret, secret non ASCII ou secret trop court en production = refus de
    démarrer. À appeler AVANT d'ajouter CORS (le dernier middleware ajouté
    est le plus externe, CORS doit répondre au pré-vol avant le verrou).
    Les messages d'erreur nomment la variable, jamais la valeur."""
    secret = (secret or "").strip()
    production = (app_env or "").strip().lower() in ENVIRONNEMENTS_PRODUCTION
    if not secret:
        if production:
            raise RuntimeError(
                f"{NOM_VARIABLE} est vide alors que APP_ENV est en production : "
                "l'API refuse de démarrer sans accès restreint."
            )
        return
    if not secret.isascii():
        raise RuntimeError(f"{NOM_VARIABLE} doit être composé de caractères ASCII uniquement.")
    if production and len(secret) < LONGUEUR_MIN_PRODUCTION:
        raise RuntimeError(
            f"{NOM_VARIABLE} est trop court en production "
            f"(au moins {LONGUEUR_MIN_PRODUCTION} caractères)."
        )
    app.add_middleware(AccesRestreintMiddleware, secret=secret)
