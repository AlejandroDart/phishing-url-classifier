from typing import Any


FEATURE_KNOWLEDGE = {
    "google_index": {
        "label": "Presencia en buscadores",
        "description": (
            "Indica si el dominio apareció en una consulta de tipo site: después "
            "de comprobar que el dominio resolvía por red."
        ),
        "kind": "google_index",
        "aliases": ("buscador", "buscadores", "google", "indexado", "indexación"),
    },
    "domain_age": {
        "label": "Antigüedad del dominio",
        "description": "Cantidad estimada de días desde la creación registrada del dominio.",
        "kind": "days",
        "aliases": ("antigüedad", "edad del dominio", "domain age"),
    },
    "nb_hyperlinks": {
        "label": "Cantidad de enlaces",
        "description": "Número de etiquetas de enlace encontradas en el HTML de la página.",
        "kind": "count",
        "aliases": ("cantidad de enlaces", "hipervínculos", "hyperlinks"),
    },
    "nb_www": {
        "label": "Uso de www",
        "description": "Cantidad de veces que aparece la cadena www en la URL completa.",
        "kind": "count",
        "aliases": ("www",),
    },
    "phish_hints": {
        "label": "Palabras asociadas a phishing",
        "description": "Cantidad de palabras de alerta encontradas en la URL, como login, verify o account.",
        "kind": "count",
        "aliases": ("palabras de phishing", "palabras sospechosas", "phish hints"),
    },
    "safe_anchor": {
        "label": "Enlaces sin destino útil",
        "description": "Proporción de enlaces vacíos, anclas #, javascript o about:blank.",
        "kind": "ratio",
        "aliases": ("safe anchor", "enlaces vacíos", "enlaces sin destino"),
    },
    "longest_word_path": {
        "label": "Palabra más larga en la ruta",
        "description": "Longitud de la palabra más extensa ubicada después del dominio.",
        "kind": "length",
        "aliases": ("palabra más larga en la ruta",),
    },
    "ratio_digits_url": {
        "label": "Proporción de números en la URL",
        "description": "Porcentaje de caracteres numéricos respecto de la longitud total de la URL.",
        "kind": "ratio",
        "aliases": ("números en la url", "dígitos en la url"),
    },
    "ratio_intHyperlinks": {
        "label": "Proporción de enlaces internos",
        "description": "Proporción de enlaces de la página que apuntan al mismo dominio.",
        "kind": "ratio",
        "aliases": ("enlaces internos",),
    },
    "longest_words_raw": {
        "label": "Palabra más larga de la URL",
        "description": "Longitud de la palabra más extensa encontrada en toda la URL.",
        "kind": "length",
        "aliases": ("palabra más larga de la url",),
    },
    "domain_in_title": {
        "label": "Dominio presente en el título",
        "description": "Indica si el nombre del dominio aparece en el título HTML de la página.",
        "kind": "binary",
        "aliases": ("dominio en el título", "título de la página"),
    },
    "length_words_raw": {
        "label": "Longitud total de palabras",
        "description": "Suma de las longitudes de las palabras que componen la URL.",
        "kind": "length",
        "aliases": ("longitud de palabras",),
    },
    "nb_dots": {
        "label": "Cantidad de puntos",
        "description": "Número de caracteres punto presentes en la URL completa.",
        "kind": "count",
        "aliases": ("cantidad de puntos de la url", "puntos en la url"),
    },
    "domain_registration_length": {
        "label": "Vigencia del registro del dominio",
        "description": "Cantidad estimada de días entre la creación y expiración registradas del dominio.",
        "kind": "days",
        "aliases": ("vigencia del dominio", "registro del dominio"),
    },
    "ratio_extRedirection": {
        "label": "Proporción de redirecciones externas",
        "description": "Proporción de redirecciones HTTP que terminan en un dominio diferente.",
        "kind": "ratio",
        "aliases": ("redirecciones externas",),
    },
    "nb_hyphens": {
        "label": "Cantidad de guiones",
        "description": "Número de guiones presentes en la URL completa.",
        "kind": "count",
        "aliases": ("guiones",),
    },
    "char_repeat": {
        "label": "Caracteres repetidos",
        "description": "Cantidad de caracteres consecutivos que se repiten dentro de la URL.",
        "kind": "count",
        "aliases": ("caracteres repetidos",),
    },
    "length_hostname": {
        "label": "Longitud del nombre de host",
        "description": "Cantidad de caracteres del host, incluidos subdominios y dominio.",
        "kind": "length",
        "aliases": ("longitud del host", "nombre de host"),
    },
    "nb_slash": {
        "label": "Cantidad de barras",
        "description": "Número de caracteres / presentes en la URL.",
        "kind": "count",
        "aliases": ("barras", "slash"),
    },
    "ratio_extHyperlinks": {
        "label": "Proporción de enlaces externos",
        "description": "Proporción de enlaces de la página que apuntan a otros dominios.",
        "kind": "ratio",
        "aliases": ("enlaces externos",),
    },
    "links_in_tags": {
        "label": "Enlaces en etiquetas HTML",
        "description": "Cantidad de referencias encontradas en etiquetas link, script y meta.",
        "kind": "count",
        "aliases": ("enlaces en etiquetas", "links in tags"),
    },
    "avg_word_path": {
        "label": "Longitud media de palabras en la ruta",
        "description": "Promedio de caracteres de las palabras ubicadas después del dominio.",
        "kind": "decimal",
        "aliases": ("promedio de palabras en la ruta",),
    },
    "domain_with_copyright": {
        "label": "Dominio junto al copyright",
        "description": "Indica si la página contiene copyright y menciona el nombre del dominio.",
        "kind": "binary",
        "aliases": ("copyright", "dominio con copyright"),
    },
    "ip": {
        "label": "Dirección IP usada como dominio",
        "description": "Indica si el host de la URL es una dirección IP en lugar de un nombre de dominio.",
        "kind": "binary",
        "aliases": ("dirección ip", "ip como dominio"),
    },
    "ratio_extMedia": {
        "label": "Proporción de contenido externo",
        "description": "Proporción de imágenes, audio o video cargados desde otros dominios.",
        "kind": "ratio",
        "aliases": ("contenido externo", "medios externos"),
    },
}


def describe_feature_value(feature: str, value: Any) -> str:
    knowledge = FEATURE_KNOWLEDGE.get(feature, {})
    kind = knowledge.get("kind")
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return f"El valor observado fue {value}."

    if kind == "google_index":
        if numeric >= 1:
            return "El valor 1 significa que el dominio fue encontrado por la comprobación."
        return (
            "El valor 0 significa que no fue encontrado o que la comprobación de red "
            "no pudo confirmarlo; por sí solo no prueba que el sitio sea malicioso."
        )
    if kind == "binary":
        return f"El valor {int(numeric)} indica que la condición {'se cumplió' if numeric >= 1 else 'no se cumplió'}."
    if kind == "ratio":
        return f"El valor equivale aproximadamente a {numeric * 100:.1f}% del total evaluado."
    if kind == "days":
        if numeric <= 0:
            return "El valor 0 puede indicar un dominio muy reciente o información de registro no disponible."
        return f"El valor observado corresponde aproximadamente a {numeric:.0f} días."
    if kind == "count":
        return f"El extractor contó {numeric:.0f} apariciones."
    if kind == "length":
        return f"La longitud observada fue de {numeric:.0f} caracteres."
    return f"El valor observado fue {numeric:.2f}."
