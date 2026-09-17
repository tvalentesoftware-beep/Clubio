import Link from "next/link";

// Sub-navegacion de Clientes: todos, lista negra, estadisticas.
export default function ClientesLayout({ children }: { children: React.ReactNode }) {
  const item = "rounded-md px-3 py-1.5 text-sm hover:bg-slate-100";
  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center gap-3">
        <h1 className="text-xl font-semibold">Clientes</h1>
        <nav className="ml-4 flex gap-1">
          <Link href="/clientes" className={item}>Todos</Link>
          <Link href="/clientes/lista-negra" className={item}>Lista negra</Link>
          <Link href="/clientes/estadisticas" className={item}>Estadísticas</Link>
        </nav>
      </div>
      {children}
    </div>
  );
}
