import Link from "next/link";
import { clubActual } from "@/lib/club";
import { salir } from "@/app/login/acciones";

// El panel se ve con la marca del club, no con la de Clubio: el color
// primario del club entra como variable CSS y todo lo que "es del club"
// la usa.
export default async function PanelLayout({ children }: { children: React.ReactNode }) {
  const club = await clubActual();
  const marca = club.color_primario ?? "#1D7BF0";

  return (
    <div
      className="min-h-screen bg-slate-50 text-slate-900"
      style={{ ["--marca" as string]: marca }}
    >
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-7xl items-center gap-6 px-6 py-3">
          <div className="flex items-center gap-3">
            {club.logo_url ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={club.logo_url} alt="" className="h-9 w-9 rounded-lg object-cover" />
            ) : (
              <div
                className="grid h-9 w-9 place-items-center rounded-lg text-sm font-bold text-white"
                style={{ background: "var(--marca)" }}
              >
                {club.nombre.slice(0, 1)}
              </div>
            )}
            <span className="font-semibold">{club.nombre}</span>
          </div>

          <nav className="flex gap-1 text-sm">
            <Link href="/turnos" className="rounded-md px-3 py-1.5 font-medium hover:bg-slate-100">
              Turnos
            </Link>
            <Link href="/clientes" className="rounded-md px-3 py-1.5 font-medium hover:bg-slate-100">
              Clientes
            </Link>
          </nav>

          <form action={salir} className="ml-auto">
            <button className="text-sm text-slate-500 hover:text-slate-900">Salir</button>
          </form>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-6 py-6">{children}</main>
    </div>
  );
}
