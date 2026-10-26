-- ============================================================
-- Corrección de categoría por edad — Club Cultural Social y
-- Deportivo Cóndor
--
-- Contexto: una subida masiva de socios tomó mal un dato de la
-- plantilla y dejó cargado el texto literal "[object Object]" en
-- socios.categoria en vez del nombre real de la categoría.
--
-- Esta corrección:
--   - Toma SOLO los socios cuya categoría quedó como "[object Object]".
--   - Calcula la edad actual a partir de fecha_nacimiento.
--   - Excluye a propósito los socios con fecha_nacimiento del año 1899
--     (valor por defecto de la plantilla rota, no una fecha real) —
--     esos quedan sin tocar hasta que tengas el dato correcto.
--   - 0 a 9 años  -> categoría "MENOR (0 A 10 años)"
--   - 10 a 17 años -> categoría "CADETE (10 A 17 años)"
--
-- Los nombres de categoría deben coincidir EXACTO con los que ya
-- existen en la sección Configuración > Categorías deportivas de
-- este club (los verificamos en pantalla: "CADETE (10 A 17 años)",
-- "MAYOR (+18)", "MENOR (0 A 10 años)"). Si en tu base están escritos
-- con mayúsculas/tildes distintas, avisame antes de correr el UPDATE.
-- ============================================================


-- 1) VERIFICACIÓN — Corré esto primero y revisá la lista antes de
--    tocar nada. Te muestra cada socio afectado, su edad calculada,
--    y qué categoría le asignaría el UPDATE de abajo.
SELECT
  s.id,
  s.numero_socio,
  s.dni,
  s.apellido,
  s.nombre,
  s.fecha_nacimiento,
  DATE_PART('year', AGE(CURRENT_DATE, s.fecha_nacimiento))::int AS edad_actual,
  CASE
    WHEN DATE_PART('year', AGE(CURRENT_DATE, s.fecha_nacimiento)) BETWEEN 0 AND 9
      THEN 'MENOR (0 A 10 años)'
    WHEN DATE_PART('year', AGE(CURRENT_DATE, s.fecha_nacimiento)) BETWEEN 10 AND 17
      THEN 'CADETE (10 A 17 años)'
    ELSE '(fuera de rango 0-17, no se toca)'
  END AS categoria_nueva
FROM socios s
JOIN clubs c ON c.id = s.club_id
WHERE c.name = 'Club Cultural Social y Deportivo Cóndor'
  AND s.categoria = '[object Object]'
  AND s.fecha_nacimiento IS NOT NULL
  AND EXTRACT(YEAR FROM s.fecha_nacimiento) <> 1899
ORDER BY edad_actual;


-- 2) Cuántos socios de este club quedan con "[object Object]" y
--    fecha_nacimiento = 1899 (los que NO se van a tocar con este
--    script, porque no se puede confiar en esa fecha). Para
--    corregirlos hay que pasarme la fecha de nacimiento real de
--    cada uno.
SELECT
  s.id, s.numero_socio, s.dni, s.apellido, s.nombre, s.fecha_nacimiento
FROM socios s
JOIN clubs c ON c.id = s.club_id
WHERE c.name = 'Club Cultural Social y Deportivo Cóndor'
  AND s.categoria = '[object Object]'
  AND (s.fecha_nacimiento IS NULL OR EXTRACT(YEAR FROM s.fecha_nacimiento) = 1899)
ORDER BY s.apellido, s.nombre;


-- 3) UPDATE — Menores (0 a 9 años). Corré esto recién después de
--    revisar el resultado del paso 1.
UPDATE socios s
SET categoria = 'MENOR (0 A 10 años)'
FROM clubs c
WHERE c.id = s.club_id
  AND c.name = 'Club Cultural Social y Deportivo Cóndor'
  AND s.categoria = '[object Object]'
  AND s.fecha_nacimiento IS NOT NULL
  AND EXTRACT(YEAR FROM s.fecha_nacimiento) <> 1899
  AND DATE_PART('year', AGE(CURRENT_DATE, s.fecha_nacimiento)) BETWEEN 0 AND 9;


-- 4) UPDATE — Cadetes (10 a 17 años).
UPDATE socios s
SET categoria = 'CADETE (10 A 17 años)'
FROM clubs c
WHERE c.id = s.club_id
  AND c.name = 'Club Cultural Social y Deportivo Cóndor'
  AND s.categoria = '[object Object]'
  AND s.fecha_nacimiento IS NOT NULL
  AND EXTRACT(YEAR FROM s.fecha_nacimiento) <> 1899
  AND DATE_PART('year', AGE(CURRENT_DATE, s.fecha_nacimiento)) BETWEEN 10 AND 17;


-- 5) VERIFICACIÓN FINAL — confirmá que ya no queda ningún socio con
--    "[object Object]" salvo los de fecha_nacimiento = 1899 (paso 2).
SELECT s.categoria, COUNT(*)
FROM socios s
JOIN clubs c ON c.id = s.club_id
WHERE c.name = 'Club Cultural Social y Deportivo Cóndor'
GROUP BY s.categoria
ORDER BY s.categoria;
