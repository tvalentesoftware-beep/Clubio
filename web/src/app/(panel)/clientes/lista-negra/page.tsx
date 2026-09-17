import Link from "next/link";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { fechaCorta } from "@/lib/formato";
import type { ClienteResumen } from "@/lib/tipos";

export default async function ListaNegra() {
  const club = await clubActual();
  const supabase = await crearClienteServidor();
  const { data, error } = await supabase
    .from("vw_clientes_resumen")
    .select("*")
    .eq("en_lista_negra", true)
    .order("lista_negra_desde", { ascending: false });
  if (error) throw error;
  const clientes = data as ClienteResumen[];

  return (
    <div className="overflow-x-auto rounded-xl border border-slate-200 bg-white">
      <table className="w-full text-sm">
        <thead className="bg-slate-50 text-left text-xs uppercase tracking-wide text-slate-500">
          <tr>
            <th className="px-4 py-2.5">Cliente</th>
            <th className="px-4 py-2.5">Teléfono</th>
            <th className="px-4 py-2.5">Desde</th>
            <th className="px-4 py-2.5">Motivo</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100">
          {clientes.map((c) => (
            <tr key={c.id}>
              <td className="px-4 py-2.5">
                <Link href={`/clientes/${c.id}`} className="font-medium hover:underline">
                  {c.nombre}
                </Link>
              </td>
              <td className="px-4 py-2.5 text-slate-600">{c.telefono}</td>
              <td className="px-4 py-2.5 text-slate-600">
                {c.lista_negra_desde ? fechaCorta(c.lista_negra_desde, club.zona_horaria) : "—"}
              </td>
              <td className="px-4 py-2.5">{c.motivo_lista_negra}</td>
            </tr>
          ))}
          {clientes.length === 0 && (
            <tr>
              <td colSpan={4} className="px-4 py-8 text-center text-slate-500">
                Nadie en la lista negra.
              </td>
            </tr>
          )}
        </tbody>
      </table>
    </div>
  );
}
