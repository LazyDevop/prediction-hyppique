import json
import os
from datetime import datetime, timezone

import pytest

from app.data import vision_client

FICHE_JSON = {
    "name": "PASSAGE VALLET",
    "num": 101,
    "age": 5,
    "poids": 57,
    "cote": 6.5,
    "perfs": [
        {"rank": 1, "part": 12, "incident": "", "niveau": 2.3, "dist": 2000, "terr": 1},
        {"rank": None, "part": None, "incident": "T", "niveau": 2, "dist": 1600, "terr": 0.97},
    ],
}
FICHE_TEXT = json.dumps(FICHE_JSON)

PROGRAMME_JSON = {
    "hippo": "Vincennes",
    "dist": 2700,
    "terr": 1,
    "niveau": 2.3,
    "partants": 2,
    "horses": [
        {
            "num": 1, "name": "CHEVAL UN", "age": 5, "poids": 58, "cote": 3.2,
            "perfs": [{"rank": 1, "incident": ""}, {"rank": None, "incident": "D"}],
        },
        {
            "num": 2, "name": "CHEVAL DEUX", "age": 4, "poids": 57, "cote": None,
            "perfs": [],
        },
    ],
}
PROGRAMME_TEXT = json.dumps(PROGRAMME_JSON)


@pytest.fixture(autouse=True)
def _reset_state(monkeypatch):
    # Chaque test part d'un compteur quotidien vierge et d'un environnement
    # connu, indépendamment de l'ordre d'exécution des tests.
    vision_client._daily_call_count = 0
    vision_client._daily_call_count_date = None
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-not-real")
    monkeypatch.delenv("VISION_DAILY_CALL_LIMIT", raising=False)
    monkeypatch.delenv("ANTHROPIC_VISION_MODEL", raising=False)
    yield


class _FakeResponse:
    def __init__(self, status_code, payload):
        self.status_code = status_code
        self._payload = payload

    def json(self):
        return self._payload


def _envelope(text):
    return {"content": [{"type": "text", "text": text}]}


def _make_fake_post(status_code, text, captured=None):
    def fake_post(url, headers=None, json=None, timeout=None):
        if captured is not None:
            captured.append({"url": url, "headers": headers, "json": json, "timeout": timeout})
        return _FakeResponse(status_code, _envelope(text))
    return fake_post


def test_fiche_image_valid_model_json_returns_populated_dataclass(monkeypatch):
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT))

    result = vision_client.extract_fiche_cheval(b"fake-image-bytes", "image/png")

    assert isinstance(result, vision_client.FicheChevalExtraite)
    assert result.name == "PASSAGE VALLET"
    assert result.num == 101
    assert result.age == 5
    assert result.poids == 57
    assert result.cote == 6.5
    assert len(result.perfs) == 2
    assert result.perfs[0].rank == 1
    assert result.perfs[0].part == 12
    assert result.perfs[0].incident == ""
    assert result.perfs[1].rank is None
    assert result.perfs[1].incident == "T"


def test_programme_pdf_uses_document_content_block_not_image(monkeypatch):
    captured = []
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, PROGRAMME_TEXT, captured))

    result = vision_client.extract_programme(b"%PDF-fake-bytes", "application/pdf")

    assert isinstance(result, vision_client.ProgrammeExtrait)
    assert len(captured) == 1
    content_block = captured[0]["json"]["messages"][0]["content"][0]
    assert content_block["type"] == "document"
    assert content_block["source"]["media_type"] == "application/pdf"
    # Et pour confirmer le contraste : une image ne doit jamais produire ce type.
    assert content_block["type"] != "image"


def test_fiche_image_media_type_uses_image_content_block(monkeypatch):
    captured = []
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT, captured))

    vision_client.extract_fiche_cheval(b"fake-image-bytes", "image/png")

    content_block = captured[0]["json"]["messages"][0]["content"][0]
    assert content_block["type"] == "image"
    assert content_block["source"]["media_type"] == "image/png"


def test_daily_limit_already_reached_blocks_before_http_call(monkeypatch):
    monkeypatch.setenv("VISION_DAILY_CALL_LIMIT", "5")
    vision_client._daily_call_count = 5
    vision_client._daily_call_count_date = datetime.now(timezone.utc).date()

    call_count = {"n": 0}

    def fake_post(*args, **kwargs):
        call_count["n"] += 1
        return _FakeResponse(200, _envelope(FICHE_TEXT))

    monkeypatch.setattr(vision_client.requests, "post", fake_post)

    with pytest.raises(vision_client.VisionBudgetExceeded):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert call_count["n"] == 0
    assert vision_client._daily_call_count == 5  # inchangé : l'appel bloqué ne consomme pas de budget


def test_daily_limit_resets_on_new_utc_date(monkeypatch):
    monkeypatch.setenv("VISION_DAILY_CALL_LIMIT", "1")
    vision_client._daily_call_count = 1
    vision_client._daily_call_count_date = datetime(2020, 1, 1, tzinfo=timezone.utc).date()

    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT))

    # La date stockée est dans le passé -> le compteur doit être remis à zéro
    # avant application du plafond, donc cet appel doit réussir.
    result = vision_client.extract_fiche_cheval(b"bytes", "image/png")
    assert isinstance(result, vision_client.FicheChevalExtraite)


def test_model_wraps_json_in_code_fences(monkeypatch):
    fenced_text = "```json\n" + FICHE_TEXT + "\n```"
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, fenced_text))

    result = vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert result.name == "PASSAGE VALLET"


def test_non_2xx_response_raises_extraction_error(monkeypatch):
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(500, "irrelevant"))

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")


def test_429_response_raises_extraction_error(monkeypatch):
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(429, "irrelevant"))

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_programme(b"bytes", "image/png")


def test_malformed_json_raises_extraction_error_not_raw_json_exception(monkeypatch):
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, "this is not { json"))

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")


def test_requests_exception_is_wrapped_not_leaked(monkeypatch):
    import requests as requests_module

    def raising_post(*args, **kwargs):
        raise requests_module.ConnectionError("network unreachable")

    monkeypatch.setattr(vision_client.requests, "post", raising_post)

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")


def test_missing_api_key_raises_extraction_error_without_http_call(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    call_count = {"n": 0}

    def fake_post(*args, **kwargs):
        call_count["n"] += 1
        return _FakeResponse(200, _envelope(FICHE_TEXT))

    monkeypatch.setattr(vision_client.requests, "post", fake_post)

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert call_count["n"] == 0
    # Revue de code : une clé absente garantit qu'aucune requête ne part
    # jamais, donc ce cas précis ne doit PAS consommer de budget (contraste
    # avec un échec HTTP réel après une tentative effective, voir
    # test_budget_consumed_even_on_http_failure ci-dessous).
    assert vision_client._daily_call_count == 0


def test_model_name_env_var_used_when_set(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_VISION_MODEL", "claude-custom-test")
    captured = []
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT, captured))

    vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert captured[0]["json"]["model"] == "claude-custom-test"


def test_model_name_defaults_when_unset(monkeypatch):
    captured = []
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT, captured))

    vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert captured[0]["json"]["model"] == vision_client.DEFAULT_MODEL == "claude-sonnet-5"


def test_api_key_never_appears_in_exception_message(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "super-secret-key-value")
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(500, "irrelevant"))

    with pytest.raises(vision_client.VisionExtractionError) as excinfo:
        vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert "super-secret-key-value" not in str(excinfo.value)


def test_programme_parses_horses_and_nested_perfs(monkeypatch):
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, PROGRAMME_TEXT))

    result = vision_client.extract_programme(b"bytes", "image/jpeg")

    assert result.hippo == "Vincennes"
    assert result.dist == 2700
    assert result.partants == 2
    assert len(result.horses) == 2
    assert result.horses[0].name == "CHEVAL UN"
    assert result.horses[0].perfs[1].incident == "D"
    assert result.horses[0].perfs[1].rank is None
    assert result.horses[1].cote is None


def test_prompts_ported_verbatim_no_placeholder():
    # Non-régression NFR-6 : les prompts ne doivent jamais être réécrits.
    assert "UNIQUEMENT avec un JSON valide" in vision_client.PROMPT
    assert '{"name":string,"num":number|null' in vision_client.PROMPT
    assert "UNIQUEMENT avec un JSON valide" in vision_client.RACE_PROMPT
    assert '{"hippo":string,"dist":number|null' in vision_client.RACE_PROMPT


def test_prompts_match_prototype_source_exactly():
    # Revue de code (blind-hunter) : un simple test de sous-chaîne (ci-dessus)
    # laisserait passer une reformulation ailleurs dans le corps du prompt.
    # Comparaison intégrale contre le fichier source du prototype pour
    # verrouiller NFR-6 mécaniquement, pas seulement par relecture manuelle.
    import re

    jsx_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "docs", "analyse_hippique_ia.jsx"
    )
    jsx_source = open(jsx_path, encoding="utf-8").read()

    prompt_match = re.search(r"const PROMPT = `(.*?)`;", jsx_source, re.S)
    race_prompt_match = re.search(r"const RACE_PROMPT = `(.*?)`;", jsx_source, re.S)
    assert prompt_match is not None
    assert race_prompt_match is not None

    assert vision_client.PROMPT == prompt_match.group(1)
    assert vision_client.RACE_PROMPT == race_prompt_match.group(1)


def test_missing_api_key_checked_before_budget_is_consumed(monkeypatch):
    # Complète test_missing_api_key_raises_extraction_error_without_http_call :
    # même avec un plafond déjà à zéro appel restant, une clé absente reste la
    # cause de l'erreur (elle est vérifiée en premier) - preuve que l'ordre
    # des deux gardes est bien "clé d'abord" et pas coïncidence.
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    monkeypatch.setenv("VISION_DAILY_CALL_LIMIT", "0")

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")


def test_budget_consumed_even_on_http_failure(monkeypatch):
    # Contraste avec la clé API manquante : une tentative réseau réellement
    # émise (même si elle échoue côté serveur) doit rester comptée dans le
    # budget - sinon une rafale d'erreurs 500/429 contournerait
    # indéfiniment le plafond quotidien que ce module doit garantir (AD-3).
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(500, "irrelevant"))

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert vision_client._daily_call_count == 1


def test_daily_limit_enforced_across_real_sequential_calls(monkeypatch):
    # Les tests de plafond existants pré-positionnent directement le compteur
    # global plutôt que de le faire progresser via de vrais appels successifs
    # - edge-case-hunter, revue de code. Ici, la limite est atteinte par
    # incrémentation réelle, pas par manipulation directe de l'état interne.
    monkeypatch.setenv("VISION_DAILY_CALL_LIMIT", "2")
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT))

    vision_client.extract_fiche_cheval(b"bytes", "image/png")  # 1/2
    vision_client.extract_fiche_cheval(b"bytes", "image/png")  # 2/2

    with pytest.raises(vision_client.VisionBudgetExceeded):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")  # 3e refusé


def test_daily_limit_zero_blocks_every_call(monkeypatch):
    monkeypatch.setenv("VISION_DAILY_CALL_LIMIT", "0")
    call_count = {"n": 0}

    def fake_post(*args, **kwargs):
        call_count["n"] += 1
        return _FakeResponse(200, _envelope(FICHE_TEXT))

    monkeypatch.setattr(vision_client.requests, "post", fake_post)

    with pytest.raises(vision_client.VisionBudgetExceeded):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert call_count["n"] == 0


def test_request_headers_use_x_api_key_not_authorization(monkeypatch):
    # verification-gap : aucun test n'inspectait les en-têtes envoyés - un
    # nom d'en-tête erroné ferait échouer chaque appel réel avec un 401 sans
    # qu'aucun test actuel ne le détecte.
    monkeypatch.setenv("ANTHROPIC_API_KEY", "the-real-key")
    captured = []
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, FICHE_TEXT, captured))

    vision_client.extract_fiche_cheval(b"bytes", "image/png")

    headers = captured[0]["headers"]
    assert headers["x-api-key"] == "the-real-key"
    assert "Authorization" not in headers
    assert headers["anthropic-version"] == vision_client.ANTHROPIC_API_VERSION


def test_top_level_json_array_raises_extraction_error_not_attribute_error(monkeypatch):
    # edge-case-hunter : json.loads réussit sur un tableau JSON racine (c'est
    # un JSON valide) - seul le isinstance(data, dict) protège contre un
    # AttributeError non documenté quand le parsing des champs tente ensuite
    # data.get(...) sur une liste.
    monkeypatch.setattr(vision_client.requests, "post", _make_fake_post(200, "[1, 2, 3]"))

    with pytest.raises(vision_client.VisionExtractionError):
        vision_client.extract_fiche_cheval(b"bytes", "image/png")


def test_non_dict_entry_in_perfs_is_dropped_not_crashed(monkeypatch):
    # verification-gap + edge-case-hunter : une entrée malformée dans "perfs"
    # (jamais un dict) doit être silencieusement ignorée (comme le fait déjà
    # open_pmu_client.py pour un JSON externe non fiable), pas faire planter
    # extract_fiche_cheval avec une AttributeError.
    fiche_avec_entree_invalide = dict(FICHE_JSON, perfs=[
        {"rank": 1, "part": 12, "incident": "", "niveau": 2.3, "dist": 2000, "terr": 1},
        "1p T Ap",  # entrée malformée, jamais un dict
    ])
    monkeypatch.setattr(
        vision_client.requests, "post",
        _make_fake_post(200, json.dumps(fiche_avec_entree_invalide)),
    )

    result = vision_client.extract_fiche_cheval(b"bytes", "image/png")

    assert len(result.perfs) == 1  # l'entrée malformée est écartée, pas plantée
    assert result.perfs[0].rank == 1
