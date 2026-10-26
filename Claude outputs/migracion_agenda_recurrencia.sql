-- Migración: soporte de recurrencia para agenda_actividades
-- (Agenda / Cumples - actividades recurrentes tipo Outlook)

ALTER TABLE agenda_actividades
  ADD COLUMN IF NOT EXISTS recurrencia_tipo VARCHAR(10) NULL,        -- 'diario' | 'semanal' | 'mensual' | 'anual' (NULL = actividad única)
  ADD COLUMN IF NOT EXISTS recurrencia_intervalo INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS recurrencia_dias_semana INTEGER[] NULL,   -- 0=Domingo .. 6=Sábado (solo aplica a 'semanal')
  ADD COLUMN IF NOT EXISTS recurrencia_hasta DATE NULL;               -- fecha límite de la repetición (opcional)

CREATE INDEX IF NOT EXISTS idx_agenda_actividades_club_activo
  ON agenda_actividades (club_id, activo);
