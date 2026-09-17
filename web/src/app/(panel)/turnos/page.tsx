import Link from "next/link";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { diasDeSemana, esFechaValida, etiquetaSemana, hoyEn, localDe, lunesDe, sumarDias } from "@/lib/semana";
import type { Cancha, CierreResumen, SerieDetalle, SerieResumen, Slot, TurnoDetalle, TurnoResumen } from "@/lib/tipos";
import { GrillaSemana } from "@/componentes/grilla-semana";
import { PanelSlot } from "@/componentes/panel-slot";

export default async function Turnos({
  searchParams,
}: {
  searchParams: Promise<{ semana?: string; cancha?: string; inicio?: string }>;
}) {
  const { semana, cancha: canchaParam, inicio: inicioParam } = await searchParams;
  const club = await clubActual();
  const hoy = hoyEn(club.zona_horaria);
  const lunes = lunesDe(esFechaValida(semana) ? semana : hoy);
  const dias = diasDeSemana(lunes);
  const domingo = dias[6];

  const supabase = await crearClienteServidor();

  // Cuatro lecturas en paralelo. La primera es la unica que sabe de reglas;
  // las otras tres solo traen nombres para mostrar.
  const [canchasR, slotsR, turnosR, seriesR, cierresR] = await Promise.all([
    supabase
      .from("canchas")
      .select("id, nombre, orden, deporte:deportes(id, nombre, duracion_min)")
      .eq("activa", true)
      .order("orden"),
    supabase.rpc("fn_disponibilidad", { p_club: club.id, p_desde: lunes, p_hasta: domingo }),
    supabase
      .from("turnos")
      .select("id, cancha_id, tipo, precio, cliente:clientes(nombre, telefono)")
      .eq("estado", "confirmado")
      .gte("inicio", `${lunes}T00:00:00`)
      .lt("inicio", `${sumarDias(domingo, 2)}T00:00:00`),
    supabase.from("series").select("id, tipo, cliente:clientes(nombre)"),
    supabase.from("cierres").select("id, motivo"),
  ]);

  const error = canchasR.error ?? slotsR.error ?? turnosR.error ?? seriesR.error ?? cierresR.error;
  if (error) throw error;

  const canchas = canchasR.data as unknown as Cancha[];
  const slots = slotsR.data as Slot[];

  // El slot abierto en el panel, si la url lo pide y existe en la grilla.
  const panel = await armarPanel(supabase, club.id, club.zona_horaria, canchas, slots, canchaParam, inicioParam);

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center gap-3">
        <h1 className="text-xl font-semibold">Turnos</h1>
        <Link href="/turnos/estadisticas" className="rounded-md px-3 py-1.5 text-sm hover:bg-slate-100">
          Ingresos
        </Link>
        <div className="ml-auto flex items-center gap-1 text-sm">
          <Link
            href={`/turnos?semana=${sumarDias(lunes, -7)}`}
            className="rounded-md border border-slate-300 bg-white px-2.5 py-1.5 hover:bg-slate-100"
            aria-label="Semana anterior"
          >
            ‹
          </Link>
          <Link
            href="/turnos"
            className="rounded-md border border-slate-300 bg-white px-3 py-1.5 hover:bg-slate-100"
          >
            Hoy
          </Link>
          <Link
            href={`/turnos?semana=${sumarDias(lunes, 7)}`}
            className="rounded-md border border-slate-300 bg-white px-2.5 py-1.5 hover:bg-slate-100"
            aria-label="Semana siguiente"
          >
            ›
          </Link>
          <span className="ml-3 font-medium text-slate-700">{etiquetaSemana(lunes)}</span>
        </div>
      </div>

      <GrillaSemana
        semana={lunes}
        seleccion={panel ? `${panel.cancha.id}|${panel.slot.inicio}` : null}
        zonaHoraria={club.zona_horaria}
        dias={dias}
        hoy={hoy}
        canchas={canchas}
        slots={slots}
        turnos={turnosR.data as unknown as TurnoResumen[]}
        series={seriesR.data as unknown as SerieResumen[]}
        cierres={cierresR.data as CierreResumen[]}
      />

      {panel && (
        <PanelSlot
          semana={lunes}
          hoy={hoy}
          zonaHoraria={club.zona_horaria}
          cancha={panel.cancha}
          slot={panel.slot}
          turno={panel.turno}
          serie={panel.serie}
          cierre={panel.cierre}
          otraCancha={panel.otraCancha}
          precioSugerido={panel.precioSugerido}
        />
      )}
    </div>
  );
}

// Lo que el panel necesita ademas de la grilla: el detalle del turno, de la
// serie o del cierre que la base asocio al slot, y el precio sugerido si
// esta libre. Solo se consulta cuando hay un slot abierto.
async function armarPanel(
  supabase: Awaited<ReturnType<typeof crearClienteServidor>>,
  clubId: string,
  zonaHoraria: string,
  canchas: Cancha[],
  slots: Slot[],
  canchaId: string | undefined,
  inicio: string | undefined,
) {
  if (!canchaId || !inicio) return null;
  const cancha = canchas.find((c) => c.id === canchaId);
  const slot = slots.find((s) => s.cancha_id === canchaId && s.inicio === inicio);
  if (!cancha || !slot) return null;

  const [turnoR, serieR, cierreR, precioR] = await Promise.all([
    slot.turno_id
      ? supabase
          .from("turnos")
          .select("id, cancha_id, tipo, precio, notas, inicio, fin, serie_id, cliente:clientes(id, nombre, telefono)")
          .eq("id", slot.turno_id)
          .single()
      : null,
    slot.serie_id
      ? supabase
          .from("series")
          .select("id, tipo, hora_inicio, duracion_min, vigente_desde, cliente:clientes(nombre, telefono)")
          .eq("id", slot.serie_id)
          .single()
      : null,
    slot.cierre_id ? supabase.from("cierres").select("id, motivo").eq("id", slot.cierre_id).single() : null,
    slot.estado === "libre"
      ? supabase.rpc("fn_precio_vigente", {
          p_club: clubId,
          p_cancha: canchaId,
          p_tipo: "normal",
          p_fecha: localDe(slot.inicio, zonaHoraria).dia,
        })
      : null,
  ]);

  const otraCancha =
    slot.turno_cancha_id && slot.turno_cancha_id !== canchaId
      ? (canchas.find((c) => c.id === slot.turno_cancha_id) ?? null)
      : null;

  return {
    cancha,
    slot,
    turno: (turnoR?.data as unknown as TurnoDetalle | null) ?? null,
    serie: (serieR?.data as unknown as SerieDetalle | null) ?? null,
    cierre: (cierreR?.data as CierreResumen | null) ?? null,
    otraCancha,
    precioSugerido: precioR?.data != null ? Number(precioR.data) : null,
  };
}
