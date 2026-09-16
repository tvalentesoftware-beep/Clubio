import { etiquetaDia, localDe } from "@/lib/semana";
import type { Cancha, CierreResumen, SerieResumen, Slot, TurnoResumen } from "@/lib/tipos";

type Props = {
  zonaHoraria: string;
  dias: string[];
  hoy: string;
  canchas: Cancha[];
  slots: Slot[];
  turnos: TurnoResumen[];
  series: SerieResumen[];
  cierres: CierreResumen[];
};

// La grilla tipo planilla que el encargado espera. No sabe ninguna regla:
// pinta lo que fn_disponibilidad dijo de cada slot, y solo agrega nombres.
export function GrillaSemana({ zonaHoraria, dias, hoy, canchas, slots, turnos, series, cierres }: Props) {
  const turnoPorId = new Map(turnos.map((t) => [t.id, t]));
  const seriePorId = new Map(series.map((s) => [s.id, s]));
  const cierrePorId = new Map(cierres.map((c) => [c.id, c]));
  const canchaPorId = new Map(canchas.map((c) => [c.id, c]));

  // slot -> (cancha, dia local, hora local)
  const porCancha = new Map<string, { horas: Set<string>; celdas: Map<string, Slot> }>();
  for (const s of slots) {
    const { dia, hora } = localDe(s.inicio, zonaHoraria);
    let c = porCancha.get(s.cancha_id);
    if (!c) {
      c = { horas: new Set(), celdas: new Map() };
      porCancha.set(s.cancha_id, c);
    }
    c.horas.add(hora);
    c.celdas.set(`${dia} ${hora}`, s);
  }

  if (slots.length === 0) {
    return (
      <p className="rounded-xl border border-dashed border-slate-300 bg-white p-8 text-center text-sm text-slate-500">
        No hay horarios configurados para esta semana.
      </p>
    );
  }

  return (
    <div className="space-y-6">
      <Leyenda />

      {canchas.map((cancha) => {
        const datos = porCancha.get(cancha.id);
        if (!datos) return null;
        const horas = [...datos.horas].sort();

        return (
          <section key={cancha.id} className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
            <div className="flex items-baseline gap-2 border-b border-slate-100 px-4 py-2.5">
              <h2 className="font-semibold">{cancha.nombre}</h2>
              <span className="text-sm text-slate-500">{cancha.deporte.nombre}</span>
            </div>

            <table className="w-full table-fixed border-separate border-spacing-1 p-2 text-xs">
              <thead>
                <tr>
                  <th className="w-12" />
                  {dias.map((d) => (
                    <th
                      key={d}
                      className={`px-1 py-1 text-left font-semibold ${d === hoy ? "text-[var(--marca)]" : "text-slate-600"}`}
                    >
                      {etiquetaDia(d)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {horas.map((hora) => (
                  <tr key={hora}>
                    <th className="px-1 text-left font-medium text-slate-500">{hora}</th>
                    {dias.map((dia) => (
                      <Celda
                        key={dia}
                        slot={datos.celdas.get(`${dia} ${hora}`)}
                        cancha={cancha}
                        turnoPorId={turnoPorId}
                        seriePorId={seriePorId}
                        cierrePorId={cierrePorId}
                        canchaPorId={canchaPorId}
                      />
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </section>
        );
      })}
    </div>
  );
}

function Celda({
  slot,
  cancha,
  turnoPorId,
  seriePorId,
  cierrePorId,
  canchaPorId,
}: {
  slot: Slot | undefined;
  cancha: Cancha;
  turnoPorId: Map<string, TurnoResumen>;
  seriePorId: Map<string, SerieResumen>;
  cierrePorId: Map<string, CierreResumen>;
  canchaPorId: Map<string, Cancha>;
}) {
  const base = "h-11 rounded-md px-2 py-1 align-top leading-tight";

  if (!slot) return <td className={base} />;

  if (slot.estado === "libre") {
    return <td className={`${base} bg-slate-100 text-slate-400`}>libre</td>;
  }

  if (slot.estado === "ocupado") {
    const turno = slot.turno_id ? turnoPorId.get(slot.turno_id) : undefined;

    // Ocupado por un turno de otra cancha que comparte el espacio.
    if (slot.turno_cancha_id && slot.turno_cancha_id !== cancha.id) {
      const otra = canchaPorId.get(slot.turno_cancha_id);
      return (
        <td className={`${base} border border-dashed border-slate-400 bg-slate-50 text-slate-500`}>
          no disponible
          <small className="block opacity-75">por {otra?.nombre ?? "otra cancha"}</small>
        </td>
      );
    }

    return (
      <td className={`${base} text-white`} style={{ background: "var(--marca)" }}>
        <b className="block truncate">{turno?.cliente.nombre ?? "Reservado"}</b>
        <small className="opacity-80">{turno?.tipo ?? ""}</small>
      </td>
    );
  }

  if (slot.estado === "serie") {
    const serie = slot.serie_id ? seriePorId.get(slot.serie_id) : undefined;
    return (
      <td className={`${base} border border-amber-300 bg-amber-50 text-amber-900`}>
        <b className="block truncate">{serie?.cliente.nombre ?? "Fijo"}</b>
        <small className="opacity-75">{serie?.tipo ?? "fijo"} · sin generar</small>
      </td>
    );
  }

  const cierre = slot.cierre_id ? cierrePorId.get(slot.cierre_id) : undefined;
  return (
    <td className={`${base} bg-red-50 text-red-800`}>
      cerrado
      <small className="block truncate opacity-75">{cierre?.motivo ?? ""}</small>
    </td>
  );
}

function Leyenda() {
  const item = "inline-flex items-center gap-1.5";
  const caja = "inline-block h-3.5 w-3.5 rounded";
  return (
    <div className="flex flex-wrap gap-4 text-xs text-slate-600">
      <span className={item}><i className={caja} style={{ background: "var(--marca)" }} /> reservado</span>
      <span className={item}><i className={`${caja} border border-dashed border-slate-400 bg-slate-50`} /> no disponible por otra cancha</span>
      <span className={item}><i className={`${caja} border border-amber-300 bg-amber-50`} /> fijo o clase sin generar</span>
      <span className={item}><i className={`${caja} bg-red-50 ring-1 ring-red-200`} /> cerrado</span>
      <span className={item}><i className={`${caja} bg-slate-100`} /> libre</span>
    </div>
  );
}
