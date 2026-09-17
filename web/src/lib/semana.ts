// Fechas como texto "YYYY-MM-DD" y aritmetica en UTC a proposito: el dia
// del club no depende de la zona horaria del servidor, y la hora local de
// cada slot se formatea con Intl usando la zona del club.

const DIAS = ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"];
const MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];

export function hoyEn(zonaHoraria: string): string {
  return new Intl.DateTimeFormat("en-CA", { timeZone: zonaHoraria }).format(new Date());
}

function aUTC(fecha: string): Date {
  const [a, m, d] = fecha.split("-").map(Number);
  return new Date(Date.UTC(a, m - 1, d));
}

function aTexto(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function sumarDias(fecha: string, dias: number): string {
  const d = aUTC(fecha);
  d.setUTCDate(d.getUTCDate() + dias);
  return aTexto(d);
}

// El lunes de la semana que contiene la fecha.
export function lunesDe(fecha: string): string {
  const d = aUTC(fecha);
  const dow = d.getUTCDay(); // 0 = domingo
  return sumarDias(fecha, dow === 0 ? -6 : 1 - dow);
}

export function diasDeSemana(lunes: string): string[] {
  return Array.from({ length: 7 }, (_, i) => sumarDias(lunes, i));
}

export function esFechaValida(s: string | undefined): s is string {
  return !!s && /^\d{4}-\d{2}-\d{2}$/.test(s) && !isNaN(aUTC(s).getTime());
}

// "lun 14"
export function etiquetaDia(fecha: string): string {
  const d = aUTC(fecha);
  return `${DIAS[d.getUTCDay()]} ${d.getUTCDate()}`;
}

// "14 al 20 de sep de 2026"
export function etiquetaSemana(lunes: string): string {
  const a = aUTC(lunes);
  const b = aUTC(sumarDias(lunes, 6));
  const mesA = MESES[a.getUTCMonth()];
  const mesB = MESES[b.getUTCMonth()];
  return mesA === mesB
    ? `${a.getUTCDate()} al ${b.getUTCDate()} de ${mesB} de ${b.getUTCFullYear()}`
    : `${a.getUTCDate()} de ${mesA} al ${b.getUTCDate()} de ${mesB} de ${b.getUTCFullYear()}`;
}

// Fecha local y hora local de un instante, en la zona del club.
export function localDe(instante: string, zonaHoraria: string): { dia: string; hora: string } {
  const d = new Date(instante);
  const dia = new Intl.DateTimeFormat("en-CA", { timeZone: zonaHoraria }).format(d);
  const hora = new Intl.DateTimeFormat("es-AR", {
    timeZone: zonaHoraria,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(d);
  return { dia, hora };
}

// "GMT-03:00" -> "-03:00". El offset de la zona del club para un instante
// dado; hace falta para armar un timestamptz local sin depender del server.
function offsetDe(instante: Date, zonaHoraria: string): string {
  const partes = new Intl.DateTimeFormat("en-US", { timeZone: zonaHoraria, timeZoneName: "longOffset" })
    .formatToParts(instante);
  const nombre = partes.find((p) => p.type === "timeZoneName")?.value ?? "GMT";
  const m = nombre.match(/GMT([+-]\d{2}:\d{2})?/);
  return m?.[1] ?? "+00:00";
}

// Fecha y hora locales del club -> instante ISO con offset ("2026-09-17T15:00:00-03:00").
// Dos pasadas por si el offset cambia justo ese dia (horario de verano).
export function instanteLocal(fecha: string, hora: string, zonaHoraria: string): string {
  let offset = offsetDe(new Date(`${fecha}T${hora}:00Z`), zonaHoraria);
  offset = offsetDe(new Date(`${fecha}T${hora}:00${offset}`), zonaHoraria);
  return `${fecha}T${hora}:00${offset}`;
}
