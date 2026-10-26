-- Paso 2 de la integración de WhatsApp: tabla de log de mensajes + columnas
-- que usa el código de envío real (bienvenida y notificaciones).
-- Correr una sola vez, en el mismo lugar donde se corrió migracion-whatsapp-paso1.sql.

-- Marca de bienvenida enviada por WhatsApp (independiente del email)
ALTER TABLE socios
  ADD COLUMN IF NOT EXISTS bienvenida_whatsapp_enviada_at TIMESTAMP NULL;

-- Canal elegido al crear una notificación (app | whatsapp | ambos)
ALTER TABLE notificaciones
  ADD COLUMN IF NOT EXISTS canal VARCHAR(20) NOT NULL DEFAULT 'app';

-- Log de cada mensaje de WhatsApp enviado (para historial + conteo de cupo mensual).
-- club_id / socio_id / notificacion_id son UUID (clubs.id y socios.id son uuid).
CREATE TABLE IF NOT EXISTS whatsapp_mensajes (
  id SERIAL PRIMARY KEY,
  club_id UUID NOT NULL REFERENCES clubs(id),
  socio_id UUID NULL REFERENCES socios(id),
  notificacion_id UUID NULL REFERENCES notificaciones(id),
  tipo VARCHAR(30) NOT NULL,          -- 'bienvenida' | 'notificacion'
  telefono VARCHAR(30) NOT NULL,
  template_name VARCHAR(60) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'enviado', -- enviado | entregado | leido | fallido
  wa_message_id VARCHAR(80) NULL,
  error TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_whatsapp_mensajes_club_mes
  ON whatsapp_mensajes (club_id, created_at);
