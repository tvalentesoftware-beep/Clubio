"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { crearClienteServidor } from "@/lib/supabase/server";
import { normalizarTelefono } from "@/lib/telefono";

export type Estado = { error?: string; ok?: string } | null;

function texto(fd: FormData, campo: string): string {
  return String(fd.get(campo) ?? "").trim();
}

// La lista negra es una marca sobre el cliente, no una baja (ADR 0007): el
// historial queda. Marcar exige motivo; la base tambien lo exige, con un
// check, por si alguien entra por otra puerta.
export async function marcarListaNegra(_prev: Estado, fd: FormData): Promise<Estado> {
  const supabase = await crearClienteServidor();
  const clienteId = texto(fd, "cliente_id");
  const marcar = texto(fd, "en_lista_negra") === "1";
  const motivo = texto(fd, "motivo");

  if (marcar && !motivo) return { error: "Escribí por qué: es lo que va a ver quien quiera tomarle un turno." };

  const { error } = await supabase
    .from("clientes")
    .update(
      marcar
        ? { en_lista_negra: true, motivo_lista_negra: motivo, lista_negra_desde: new Date().toISOString() }
        : { en_lista_negra: false, motivo_lista_negra: null, lista_negra_desde: null },
    )
    .eq("id", clienteId);
  if (error) return { error: error.message };

  revalidatePath("/clientes");
  redirect(`/clientes/${clienteId}`);
}

export async function editarCliente(_prev: Estado, fd: FormData): Promise<Estado> {
  const supabase = await crearClienteServidor();
  const clienteId = texto(fd, "cliente_id");
  const nombre = texto(fd, "nombre");
  const notas = texto(fd, "notas") || null;

  if (!nombre) return { error: "Falta el nombre." };
  const telefono = normalizarTelefono(texto(fd, "telefono"));
  if (!telefono) return { error: "No entiendo ese teléfono." };

  const { error } = await supabase.from("clientes").update({ nombre, telefono, notas }).eq("id", clienteId);
  if (error) {
    if (error.code === "23505") return { error: "Ese teléfono ya es de otro cliente del club." };
    return { error: error.message };
  }

  revalidatePath("/clientes");
  return { ok: "Guardado." };
}
