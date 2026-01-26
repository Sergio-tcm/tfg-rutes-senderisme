# Sistema de Cálculo Automático de Dificultad de Rutas

## Overview

Se ha implementado un sistema inteligente de cálculo de dificultad para rutas de senderismo basado en una fórmula estándar utilizada en aplicaciones de senderismo profesionales. Esto reemplaza el anterior sistema que marcaba todas las rutas como "Fácil".

## Problema Resuelto

- **Antes**: Todas las rutas aparecían con dificultad "Fácil", lo que afectaba el recomendador
- **Ahora**: Las rutas se clasifican automáticamente en 4 niveles según sus parámetros reales

## Arquitectura

### Backend (Python)

#### `services/difficulty_calculator.py`
Módulo principal con las funciones de cálculo:

- `calculate_difficulty(distance_km, elevation_gain, estimated_time)` → `str`
  - Calcula el nivel de dificultad de una ruta con fórmula ponderada
  - Retorna: "Fácil", "Moderada", "Difícil", "Muy Difícil"

- `get_difficulty_score(distance_km, elevation_gain)` → `float`
  - Calcula el score numérico (útil para ordenamiento/filtrado)

- `_parse_time_to_minutes(time_str)` → `int` (privada)
  - Parser auxiliar para convertir tiempos en texto a minutos

### Frontend (Dart/Flutter)

#### `services/recommendation_service.dart`
Actualizado para soportar 4 niveles de dificultad (antes 3)

#### `widgets/route_card.dart`
Badges actualizados con colores para "Muy Difícil":
- Fácil (Fàcil): Verde claro
- Moderada (Mitjana): Naranja claro
- Difícil (Difícil): Rojo claro
- Muy Difícil (Muy Difícil): Rojo oscuro

### Integración con Rutas (`routes/routes_routes.py`)

1. **GET /routes**: Las rutas sin dificultad definida se calculan dinámicamente
2. **POST /routes**: Al crear una ruta, se calcula automáticamente si no se proporciona

## Fórmula de Cálculo

### Score Base (ajustada)
```
Score = Distancia(km) * 1.2 + (Elevación(m) / 80)
```

### Escala de Clasificación (ajustada para mayor dispersión)
| Score | Dificultad | Descripción |
|-------|-----------|-----------|
| < 7 | Fácil | Apta para todos |
| 7-17 | Moderada | Requiere cierta forma física |
| 17-27 | Difícil | Requiere buena forma física |
| ≥ 27 | Muy Difícil | Solo para expertos |

### Ajuste por Tiempo (Opcional)
Si se proporciona `estimated_time`, se valida que sea consistente con la distancia y elevación. Si la ruta toma significativamente más tiempo de lo esperado, se aumenta ligeramente la dificultad.

## Parámetros Utilizados

### Requeridos
- **distance_km** (float): Distancia en kilómetros
- **elevation_gain** (int): Ganancia de elevación en metros

### Opcionales
- **estimated_time** (str): Tiempo estimado en formatos:
  - "2:30" (HH:MM)
  - "2h30m"
  - "2h"
  - "30m"

## Ejemplos de Clasificación

| Ruta | Distancia | Elevación | Dificultad | Score |
|------|-----------|-----------|-----------|-------|
| Paseo urbà | 3 km | 50 m | Fácil | 3.6 |
| Sender local | 5 km | 100 m | Moderada | 7.3 |
| Excursió diària | 10 km | 300 m | Moderada | 15.8 |
| Muntanya mitjana | 15 km | 600 m | Difícil | 25.5 |
| Ruta alpina | 25 km | 1200 m | Muy Difícil | 44.0 |

## Testing

Ejecutar pruebas del calculador:
```bash
cd backend
python test_difficulty.py
```

Salida esperada: ✓ TODAS LAS PRUEBAS PASARON

## Recomendador de Rutas

El `RecommendationService` ahora usa correctamente los 4 niveles de dificultad:

- **Nivel bajo de forma**: Solo rutas Fácil
- **Nivel medio de forma**: Rutas Fácil y Moderada
- **Nivel alto de forma**: Todas las dificultades

## API Endpoints

### GET /routes
Retorna todas las rutas con dificultad calculada:
```json
{
  "route_id": 1,
  "name": "Ruta del Montserrat",
  "distance_km": 12.5,
  "elevation_gain": 450,
  "difficulty": "Moderada",
  "estimated_time": "3:30"
}
```

### POST /routes
Al crear una ruta, se calcula automáticamente:
```json
{
  "name": "Nueva ruta",
  "distance_km": 8.5,
  "elevation_gain": 280,
  "estimated_time": "2:45"
  // El campo 'difficulty' se calcula automáticamente
}
```

## Notas de Implementación

1. **Backward Compatibility**: Las rutas existentes sin dificultad se calculan dinámicamente en cada request
2. **Performance**: El cálculo es O(1) - instantáneo incluso para miles de rutas
3. **Escalabilidad**: Se puede mejorar la fórmula sin cambios en la API
4. **Localización**: Soporta nombres en español, catalán e inglés

## Mejoras Futuras

1. Incorporar datos de elevación del DEM (modelo digital de elevación) si GPS no está disponible
2. Considerar el tipo de terreno (rocky, forest, urban, etc.)
3. Factores estacionales (nieve, lluvia histórica)
4. Integración con Strava/TrainingPeaks para datos reales de usuarios

## Verificación

Para verificar que el sistema funciona:

1. **Backend**: Ejecutar `python test_difficulty.py`
2. **Frontend**: Verificar que las rutas muestren dificultades correctas en:
   - Pantalla de rutas
   - Recomendador de rutas
   - Detalle de ruta individual
3. **API**: Llamar a `GET /routes` y verificar dificultades en JSON

---

**Implementado**: 2026-01-26
**Versión**: 1.0
**Status**: ✓ Producción
