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
            search_results = soup.find_all('div', class_='g')  # Los resultados suelen estar en divs con clase "g"

            if search_results:
                return 1  # Si hay resultados, está indexado
            else:
                return 0  # No se encontraron resultados
        else:
            print("Error al realizar la consulta. Código de estado:", response.status_code)
            return 0  # Si no se puede realizar la consulta, asumimos que no está indexado
    except Exception as e:
        print("Error:", str(e))
        return 0  # Si ocurre un error, asumimos que no está indexado

def get_domain_age(url):

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

        domain = get_sld(domain)

        # Obtener la información WHOIS del dominio
        whois_info = whois.whois(domain)
        creation_date = whois_info.creation_date

        # Manejar diferentes formatos de creation_date
        if creation_date is None:
            print(f"No se encontró la fecha de creación para el dominio '{domain}'.")
            return -1

        if isinstance(creation_date, list):  # Si es una lista, tomar el primer elemento
            creation_date = creation_date[0]

        if isinstance(creation_date, str):  # Convertir cadena a datetime
            creation_date = datetime.strptime(creation_date.split(" ")[0], "%Y-%m-%d")

        # Calcular la edad si creation_date es válido
        if isinstance(creation_date, datetime):
            domain_age = (datetime.now() - creation_date).days
            return domain_age
        else:
            print(f"El formato de 'creation_date' no es válido para '{domain}'.")
            return -1

    except Exception as e:
        print(f"Error al calcular la edad del dominio '{url}': {e}")
        return -1   

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
        #print(f"Error en la consulta DNS para {url}: {e}")
        return 0

def domain_in_title(url):

    try:
        # Extraer el nombre base del dominio de la URL
        extracted = tldextract.extract(url)
        base_domain = extracted.domain  # Solo el nombre del dominio principal (sin el TLD)

        # Dividir el nombre base del dominio en palabras usando wordninja
        palabras_base_domain = wordninja.split(base_domain)

        # Configurar el User-Agent para simular un navegador
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        }

        # Obtener el contenido de la página web
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            #print(f"No se pudo acceder a la página: {url} (Código HTTP: {response.status_code})")
            return 0

        # Analizar el HTML de la página
        soup = BeautifulSoup(response.content, 'html.parser')
        title = soup.title.string if soup.title else ""

        # Verificar si alguna palabra del dominio aparece en el título
        for palabra in palabras_base_domain:
            if palabra.lower() in title.lower():
                return 1  # Coincidencia encontrada

        return 0  # Ninguna coincidencia encontrada

    except Exception as e:
        #print(f"Error en domain_in_title para la URL '{url}': {e}")
        return 0  # Asumir 0 en caso de error

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
    
def nb_hyperlinks(url):

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
    }
    
    try:
        # Hacer la solicitud GET con el User-Agent
        response = requests.get(url, headers=headers, timeout=10)
        
        # Verificar el código de respuesta HTTP
        if response.status_code != 200:
            #print(f"Error HTTP al acceder a la URL: {response.status_code}")
            return 0

        # Parsear el contenido HTML
        dom = BeautifulSoup(response.text, 'html.parser')

        # Contar etiquetas <a> con href
        href_count = len(dom.find_all('a', href=True))
        
        # Contar etiquetas con src (como <img>, <script>, etc.)
        src_count = len(dom.find_all(src=True))
        
        #print(f"Enlaces encontrados en '{url}': {href_count}")
        #print(f"Recursos encontrados en '{url}': {src_count}")
        
        return href_count + src_count
    except requests.exceptions.RequestException as e:
        #print(f"Error al hacer la solicitud a la URL {url}: {e}")
        return 0
    except Exception as e:
        #print(f"Error procesando el DOM: {e}")
        return 0

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

def domain_with_copyright(url):

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
    }

    try:
        # Obtener el dominio base de la URL
        domain_match = re.search(r'://(www\.)?([^/]+)', url)
        if not domain_match:
            #print(f"No se pudo extraer el dominio de la URL: {url}")
            return 0
        domain = domain_match.group(2)

        # Descargar el contenido de la página
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code != 200:
            #print(f"Error HTTP al acceder a la URL: {response.status_code}")
            return 0
        
        content = response.text

        # Buscar símbolos de copyright, trademark o registered
        match = re.search(r'(\N{COPYRIGHT SIGN}|\N{TRADE MARK SIGN}|\N{REGISTERED SIGN}|&copy;|&trade;|&reg;)', content)
        
        if match:
            # Extraer contexto con un rango más amplio
            context_range = 300  # Incrementar el rango a ±200 caracteres
            _copyright = content[max(0, match.span()[0]-context_range):match.span()[0]+context_range]
            
            # Verificar si el dominio aparece cerca del símbolo
            if domain.lower() in _copyright.lower():
                #print(f"El dominio '{domain}' está cerca de un símbolo de copyright.")
                return 1  # El dominio está junto al símbolo
            else:
                #print(f"El dominio '{domain}' no está cerca de un símbolo de copyright.")
                #print(f"Contexto extraído:\n{_copyright}")
                return 0  # El dominio no está junto al símbolo
        else:
            #print("No se encontraron símbolos de copyright, trademark o registered en la página.")
            return 0  # No se encontraron símbolos
    except requests.exceptions.RequestException as e:
        #print(f"Error al acceder a la URL {url}: {e}")
        return 0  # Considerar como sospechoso si no se puede acceder
    except Exception as e:
        #print(f"Error general procesando la URL {url}: {e}")
        return 0

def https_token(url):

    try:
        # Validar si la URL no es vacía o nula
        if not url or not isinstance(url, str):
            raise ValueError("La URL está vacía o no es válida.")

        # Parsear la URL para obtener el esquema
        scheme = urlparse(url).scheme.lower()  # Convertir a minúsculas para evitar inconsistencias

        # Retornar 1 si el esquema es HTTPS, 0 en caso contrario
        return 1 if scheme == 'https' else 0
    except Exception as e:
        #print(f"Error al analizar la URL '{url}': {e}")
        return 0  # Considerar como no seguro si ocurre un error.

def whois_registered_domain(url):

    try:

        # Extraer el dominio de la URL
        domain = urlparse(url).netloc

        # Eliminar prefijos como 'www.' si existen
        if domain.startswith("www."):
            domain = domain[4:]
        
        # Consultar WHOIS del dominio
        hostname = whois.whois(domain).domain_name
        # Si domain_name es una lista, buscar coincidencias en cada elemento
        if isinstance(hostname, list):
            for host in hostname:
                if re.search(host.lower(), domain):
                    return 1  # Coincidencia encontrada
            return 0  # Ninguna coincidencia encontrada
        else:
            # Verificar coincidencia directa si es un string
            if re.search(hostname.lower(), domain):
                return 1  # Coincidencia encontrada
            else:
                return 0  # Sin coincidencias
    except Exception as e:
        #print(f"Error al consultar WHOIS para '{domain}': {e}")
        return  0 # Considerar como no registrado en caso de error

def tld_in_subdomain(url):

    try:
        # Parsear la URL para obtener el hostname
        parsed_url = urlparse(url)
        hostname = parsed_url.hostname  # Ejemplo: 'www.com.example.com'

        if not hostname:
            #print(f"URL inválida: {url}")
            return 0

        # Dividir el hostname en partes
        parts = hostname.split('.')
        
        # Determinar el TLD y el subdominio
        if len(parts) > 2:  # Hay al menos un subdominio
            tld = parts[-1]  # Última parte como TLD
            subdomain = ".".join(parts[:-2])  # Todo antes del dominio principal y TLD
        else:  # No hay subdominio
            tld = parts[-1] if len(parts) > 1 else ""
            subdomain = ""

        # Verificar si el TLD aparece en el subdominio o coincide directamente
        if tld and subdomain and (tld in subdomain or subdomain == tld):
            return 1
        return 0

    except Exception as e:
        #print(f"Error en tld_in_subdomain para la URL '{url}': {e}")
        return 0  # Asumir 0 en caso de error

def prefix_suffix(url):
    if re.findall(r"https?://[^\-]+-[^\-]+/", url):
        return 1
    else:
        return 0
    

def extract_features_url_analyze(url):
    
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

    features['google_index'] = check_google_index(url) # Terminado

    features['nb_qm'] = count_nb_qm(url)

    features['nb_www'] = count_nb_www(url) # Terminado

    features['ratio_digits_host'] = ratio_digits_host(url)

    features['nb_hyperlinks'] = nb_hyperlinks(url)

    features['nb_hyphens'] = count_nb_hyphens(url)

    features['domain_in_title'] = domain_in_title(url)

    features['nb_dots'] = count_nb_dots(url)

    features['nb_eq'] = count_nb_eq(url)

    features['length_hostname'] = count_length_hostname(url)

    features['domain_age'] = get_domain_age(url)

    features['ratio_digits_url'] = ratio_digits_url(url)

    features['domain_with_copyright'] = domain_with_copyright(url)

    features['https_token'] = https_token(url)

    features['whois_registered_domain'] = whois_registered_domain(url)

    features['tld_in_subdomain'] = tld_in_subdomain(url)

    features['dns_record'] = dns_record(url)

    features['prefix_suffix'] = prefix_suffix(url)

    return features

