"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { crearClienteServidor } from "@/lib/supabase/server";
import { clubActual } from "@/lib/club";
import { normalizarTelefono } from "@/lib/telefono";
import { instanteLocal, sumarDias } from "@/lib/semana";
import type { FilaMaterializacion } from "@/lib/tipos";

// Todas las escrituras del panel de turnos pasan por aca. Ninguna sabe una
// regla del negocio: validan lo que vino del formulario, resuelven el
// cliente por telefono, y le piden a la base que haga el resto. Si la base
// dice que no -exclusion, RLS, check- eso vuelve como mensaje.
//
// Cada accion recibe el estado anterior (useActionState) y el FormData, y
// devuelve un estado con error o aviso, o redirige a la semana si salio bien.

// React vacia el formulario cuando la accion responde, asi que lo que el
// encargado escribio vuelve en `valores` para repoblarlo.
export type Valores = Record<string, string>;

export type Estado = {
  error?: string;
  aviso?: FilaMaterializacion[];
  valores?: Valores;
} | null;

function valoresDe(fd: FormData, campos: string[]): Valores {
  return Object.fromEntries(campos.map((c) => [c, String(fd.get(c) ?? "")]));
}

const TIPOS = new Set(["normal", "fijo", "clase"]);

function texto(fd: FormData, campo: string): string {
  return String(fd.get(campo) ?? "").trim();
}

// Quien esta operando: firma turnos y eventos.
async function usuarioId(supabase: Awaited<ReturnType<typeof crearClienteServidor>>): Promise<string | null> {
  const { data } = await supabase.auth.getUser();
  return data.user?.id ?? null;
}

function volver(semana: string): never {
  revalidatePath("/turnos");
  redirect(`/turnos?semana=${semana}`);
}

// Un cliente por telefono: si existe, se actualiza el nombre con lo que el
// encargado escribio (ultimo gana, como en la planilla); si no, se crea.
// Si esta en lista negra, se frena aca con el motivo.
async function resolverCliente(
  supabase: Awaited<ReturnType<typeof crearClienteServidor>>,
  clubId: string,
  nombre: string,
  telefono: string,
): Promise<{ id: string } | { error: string }> {
  const { data: existente, error: e1 } = await supabase
    .from("clientes")
    .select("id, nombre, en_lista_negra, motivo_lista_negra")
    .eq("club_id", clubId)
    .eq("telefono", telefono)
    .maybeSingle();
  if (e1) return { error: e1.message };

  if (existente) {
    if (existente.en_lista_negra) {
      return { error: `Este cliente está en la lista negra: ${existente.motivo_lista_negra ?? "sin motivo cargado"}.` };
    }
    if (existente.nombre !== nombre) {
      const { error } = await supabase.from("clientes").update({ nombre }).eq("id", existente.id);
      if (error) return { error: error.message };
    }
    return { id: existente.id };
  }

  const { data, error } = await supabase
    .from("clientes")
    .insert({ club_id: clubId, nombre, telefono })
    .select("id")
    .single();
  if (error) return { error: error.message };
  return { id: data.id };
}

export async function agendar(_prev: Estado, fd: FormData): Promise<Estado> {
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const semana = texto(fd, "semana");
  const canchaId = texto(fd, "cancha_id");
  const fecha = texto(fd, "fecha");
  const hora = texto(fd, "hora");
  const duracion = Number(texto(fd, "duracion_min"));
  const nombre = texto(fd, "nombre");
  const tipo = texto(fd, "tipo");
  const precio = Number(texto(fd, "precio").replace(",", "."));
  const notas = texto(fd, "notas") || null;
  const confirmar = texto(fd, "confirmar") === "1";
  const valores = valoresDe(fd, ["nombre", "telefono", "tipo", "precio", "notas"]);

  if (!nombre) return { error: "Falta el nombre.", valores };
  const telefono = normalizarTelefono(texto(fd, "telefono"));
  if (!telefono) return { error: "No entiendo ese teléfono. Probá con código de área, sin 0 ni 15: 342 555 0101.", valores };
  if (!TIPOS.has(tipo)) return { error: "Tipo de turno inválido.", valores };
  if (!Number.isFinite(precio) || precio < 0) return { error: "El precio no es válido.", valores };
  if (!canchaId || !fecha || !hora || !duracion) return { error: "Faltan datos del turno.", valores };

  const cliente = await resolverCliente(supabase, club.id, nombre, telefono);
  if ("error" in cliente) return { error: cliente.error, valores };

  if (tipo === "normal") {
    const inicio = instanteLocal(fecha, hora, club.zona_horaria);
    const fin = new Date(new Date(inicio).getTime() + duracion * 60_000).toISOString();

    const usuario = await usuarioId(supabase);
    const { data: turno, error } = await supabase
      .from("turnos")
      .insert({ club_id: club.id, cancha_id: canchaId, cliente_id: cliente.id, tipo, inicio, fin, precio, notas, creado_por: usuario })
      .select("id")
      .single();

    if (error) {
      if (error.code === "23P01") return { error: "Ese horario se acaba de ocupar. Actualizá la grilla.", valores };
      return { error: error.message, valores };
    }

    await supabase.from("turno_eventos").insert({
      club_id: club.id,
      turno_id: turno.id,
      tipo: "creado",
      detalle: { origen: "panel" },
      usuario_id: usuario,
    });

    volver(semana);
  }

  // Fijo o clase: la base crea la serie, simula, y avisa si algo choca.
  const { data, error } = await supabase.rpc("fn_crear_serie", {
    p_club: club.id,
    p_cancha: canchaId,
    p_cliente: cliente.id,
    p_tipo: tipo,
    p_dia_semana: new Date(`${fecha}T00:00:00Z`).getUTCDay(),
    p_hora_inicio: hora,
    p_duracion_min: duracion,
    p_vigente_desde: fecha,
    p_hasta: sumarDias(fecha, 56),
    p_confirmar: confirmar,
  });
  if (error) return { error: error.message, valores };

  const filas = (data ?? []) as FilaMaterializacion[];
  if (filas.some((f) => f.resultado === "a_crear")) {
    // Simulacion: no se escribio nada. El formulario muestra el aviso y
    // ofrece crear igual.
    return { aviso: filas, valores };
  }

  volver(semana);
}

export async function cancelar(_prev: Estado, fd: FormData): Promise<Estado> {
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const semana = texto(fd, "semana");
  const turnoId = texto(fd, "turno_id");
  const por = texto(fd, "cancelado_por");
  if (por !== "cliente" && por !== "club") return { error: "Indicá quién canceló." };

  const { error } = await supabase
    .from("turnos")
    .update({ estado: "cancelado", cancelado_por: por, cancelado_en: new Date().toISOString() })
    .eq("id", turnoId)
    .eq("estado", "confirmado");
  if (error) return { error: error.message };

  await supabase.from("turno_eventos").insert({
    club_id: club.id,
    turno_id: turnoId,
    tipo: "cancelado",
    detalle: { por },
    usuario_id: await usuarioId(supabase),
  });

  volver(semana);
}

export async function editar(_prev: Estado, fd: FormData): Promise<Estado> {
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const semana = texto(fd, "semana");
  const turnoId = texto(fd, "turno_id");
  const clienteId = texto(fd, "cliente_id");
  const nombre = texto(fd, "nombre");
  const precio = Number(texto(fd, "precio").replace(",", "."));
  const notas = texto(fd, "notas") || null;
  const valores = valoresDe(fd, ["nombre", "telefono", "precio", "notas"]);

  if (!nombre) return { error: "Falta el nombre.", valores };
  const telefono = normalizarTelefono(texto(fd, "telefono"));
  if (!telefono) return { error: "No entiendo ese teléfono.", valores };
  if (!Number.isFinite(precio) || precio < 0) return { error: "El precio no es válido.", valores };

  // Cambiar el nombre o el numero es editar al cliente, no al turno (ADR 0006).
  const { error: e1 } = await supabase.from("clientes").update({ nombre, telefono }).eq("id", clienteId);
  if (e1) {
    if (e1.code === "23505") return { error: "Ese teléfono ya es de otro cliente del club.", valores };
    return { error: e1.message, valores };
  }

  const { error: e2 } = await supabase.from("turnos").update({ precio, notas }).eq("id", turnoId);
  if (e2) return { error: e2.message, valores };

  await supabase.from("turno_eventos").insert({
    club_id: club.id,
    turno_id: turnoId,
    tipo: "editado",
    detalle: { nombre, telefono, precio, notas },
    usuario_id: await usuarioId(supabase),
  });

  volver(semana);
}

export async function bloquear(_prev: Estado, fd: FormData): Promise<Estado> {
  const club = await clubActual();
  const supabase = await crearClienteServidor();

  const semana = texto(fd, "semana");
  const canchaId = texto(fd, "cancha_id");
  const fecha = texto(fd, "fecha");
  const hora = texto(fd, "hora");
  const duracion = Number(texto(fd, "duracion_min"));
  const motivo = texto(fd, "motivo");
  const todoElDia = texto(fd, "todo_el_dia") === "1";
  const todoElClub = texto(fd, "todo_el_club") === "1";

  const valores = valoresDe(fd, ["motivo", "todo_el_dia", "todo_el_club"]);
  if (!motivo) return { error: "Escribí el motivo: es lo que va a ver quien mire la grilla.", valores };

  let desde: string;
  let hasta: string;
  if (todoElDia) {
    desde = instanteLocal(fecha, "00:00", club.zona_horaria);
    hasta = instanteLocal(sumarDias(fecha, 1), "00:00", club.zona_horaria);
  } else {
    desde = instanteLocal(fecha, hora, club.zona_horaria);
    hasta = new Date(new Date(desde).getTime() + duracion * 60_000).toISOString();
  }

  const { error } = await supabase.from("cierres").insert({
    club_id: club.id,
    cancha_id: todoElClub ? null : canchaId,
    durante: `[${desde},${hasta})`,
    motivo,
    creado_por: await usuarioId(supabase),
  });
  if (error) return { error: error.message, valores };

  volver(semana);
}

export async function quitarCierre(_prev: Estado, fd: FormData): Promise<Estado> {
  const supabase = await crearClienteServidor();
  const semana = texto(fd, "semana");
  const { error } = await supabase.from("cierres").delete().eq("id", texto(fd, "cierre_id"));
  if (error) return { error: error.message };
  volver(semana);
}

export async function generarSerie(_prev: Estado, fd: FormData): Promise<Estado> {
  const supabase = await crearClienteServidor();
  const semana = texto(fd, "semana");
  const desde = texto(fd, "desde");
  const { error } = await supabase.rpc("fn_materializar_serie", {
    p_serie: texto(fd, "serie_id"),
    p_desde: desde,
    p_hasta: sumarDias(desde, 56),
  });
  if (error) return { error: error.message };
  volver(semana);
}
