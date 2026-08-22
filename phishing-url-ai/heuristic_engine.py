"""Motor heurístico léxico para evaluar URLs sin consultar servicios externos."""

from __future__ import annotations

import ipaddress
import math
import re
from dataclasses import asdict, dataclass
from urllib.parse import unquote, urlsplit


SUSPICIOUS_TERMS = {
    "account", "actualizar", "auth", "banco", "confirm", "cuenta",
    "login", "password", "payment", "recover", "secure", "signin",
    "support", "unlock", "update", "urgent", "validate", "verify",
    "wallet", "webscr",
}
SHORTENERS = {
    "bit.ly", "cutt.ly", "goo.gl", "is.gd", "ow.ly", "rebrand.ly",
    "shorturl.at", "t.co", "tiny.cc", "tinyurl.com",
}
SUSPICIOUS_TLDS = {
    "click", "country", "download", "gq", "kim", "link", "ml", "mom",
    "party", "rest", "review", "science", "support", "tk", "top", "work",
    "zip",
}


@dataclass(frozen=True)
class HeuristicRule:
    id: str
    label: str
    description: str
    weight: float
    evidence: str


@dataclass(frozen=True)
class HeuristicResult:
    probability: float
    raw_score: float
    maximum_score: float
    rules: list[HeuristicRule]

    def to_dict(self) -> dict:
        return {
            "probability": round(self.probability, 8),
            "raw_score": round(self.raw_score, 4),
            "maximum_score": round(self.maximum_score, 4),
            "triggered_rule_count": len(self.rules),
            "rules": [asdict(rule) for rule in self.rules],
        }


def _normalized_url(url: str) -> tuple[str, object]:
    value = str(url or "").strip()
    candidate = value if "://" in value else f"http://{value}"
    return value, urlsplit(candidate)


def _is_ip(hostname: str) -> bool:
    try:
        ipaddress.ip_address(hostname)
        return True
    except ValueError:
        return False


def analyze_url_heuristics(url: str) -> HeuristicResult:
    original, parsed = _normalized_url(url)
    lowered = unquote(original).lower()
    hostname = (parsed.hostname or "").lower().strip(".")
    path_and_query = f"{parsed.path}?{parsed.query}".lower()
    labels = [part for part in hostname.split(".") if part]
    tld = labels[-1] if labels else ""
    rules: list[HeuristicRule] = []

    def add(rule_id: str, label: str, description: str, weight: float, evidence: str):
        rules.append(HeuristicRule(rule_id, label, description, weight, evidence))

    if hostname and _is_ip(hostname):
        add("ip_host", "Dirección IP como dominio", "Oculta el dominio reconocible detrás de una dirección numérica.", 2.5, hostname)
    if "xn--" in hostname:
        add("punycode", "Dominio Punycode", "Puede representar caracteres visualmente parecidos a los de otra marca.", 2.0, hostname)
    if "@" in original:
        add("at_symbol", "Símbolo @", "El texto anterior a @ puede desviar la atención del dominio real.", 2.0, "@")
    matched_terms = sorted(term for term in SUSPICIOUS_TERMS if term in lowered)
    if matched_terms:
        add("phishing_terms", "Palabras de presión o acceso", "La URL contiene términos usados habitualmente para solicitar acceso, validación o urgencia.", min(2.2, 0.7 + 0.35 * len(matched_terms)), ", ".join(matched_terms[:6]))
    if hostname in SHORTENERS or any(hostname.endswith(f".{item}") for item in SHORTENERS):
        add("shortener", "Servicio acortador", "El acortador impide ver directamente el destino final.", 1.6, hostname)
    if len(labels) >= 5:
        add("many_subdomains", "Exceso de subdominios", "Una cadena extensa de subdominios puede imitar el nombre de una organización.", 1.2, f"{len(labels) - 2} subdominios")
    if len(original) >= 120:
        add("long_url", "URL demasiado extensa", "La longitud puede utilizarse para ocultar el dominio o parámetros relevantes.", 1.0, f"{len(original)} caracteres")
    hyphens = hostname.count("-")
    if hyphens >= 3:
        add("many_hyphens", "Muchos guiones en el dominio", "Los guiones pueden construir dominios parecidos a nombres legítimos.", 0.9, f"{hyphens} guiones")
    if parsed.port and parsed.port not in {80, 443}:
        add("unusual_port", "Puerto no habitual", "La URL utiliza un puerto distinto de HTTP o HTTPS estándar.", 1.3, str(parsed.port))
    percent_count = original.count("%")
    if percent_count >= 2:
        add("encoded_content", "Contenido codificado", "La codificación repetida puede dificultar la lectura del destino.", 0.8, f"{percent_count} secuencias")
    if "//" in path_and_query:
        add("double_slash_path", "Doble barra en la ruta", "Una ruta inusual puede intentar ocultar redirecciones o destinos.", 0.7, parsed.path[:80])
    digit_ratio = sum(char.isdigit() for char in original) / max(len(original), 1)
    if digit_ratio >= 0.25:
        add("many_digits", "Alta proporción de números", "Una cantidad elevada de dígitos reduce la legibilidad de la URL.", 0.8, f"{digit_ratio:.0%}")
    if tld in SUSPICIOUS_TLDS:
        add("suspicious_tld", "Extensión de dominio de mayor riesgo", "La extensión aparece con frecuencia en campañas abusivas y requiere mayor revisión.", 0.9, f".{tld}")
    if parsed.scheme.lower() != "https":
        add("no_https", "Conexión sin HTTPS", "La URL no declara cifrado HTTPS; esto no demuestra phishing por sí solo.", 0.35, parsed.scheme or "sin protocolo")

    raw_score = sum(rule.weight for rule in rules)
    maximum_score = 17.25
    probability = 1 / (1 + math.exp(-(raw_score - 2.8) / 1.45))
    return HeuristicResult(
        probability=max(0.01, min(0.99, probability)),
        raw_score=raw_score,
        maximum_score=maximum_score,
        rules=rules,
    )


def heuristic_probability(url: str) -> float:
    return analyze_url_heuristics(url).probability
