# Semana 7 - Consumo de API rest

## Equipo e Integrantes

- **Equipo:** #11
- Roberto Morán
- Óscar Pleités
- Diego Arévalo
- Roberto Polanco
- Christopher Marroquín
- Angie Guzmán

## Acerca de

Este proyecto contiene un formulario en Flutter con 2 campos, aplicando validación cruzada (ambos campos deben coincidir) y una longitud mínima de 3 caracteres y consume la API de OMDb para mostrar un listado de películas.

### Funcionalidades
- Validación en tiempo real con mensajes de error en español.
- Búsqueda de películas con la API de OMDb usando el paquete `http`.
- Listado con póster y título, con scroll infinito (carga más páginas al bajar).
- Manejo de errores (API key inválida, límite de consultas, sin conexión) con opción de reintentar.
- Soporte para tema claro y oscuro.

## Cómo ejecutarlo
La API key de OMDb se pasa como variable al ejecutar:

flutter run --dart-define=OMDB_API_KEY=tu_api_key

## Uso de IA

Durante la actividad se utilizó inteligencia artificial como herramienta de apoyo en cuatro aspectos. Primero, para diseñar un formulario siguiendo el estandar de Material 3 usando stitch, con iconos, decoraciones y un tema visual. Segundo, para consultar el funcionamiento de la API y cómo poder consumirla. Tercero, como ayuda para el debug y resolución de errores. Por último, como apoyo en la redacción de este README. En todos los casos, el resultado fue revisado y ajustado por el equipo. 
