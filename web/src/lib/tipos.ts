// Tipos de lo que la app lee de la base. Escritos a mano y a proposito
// minimos: solo lo que las pantallas usan. Cuando el esquema se estabilice
// se pueden generar con `supabase gen types`.

export type Club = {
  id: string;
  nombre: string;
  slug: string;
  zona_horaria: string;
  moneda: string;
  logo_url: string | null;
  color_primario: string | null;
  color_secundario: string | null;
};

export type Cancha = {
  id: string;
  nombre: string;
  orden: number;
  deporte: { id: string; nombre: string; duracion_min: number };
};

export type EstadoSlot = "libre" | "ocupado" | "cerrado" | "serie";

// Una fila de fn_disponibilidad.
export type Slot = {
  cancha_id: string;
  inicio: string;
  fin: string;
  estado: EstadoSlot;
  turno_id: string | null;
  turno_cancha_id: string | null;
  cierre_id: string | null;
  serie_id: string | null;
};

export type TipoTurno = "normal" | "fijo" | "clase";

export type TurnoResumen = {
  id: string;
  cancha_id: string;
  tipo: TipoTurno;
  precio: number;
  cliente: { nombre: string; telefono: string };
};

export type SerieResumen = {
  id: string;
  tipo: "fijo" | "clase";
  cliente: { nombre: string };
};

export type CierreResumen = {
  id: string;
  motivo: string;
};

// Lo que el panel lateral necesita de un turno.
export type TurnoDetalle = {
  id: string;
  cancha_id: string;
  tipo: TipoTurno;
  precio: number;
  notas: string | null;
  inicio: string;
  fin: string;
  serie_id: string | null;
  cliente: { id: string; nombre: string; telefono: string };
};

export type SerieDetalle = {
  id: string;
  tipo: "fijo" | "clase";
  hora_inicio: string;
  duracion_min: number;
  vigente_desde: string;
  cliente: { nombre: string; telefono: string };
};

// Una fila de fn_materializar_serie / fn_crear_serie.
export type ResultadoMaterializacion =
  | "creado" | "a_crear" | "ya_existia" | "conflicto" | "conflicto_serie"
  | "cerrado" | "fuera_de_horario" | "sin_tarifa";

export type FilaMaterializacion = {
  fecha: string;
  resultado: ResultadoMaterializacion;
  turno_id: string | null;
  referencia_id: string | null;
  detalle: string | null;
};
