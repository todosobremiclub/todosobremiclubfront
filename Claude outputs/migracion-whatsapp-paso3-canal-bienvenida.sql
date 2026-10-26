-- Paso 3 de la integración de WhatsApp: permite elegir canal (email | whatsapp | ambos)
-- al enviar la bienvenida, igual que ya se puede elegir canal en notificaciones.
-- Correr una sola vez, en el mismo lugar donde se corrieron los pasos 1 y 2.

ALTER TABLE bienvenida_envios_programados
  ADD COLUMN IF NOT EXISTS canal VARCHAR(20) NOT NULL DEFAULT 'ambos';
