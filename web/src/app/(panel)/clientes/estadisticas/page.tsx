import Link from "next/link";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { pesos } from "@/lib/formato";
import type { ClientePorDeporte, ClienteResumen } from "@/lib/tipos";

// Los rankings del brief: los que mas jugaron (en general y por deporte) y
// los que mas cancelaron. Todo sale de las dos vistas; el top se corta aca.
const TOP = 10;

type Fila = { id: string; nombre: string; n: number; extra?: string };

function Ranking({ filas }: { filas: Fila[] }) {
  if (filas.length === 0) return <p className="text-sm text-slate-500">Sin datos todavía.</p>;
  return (
    <ol className="divide-y divide-slate-100 text-sm">
      {filas.map((f, i) => (
        <li key={f.id} className="flex items-center gap-3 py-1.5">
          <span className="w-5 text-right text-xs text-slate-400">{i + 1}</span>
          <Link href={`/clientes/${f.id}`} className="flex-1 truncate hover:underline">
            {f.nombre}
          </Link>
          {f.extra && <span className="text-xs text-slate-500">{f.extra}</span>}
          <span className="font-medium tabular-nums">{f.n}</span>
        </li>
      ))}
    </ol>
  );
}

export default async function Estadisticas() {
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const [generalR, porDeporteR, cancelR, deportesR] = await Promise.all([
    supabase
      .from("vw_clientes_resumen")
      .select("*")
      .gt("turnos_jugados", 0)
      .order("turnos_jugados", { ascending: false })
      .order("total_aportado", { ascending: false })
      .limit(TOP),
    supabase.from("vw_clientes_por_deporte").select("*").order("turnos_jugados", { ascending: false }),
    supabase
      .from("vw_clientes_resumen")
      .select("*")
      .gt("cancelados", 0)
      .order("cancelados", { ascending: false })
      .limit(TOP),
    supabase.from("deportes").select("id, nombre").eq("activo", true).order("nombre"),
  ]);
  const error = generalR.error ?? porDeporteR.error ?? cancelR.error ?? deportesR.error;
  if (error) throw error;

  const general = generalR.data as ClienteResumen[];
  const cancelados = cancelR.data as ClienteResumen[];
  const porDeporte = porDeporteR.data as ClientePorDeporte[];
  const nombres = new Map(general.concat(cancelados).map((c) => [c.id, c.nombre]));

  // Los nombres de los que solo aparecen en el ranking por deporte.
  const faltan = [...new Set(porDeporte.map((d) => d.cliente_id))].filter((id) => !nombres.has(id));
  if (faltan.length) {
    const { data } = await supabase.from("clientes").select("id, nombre").in("id", faltan);
    for (const c of data ?? []) nombres.set(c.id, c.nombre);
  }

  const tarjeta = "rounded-xl border border-slate-200 bg-white p-4";

  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <section className={tarjeta}>
        <h3 className="mb-2 text-sm font-semibold">Los que más jugaron</h3>
        <Ranking
          filas={general.map((c) => ({
            id: c.id,
            nombre: c.nombre,
            n: c.turnos_jugados,
            extra: pesos(c.total_aportado, club.moneda),
          }))}
        />
      </section>

      <section className={tarjeta}>
        <h3 className="mb-2 text-sm font-semibold">Los que más cancelaron</h3>
        <Ranking filas={cancelados.map((c) => ({ id: c.id, nombre: c.nombre, n: c.cancelados }))} />
      </section>

      <div className="space-y-6">
        {(deportesR.data ?? []).map((d) => (
          <section key={d.id} className={tarjeta}>
            <h3 className="mb-2 text-sm font-semibold">Los que más jugaron · {d.nombre}</h3>
            <Ranking
              filas={porDeporte
                .filter((x) => x.deporte_id === d.id)
                .slice(0, TOP)
                .map((x) => ({ id: x.cliente_id, nombre: nombres.get(x.cliente_id) ?? "", n: x.turnos_jugados }))}
            />
          </section>
        ))}
      </div>
    </div>
  );
}
