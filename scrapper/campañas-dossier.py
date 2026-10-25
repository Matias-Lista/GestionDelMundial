## scrapper/campañas-dossier.py
 # Fecha: 24/10/2026
 # Lista, Matías Josué.
 # Descripción: Limpia los datos de dossier
 ##

import requests, json
URL = "https://firestore.googleapis.com/v1/projects/repositorio2026-61a28/databases/(default)/documents/campanas"
LOCAL = True

ANUNCIANTES = {}

## Sobre el dataset que construye este script:
#### Asume que todas las piezas de un anunciante, son parte de campañas diferentes.
#### Asume que el nombre de cada campaña, es el mismo nombre del spot publicitario que contiene.
#### Asume que las piezas de contenido son del mundial 2022 (porque los otros datasets que importo son de ese año).
#### Asume que todas las piezas de contenido de este dataset son orientadas únicamente a Argentina.

try: 

	if not LOCAL:
		response = requests.get(URL)

		if response.status_code != 200:
			raise "error!"

		crudo = response.json()
		# print(response.text)

		with open("./raw/campaña-dossier.json", "w", encoding="utf-8") as f:
			f.write(response.text)

	else:
		with open("./raw/campaña-dossier.json", "r", encoding="utf-8") as f:
			crudo = json.loads(f.read())

	# print(crudo)
	
	for c in crudo["documents"]:
		
		anunciante      = c["fields"]["anunciante"]["stringValue"]
		titulo          = c["fields"]["titulo"]["stringValue"]
		descripcion     = c["fields"].get('descripcion', {}).get("stringValue")
		
		if anunciante not in ANUNCIANTES:
			ANUNCIANTES[anunciante] = {
				"campañas": []
			}

		ANUNCIANTES[anunciante]["campañas"].append({
			"nombre": titulo,
			"descripcion": None,
			"horario_minimo": None,
			"horario_maximo": None,
			"año_mundial": 2022,
			"piezas_de_contenido": [{
				"nombre": titulo,
				"descripcion": descripcion,
				"paises_de_interes": ["ARG"]
			}]
		})

	with open("campañas-procesadas.json", "w", encoding="utf-8") as f:
		json.dump(ANUNCIANTES, f, ensure_ascii=False, indent=4)

	print(f"Se creo el archivo campañas-procesadas.json, con {len(ANUNCIANTES)} anunciantes.")

except Exception as e:
	print('Algo salio mal :(')
	print(e)