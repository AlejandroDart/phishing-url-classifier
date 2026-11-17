import pytest
from psycopg2 import OperationalError

from app import app
from routes import stats_routes
from services import feature_extractor_top25


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setitem(app.config, "API_KEY", "local-test-key")
    return app.test_client()


PROTECTED_ROUTES = [
    ("POST", "/predict"),
    ("POST", "/explain-features"),
    ("GET", "/models"),
    ("GET", "/model/info"),
    ("POST", "/chat"),
    ("GET", "/chat/health"),
    ("GET", "/stats/count"),
    ("GET", "/stats/phishing-ratio"),
    ("GET", "/stats/recent"),
    ("GET", "/stats/daily"),
]


@pytest.mark.parametrize("method,path", PROTECTED_ROUTES)
def test_protected_routes_require_the_service_key(client, method, path):
    assert client.open(path, method=method).status_code == 403
    result = client.open(path, method=method, headers={"X-API-KEY": "incorrecta"})
    assert result.status_code == 403


def test_empty_service_key_fails_closed(client, monkeypatch):
    monkeypatch.setitem(app.config, "API_KEY", "")
    assert client.get("/").status_code == 200
    assert client.get("/models").status_code == 403


@pytest.mark.parametrize("body", [[1], 123, {"url": 123}, {"url": " "}])
def test_prediction_rejects_bad_request_bodies(client, body):
    result = client.post("/predict", json=body, headers={"X-API-KEY": "local-test-key"})
    assert result.status_code == 400
    assert result.json["error"]


def test_cors_preflight_respects_the_local_allowlist(client):
    preflight = {
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "Content-Type, X-API-KEY",
    }
    allowed = client.options("/predict", headers={**preflight, "Origin": "http://127.0.0.1:8005"})
    assert allowed.status_code == 200
    assert allowed.headers["Access-Control-Allow-Origin"] == "http://127.0.0.1:8005"
    denied = client.options("/predict", headers={**preflight, "Origin": "https://third-party.example"})
    assert "Access-Control-Allow-Origin" not in denied.headers


def test_database_outage_returns_controlled_stats_response(client, monkeypatch):
    def unavailable():
        raise OperationalError("internal test detail")

    monkeypatch.setattr(stats_routes, "get_total_analysis", unavailable)
    result = client.get("/stats/count", headers={"X-API-KEY": "local-test-key"})
    assert result.status_code == 503
    assert result.json == {"error": "Estadísticas globales temporalmente no disponibles"}
    assert client.get("/").status_code == 200


def test_offline_extraction_does_not_fetch_external_data(monkeypatch):
    def unexpected(*args, **kwargs):
        pytest.fail("Offline extraction accessed the network")

    for method in ("fetch_html", "get_domain_age_and_registration_length", "get_google_index"):
        monkeypatch.setattr(feature_extractor_top25, method, unexpected)
    result = feature_extractor_top25.extract_top25_features(
        "https://example.test/reference", use_network_features=False
    )
    assert len(result.columns) == 25
    assert result.iloc[0]["domain_age"] == 0


def test_authenticated_model_catalog_returns_all_models(client):
    result = client.get("/models", headers={"X-API-KEY": "local-test-key"})

    assert result.status_code == 200
    assert len(result.json["models"]) == 14
