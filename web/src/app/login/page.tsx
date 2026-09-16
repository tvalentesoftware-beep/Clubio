import Image from "next/image";
import { ingresar } from "./acciones";

export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  const { error } = await searchParams;

  return (
    <main className="min-h-screen grid place-items-center bg-slate-50 p-6">
      <form
        action={ingresar}
        className="w-full max-w-sm rounded-2xl bg-white p-8 shadow-sm ring-1 ring-slate-200"
      >
        <div className="mb-6 flex items-center gap-3">
          <Image src="/clubio.png" alt="" width={40} height={40} priority />
          <div>
            <h1 className="text-lg font-semibold text-slate-900">Clubio</h1>
            <p className="text-sm text-slate-500">Panel del club</p>
          </div>
        </div>

        <label className="block text-sm font-medium text-slate-700">
          Mail
          <input
            name="email"
            type="email"
            required
            autoComplete="email"
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-slate-900 outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
          />
        </label>

        <label className="mt-4 block text-sm font-medium text-slate-700">
          Contraseña
          <input
            name="password"
            type="password"
            required
            autoComplete="current-password"
            className="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2 text-slate-900 outline-none focus:border-sky-500 focus:ring-2 focus:ring-sky-100"
          />
        </label>

        {error && (
          <p className="mt-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">
            Mail o contraseña incorrectos.
          </p>
        )}

        <button
          type="submit"
          className="mt-6 w-full rounded-lg bg-sky-600 px-4 py-2.5 font-medium text-white hover:bg-sky-700"
        >
          Entrar
        </button>
      </form>
    </main>
  );
}
