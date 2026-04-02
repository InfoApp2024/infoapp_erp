# Guía Funcional: Workflow Inteligente (InfoApp)

Este documento detalla el funcionamiento del sistema de estados y transiciones, tanto en su configuración como en su aplicación práctica en el módulo de servicios.

---

## 🏗️ 1. Configuración de Estados

En el panel de **Estados y Transiciones**, puedes gestionar cómo fluye un servicio.

### A. Tipos de Estados
*   **Estados Oficiales (Protegidos)**: El sistema identifica exactamente 7 estados base (Abierto, Programado, Asignado, En Ejecución, Finalizado, Cerrado y Cancelado). Estos **no pueden borrarse** para garantizar que el sistema siempre funcione.
*   **Estados de Usuario**: Puedes crear infinitos estados adicionales (ej: "En Espera de Repuestos", "Revisión Especial"). Estos sí se pueden borrar siempre que no tengan servicios asociados.

### B. Propiedades Clave
*   **Estado Base**: Define la "naturaleza" del estado ante el sistema. 
    *   *Ejemplo*: Si un estado se llama "Iniciado" y su base es `ABIERTO`, el sistema lo tratará como el punto de inicio.
*   **Estado Final**: Indica que el servicio ha concluido su ciclo de vida. Al entrar en este estado, el servicio se marca como "Finalizado" en los reportes.
*   **Bloquea Cierre**: Es un "muro preventivo". Si un servicio está en un estado con esta opción activa, el sistema **impedirá** que pase a cualquier "Estado Final". 
    *   *Uso común*: "Esperando Repuestos", "Pendiente de Aprobación".

---

## ⚡ 2. Transiciones y Automatización

Las transiciones son las "flechas" que conectan los estados.

*   **Flujo Manual**: Define qué botones verá el técnico. Si no hay una flecha entre "Abierto" y "Cerrado", el técnico no podrá saltarse los pasos intermedios.
*   **Disparadores (Triggers)**: Permiten que el sistema cambie el estado automáticamente tras una acción.
    *   **Firma Digital**: Al capturar la firma del cliente, el servicio puede saltar automáticamente a "Finalizado".
    *   **Captura de Fotos**: Al tomar las fotos de evidencia, el servicio puede saltar a "Atendido".

---

## 📱 3. Aplicación en el Módulo de Servicios

Así es como el técnico y el administrador experimentan el workflow:

### A. Botones de "Siguiente Paso"
En el formulario del servicio, el técnico no tiene que adivinar. El sistema lee las **Transiciones** configuradas y muestra botones claros con el nombre del siguiente estado.

### B. Reglas de Integridad
*   **Validación de Cierre**: Si el técnico intenta finalizar un servicio pero el estado actual tiene "Bloquea Cierre" activo, verá un mensaje de advertencia y el cambio será rechazado.
*   **Protección de Datos**: No se puede eliminar un estado del panel de configuración si existen servicios (activos o históricos) que estén usando ese estado. El sistema te informará cuántos registros están bloqueando la eliminación.

---

## 🔧 4. Mantenimiento y Orden
Para mantener el sistema limpio, se recomienda:
1.  **Mapear correctamente**: Asegurar que cada estado tenga asignado el **Estado Base** correcto.
2.  **Evitar duplicados**: Usar la herramienta de limpieza si aparecen estados con el mismo nombre.
3.  **Diagramar con lógica**: Asegurarse de que todos los caminos lleven eventualmente a un estado marcado como **Final**.
