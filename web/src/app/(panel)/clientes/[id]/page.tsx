import Link from "next/link";
import { notFound } from "next/navigation";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { fechaHora, pesos } from "@/lib/formato";
import type { ClientePorDeporte, ClienteResumen } from "@/lib/tipos";
import { FormEditarCliente, FormListaNegra } from "@/componentes/formularios-cliente";

type TurnoFila = {
  id: string;
  inicio: string;
  tipo: string;
  estado: string;
  precio: number;
  cancelado_por: string | null;
  cancha: { nombre: string; deporte: { nombre: string } };
};

export default async function Cliente({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const [resumenR, porDeporteR, turnosR] = await Promise.all([
    supabase.from("vw_clientes_resumen").select("*").eq("id", id).maybeSingle(),
    supabase
      .from("vw_clientes_por_deporte")
      .select("*")
      .eq("cliente_id", id)
      .order("total_aportado", { ascending: false }),
    supabase
      .from("turnos")
      .select("id, inicio, tipo, estado, precio, cancelado_por, cancha:canchas(nombre, deporte:deportes(nombre))")
      .eq("cliente_id", id)
      .order("inicio", { ascending: false })
      .limit(30),
  ]);

  if (resumenR.error) throw resumenR.error;
  if (!resumenR.data) notFound();
  const cliente = resumenR.data as ClienteResumen;
  const porDeporte = (porDeporteR.data ?? []) as ClientePorDeporte[];
  const turnos = (turnosR.data ?? []) as unknown as TurnoFila[];

  const tarjeta = "rounded-xl border border-slate-200 bg-white p-4";
  const dato = "text-2xl font-semibold tabular-nums";
  const rotulo = "text-xs uppercase tracking-wide text-slate-500";

  return (
    <div className="space-y-6">
      <div className="flex items-baseline gap-3">
        <Link href="/clientes" className="text-sm text-slate-500 hover:underline">
          ← Todos
        </Link>
        <h2 className="text-lg font-semibold">{cliente.nombre}</h2>
        <span className="text-sm text-slate-500">{cliente.telefono}</span>
      </div>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className={tarjeta}>
          <p className={rotulo}>Turnos jugados</p>
          <p className={dato}>{cliente.turnos_jugados}</p>
        </div>
        <div className={tarjeta}>
          <p className={rotulo}>Total aportado</p>
          <p className={dato}>{pesos(cliente.total_aportado, club.moneda)}</p>
        </div>
        <div className={tarjeta}>
          <p className={rotulo}>Canceló</p>
          <p className={dato}>{cliente.cancelados}</p>
        </div>
        <div className={tarjeta}>
          <p className={rotulo}>Próximos</p>
          <p className={dato}>{cliente.turnos_futuros}</p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          {porDeporte.length > 0 && (
            <section className={tarjeta}>
              <h3 className="mb-2 text-sm font-semibold">Por deporte</h3>
              <table className="w-full text-sm">
                <tbody className="divide-y divide-slate-100">
                  {porDeporte.map((d) => (
                    <tr key={d.deporte_id}>
                      <td className="py-1.5">{d.deporte}</td>
                      <td className="py-1.5 text-right tabular-nums text-slate-600">{d.turnos_jugados} turnos</td>
                      <td className="py-1.5 text-right font-medium tabular-nums">{pesos(d.total_aportado, club.moneda)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </section>
          )}

          <section className={tarjeta}>
            <h3 className="mb-2 text-sm font-semibold">Historial</h3>
            {turnos.length === 0 ? (
              <p className="text-sm text-slate-500">Todavía no tiene turnos.</p>
            ) : (
              <table className="w-full text-sm">
                <tbody className="divide-y divide-slate-100">
                  {turnos.map((t) => (
                    <tr key={t.id} className={t.estado === "cancelado" ? "text-slate-400" : ""}>
                      <td className="py-1.5">{fechaHora(t.inicio, club.zona_horaria)}</td>
                      <td className="py-1.5">
                        {t.cancha.nombre} <span className="text-slate-500">· {t.cancha.deporte.nombre}</span>
                      </td>
                      <td className="py-1.5">{t.tipo}</td>
                      <td className="py-1.5 text-right tabular-nums">{pesos(t.precio, club.moneda)}</td>
                      <td className="py-1.5 text-right text-xs">
                        {t.estado === "cancelado" ? `cancelado (${t.cancelado_por})` : ""}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
        </div>

        <div className="space-y-6">
          <section className={tarjeta}>
            <h3 className="mb-3 text-sm font-semibold">Datos</h3>
            <FormEditarCliente cliente={cliente} />
          </section>
          <FormListaNegra cliente={cliente} />
        </div>
      </div>
    </div>
  );
}
