"use client";

import { useActionState } from "react";
import { agendar, bloquear, cancelar, editar, generarSerie, quitarCierre, type Estado } from "@/app/(panel)/turnos/acciones";
import type { FilaMaterializacion, TurnoDetalle } from "@/lib/tipos";

// Los formularios del panel lateral. Son componentes de cliente solo para
// mostrar el error o el aviso que devuelve la accion; la logica esta en
// las acciones y en la base.

const input =
  "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100";
const etiqueta = "block text-xs font-medium text-slate-600";
const primario =
  "rounded-lg px-4 py-2 text-sm font-medium text-white disabled:opacity-50";
const secundario =
  "rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50";

function Error_({ estado }: { estado: Estado }) {
  if (!estado?.error) return null;
  return <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.error}</p>;
}

type Contexto = {
  semana: string;
  canchaId: string;
  fecha: string;
  hora: string;
  duracionMin: number;
};

function Ocultos({ ctx }: { ctx: Contexto }) {
  return (
    <>
      <input type="hidden" name="semana" value={ctx.semana} />
      <input type="hidden" name="cancha_id" value={ctx.canchaId} />
      <input type="hidden" name="fecha" value={ctx.fecha} />
      <input type="hidden" name="hora" value={ctx.hora} />
      <input type="hidden" name="duracion_min" value={ctx.duracionMin} />
    </>
  );
}

// ---------------------------------------------------------------------------

export function FormAgendar({ ctx, precioSugerido }: { ctx: Contexto; precioSugerido: number | null }) {
  const [estado, accion, pendiente] = useActionState(agendar, null);
  const v = estado?.valores ?? {};

  return (
    <form action={accion} className="space-y-3">
      <Ocultos ctx={ctx} />

      <label className={etiqueta}>
        Nombre completo
        <input name="nombre" required autoFocus defaultValue={v.nombre} className={input} />
      </label>

      <label className={etiqueta}>
        Teléfono
        <input name="telefono" required inputMode="tel" placeholder="342 555 0101" defaultValue={v.telefono} className={input} />
      </label>

      <div className="grid grid-cols-2 gap-3">
        <label className={etiqueta}>
          Tipo
          {/* key: un select solo toma defaultValue al montarse; si la accion
              devuelve otro valor hay que remontarlo o "Crear igual" mandaria
              el tipo equivocado */}
          <select key={v.tipo ?? "normal"} name="tipo" defaultValue={v.tipo ?? "normal"} className={input}>
            <option value="normal">Normal</option>
            <option value="fijo">Fijo (todas las semanas)</option>
            <option value="clase">Clase (todas las semanas)</option>
          </select>
        </label>
        <label className={etiqueta}>
          Precio
          <input name="precio" required inputMode="decimal" defaultValue={v.precio ?? precioSugerido ?? ""} className={input} />
        </label>
      </div>

      <label className={etiqueta}>
        Notas
        <input name="notas" defaultValue={v.notas} className={input} />
      </label>

      <Error_ estado={estado} />

      {estado?.aviso ? (
        <Aviso filas={estado.aviso} pendiente={pendiente} />
      ) : (
        <button disabled={pendiente} className={primario} style={{ background: "var(--marca)" }}>
          {pendiente ? "Guardando…" : "Agendar"}
        </button>
      )}
    </form>
  );
}

const TEXTO_RESULTADO: Record<string, string> = {
  a_crear: "se va a crear",
  creado: "creado",
  ya_existia: "ya existía",
  conflicto: "ocupado",
  conflicto_serie: "choca con otro fijo",
  cerrado: "cerrado",
  fuera_de_horario: "fuera del horario",
  sin_tarifa: "sin tarifa",
};

// La simulacion de fn_crear_serie: que dias se crearian y cuales no, y por
// que. El boton reenvia el mismo formulario con confirmar=1.
function Aviso({ filas, pendiente }: { filas: FilaMaterializacion[]; pendiente: boolean }) {
  const problemas = filas.filter((f) => f.resultado !== "a_crear");
  return (
    <div className="space-y-3 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm text-amber-900">
      <p className="font-medium">
        {problemas.length === 1 ? "Hay un día que no se puede generar:" : `Hay ${problemas.length} días que no se pueden generar:`}
      </p>
      <ul className="space-y-1 text-xs">
        {problemas.map((f) => (
          <li key={f.fecha}>
            <b>{f.fecha}</b> — {TEXTO_RESULTADO[f.resultado] ?? f.resultado}
            {f.detalle ? `: ${f.detalle}` : ""}
          </li>
        ))}
      </ul>
      <p className="text-xs">
        Los otros {filas.length - problemas.length} sí. Si seguís, esos días quedan sin turno y el resto se genera.
      </p>
      <input type="hidden" name="confirmar" value="1" />
      <button disabled={pendiente} className={primario} style={{ background: "var(--marca)" }}>
        {pendiente ? "Guardando…" : "Crear igual"}
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------

export function FormBloquear({ ctx }: { ctx: Contexto }) {
  const [estado, accion, pendiente] = useActionState(bloquear, null);
  const v = estado?.valores ?? {};

  return (
    <form action={accion} className="space-y-3">
      <Ocultos ctx={ctx} />
      <label className={etiqueta}>
        Motivo
        <input name="motivo" required placeholder="Lluvia, mantenimiento, evento…" defaultValue={v.motivo} className={input} />
      </label>
      <label className="flex items-center gap-2 text-sm text-slate-700">
        <input type="checkbox" name="todo_el_dia" value="1" defaultChecked={v.todo_el_dia === "1"} /> Todo el día
      </label>
      <label className="flex items-center gap-2 text-sm text-slate-700">
        <input type="checkbox" name="todo_el_club" value="1" defaultChecked={v.todo_el_club === "1"} /> Todas las canchas
      </label>
      <Error_ estado={estado} />
      <button disabled={pendiente} className={secundario}>
        {pendiente ? "Guardando…" : "Bloquear"}
      </button>
    </form>
  );
}

// ---------------------------------------------------------------------------

export function FormEditar({ turno, semana }: { turno: TurnoDetalle; semana: string }) {
  const [estado, accion, pendiente] = useActionState(editar, null);
  const v = estado?.valores ?? {};

  return (
    <form action={accion} className="space-y-3">
      <input type="hidden" name="semana" value={semana} />
      <input type="hidden" name="turno_id" value={turno.id} />
      <input type="hidden" name="cliente_id" value={turno.cliente.id} />

      <label className={etiqueta}>
        Nombre
        <input name="nombre" required defaultValue={v.nombre ?? turno.cliente.nombre} className={input} />
      </label>
      <label className={etiqueta}>
        Teléfono
        <input name="telefono" required defaultValue={v.telefono ?? turno.cliente.telefono} className={input} />
      </label>
      <label className={etiqueta}>
        Precio
        <input name="precio" required inputMode="decimal" defaultValue={v.precio ?? turno.precio} className={input} />
      </label>
      <label className={etiqueta}>
        Notas
        <input name="notas" defaultValue={v.notas ?? turno.notas ?? ""} className={input} />
      </label>

      <Error_ estado={estado} />
      <button disabled={pendiente} className={secundario}>
        {pendiente ? "Guardando…" : "Guardar cambios"}
      </button>
    </form>
  );
}

export function FormCancelar({ turnoId, semana }: { turnoId: string; semana: string }) {
  const [estado, accion, pendiente] = useActionState(cancelar, null);

  return (
    <form action={accion} className="space-y-3 rounded-lg border border-red-200 bg-red-50/50 p-3">
      <input type="hidden" name="semana" value={semana} />
      <input type="hidden" name="turno_id" value={turnoId} />
      <p className="text-sm font-medium text-slate-800">Cancelar este turno</p>
      <p className="text-xs text-slate-600">
        El horario queda libre. El turno no se borra: queda registrado quién lo canceló.
      </p>
      <div className="flex gap-4 text-sm text-slate-700">
        <label className="flex items-center gap-1.5">
          <input type="radio" name="cancelado_por" value="cliente" required /> Canceló el cliente
        </label>
        <label className="flex items-center gap-1.5">
          <input type="radio" name="cancelado_por" value="club" /> Canceló el club
        </label>
      </div>
      <Error_ estado={estado} />
      <button disabled={pendiente} className="rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50">
        {pendiente ? "Cancelando…" : "Cancelar turno"}
      </button>
    </form>
  );
}

// ---------------------------------------------------------------------------

export function BotonQuitarCierre({ cierreId, semana }: { cierreId: string; semana: string }) {
  const [estado, accion, pendiente] = useActionState(quitarCierre, null);
  return (
    <form action={accion} className="space-y-2">
      <input type="hidden" name="semana" value={semana} />
      <input type="hidden" name="cierre_id" value={cierreId} />
      <Error_ estado={estado} />
      <button disabled={pendiente} className={secundario}>
        {pendiente ? "Quitando…" : "Quitar el cierre"}
      </button>
    </form>
  );
}

export function BotonGenerarSerie({ serieId, desde, semana }: { serieId: string; desde: string; semana: string }) {
  const [estado, accion, pendiente] = useActionState(generarSerie, null);
  return (
    <form action={accion} className="space-y-2">
      <input type="hidden" name="semana" value={semana} />
      <input type="hidden" name="serie_id" value={serieId} />
      <input type="hidden" name="desde" value={desde} />
      <Error_ estado={estado} />
      <button disabled={pendiente} className={primario} style={{ background: "var(--marca)" }}>
        {pendiente ? "Generando…" : "Generar los próximos turnos"}
      </button>
    </form>
  );
}
