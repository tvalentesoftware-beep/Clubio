import Link from "next/link";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { diasDeSemana, esFechaValida, etiquetaSemana, hoyEn, lunesDe, sumarDias } from "@/lib/semana";
import type { Cancha, CierreResumen, SerieResumen, Slot, TurnoResumen } from "@/lib/tipos";
import { GrillaSemana } from "@/componentes/grilla-semana";

export default async function Turnos({
  searchParams,
}: {
  searchParams: Promise<{ semana?: string }>;
}) {
  const { semana } = await searchParams;
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

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center gap-3">
        <h1 className="text-xl font-semibold">Turnos</h1>
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
        zonaHoraria={club.zona_horaria}
        dias={dias}
        hoy={hoy}
        canchas={canchasR.data as unknown as Cancha[]}
        slots={slotsR.data as Slot[]}
        turnos={turnosR.data as unknown as TurnoResumen[]}
        series={seriesR.data as unknown as SerieResumen[]}
        cierres={cierresR.data as CierreResumen[]}
      />
    </div>
  );
}
