# Decisiones de arquitectura

Una decisión por archivo, en el orden en que se tomaron. Cada una dice qué se
descartó y por qué, y qué se paga por haber elegido lo que se eligió.

El formato está en [plantilla.md](plantilla.md). La sección de **costo
asumido** es obligatoria: una decisión sin costo no era una decisión, era una
obviedad.

| # | Decisión | En una línea |
|---|---|---|
| [0001](0001-multi-tenant-modelo-pool.md) | Multi-club en un solo esquema | `club_id` + RLS + claves foráneas compuestas, en vez de una base por club |
| [0002](0002-agenda-sin-grilla-pregenerada.md) | Disponibilidad calculada | La reserva se inserta al reservar; no hay grilla pre-generada que se termine |
| [0003](0003-espacios-compartidos.md) | Canchas hechas de espacios | La restricción de exclusión impide vender dos veces el mismo piso |
| [0004](0004-fijos-como-serie.md) | El fijo es una regla | Serie con horizonte rodante, en vez de copiar cincuenta filas al tildar |
| [0005](0005-precios-con-vigencia.md) | Tarifas con vigencia | El turno congela su precio: el pasado no cambia cuando el club aumenta |
| [0006](0006-identidad-del-cliente.md) | Teléfono sin ser clave primaria | Es la clave del negocio, no la técnica: cambiar de número es editar un campo |
| [0007](0007-historia-en-eventos.md) | Cancelar no borra | Estado y bitácora; los contadores por cliente se calculan, no se guardan |
| [0008](0008-stack.md) | Next.js sobre Supabase | El stack sale de lo que las decisiones anteriores le exigen a la base |

Casi todas se apoyan en el mismo material: lo que pasó operando el sistema
anterior, documentado en [../05-caso-punto-country.md](../05-caso-punto-country.md).
