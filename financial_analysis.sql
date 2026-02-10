/* ============================================================
   1. Exploratory Data Analysis (EDA) / Anális exploratoria de datos
   ============================================================ */


SELECT * FROM ventas_2017 LIMIT 10;
SELECT * FROM productos LIMIT 10;
SELECT * FROM productos_categorias LIMIT 10;
SELECT * FROM territorios LIMIT 10;
SELECT * FROM campanas LIMIT 10;


/* ============================================================
   2. Join core tables and calculate revenue & cost per order /
     Joins y cálculo de ingresos y costos por pedido
   ============================================================ */

-- Combine sales, products, territories, and categories
-- COALESCE is used to handle NULL values during calculations

CREATE OR REPLACE VIEW ventas_clean AS
SELECT
    v.numero_pedido,
    v.clave_producto,
    p.nombre_producto,
    pc.clave_categoria,
    p.precio_producto,
    v.cantidad_pedido,
    p.costo_producto,
    t.pais,
    t.continente,
    v.clave_territorio,
    COALESCE(v.cantidad_pedido, 0) * COALESCE(p.precio_producto, 0) AS ingreso_total,
    COALESCE(v.cantidad_pedido, 0) * COALESCE(p.costo_producto, 0) AS costo_total
FROM ventas_2017 v
LEFT JOIN productos p
    ON v.clave_producto = p.clave_producto
LEFT JOIN territorios t
    ON t.clave_territorio = v.clave_territorio
LEFT JOIN productos_categorias pc
    ON pc.clave_subcategoria = p.clave_subcategoria;


/* ============================================================
   3. Aggregate revenue and cost by country and territory /
        Agrupación de ingresos y costos por país y territorio
   ============================================================ */

CREATE OR REPLACE VIEW pais_ingreso_costo AS
SELECT
    pais,
    clave_territorio,
    SUM(ingreso_total)::INTEGER AS ingresos,
    SUM(costo_total)::INTEGER AS costos
FROM ventas_clean
GROUP BY pais, clave_territorio;


/* ============================================================
   4. Add marketing campaign costs / Cálcul|o de costos de campañas de marketing
   ============================================================ */

CREATE OR REPLACE VIEW pais_campanas AS
SELECT
    v.pais,
    v.clave_territorio,
    SUM(v.ingreso_total)::INTEGER AS ingresos,
    SUM(v.costo_total)::INTEGER AS costos,
    SUM(COALESCE(c.costo_campana, 0))::INTEGER AS costo_campana
FROM ventas_clean v
LEFT JOIN campanas c
    ON v.clave_territorio = c.clave_territorio::INTEGER
GROUP BY v.pais, v.clave_territorio;


/* ============================================================
   5. Final financial metrics by territory / Métricas financieras finales por territorio
   ============================================================ */

SELECT
    p.pais,
    p.clave_territorio,
    SUM(p.ingresos)::INTEGER AS ingresos,
    SUM(p.costos)::INTEGER AS costos,
    COALESCE(SUM(c.costo_campana), 0)::INTEGER AS costo_campana,

    -- Gross profit
    (SUM(p.ingresos) - SUM(p.costos))::INTEGER AS beneficio_bruto,

    -- Margin %
    ((SUM(p.ingresos) - SUM(p.costos)) * 100.0)
        / NULLIF(SUM(p.ingresos), 0) AS margen_pct,

    -- ROI %
    ((SUM(p.ingresos) - SUM(p.costos)) * 100.0)
        / NULLIF(SUM(c.costo_campana), 0) AS roi_pct

FROM pais_ingreso_costo p
LEFT JOIN pais_campanas c
    ON p.clave_territorio = c.clave_territorio
GROUP BY p.pais, p.clave_territorio
ORDER BY ingresos DESC;
