// Normaliza un telefono a formato internacional (+549342...), con criterio
// argentino. Es la unica puerta por la que un telefono entra a la base
// (ADR 0006): el indice unico por club no alcanza si el mismo numero se
// escribe de tres maneras.
//
// Casos que cubre, todos escritos como los escribe la gente:
//   "342 555-0101"          -> +5493425550101   (area + numero, se asume celular)
//   "0342 15 555 0101"      -> +5493425550101   (0 de larga distancia y 15 de celular)
//   "11 15 4567 8901"       -> +5491145678901   (Buenos Aires, area de 2 digitos)
//   "+54 9 342 555 0101"    -> +5493425550101   (ya internacional)
//   "0054 342 555 0101"     -> +543425550101    (00 en vez de +)
//
// Devuelve null si no se puede interpretar. Mejor rechazar que guardar
// cualquier cosa.

export function normalizarTelefono(entrada: string, pais = "54"): string | null {
  const bruto = entrada.trim();
  if (!bruto) return null;

  const internacional = bruto.startsWith("+") || bruto.startsWith("00");
  let d = bruto.replace(/\D/g, "");

  if (internacional) {
    if (bruto.startsWith("00")) d = d.slice(2);
    return d.length >= 8 && d.length <= 15 ? `+${d}` : null;
  }

  // Nacional. Fuera el 0 de larga distancia.
  if (d.startsWith("0")) d = d.slice(1);

  // Alguien escribio el codigo de pais sin el +.
  if (d.startsWith(pais) && d.length >= 12) return `+${d}`;

  // El 15 del celular va entre el area y el numero; el area tiene 2, 3 o 4
  // digitos. Con 12 digitos en total, alguna de las tres posiciones lo tiene.
  if (d.length === 12) {
    for (const corte of d.startsWith("11") ? [2] : [3, 4, 2]) {
      if (d.slice(corte, corte + 2) === "15") {
        d = d.slice(0, corte) + d.slice(corte + 2);
        break;
      }
    }
  }

  if (d.length === 10) return `+${pais}9${d}`;   // area + numero: celular
  if (d.length === 11 && d.startsWith("9")) return `+${pais}${d}`;

  return null;
}
