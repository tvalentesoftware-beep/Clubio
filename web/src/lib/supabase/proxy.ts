import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

// Refresca la sesion en cada request y decide a donde va el usuario:
// sin sesion, a /login; con sesion, /login lo manda al panel.
export async function actualizarSesion(request: NextRequest) {
  let respuesta = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          respuesta = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            respuesta.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // getUser valida el token contra Supabase; getSession solo lee la cookie.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const enLogin = request.nextUrl.pathname.startsWith("/login");

  if (!user && !enLogin) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.search = "";
    return NextResponse.redirect(url);
  }

  if (user && enLogin) {
    const url = request.nextUrl.clone();
    url.pathname = "/turnos";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return respuesta;
}
