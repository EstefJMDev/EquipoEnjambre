# FlowWeaver - Architecture Overview

## Proposito

Describir la arquitectura conceptual del producto solo en el nivel necesario
para gobernar fases, limites y ownership multiagente.
Este documento no autoriza implementacion funcional dentro de este repo.

## Principios

* arquitectura por fases, no "construir todo el futuro ahora"
* separacion estricta entre captura, preparacion, sync y aprendizaje
* desktop MVP sin observacion activa
* Privacy Level 1 por defecto
* fallbacks compatibles antes que redisenio estructural

## Capas Conceptuales

| Capa | Funcion | Primer uso | Restricciones |
| --- | --- | --- | --- |
| Bootstrap Import Layer | Importacion local retroactiva para demos 0a. | 0a | Solo bootstrap; no es observer ni caso nucleo. |
| Capture Layer | Recibe seniales explicitas del usuario. | 0b con Share Extension iOS | En MVP el unico observer activo es Share Extension iOS. |
| Session Layer | Agrupa seniales en una sesion interpretable. | 0b | No sustituye aprendizaje longitudinal. |
| Detection Layer | Decide si hay un episodio accionable. | 0b | Pattern Detector y Trust quedan fuera hasta Fase 2. |
| Workspace Layer | Prepara el contenedor de trabajo. | 0a | Esto es lo que valida 0a. |
| Sync Layer | Mueve la senial entre dispositivos. | 0b | Solo relay cifrado; no backend propia. QR fallback permitido. |
| Privacy And Control Layer | Expone almacenamiento, control y borrado. | minimo en 0b, completo en Fase 2 | No debe prometer mas de lo defendible. |
| Longitudinal Intelligence Layer | Aprende habitos y gobierna confianza progresiva. | Fase 2 | No puede contaminar MVP. |

## Lectura Por Fase

### 0a

* objetivo: validar el valor del contenedor workspace
* arquitectura activa: Bootstrap Import Layer mas Workspace Layer
* arquitectura prohibida: Share Extension, sync real, Episode Detector real,
  Pattern Detector, Trust, backend propia

### 0b

* objetivo: validar el puente movil -> desktop
* arquitectura activa: Share Extension iOS, Session Layer, Episode Detector
  dual-mode, Sync Layer MVP, Privacy Dashboard minimo
* arquitectura prohibida: observer activo desktop, FS Watcher, backend propia,
  aprendizaje longitudinal

### 1

* objetivo: aniadir un segundo caso de uso local con archivos
* arquitectura activa adicional: FS Watcher y adaptacion del detector a archivos
* arquitectura prohibida: Pattern Detector parcial "para ahorrar despues"

### 2

* objetivo: aprendizaje longitudinal y confianza progresiva
* arquitectura activa adicional: Pattern Detector, Trust Scorer, State Machine,
  Explainability Log, dashboard completo

### 3

* objetivo: beta y calibracion
* arquitectura activa: capas previamente aceptadas mas medicion y ajuste
* restriccion: el LLM local sigue siendo opcional

## Regla

Los agentes tecnicos usan este documento para describir limites y contratos,
nunca para justificar codigo del producto en este repositorio.
