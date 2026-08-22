import os
import sys
import ipaddress
import re
import socket
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

import joblib
import numpy as np
import pandas as pd
import requests
from bs4 import BeautifulSoup

sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

try:
    import whois
except ImportError:
    whois = None

try:
    import tldextract
except ImportError:
    tldextract = None


BASE_DIR = Path(__file__).resolve().parent.parent
MODEL_PATH = BASE_DIR / "models" / "ml" / "mejor_modelo_ml.pkl"
FEATURES_PATH = BASE_DIR / "models" / "ml" / "features_mejor_modelo_ml.pkl"
SCALER_PATH = BASE_DIR / "models" / "scaler_top.pkl"
CONTINUOUS_FEATURES_PATH = BASE_DIR / "models" / "features_continuas_top.pkl"

TLD_EXTRACTOR = (
    tldextract.TLDExtract(cache_dir=None, suffix_list_urls=())
    if tldextract is not None
    else None
)

PHISH_HINTS = [
    "login", "signin", "verify", "verification", "secure", "account",
    "update", "confirm", "password", "bank", "wallet", "paypal",
    "amazon", "apple", "microsoft", "office", "support", "billing",
    "webscr", "ebayisapi", "token", "auth", "recover",
]


def load_feature_names():
    return joblib.load(FEATURES_PATH)


def load_continuous_features():
    return joblib.load(CONTINUOUS_FEATURES_PATH)


def load_scaler():
    return joblib.load(SCALER_PATH)


def load_model():
    model = joblib.load(MODEL_PATH)
    if hasattr(model, "n_jobs"):
        model.n_jobs = 1
    return model


def normalize_url(url: str) -> str:
    normalized = str(url).strip()
    if not re.match(r"^https?://", normalized, flags=re.IGNORECASE):
        normalized = "http://" + normalized
    return normalized


def safe_ratio(numerator, denominator):
    return 0 if denominator == 0 else numerator / denominator


def tokenize(text: str):
    return [token for token in re.split(r"[^A-Za-z0-9]+", str(text)) if token]


def has_ip(hostname: str) -> int:
    try:
        ipaddress.ip_address(hostname)
        return 1
    except Exception:
        return 0


def get_registered_domain(url: str) -> str:
    parsed = urlparse(normalize_url(url))
    hostname = parsed.hostname or ""

    if TLD_EXTRACTOR is not None:
        try:
            ext = TLD_EXTRACTOR(hostname)
            if ext.domain and ext.suffix:
                return f"{ext.domain}.{ext.suffix}"
        except Exception:
            pass

    parts = hostname.split(".")
    return ".".join(parts[-2:]) if len(parts) >= 2 else hostname


def is_internal_link(link: str, base_domain: str) -> bool:
    if not link:
        return False

    clean_link = str(link).strip()
    lower_link = clean_link.lower()

    if clean_link.startswith("#") or lower_link.startswith("javascript"):
        return False

    parsed = urlparse(clean_link)
    if not parsed.netloc:
        return True

    return get_registered_domain(clean_link) == base_domain


def fetch_html(url: str, timeout: int = 8):
    normalized_url = normalize_url(url)

    try:
        response = requests.get(
            normalized_url,
            timeout=timeout,
            allow_redirects=True,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        content_type = response.headers.get("Content-Type", "").lower()

        if "text/html" in content_type or response.text.strip().startswith("<"):
            return response.text, response.url, response.history, response.status_code
    except Exception:
        pass

    return None, normalized_url, [], None


def normalize_datetime(value):
    if not value:
        return None

    if isinstance(value, list):
        for item in value:
            parsed = normalize_datetime(item)
            if parsed is not None:
                return parsed
        return None

    if isinstance(value, datetime):
        if value.tzinfo is not None:
            return value.astimezone(timezone.utc).replace(tzinfo=None)
        return value

    if isinstance(value, str):
        clean_value = value.strip()
        timezone_suffixes = [
            " CLST", " CLT", " UTC", " GMT", " Z",
        ]
        for suffix in timezone_suffixes:
            if clean_value.upper().endswith(suffix):
                clean_value = clean_value[: -len(suffix)].strip()
                break

        formats = [
            "%Y-%m-%d %H:%M:%S",
            "%Y-%m-%d",
            "%d-%m-%Y",
            "%d/%m/%Y",
            "%Y/%m/%d",
        ]
        for date_format in formats:
            try:
                return datetime.strptime(clean_value, date_format)
            except ValueError:
                pass

        try:
            from dateutil import parser
            parsed = parser.parse(clean_value, fuzzy=True)
            if parsed.tzinfo is not None:
                return parsed.astimezone(timezone.utc).replace(tzinfo=None)
            return parsed
        except Exception:
            return None

    return None


def get_nic_cl_domain_dates(domain: str):
    diagnostics = {
        "creation_date": None,
        "expiration_date": None,
        "creation_date_raw": None,
        "expiration_date_raw": None,
        "error": "",
    }

    if not domain.lower().endswith(".cl"):
        diagnostics["error"] = "Domain is not .cl"
        return diagnostics

    try:
        response = requests.get(
            "https://www.nic.cl/registry/Whois.do",
            params={"d": domain},
            timeout=12,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        response.raise_for_status()

        soup = BeautifulSoup(response.text, "html.parser")
        values = []

        for table_cell in soup.select(".tablabusqueda td"):
            divs = table_cell.find_all("div")
            if len(divs) > 1:
                value = divs[1].get_text(" ", strip=True)
                if value:
                    values.append(value)

        parsed_dates = []
        for value in values:
            parsed = normalize_datetime(value)
            if parsed is not None:
                parsed_dates.append((value, parsed))

        if not parsed_dates:
            diagnostics["error"] = "NIC Chile response did not include parseable dates"
            return diagnostics

        parsed_dates.sort(key=lambda item: item[1])
        creation_raw, creation_date = parsed_dates[0]
        expiration_raw, expiration_date = parsed_dates[-1]

        diagnostics.update({
            "creation_date": creation_date,
            "expiration_date": expiration_date,
            "creation_date_raw": creation_raw,
            "expiration_date_raw": expiration_raw,
        })
        return diagnostics
    except Exception as error:
        diagnostics["error"] = str(error)
        return diagnostics


def get_domain_age_diagnostics(url: str):
    domain = get_registered_domain(url)
    diagnostics = {
        "url": normalize_url(url),
        "domain": domain,
        "domain_age": 0,
        "domain_registration_length": 0,
        "creation_date_raw": None,
        "expiration_date_raw": None,
        "creation_date_parsed": None,
        "expiration_date_parsed": None,
        "whois_ok": False,
        "whois_error": "",
        "whois_source": "",
    }

    if domain.lower().endswith(".cl"):
        nic_cl_dates = get_nic_cl_domain_dates(domain)
        creation_date = nic_cl_dates["creation_date"]
        expiration_date = nic_cl_dates["expiration_date"]

        if creation_date or expiration_date:
            today = datetime.now()
            diagnostics.update({
                "creation_date_raw": str(nic_cl_dates["creation_date_raw"]),
                "expiration_date_raw": str(nic_cl_dates["expiration_date_raw"]),
                "creation_date_parsed": creation_date.isoformat() if creation_date else None,
                "expiration_date_parsed": expiration_date.isoformat() if expiration_date else None,
                "whois_ok": True,
                "whois_source": "nic.cl",
            })

            if creation_date:
                diagnostics["domain_age"] = max((today - creation_date).days, 0)
            if expiration_date:
                diagnostics["domain_registration_length"] = max((expiration_date - today).days, 0)

            return diagnostics

        diagnostics["whois_error"] = nic_cl_dates["error"]

    if whois is None:
        diagnostics["whois_error"] = "python-whois is not installed"
        return diagnostics

    try:
        data = whois.whois(domain)
        creation_date_raw = getattr(data, "creation_date", None)
        expiration_date_raw = getattr(data, "expiration_date", None)

        creation_date = normalize_datetime(creation_date_raw)
        expiration_date = normalize_datetime(expiration_date_raw)
        today = datetime.now()

        diagnostics.update({
            "creation_date_raw": str(creation_date_raw),
            "expiration_date_raw": str(expiration_date_raw),
            "creation_date_parsed": creation_date.isoformat() if creation_date else None,
            "expiration_date_parsed": expiration_date.isoformat() if expiration_date else None,
            "whois_ok": creation_date is not None or expiration_date is not None,
            "whois_source": "python-whois",
        })

        if creation_date:
            diagnostics["domain_age"] = max((today - creation_date).days, 0)
        if expiration_date:
            diagnostics["domain_registration_length"] = max((expiration_date - today).days, 0)

        return diagnostics
    except Exception as error:
        diagnostics["whois_error"] = str(error)
        return diagnostics


def get_domain_age_and_registration_length(url: str):
    diagnostics = get_domain_age_diagnostics(url)
    return diagnostics["domain_age"], diagnostics["domain_registration_length"]


def domain_resolves(url: str) -> bool:
    try:
        hostname = urlparse(normalize_url(url)).hostname
        if not hostname:
            return False
        socket.gethostbyname(hostname)
        return True
    except Exception:
        return False


def get_full_hostname(url: str) -> str:
    parsed = urlparse(normalize_url(url))
    return parsed.hostname or ""


def google_has_results_diagnostics(query: str, expected_text: str):
    diagnostics = {
        "query": query,
        "expected_text": expected_text,
        "status_code": None,
        "has_expected_text": False,
        "blocked": False,
        "no_results": False,
        "result": False,
        "error": "",
    }

    try:
        response = requests.get(
            "https://www.google.com/search",
            params={"q": query, "hl": "en"},
            timeout=8,
            headers={
                "User-Agent": (
                    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/120.0 Safari/537.36"
                )
            },
        )

        response_text = response.text.lower()
        blocked_patterns = [
            "unusual traffic",
            "our systems have detected",
            "captcha",
            "/sorry/index",
        ]
        no_result_patterns = [
            "did not match any documents",
            "no results found",
            "make sure that all words are spelled correctly",
            "try different keywords",
        ]

        blocked = any(pattern in response_text for pattern in blocked_patterns)
        no_results = any(pattern in response_text for pattern in no_result_patterns)
        has_expected_text = expected_text.lower() in response_text
        result = response.status_code == 200 and has_expected_text and not blocked and not no_results

        diagnostics.update({
            "status_code": response.status_code,
            "has_expected_text": has_expected_text,
            "blocked": blocked,
            "no_results": no_results,
            "result": result,
        })
        return diagnostics
    except Exception as error:
        diagnostics["error"] = str(error)
        return diagnostics


def google_has_results(query: str, expected_text: str) -> bool:
    return google_has_results_diagnostics(query, expected_text)["result"]


def get_google_index_diagnostics(url: str):
    normalized_url = normalize_url(url)
    hostname = get_full_hostname(normalized_url)
    registered_domain = get_registered_domain(normalized_url)
    diagnostics = {
        "url": normalized_url,
        "hostname": hostname,
        "registered_domain": registered_domain,
        "hostname_resolves": False,
        "registered_domain_resolves": False,
        "google_index": 0,
        "queries": [],
        "error": "",
    }

    if not hostname or not registered_domain:
        diagnostics["error"] = "Missing hostname or registered domain"
        return diagnostics

    hostname_resolves = domain_resolves("http://" + hostname)
    registered_domain_resolves = domain_resolves("http://" + registered_domain)
    diagnostics["hostname_resolves"] = hostname_resolves
    diagnostics["registered_domain_resolves"] = registered_domain_resolves

    if not hostname_resolves and not registered_domain_resolves:
        return diagnostics

    queries = []
    if hostname_resolves:
        queries.append((f"site:{hostname}", hostname))
    if registered_domain_resolves and registered_domain != hostname:
        queries.append((f"site:{registered_domain}", registered_domain))

    for query, expected in queries:
        query_diagnostics = google_has_results_diagnostics(query, expected)
        diagnostics["queries"].append(query_diagnostics)
        if query_diagnostics["result"]:
            diagnostics["google_index"] = 1
            return diagnostics

    return diagnostics


def get_google_index(url: str):
    return get_google_index_diagnostics(url)["google_index"]


def extract_top25_features(url: str, use_network_features: bool = True) -> pd.DataFrame:
    model_features = load_feature_names()
    normalized_url = normalize_url(url)
    parsed = urlparse(normalized_url)

    hostname = parsed.hostname or ""
    path = parsed.path or ""
    full_without_scheme = normalized_url.replace("http://", "").replace("https://", "")

    tokens_raw = tokenize(full_without_scheme)
    tokens_path = tokenize(path)

    html, final_url, history, _status_code = fetch_html(normalized_url)
    soup = BeautifulSoup(html, "html.parser") if html else BeautifulSoup("", "html.parser")

    base_domain = get_registered_domain(final_url)
    domain_name = base_domain.split(".")[0] if base_domain else ""
    digits_url = sum(character.isdigit() for character in normalized_url)

    features = {
        "nb_www": normalized_url.lower().count("www"),
        "phish_hints": sum(1 for hint in PHISH_HINTS if hint in normalized_url.lower()),
        "longest_word_path": max([len(token) for token in tokens_path], default=0),
        "ratio_digits_url": safe_ratio(digits_url, len(normalized_url)),
        "longest_words_raw": max([len(token) for token in tokens_raw], default=0),
        "length_words_raw": sum(len(token) for token in tokens_raw),
        "nb_dots": normalized_url.count("."),
        "nb_hyphens": normalized_url.count("-"),
        "char_repeat": sum(
            1 for index in range(1, len(normalized_url))
            if normalized_url[index] == normalized_url[index - 1]
        ),
        "length_hostname": len(hostname),
        "nb_slash": normalized_url.count("/"),
        "avg_word_path": float(np.mean([len(token) for token in tokens_path])) if tokens_path else 0,
        "ip": has_ip(hostname),
    }

    links = [anchor.get("href", "") for anchor in soup.find_all("a")]
    total_links = len(links)
    internal_links = 0
    external_links = 0
    safe_links = 0

    for link in links:
        clean_link = str(link).strip()
        lower_link = clean_link.lower()

        if lower_link in ["", "#", "javascript:void(0)", "javascript:;", "about:blank"]:
            safe_links += 1
        elif is_internal_link(clean_link, base_domain):
            internal_links += 1
        else:
            external_links += 1

    ext_redirections = 0
    int_redirections = 0

    for redirect in history:
        try:
            origin_domain = get_registered_domain(redirect.url)
            target_domain = get_registered_domain(final_url)
            if origin_domain == target_domain:
                int_redirections += 1
            else:
                ext_redirections += 1
        except Exception:
            pass

    total_redirections = int_redirections + ext_redirections

    tag_links = []
    for tag_name in ["link", "script", "meta"]:
        for tag in soup.find_all(tag_name):
            href = tag.get("href") or tag.get("src") or tag.get("content") or ""
            if href:
                tag_links.append(href)

    media_links = []
    for tag_name, attr in [
        ("img", "src"),
        ("audio", "src"),
        ("video", "src"),
        ("source", "src"),
        ("embed", "src"),
    ]:
        for tag in soup.find_all(tag_name):
            src = tag.get(attr, "")
            if src:
                media_links.append(src)

    total_media = len(media_links)
    external_media = sum(1 for media in media_links if not is_internal_link(media, base_domain))

    title = soup.title.string.strip() if soup.title and soup.title.string else ""
    page_text = soup.get_text(" ", strip=True).lower()
    has_copyright = "copyright" in page_text or "\u00a9" in page_text

    features.update({
        "nb_hyperlinks": total_links,
        "safe_anchor": safe_ratio(safe_links, total_links),
        "ratio_intHyperlinks": safe_ratio(internal_links, total_links),
        "domain_in_title": int(domain_name.lower() in title.lower()) if domain_name else 0,
        "ratio_extRedirection": safe_ratio(ext_redirections, total_redirections),
        "ratio_extHyperlinks": safe_ratio(external_links, total_links),
        "links_in_tags": len(tag_links),
        "domain_with_copyright": int(has_copyright and domain_name.lower() in page_text) if domain_name else 0,
        "ratio_extMedia": safe_ratio(external_media, total_media),
    })

    if use_network_features:
        domain_age, domain_registration_length = get_domain_age_and_registration_length(normalized_url)
        google_index = get_google_index(normalized_url)
    else:
        domain_age = 0
        domain_registration_length = 0
        google_index = 0

    features.update({
        "google_index": google_index,
        "domain_age": domain_age,
        "domain_registration_length": domain_registration_length,
    })

    dataframe = pd.DataFrame([features])

    for column in model_features:
        if column not in dataframe.columns:
            dataframe[column] = 0

    dataframe = dataframe[model_features]
    dataframe = dataframe.replace([np.inf, -np.inf], np.nan).fillna(0)

    for column in model_features:
        dataframe[column] = pd.to_numeric(dataframe[column], errors="coerce").fillna(0)

    return dataframe


def scale_top25_features(features: pd.DataFrame) -> pd.DataFrame:
    model_features = load_feature_names()
    continuous_features = load_continuous_features()
    scaler = load_scaler()

    scaled = features.copy()
    columns_to_scale = [column for column in continuous_features if column in scaled.columns]

    if columns_to_scale:
        scaled[columns_to_scale] = scaler.transform(scaled[columns_to_scale])

    return scaled[model_features]


def extract_features_for_model(url: str, use_network_features: bool = True) -> pd.DataFrame:
    raw_features = extract_top25_features(url, use_network_features=use_network_features)
    return scale_top25_features(raw_features)


def predict_url(url: str, use_network_features: bool = True):
    model = load_model()
    features = extract_features_for_model(url, use_network_features=use_network_features)

    if hasattr(model, "feature_names_in_") and list(model.feature_names_in_) != list(features.columns):
        raise ValueError("Model feature order does not match extracted feature order.")

    prediction = int(model.predict(features)[0])
    probability = None

    if hasattr(model, "predict_proba"):
        classes = list(model.classes_)
        probabilities = model.predict_proba(features)[0]
        if 1 in classes:
            probability = float(probabilities[classes.index(1)])

    label = "phishing" if prediction == 1 else "legitimate"

    return {
        "url": normalize_url(url),
        "label": label,
        "prediction": prediction,
        "probability": probability,
        "features": features,
    }


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Extract top 25 phishing URL features.")
    parser.add_argument("url", help="URL to analyze")
    parser.add_argument(
        "--no-network",
        action="store_true",
        help="Disable WHOIS and Google index features.",
    )
    parser.add_argument(
        "--scaled",
        action="store_true",
        help="Print scaled features ready for the model.",
    )
    args = parser.parse_args()

    raw = extract_top25_features(args.url, use_network_features=not args.no_network)
    output = scale_top25_features(raw) if args.scaled else raw
    print(output.to_string(index=False))



