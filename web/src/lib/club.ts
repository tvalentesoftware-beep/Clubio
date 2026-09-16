import { redirect } from "next/navigation";
import { crearClienteServidor } from "@/lib/supabase/server";
import type { Club } from "@/lib/tipos";

// El club que el usuario administra. Por ahora se asume uno solo por
// usuario; el modelo permite varios y el selector queda para despues.
export async function clubActual(): Promise<Club> {
  const supabase = await crearClienteServidor();

  const { data, error } = await supabase
    .from("usuarios_club")
    .select("rol, club:clubes(id, nombre, slug, zona_horaria, moneda, logo_url, color_primario, color_secundario)")
    .eq("activo", true)
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  if (!data?.club) redirect("/sin-club");

  // PostgREST devuelve la relacion como objeto porque es N:1.
  return data.club as unknown as Club;
}
