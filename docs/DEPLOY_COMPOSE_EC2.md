# Deploy de Producción con Nginx Reverse Proxy (Docker Compose)

Este despliegue publica un único punto de entrada HTTP (`nginx`) y mantiene privadas las APIs internas (`search-api`, `songs-api`, `movies-api`, `football-api`) dentro de la red Docker `group-network`.
MongoDB tampoco publica puertos al host: solo es accesible desde la red interna de Docker.

## Arranque

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

El gateway `nginx` publica `80/tcp` y enruta por prefijos a los servicios internos.
Los backends y MongoDB no usan `ports:` en este despliegue.

## Parada

```bash
docker compose -f docker-compose.prod.yml down
```

## Puertos expuestos

- Expuesto al host: solo `80:80` (servicio `nginx`).
- Variante local opcional: sustituir temporalmente `80:80` por `8080:80` en `docker-compose.prod.yml`.
- No se exponen `3000`, `3001`, `3002`, `3003` ni puertos de MongoDB.

## Routing publicado por Nginx

### Rutas principales con prefijo

- `GET /healthz` -> responde `200 ok`
- `/search/` -> `search-api`
- `/songs/` -> `songs-api`
- `/movies/` -> `movies-api`
- `/football/` -> `football-api`

### URLs finales de uso

- Search Swagger: `http://localhost/search/docs`
- Songs Swagger: `http://localhost/songs/docs`
- Movies Swagger: `http://localhost/movies/docs`
- Football Swagger: `http://localhost/football/docs`
- Endpoint unificado: `http://localhost/search/api/v1/search`

Nota: las rutas `/search/docs`, `/songs/docs`, `/movies/docs` y `/football/docs` pueden responder con `301` hacia la URL equivalente con slash final (`/docs/`).

### Compatibility routes públicas

Se mantienen rutas adicionales en raíz para que Swagger UI "Try it out" siga funcionando cuando los upstream OpenAPI no publican `servers` con el prefijo del reverse proxy.

- `http://localhost/api/v1/search`
- `http://localhost/api/v1/songs`
- `http://localhost/api/v1/movies`
- `http://localhost/api/v1/footballteams`

Estas rutas también son públicas a través de Nginx. No exponen puertos nuevos, pero sí amplían las rutas HTTP disponibles en el gateway.

## URLs de prueba

### Local

- Healthcheck Nginx: `http://localhost/healthz`
- Search Swagger: `http://localhost/search/docs`
- Songs Swagger: `http://localhost/songs/docs`
- Movies Swagger: `http://localhost/movies/docs`
- Football Swagger: `http://localhost/football/docs`
- Endpoint principal: `http://localhost/search/api/v1/search`
- Compatibility route Search: `http://localhost/api/v1/search`
- Compatibility route Songs: `http://localhost/api/v1/songs`
- Compatibility route Movies: `http://localhost/api/v1/movies`
- Compatibility route Football: `http://localhost/api/v1/footballteams`

### EC2 (IP pública)

- Healthcheck Nginx: `http://<IP_PUBLICA_EC2>/healthz`
- Search Swagger: `http://<IP_PUBLICA_EC2>/search/docs`
- Songs Swagger: `http://<IP_PUBLICA_EC2>/songs/docs`
- Movies Swagger: `http://<IP_PUBLICA_EC2>/movies/docs`
- Football Swagger: `http://<IP_PUBLICA_EC2>/football/docs`
- Endpoint principal: `http://<IP_PUBLICA_EC2>/search/api/v1/search`
- Compatibility route Search: `http://<IP_PUBLICA_EC2>/api/v1/search`
- Compatibility route Songs: `http://<IP_PUBLICA_EC2>/api/v1/songs`
- Compatibility route Movies: `http://<IP_PUBLICA_EC2>/api/v1/movies`
- Compatibility route Football: `http://<IP_PUBLICA_EC2>/api/v1/footballteams`

## Por qué no se exponen los puertos 3000–3003 en producción

- Reduce superficie de ataque: solo Nginx recibe tráfico externo.
- Centraliza políticas de entrada (timeouts, tamaño de payload, headers reenviados).
- Evita acceso directo a microservicios internos.
- Facilita observabilidad y control en un único gateway.

## Operación

- `docker compose -f docker-compose.prod.yml up -d --build` recrea los servicios necesarios.
- `nginx` depende de los backends con `depends_on` en sintaxis larga y `restart: true` para acompañar recreaciones hechas por Compose.
- Si recreas un backend manualmente fuera de ese flujo, fuerza también el reciclado del gateway:

```bash
docker compose -f docker-compose.prod.yml restart nginx
```

## Security Group mínimo para EC2

- Inbound `80/tcp`: público (`0.0.0.0/0`; `::/0` si aplica IPv6).
- Inbound `22/tcp`: restringido a tu IP administrativa o, preferiblemente, usar AWS SSM Session Manager.
- No abrir `3000-3003` ni `27017`.
