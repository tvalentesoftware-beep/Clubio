import Link from "next/link";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { pesos } from "@/lib/formato";

// Las estadisticas de ingresos del brief. Los numeros salen de fn_ingresos
// y fn_ingresos_mensuales; aca solo se suman filas ya agregadas y se pintan.

type FilaIngresos = { periodo: "mes" | "historico"; deporte: string; tipo: string; turnos: number; total: number };
type FilaMes = { mes: string; deporte: string; tipo: string; turnos: number; total: number };

const TIPO: Record<string, string> = { normal: "Turnos sueltos", fijo: "Fijos", clase: "Clases" };
const MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

function suma(filas: FilaIngresos[], f: (x: FilaIngresos) => boolean): number {
  return filas.filter(f).reduce((a, x) => a + Number(x.total), 0);
}

export default async function EstadisticasTurnos() {
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const [ingresosR, mensualR] = await Promise.all([
    supabase.rpc("fn_ingresos", { p_club: club.id }),
    supabase.rpc("fn_ingresos_mensuales", { p_club: club.id, p_meses: 12 }),
  ]);
  const error = ingresosR.error ?? mensualR.error;
  if (error) throw error;

  const filas = (ingresosR.data ?? []) as FilaIngresos[];
  const mensual = (mensualR.data ?? []) as FilaMes[];

  const deportes = [...new Set(filas.map((f) => f.deporte))].sort();
  const tipos = ["normal", "fijo", "clase"];

  const totalMes = suma(filas, (f) => f.periodo === "mes");
  const totalHist = suma(filas, (f) => f.periodo === "historico");

  // Serie mensual: total por mes, con el desglose por deporte para la barra.
  const meses = [...new Set(mensual.map((m) => m.mes))].sort();
  const porMes = meses.map((mes) => ({
    mes,
    total: mensual.filter((m) => m.mes === mes).reduce((a, m) => a + Number(m.total), 0),
    porDeporte: deportes.map((d) => ({
      deporte: d,
      total: mensual.filter((m) => m.mes === mes && m.deporte === d).reduce((a, m) => a + Number(m.total), 0),
    })),
  }));
  const maximo = Math.max(1, ...porMes.map((m) => m.total));

  const tarjeta = "rounded-xl border border-slate-200 bg-white p-4";
  const rotulo = "text-xs uppercase tracking-wide text-slate-500";
  const celda = "py-1.5 text-right tabular-nums";

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-xl font-semibold">Ingresos</h1>
        <Link href="/turnos" className="text-sm text-slate-500 hover:underline">← Grilla</Link>
        <p className="ml-auto text-xs text-slate-500">
          Cuenta cada turno confirmado que ya se jugó, al precio con el que se cargó. Sin cancelados ni futuros.
        </p>
      </div>

      <div className="grid gap-3 md:grid-cols-2">
        <div className={tarjeta}>
          <p className={rotulo}>Este mes, hasta hoy</p>
          <p className="text-3xl font-semibold tabular-nums">{pesos(totalMes, club.moneda)}</p>
        </div>
        <div className={tarjeta}>
          <p className={rotulo}>Histórico, hasta hoy</p>
          <p className="text-3xl font-semibold tabular-nums">{pesos(totalHist, club.moneda)}</p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <section className={tarjeta}>
          <h3 className="mb-2 text-sm font-semibold">Por deporte</h3>
          <table className="w-full text-sm">
            <thead className="text-xs text-slate-500">
              <tr><th className="text-left font-medium">Deporte</th><th className="text-right font-medium">Este mes</th><th className="text-right font-medium">Histórico</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {deportes.map((d) => (
                <tr key={d}>
                  <td className="py-1.5">{d}</td>
                  <td className={celda}>{pesos(suma(filas, (f) => f.periodo === "mes" && f.deporte === d), club.moneda)}</td>
                  <td className={`${celda} font-medium`}>{pesos(suma(filas, (f) => f.periodo === "historico" && f.deporte === d), club.moneda)}</td>
                </tr>
              ))}
              {deportes.length === 0 && (
                <tr><td colSpan={3} className="py-4 text-center text-slate-500">Todavía no hay turnos jugados.</td></tr>
              )}
            </tbody>
          </table>
        </section>

        <section className={tarjeta}>
          <h3 className="mb-2 text-sm font-semibold">Fijos, clases y sueltos</h3>
          <table className="w-full text-sm">
            <thead className="text-xs text-slate-500">
              <tr><th className="text-left font-medium">Tipo</th><th className="text-right font-medium">Este mes</th><th className="text-right font-medium">Histórico</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {tipos.map((t) => (
                <tr key={t}>
                  <td className="py-1.5">{TIPO[t]}</td>
                  <td className={celda}>{pesos(suma(filas, (f) => f.periodo === "mes" && f.tipo === t), club.moneda)}</td>
                  <td className={`${celda} font-medium`}>{pesos(suma(filas, (f) => f.periodo === "historico" && f.tipo === t), club.moneda)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </div>

      <section className={tarjeta}>
        <h3 className="mb-3 text-sm font-semibold">Últimos doce meses</h3>
        {porMes.length === 0 ? (
          <p className="text-sm text-slate-500">Todavía no hay turnos jugados.</p>
        ) : (
          <div className="space-y-1.5">
            {porMes.map((m) => {
              const [anio, mesNum] = m.mes.split("-").map(Number);
              return (
                <div key={m.mes} className="flex items-center gap-3 text-sm">
                  <span className="w-16 text-slate-600">{MESES[mesNum - 1]} {String(anio).slice(2)}</span>
                  <div className="flex h-5 flex-1 overflow-hidden rounded bg-slate-100" title={m.porDeporte.map((d) => `${d.deporte}: ${pesos(d.total, club.moneda)}`).join(" · ")}>
                    {m.porDeporte.map((d, i) => (
                      <div
                        key={d.deporte}
                        style={{ width: `${(d.total / maximo) * 100}%`, background: "var(--marca)", opacity: 1 - i * 0.25 }}
                      />
                    ))}
                  </div>
                  <span className="w-28 text-right font-medium tabular-nums">{pesos(m.total, club.moneda)}</span>
                </div>
              );
            })}
            <p className="pt-2 text-xs text-slate-500">
              Cada barra se parte por deporte, en el orden: {deportes.join(", ")}.
            </p>
          </div>
        )}
      </section>
    </div>
  );
}
