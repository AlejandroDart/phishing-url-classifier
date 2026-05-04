import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse
from datetime import datetime
import whois
from publicsuffix2 import get_sld
import dns.resolver
import tldextract
import wordninja
import re
from concurrent.futures import ThreadPoolExecutor
import time
from functools import lru_cache
import redis
import json

# Configurar conexión a Redis
redis_client = redis.StrictRedis(
    host='localhost', port=6379, db=0, decode_responses=True)


# Función para almacenar en caché con tiempo de vida
def cache_get_or_set(key, func, ttl=3600, *args, **kwargs):
    """
    Obtiene un valor de la caché o lo calcula y almacena si no existe.
    :param key: Clave de la caché.
    :param func: Función que genera el valor si no está en caché.
    :param ttl: Tiempo de vida en segundos (por defecto, 1 hora).
    :return: Valor almacenado en caché o calculado.
    """
    value = redis_client.get(key)
    if value is not None:
        return json.loads(value)  # Deserializar JSON
    # Ejecutar la función si no está en caché
    result = func(*args, **kwargs)
    redis_client.setex(key, ttl, json.dumps(result))  # Serializar JSON
    return result


@lru_cache(maxsize=20)
def check_google_index(url):

    parsed_url = urlparse(url)
    domain = parsed_url.netloc

    # Construye la consulta con el dork site:
    query = f"site:{domain}"
    google_url = f"https://www.google.com/search?q={query}"

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
    }

    try:
        response = requests.get(google_url, headers=headers)

        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')

            # Busca elementos de resultados en la página
            # Los resultados suelen estar en divs con clase "g"
            search_results = soup.find_all('div', class_='g')

            if search_results:
                return 1  # Si hay resultados, está indexado
            else:
                return 0  # No se encontraron resultados
        else:
            print("Error al realizar la consulta. Código de estado:",
                  response.status_code)
            return 0  # Si no se puede realizar la consulta, asumimos que no está indexado
    except Exception as e:
        print("Error:", str(e))
        return 0  # Si ocurre un error, asumimos que no está indexado


@lru_cache(maxsize=20)
def fetch_whois_info(domain, max_retries=3):
    for attempt in range(max_retries):
        try:
            result = whois.whois(domain)
            if result and result.domain_name:
                return result
        except Exception as e:
            print(
                f"Intento {attempt + 1} fallido para WHOIS de '{domain}': {e}")
            if attempt == max_retries - 1:
                raise  # Re-lanza la excepción si se agotaron los intentos

    # Si llega aquí, no se obtuvo un resultado válido en ningún intento
    raise Exception(
        f"No se pudo obtener información WHOIS para '{domain}' tras '{max_retries}' intentos.")


def check_domain_registration(whois_info, domain):
    """Verificar si el dominio está registrado."""
    is_registered = 0
    try:
        hostname = whois_info.domain_name
        if isinstance(hostname, list):  # Si WHOIS devuelve una lista de dominios
            for host in hostname:
                if re.search(host.lower(), domain):
                    is_registered = 1
                    break
        # Si WHOIS devuelve un único dominio
        elif hostname and re.search(hostname.lower(), domain):
            is_registered = 1
    except Exception as e:
        print(f"Error al verificar registro de dominio: {e}")
    return is_registered


def calculate_domain_age(whois_info):
    """Calcular la edad del dominio."""
    domain_age = -1
    try:
        creation_date = whois_info.creation_date
        if creation_date:
            if isinstance(creation_date, list):  # Si es una lista, tomar el primer elemento
                creation_date = creation_date[0]

            if isinstance(creation_date, str):  # Convertir cadena a datetime
                creation_date = datetime.strptime(
                    creation_date.split(" ")[0], "%Y-%m-%d")

            if isinstance(creation_date, datetime):  # Calcular la edad
                domain_age = (datetime.now() - creation_date).days
    except Exception as e:
        print(f"Error al calcular la edad del dominio: {e}")
    return domain_age


def analyze_domain_whois(url):

    try:
        # Parsear la URL para obtener el dominio
        parsed_url = urlparse(url)
        domain = parsed_url.netloc

        # Eliminar prefijo 'www.' si existe
        if domain.startswith("www."):
            domain = domain[4:]

        # Caso especial: dominios que terminan en 'gob.cl'
        if domain.endswith("gob.cl"):
            domain = "gob.cl"

        # Obtener el dominio base
        domain = get_sld(domain)

        # Realizar la consulta WHOIS
        whois_info = fetch_whois_info(domain)

        # Ejecutar tareas en paralelo
        with ThreadPoolExecutor() as executor:
            future_registration = executor.submit(
                check_domain_registration, whois_info, domain)
            future_age = executor.submit(calculate_domain_age, whois_info)

            is_registered = future_registration.result()  # Resultado de registro
            domain_age = future_age.result()  # Resultado de la edad del dominio

        # Retornar los resultados
        return {
            "domain_age": domain_age,
            "is_registered": is_registered
        }

    except Exception as e:
        print(f"Error al analizar dominio WHOIS para '{url}': {e}")
        return {
            "domain_age": -1,
            "is_registered": 0
        }


@lru_cache(maxsize=20)
def dns_record(url):

    try:
        # Extraer el dominio de la URL
        domain = urlparse(url).netloc

        # Eliminar prefijos como 'www.' si existen
        if domain.startswith("www."):
            domain = domain[4:]

        # Caso especial: dominios que terminan en 'gob.cl'
        if domain.endswith("gob.cl"):
            domain = "gob.cl"

        domain = get_sld(domain)

        # Resolver registros NS del dominio
        nameservers = dns.resolver.resolve(domain, 'NS')

        # Verificar si se encontraron registros NS
        if len(nameservers) > 0:
            return 1  # Dominio válido con registros NS
        else:
            return 0  # No se encontraron registros NS
    except Exception as e:
        # En caso de error, asumimos que el dominio no tiene registros válidos
        # print(f"Error en la consulta DNS para {url}: {e}")
        return 0


def count_nb_qm(url):
    return url.count('?')


def count_nb_www(url):
    return url.lower().count('www')


def ratio_digits_host(url):

    try:
        # Extraer el host de la URL
        parsed_url = urlparse(url)
        host = parsed_url.netloc

        # Contar dígitos en el host
        num_digitos = sum(c.isdigit() for c in host)
        longitud_host = len(host)

        # Evitar divisiones por cero
        if longitud_host == 0:
            return 0.000000

        # Calcular la proporción y redondear a 6 decimales
        return round(num_digitos / longitud_host, 6)
    except Exception as e:
        print(f"Error procesando la URL: {url}, {e}")
        return 0.000000


@lru_cache(maxsize=20)
def fetch_page_content(url):
    """Descargar el contenido HTML de la página."""
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            return response.text
        else:
            return None
    except requests.exceptions.RequestException:
        return None


def calculate_hyperlinks(soup):
    """Calcular la cantidad de enlaces y elementos con src."""
    href_count = len(soup.find_all('a', href=True)
                     )  # Contar enlaces <a> con href
    # Contar etiquetas con src (ej., <img>, <script>, etc.)
    src_count = len(soup.find_all(src=True))
    return href_count + src_count


def check_domain_in_title(soup, url):
    """Verificar si el dominio está en el título."""
    extracted = tldextract.extract(url)
    base_domain = extracted.domain  # Nombre base del dominio (sin TLD)
    palabras_base_domain = wordninja.split(base_domain)  # Dividir en palabras
    title = soup.title.string if soup.title else ""
    return int(any(palabra.lower() in title.lower() for palabra in palabras_base_domain))


def check_domain_with_copyright(html_content, url):
    """Verificar si el dominio aparece con copyright."""
    extracted = tldextract.extract(url)
    domain_full = f"{extracted.domain}.{extracted.suffix}"
    match = re.search(r'(©|\(c\)|&copy;|&trade;|&reg;)', html_content)
    if match:
        context_range = 250  # Reducido para mejorar rendimiento
        start = max(0, match.start() - context_range)
        end = match.end() + context_range
        _copyright = html_content[start:end].lower()
        if domain_full.lower() in _copyright:
            return 1
    return 0


def analyze_page_content(url):
    """Analizar contenido de la página y calcular características."""
    html_content = fetch_page_content(url)

    if not html_content:
        return {
            "nb_hyperlinks": 0,
            "domain_in_title": 0,
            "domain_with_copyright": 0
        }

    # Crear instancia de BeautifulSoup
    soup = BeautifulSoup(html_content, 'html.parser')

    # Ejecutar tareas en paralelo con hilos
    with ThreadPoolExecutor() as executor:
        future_hyperlinks = executor.submit(calculate_hyperlinks, soup)
        future_domain_in_title = executor.submit(
            check_domain_in_title, soup, url)
        future_domain_with_copyright = executor.submit(
            check_domain_with_copyright, html_content, url)

        # Obtener los resultados de las tareas
        nb_hyperlinks = future_hyperlinks.result()
        domain_in_title = future_domain_in_title.result()
        domain_with_copyright = future_domain_with_copyright.result()

    return {
        "nb_hyperlinks": nb_hyperlinks,
        "domain_in_title": domain_in_title,
        "domain_with_copyright": domain_with_copyright
    }


def count_nb_hyphens(url):
    return url.count('-')


def count_nb_dots(url):
    return url.count('.')


def count_nb_eq(url):
    return url.count('=')


def count_length_hostname(url):
    parsed_url = urlparse(url)
    hostname = parsed_url.hostname
    return len(hostname)


def ratio_digits_url(url):

    # Contar la cantidad de dígitos en la URL
    num_digitos = len(re.findall(r'\d', url))

    # Calcular la longitud total de la URL
    longitud_url = len(url)

    # Evitar división por cero
    if longitud_url == 0:
        return 0.000000

    # Calcular el ratio
    return round(num_digitos / longitud_url, 6)


def https_token(url):

    try:
        # Validar si la URL no es vacía o nula
        if not url or not isinstance(url, str):
            raise ValueError("La URL está vacía o no es válida.")

        # Parsear la URL para obtener el esquema
        scheme = urlparse(url).scheme.lower()

        # Retornar 1 si el esquema es HTTPS, 0 en caso contrario
        return 1 if scheme == 'https' else 0
    except Exception as e:
        # print(f"Error al analizar la URL '{url}': {e}")
        return 0  # Considerar como no seguro si ocurre un error.


def tld_in_subdomain(url):

    try:
        # Parsear la URL para obtener el hostname
        parsed_url = urlparse(url)
        hostname = parsed_url.hostname  # Ejemplo: 'www.com.example.com'

        if not hostname:
            # print(f"URL inválida: {url}")
            return 0

        # Dividir el hostname en partes
        parts = hostname.split('.')

        # Determinar el TLD y el subdominio
        if len(parts) > 2:  # Hay al menos un subdominio
            tld = parts[-1]  # Última parte como TLD
            # Todo antes del dominio principal y TLD
            subdomain = ".".join(parts[:-2])
        else:  # No hay subdominio
            tld = parts[-1] if len(parts) > 1 else ""
            subdomain = ""

        # Verificar si el TLD aparece en el subdominio o coincide directamente
        if tld and subdomain and (tld in subdomain or subdomain == tld):
            return 1
        return 0

    except Exception as e:
        # print(f"Error en tld_in_subdomain para la URL '{url}': {e}")
        return 0  # Asumir 0 en caso de error


def prefix_suffix(url):
    if re.findall(r"https?://[^\-]+-[^\-]+/", url):
        return 1
    else:
        return 0


def extract_features_url_analyze(url):
    """
    Extrae las características de una URL utilizando tanto ejecución paralela como secuencial.
    """
    # Inicializar características
    features = {
        'google_index': 0,
        'nb_qm': 0,
        'nb_www': 0,
        'ratio_digits_host': 0.000000,
        'nb_hyperlinks': 0,
        'nb_hyphens': 0,
        'domain_in_title': 0,
        'nb_dots': 0,
        'nb_eq': 0,
        'length_hostname': 0,
        'domain_age': 0,
        'ratio_digits_url': 0,
        'domain_with_copyright': 0,
        'https_token': 0,
        'whois_registered_domain': 0,
        'tld_in_subdomain': 0,
        'dns_record': 0,
        'prefix_suffix': 0
    }

    timings = {}

    # Ejecutar tareas paralelas
    start_parallel = time.time()
    with ThreadPoolExecutor(max_workers=4) as executor:
        # Lanzar todas las tareas en paralelo
        future_tasks = {
            'google_index': executor.submit(check_google_index, url),
            'analyze_page_content': executor.submit(analyze_page_content, url),
            'analyze_domain_whois': executor.submit(analyze_domain_whois, url),
            'dns_record': executor.submit(dns_record, url)
        }

        # Recolectar resultados y medir tiempos para cada tarea
        for key, future in future_tasks.items():
            start_task = time.time()
            try:
                result = future.result()
                timings[f"{key}_execution"] = time.time() - start_task

                # Asignar resultados a las características
                if key == 'google_index':
                    features['google_index'] = result
                elif key == 'analyze_page_content':
                    features['nb_hyperlinks'] = result['nb_hyperlinks']
                    features['domain_in_title'] = result['domain_in_title']
                    features['domain_with_copyright'] = result['domain_with_copyright']
                elif key == 'analyze_domain_whois':
                    features['domain_age'] = result['domain_age']
                    features['whois_registered_domain'] = result['is_registered']
                elif key == 'dns_record':
                    features['dns_record'] = result

            except Exception as e:
                print(f"Error en {key}: {e}")

    timings['parallel_execution'] = time.time() - start_parallel

    # Ejecución secuencial del resto de funciones y medir tiempos
    start_sequential = time.time()

    start = time.time()
    features['nb_qm'] = count_nb_qm(url)
    timings['count_nb_qm'] = time.time() - start

    start = time.time()
    features['nb_www'] = count_nb_www(url)
    timings['count_nb_www'] = time.time() - start

    start = time.time()
    features['ratio_digits_host'] = ratio_digits_host(url)
    timings['ratio_digits_host'] = time.time() - start

    start = time.time()
    features['nb_hyphens'] = count_nb_hyphens(url)
    timings['count_nb_hyphens'] = time.time() - start

    start = time.time()
    features['nb_dots'] = count_nb_dots(url)
    timings['count_nb_dots'] = time.time() - start

    start = time.time()
    features['nb_eq'] = count_nb_eq(url)
    timings['count_nb_eq'] = time.time() - start

    start = time.time()
    features['length_hostname'] = count_length_hostname(url)
    timings['count_length_hostname'] = time.time() - start

    start = time.time()
    features['ratio_digits_url'] = ratio_digits_url(url)
    timings['ratio_digits_url'] = time.time() - start

    start = time.time()
    features['https_token'] = https_token(url)
    timings['https_token'] = time.time() - start

    start = time.time()
    features['tld_in_subdomain'] = tld_in_subdomain(url)
    timings['tld_in_subdomain'] = time.time() - start

    start = time.time()
    features['prefix_suffix'] = prefix_suffix(url)
    timings['prefix_suffix'] = time.time() - start

    timings['sequential_execution'] = time.time() - start_sequential

    # Imprimir tiempos de ejecución
    print("\nTiempos de Ejecución:")
    for key, value in timings.items():
        print(f"{key}: {value:.4f} segundos")

    return features
