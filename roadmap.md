# Roadmap

Este documento describe los problemas identificados que motivan la evolución del ecosistema
de herramientas y procesos de desarrollo. Cada pain point representa una fricción real que
impacta la velocidad, la calidad o la comunicación entre equipos.

---

## Pain 2 — Única fuente de verdad para los contratos

**Problema:** Los contratos entre frontend y backend (modelos de datos, endpoints, respuestas
esperadas) están definidos en múltiples lugares: documentación manual, código de frontend,
código de backend, y tests de cada equipo por separado. Cuando un contrato cambia, cada
representación debe actualizarse de forma independiente, lo que genera inconsistencias y
una red de seguridad falsa.

**Objetivo:** Establecer una única fuente de verdad para los contratos, compartida y
consumida por todos los equipos, de modo que cualquier cambio sea propagado automáticamente
y detectado antes de llegar a producción.

---

## Pain 3 — Adaptación manual del código ante cambios de contrato

**Problema:** Cuando un contrato cambia, los equipos deben identificar manualmente todos
los puntos del código afectados y actualizarlos. Este proceso es propenso a errores,
consume tiempo de desarrollo y no escala con la complejidad del sistema.

**Objetivo:** Apoyarse en herramientas que automaticen la propagación de cambios de
contrato (generación de código, validación estática, pipelines de contrato) para que el
esfuerzo manual se reduzca al mínimo y los errores sean detectados por la máquina, no por
el desarrollador.

---

## Pain 4 — Comunicación reactiva entre equipos

**Problema:** Los equipos se enteran de los cambios disruptivos de otros equipos de forma
reactiva: cuando algo falla en CI, en staging o en producción. No existe un mecanismo
proactivo que obligue a comunicar los cambios de contrato antes de que impacten a otros.

**Objetivo:** Implementar procesos y herramientas que hagan que la comunicación entre
equipos sea un efecto natural del flujo de trabajo (e.g., un PR de backend que rompe tests
de frontend bloquea el merge y notifica al equipo afectado), eliminando la dependencia de
la comunicación informal.

---

## Pain 5 — Falta de procesos multidisciplinarios para el desarrollo de features

**Problema:** Las features se desarrollan en silos: negocio define requerimientos, QA
valida al final, frontend y backend implementan en paralelo sin sincronización temprana.
Los problemas de integración, los malentendidos de negocio y los bugs de contrato se
descubren tarde, cuando el costo de corrección es mayor.

**Objetivo:** Establecer un proceso conjunto en el que negocio, QA, frontend y backend
aborden cada feature desde el inicio: definiendo el contrato, los criterios de aceptación
y los casos de prueba antes de escribir una línea de código de producción.

---

## Pain 6 — Historias de usuario verbosas y difíciles de consumir

**Problema:** Las HUs actuales contienen información redundante, ambigua o incompleta que
dificulta su desarrollo. Los equipos pierden tiempo interpretando requerimientos en lugar
de implementarlos.

**Objetivo:** Estandarizar las HUs a un formato mínimo y suficiente que incluya exactamente
lo necesario para el desarrollo:

- **Contrato:** qué datos se envían y se reciben (request/response)
- **Figma:** enlace directo al diseño de la pantalla o componente
- **Flujo:** descripción del camino feliz y los casos de error
- **Ejemplo:** un caso concreto con datos reales que ilustre el comportamiento esperado

---

## Pain 7 — Alucinaciones de la IA por falta de contexto compartido

**Problema:** Los proyectos carecen de un PRD (Product Requirements Document) conjunto que
defina el alcance, la lógica de negocio y las reglas del dominio. Cuando los equipos usan
herramientas de IA para generar código o documentación, la IA opera sin contexto suficiente
y produce resultados incorrectos o inconsistentes con el producto real.

**Objetivo:** Crear y mantener un PRD vivo por proyecto que centralice el alcance, la
lógica de negocio, los flujos principales y las decisiones de arquitectura. Este documento
actúa como contexto base para las herramientas de IA y como referencia única para todos
los equipos, reduciendo las alucinaciones y los malentendidos.