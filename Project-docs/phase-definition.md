# FlowWeaver — Phase Definition

## Propósito de este documento

Definir qué valida cada fase, qué no valida y qué errores de interpretación debe bloquear el enjambre.

## Fase 0a

### Qué valida
- comprensión del formato workspace
- utilidad de la agrupación visual
- claridad del contenedor de trabajo
- reacción inicial ante recursos agrupados y siguientes pasos

### Qué NO valida
- product-market fit
- hipótesis núcleo del puente móvil→desktop
- aprendizaje del sistema
- confianza progresiva
- fiabilidad de sync

### Riesgo de interpretación
Confundir entusiasmo por una demo retroactiva con validación del producto real.

### Workspace en esta fase
El workspace de 0a contiene Panel A y Panel C únicamente.
Panel B (resumen) no se construye en 0a ni en 0b.
Panel B entra en Fase 1 junto con el segundo caso de uso local.
Cualquier entregable de 0a que incluya Panel B debe bloquearse como contaminación de fase.

## Fase 0b

### Qué valida
- la hipótesis núcleo del producto
- que el puente móvil→desktop genere wow
- que la sync permita preparar el workspace a tiempo
- que el Episode Detector entregue valor real
- que el sistema respete privacidad y control mínimos

### Qué NO valida
- aprendizaje longitudinal
- automatización autónoma madura
- Pattern Detector
- Trust Scorer
- beta pública a escala

### Riesgo de interpretación
Aceptar un flujo técnicamente correcto pero sin impacto emocional suficiente.

### Workspace en esta fase
El workspace que el usuario encuentra al abrir desktop en 0b contiene Panel A y Panel C.
Panel B no se introduce en 0b.
La ausencia de Panel B no invalida el wow moment: el valor de 0b depende del puente móvil→desktop, no del resumen.
Panel B entra en Fase 1. Cualquier entregable de 0b que incluya Panel B debe bloquearse como contaminación de fase.

## Fase 0c

### Qué valida
- que el usuario encuentra valor en el móvil sin abrir el desktop
- que el móvil puede procesar y organizar sus propias capturas localmente
- que el sync bidireccional funciona con dos emisores sin pérdida ni duplicación
- que la galería de categorías es comprensible y útil para el usuario

### Qué NO valida
- workspace rico en móvil (el workspace narrativo sigue siendo patrimonio del desktop)
- aprendizaje longitudinal en móvil (Fase 2 desktop primero)
- automatización ni preparación silenciosa en móvil
- sincronización en tiempo real
- confianza progresiva ni State Machine en móvil

### Riesgo de interpretación
Confundir "cliente completo" con "paridad de funcionalidades con el desktop".
Fase 0c da al móvil su propia galería organizada — no replica el workspace
completo del desktop. El workspace rico (Panel B, Episode Detector, anticipación)
sigue siendo el valor diferencial del desktop.

### Workspace en esta fase
No hay workspace narrativo en el móvil. Hay una galería: categorías → recursos.
Tap en recurso → abre URL en navegador. Sin resumen, sin sugerencias, sin Panel B.

## Fase 1

### Qué valida
- viabilidad de un segundo caso de uso local
- reutilización del enfoque de detección sobre archivos

### Qué NO valida
- confianza longitudinal
- automatización avanzada

## Fase 2

### Qué valida
- aprendizaje longitudinal
- transición entre estados de confianza
- tolerancia del usuario a preparación silenciosa y automatización progresiva

### Qué NO valida
- escalado comercial definitivo

## Fase 3

### Qué valida
- comportamiento con usuarios beta reales
- métricas de valor, precisión y confianza
- calibración de umbrales

## Regla para el enjambre

Ningún agente puede describir una fase anterior usando lenguaje de validación propio de una fase posterior.