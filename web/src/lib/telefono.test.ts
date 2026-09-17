import { test } from "node:test";
import assert from "node:assert/strict";
import { normalizarTelefono } from "./telefono.ts";

const casos: [string, string | null][] = [
  ["342 555-0101", "+5493425550101"],
  ["3425550101", "+5493425550101"],
  ["0342 15 555 0101", "+5493425550101"],
  ["0342155550101", "+5493425550101"],
  ["11 15 4567 8901", "+5491145678901"],
  ["+54 9 342 555 0101", "+5493425550101"],
  ["+543425550101", "+543425550101"],
  ["0054 342 555 0101", "+543425550101"],
  ["54 9 342 555 0101", "+5493425550101"],
  ["9 342 555 0101", "+5493425550101"],
  ["15 5550-999", null],
  ["hola", null],
  ["", null],
];

for (const [entrada, esperado] of casos) {
  test(`"${entrada}" -> ${esperado}`, () => {
    assert.equal(normalizarTelefono(entrada), esperado);
  });
}
