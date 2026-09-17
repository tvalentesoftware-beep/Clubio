// Formatos de presentacion. Solo eso: nada de calculos aca.

export function pesos(monto: number | string, moneda = "ARS"): string {
  return new Intl.NumberFormat("es-AR", { style: "currency", currency: moneda, maximumFractionDigits: 0 })
    .format(Number(monto));
}

export function fechaCorta(instante: string, zonaHoraria: string): string {
  return new Intl.DateTimeFormat("es-AR", { timeZone: zonaHoraria, day: "2-digit", month: "2-digit", year: "numeric" })
    .format(new Date(instante));
}

export function fechaHora(instante: string, zonaHoraria: string): string {
  return new Intl.DateTimeFormat("es-AR", {
    timeZone: zonaHoraria, weekday: "short", day: "2-digit", month: "2-digit", hour: "2-digit", minute: "2-digit", hour12: false,
  }).format(new Date(instante));
}
