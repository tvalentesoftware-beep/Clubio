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
