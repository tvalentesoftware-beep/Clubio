import Link from "next/link";
import { etiquetaDia, localDe } from "@/lib/semana";
import type { Cancha, CierreResumen, SerieDetalle, Slot, TurnoDetalle } from "@/lib/tipos";
import {
  BotonGenerarSerie,
  BotonQuitarCierre,
  FormAgendar,
  FormBloquear,
  FormCancelar,
  FormEditar,
} from "@/componentes/formularios-turno";

type Props = {
  semana: string;
  hoy: string;
  zonaHoraria: string;
  cancha: Cancha;
  slot: Slot;
  turno: TurnoDetalle | null;
  serie: SerieDetalle | null;
  cierre: CierreResumen | null;
  otraCancha: Cancha | null;
  precioSugerido: number | null;
};

// El panel que se abre al tocar una celda. Decide que mostrar segun el
// estado que la base le dio al slot; no calcula nada por su cuenta.
export function PanelSlot({ semana, hoy, zonaHoraria, cancha, slot, turno, serie, cierre, otraCancha, precioSugerido }: Props) {
  const { dia: fecha, hora } = localDe(slot.inicio, zonaHoraria);
  const { hora: horaFin } = localDe(slot.fin, zonaHoraria);
  const cerrar = `/turnos?semana=${semana}`;
  const ctx = { semana, canchaId: cancha.id, fecha, hora, duracionMin: cancha.deporte.duracion_min };

  return (
    <>
      <Link href={cerrar} aria-label="Cerrar" className="fixed inset-0 z-40 bg-slate-900/20" />
      <aside className="fixed inset-y-0 right-0 z-50 flex w-full max-w-md flex-col overflow-y-auto bg-white shadow-2xl">
        <header className="flex items-start gap-3 border-b border-slate-200 px-5 py-4">
          <div>
            <p className="text-xs uppercase tracking-wide text-slate-500">{cancha.deporte.nombre}</p>
            <h2 className="text-lg font-semibold">{cancha.nombre}</h2>
            <p className="text-sm text-slate-600">
              {etiquetaDia(fecha)} · {hora} a {horaFin}
            </p>
          </div>
          <Link href={cerrar} className="ml-auto rounded-md px-2 py-1 text-slate-500 hover:bg-slate-100" aria-label="Cerrar">
            ✕
          </Link>
        </header>

        <div className="space-y-6 px-5 py-5">
          {slot.estado === "libre" && (
            <>
              <section>
                <h3 className="mb-3 text-sm font-semibold text-slate-800">Agendar</h3>
                <FormAgendar ctx={ctx} precioSugerido={precioSugerido} />
              </section>
              <section className="border-t border-slate-100 pt-5">
                <h3 className="mb-3 text-sm font-semibold text-slate-800">Bloquear este horario</h3>
                <FormBloquear ctx={ctx} />
              </section>
            </>
          )}

          {slot.estado === "ocupado" && turno && (
            <>
              {otraCancha && (
                <p className="rounded-lg border border-dashed border-slate-400 bg-slate-50 px-3 py-2 text-sm text-slate-600">
                  Este horario no está disponible porque <b>{otraCancha.nombre}</b> ocupa el mismo espacio.
                  Lo que sigue es esa reserva.
                </p>
              )}
              <section>
                <h3 className="mb-1 text-sm font-semibold text-slate-800">
                  {turno.cliente.nombre}
                  <span className="ml-2 rounded bg-slate-100 px-1.5 py-0.5 text-xs font-normal text-slate-600">{turno.tipo}</span>
                </h3>
                <p className="text-sm text-slate-600">{turno.cliente.telefono}</p>
                <p className="mt-1 text-sm text-slate-600">
                  {localDe(turno.inicio, zonaHoraria).hora} a {localDe(turno.fin, zonaHoraria).hora} ·{" "}
                  <b>${Number(turno.precio).toLocaleString("es-AR")}</b>
                </p>
                {turno.serie_id && (
                  <p className="mt-1 text-xs text-slate-500">Generado por un {turno.tipo}: cancelar solo afecta este día.</p>
                )}
              </section>
              <section className="border-t border-slate-100 pt-5">
                <h3 className="mb-3 text-sm font-semibold text-slate-800">Editar</h3>
                <FormEditar turno={turno} semana={semana} />
              </section>
              <FormCancelar turnoId={turno.id} semana={semana} />
            </>
          )}

          {slot.estado === "serie" && serie && (
            <section className="space-y-3">
              <div className="rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 text-sm text-amber-900">
                <b>{serie.cliente.nombre}</b> tiene un {serie.tipo} acá, los {etiquetaDia(fecha).slice(0, 3)} a las{" "}
                {serie.hora_inicio.slice(0, 5)}, desde el {serie.vigente_desde}. Los turnos de las próximas semanas
                todavía no se generaron: el horario está reservado igual.
              </div>
              <p className="text-sm text-slate-600">{serie.cliente.telefono}</p>
              <BotonGenerarSerie serieId={serie.id} desde={hoy} semana={semana} />
            </section>
          )}

          {slot.estado === "cerrado" && cierre && (
            <section className="space-y-3">
              <div className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-800">
                Cerrado: <b>{cierre.motivo}</b>
              </div>
              <BotonQuitarCierre cierreId={cierre.id} semana={semana} />
            </section>
          )}
        </div>
      </aside>
    </>
  );
}
