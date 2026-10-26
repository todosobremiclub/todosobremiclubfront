-- Migración: Notificaciones programadas
-- Correr una sola vez contra la base de datos de producción (Render > tu
-- base Postgres > Query / psql), ANTES de subir el código nuevo, o justo
-- después de subirlo pero antes de que un admin intente programar un envío.

CREATE TABLE IF NOT EXISTS notificaciones_programadas (
  id SERIAL PRIMARY KEY,
  club_id UUID NOT NULL REFERENCES clubs(id),
  titulo TEXT NOT NULL,
  cuerpo TEXT NOT NULL,
  data JSONB,                          -- destino: mismo formato que notificaciones.data
  canal VARCHAR(20) NOT NULL DEFAULT 'app',   -- 'app' | 'whatsapp' | 'ambos'
  tipo_repeticion VARCHAR(20) NOT NULL,       -- 'una_vez' | 'mensual'
  fecha_hora TIMESTAMP,                -- solo si tipo_repeticion = 'una_vez' (UTC)
  dia_mes INTEGER,                     -- solo si tipo_repeticion = 'mensual' (1-31)
  hora TIME,                           -- hora de envío (horario Argentina), formato HH:MM
  proxima_ejecucion TIMESTAMP NOT NULL, -- próxima vez que corresponde disparar (UTC)
  ultima_ejecucion TIMESTAMP,
  activo BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- El worker consulta cada 5 minutos "activo = true AND proxima_ejecucion <= NOW()",
-- este índice hace esa consulta instantánea aunque haya miles de filas.
CREATE INDEX IF NOT EXISTS idx_notificaciones_programadas_pendientes
  ON notificaciones_programadas (activo, proxima_ejecucion);

CREATE INDEX IF NOT EXISTS idx_notificaciones_programadas_club
  ON notificaciones_programadas (club_id, activo);
