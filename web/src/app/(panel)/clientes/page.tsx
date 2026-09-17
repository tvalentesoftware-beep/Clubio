import Link from "next/link";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { pesos, fechaCorta } from "@/lib/formato";
import type { ClienteResumen } from "@/lib/tipos";

// La tabla del brief: todos los clientes, ordenados por lo que le dejaron
// al club. Los numeros salen de vw_clientes_resumen; aca no se calcula nada.
export default async function Clientes({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  const { q } = await searchParams;
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  let consulta = supabase
    .from("vw_clientes_resumen")
    .select("*")
    .order("total_aportado", { ascending: false })
    .order("nombre");

  if (q) {
    const digitos = q.replace(/\D/g, "");
    consulta = consulta.or(
      digitos ? `nombre.ilike.%${q}%,telefono.ilike.%${digitos}%` : `nombre.ilike.%${q}%`,
    );
  }

  const { data, error } = await consulta;
  if (error) throw error;
  const clientes = data as ClienteResumen[];

  return (
    <div className="space-y-4">
      <form className="flex gap-2">
        <input
          name="q"
          defaultValue={q ?? ""}
          placeholder="Buscar por nombre o teléfono"
          className="w-full max-w-sm rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
        />
        <button className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm hover:bg-slate-50">Buscar</button>
      </form>

      <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
        <table className="w-full text-sm">
          <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
            <tr>
              <th className="px-4 py-2.5">Cliente</th>
              <th className="px-4 py-2.5">Teléfono</th>
              <th className="px-4 py-2.5 text-right">Turnos jugados</th>
              <th className="px-4 py-2.5">Deportes</th>
              <th className="px-4 py-2.5 text-right">Total aportado</th>
              <th className="px-4 py-2.5">Último turno</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {clientes.map((c) => (
              <tr key={c.id} className="hover:bg-slate-50">
                <td className="px-4 py-2.5">
                  <Link href={`/clientes/${c.id}`} className="font-medium text-slate-900 hover:underline">
                    {c.nombre}
                  </Link>
                  {c.en_lista_negra && (
                    <span className="ml-2 rounded bg-red-100 px-1.5 py-0.5 text-xs text-red-800">lista negra</span>
                  )}
                </td>
                <td className="px-4 py-2.5 text-slate-600">{c.telefono}</td>
                <td className="px-4 py-2.5 text-right tabular-nums">{c.turnos_jugados}</td>
                <td className="px-4 py-2.5 text-slate-600">{c.deportes.join(", ") || "—"}</td>
                <td className="px-4 py-2.5 text-right font-medium tabular-nums">{pesos(c.total_aportado, club.moneda)}</td>
                <td className="px-4 py-2.5 text-slate-600">
                  {c.ultimo_turno ? fechaCorta(c.ultimo_turno, club.zona_horaria) : "—"}
                </td>
              </tr>
            ))}
            {clientes.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-slate-500">
                  {q ? "Ningún cliente coincide." : "Todavía no hay clientes: aparecen al agendar el primer turno."}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
