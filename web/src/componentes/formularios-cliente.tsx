"use client";

import { useActionState } from "react";
import { editarCliente, marcarListaNegra, type Estado } from "@/app/(panel)/clientes/acciones";
import type { ClienteResumen } from "@/lib/tipos";

const input =
  "mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100";
const etiqueta = "block text-xs font-medium text-slate-600";
const secundario =
  "rounded-lg border border-slate-300 bg-white px-4 py-2 text-sm text-slate-700 hover:bg-slate-50 disabled:opacity-50";

function Mensaje({ estado }: { estado: Estado }) {
  if (estado?.error) return <p className="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{estado.error}</p>;
  if (estado?.ok) return <p className="rounded-lg bg-emerald-50 px-3 py-2 text-sm text-emerald-700">{estado.ok}</p>;
  return null;
}

export function FormEditarCliente({ cliente }: { cliente: ClienteResumen }) {
  const [estado, accion, pendiente] = useActionState(editarCliente, null);
  return (
    <form action={accion} className="space-y-3">
      <input type="hidden" name="cliente_id" value={cliente.id} />
      <label className={etiqueta}>
        Nombre
        <input name="nombre" required defaultValue={cliente.nombre} className={input} />
      </label>
      <label className={etiqueta}>
        Teléfono
        <input name="telefono" required defaultValue={cliente.telefono} className={input} />
      </label>
      <label className={etiqueta}>
        Notas
        <textarea name="notas" rows={2} defaultValue={cliente.notas ?? ""} className={input} />
      </label>
      <Mensaje estado={estado} />
      <button disabled={pendiente} className={secundario}>
        {pendiente ? "Guardando…" : "Guardar"}
      </button>
    </form>
  );
}

// La casilla del brief: tildar exige escribir el porque.
export function FormListaNegra({ cliente }: { cliente: ClienteResumen }) {
  const [estado, accion, pendiente] = useActionState(marcarListaNegra, null);

  if (cliente.en_lista_negra) {
    return (
      <form action={accion} className="space-y-3 rounded-lg border border-red-200 bg-red-50 p-4">
        <input type="hidden" name="cliente_id" value={cliente.id} />
        <input type="hidden" name="en_lista_negra" value="0" />
        <p className="text-sm font-semibold text-red-800">En lista negra</p>
        <p className="text-sm text-red-900">{cliente.motivo_lista_negra}</p>
        <p className="text-xs text-red-700">
          No se le toman turnos: el panel frena al agendar con este teléfono.
        </p>
        <Mensaje estado={estado} />
        <button disabled={pendiente} className={secundario}>
          {pendiente ? "Guardando…" : "Sacar de la lista negra"}
        </button>
      </form>
    );
  }

  return (
    <form action={accion} className="space-y-3 rounded-lg border border-slate-200 p-4">
      <input type="hidden" name="cliente_id" value={cliente.id} />
      <input type="hidden" name="en_lista_negra" value="1" />
      <p className="text-sm font-semibold text-slate-800">Lista negra</p>
      <label className={etiqueta}>
        Motivo
        <input name="motivo" required placeholder="Qué pasó" className={input} />
      </label>
      <Mensaje estado={estado} />
      <button
        disabled={pendiente}
        className="rounded-lg bg-red-600 px-4 py-2 text-sm font-medium text-white hover:bg-red-700 disabled:opacity-50"
      >
        {pendiente ? "Guardando…" : "Poner en lista negra"}
      </button>
    </form>
  );
}
