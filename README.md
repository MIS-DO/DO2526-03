# DO2526-03 — API de Búsqueda Integrada

API de búsqueda unificada que integra las tres APIs individuales del grupo y permite buscar canciones, películas y equipos de fútbol filtrando por año.

---

## Arquitectura

El sistema está compuesto por **7 contenedores Docker** orquestados con Docker Compose:

| Servicio | Imagen | Puerto | Descripción |
|---|---|---|---|
| `search-api` | build local | `3000` | **API de búsqueda** (este repositorio) |
| `songs-api` | `danvelcam621/songs-api:latest` | `3001` | API individual de canciones |
| `movies-api` | `migencmar/moviesapi:latest` | `3002` | API individual de películas |
| `football-api` | `jorgeflorentino8/footballteamapi:latest` | `3003` | API individual de equipos de fútbol |
| `songs-mongo` | `mongo` | — | Base de datos de songs-api |
| `movies-mongo` | `mongo` | — | Base de datos de movies-api |
| `football-mongo` | `mongo` | — | Base de datos de football-api |

La `search-api` no tiene base de datos propia: llama a las otras tres APIs en paralelo, filtra los resultados por año y los devuelve combinados en una única respuesta.

```
Cliente → search-api:3000 ──┬──▶ songs-api:3001   ──▶ songs-mongo
                             ├──▶ movies-api:3002  ──▶ movies-mongo
                             └──▶ football-api:3003 ──▶ football-mongo
```

---

## Despliegue

### Requisitos
- [Docker](https://docs.docker.com/get-docker/) y Docker Compose instalados

### Arrancar todo el sistema

```bash
docker compose up --build
```

Esto descarga las imágenes de Docker Hub de las tres APIs individuales, construye la `search-api` y levanta todos los servicios.

### Parar el sistema

```bash
docker compose down
```

---

## Endpoint de búsqueda

### `GET /api/v1/search`

Busca en las tres APIs filtrando por año. Al menos uno de los parámetros debe estar presente.

#### Parámetros de query

| Parámetro | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `year` | integer | Año exacto | `?year=2010` |
| `minYear` | integer | Año mínimo (inclusive) | `?minYear=2000` |
| `maxYear` | integer | Año máximo (inclusive) | `?maxYear=2005` |

Los parámetros `minYear` y `maxYear` pueden combinarse para definir un rango.

#### Ejemplos

```bash
# Año exacto
curl "http://localhost:3000/api/v1/search?year=2010"

# Rango de años
curl "http://localhost:3000/api/v1/search?minYear=2000&maxYear=2015"

# Desde un año en adelante
curl "http://localhost:3000/api/v1/search?minYear=2010"

# Hasta un año concreto
curl "http://localhost:3000/api/v1/search?maxYear=1999"
```

#### Respuesta (200 OK)

```json
{
  "songs": [
    {
      "id": "2",
      "title": "Black Hole Sun",
      "artist": "Soundgarden",
      "releaseYear": 1994,
      "durationSeconds": 320,
      "isExplicit": false
    }
  ],
  "movies": [
    {
      "title": "The Fighter",
      "director": "David Fincher",
      "release_year": 2010,
      "duration_minutes": 120,
      "is_available": true
    }
  ],
  "footballTeams": [
    {
      "name": "Real Madrid CF",
      "foundationDate": "1902-03-06",
      "stadiumCapacity": 81044,
      "hasWonChampionsLeague": true,
      "mainSponsors": ["Adidas", "Emirates"]
    }
  ]
}
```

> **Nota:** Si una de las APIs individuales no está disponible, su array correspondiente aparece vacío (`[]`) sin romper la búsqueda.

---

## Documentación interactiva (Swagger UI)

Una vez levantado el sistema, la documentación interactiva de cada API está disponible en:

| API | Swagger UI |
|---|---|
| **Search API** | http://localhost:3000/docs |
| Songs API | http://localhost:3001/docs |
| Movies API | http://localhost:3002/docs |
| Football API | http://localhost:3003/docs |

---

## Estructura del repositorio

```
DO2526-03/
├── docker-compose.yml          # Orquestación de todos los servicios
└── search-api/
    ├── api/
    │   └── oas-doc.yaml        # Especificación OpenAPI del endpoint de búsqueda
    ├── controllers/
    │   └── apiv1searchController.js  # Lógica de aggregación y filtrado
    ├── index.js                # Arranque del servidor (OAS-Tools + Express)
    ├── package.json
    ├── .oastoolsrc             # Configuración de OAS-Tools
    └── Dockerfile
```
