-- Paso 1 de la integración de WhatsApp: solo el add-on habilitable por club.
-- Los mensajes en sí (bienvenida / notificaciones) todavía no se envían —
-- eso es el paso 2, una vez que Meta esté listo.

ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS whatsapp_habilitado BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE clubs
  ADD COLUMN IF NOT EXISTS whatsapp_limite_mensual INTEGER NOT NULL DEFAULT 300;
