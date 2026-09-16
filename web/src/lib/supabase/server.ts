import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

// Cliente de Supabase para Server Components, Server Actions y Route
// Handlers. Lee la sesion de las cookies; RLS aplica con el usuario logueado.
export async function crearClienteServidor() {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Un Server Component no puede escribir cookies; el proxy ya
            // refresca la sesion, asi que se puede ignorar.
          }
        },
      },
    },
  );
}
