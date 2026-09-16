import { salir } from "@/app/login/acciones";

export default function SinClub() {
  return (
    <main className="min-h-screen grid place-items-center bg-slate-50 p-6 text-center">
      <div className="max-w-md">
        <h1 className="text-lg font-semibold text-slate-900">Tu usuario no tiene ningún club asignado</h1>
        <p className="mt-2 text-sm text-slate-600">
          Pedile al administrador de Clubio que te vincule al club, y volvé a entrar.
        </p>
        <form action={salir} className="mt-6">
          <button className="rounded-lg border border-slate-300 px-4 py-2 text-sm text-slate-700 hover:bg-white">
            Salir
          </button>
        </form>
      </div>
    </main>
  );
}
