# FlowWeaver — Agent Activation Matrix

Genera en este documento una matriz completa por fases con columnas:

- Agent
- 0a
- 0b
- 1
- 2
- 3
- V1/V2+
- Notes

## Estados permitidos

- ACTIVE
- LISTENING
- LOCKED
- ARCHIVAL

## Requisitos obligatorios

La matriz debe:
- reflejar exactamente la activación definida por el sistema operativo del enjambre
- indicar qué agentes existen desde el principio aunque permanezcan LOCKED
- explicar qué significa cada estado
- explicar qué permisos operativos tiene cada estado
- explicar qué errores comunes ocurren al activar agentes demasiado pronto
- explicar por qué algunos agentes existen desde el inicio pero no lideran trabajo aún

## Regla central

La activación de agentes debe responder a la lógica del desarrollo del producto,
pero sin convertir este repositorio en la implementación del producto.