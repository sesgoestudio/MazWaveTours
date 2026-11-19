-- MazWaveTours: inicializar una sola vez los contadores persistentes.
-- Ejecutar una vez en Supabase > SQL Editor.
UPDATE public.site_config AS sc
SET data = jsonb_set(
    COALESCE(sc.data, '{}'::jsonb),
    '{catalogCounts}',
    (
        SELECT jsonb_build_object(
            'all', COUNT(*),
            'trimaran', COUNT(*) FILTER (WHERE category_key ~ '(trim|catamaran)'),
            'yate', COUNT(*) FILTER (WHERE category_key ~ '(yate|lancha|boat|barco)'),
            'tour', COUNT(*) FILTER (WHERE category_key !~ '(trim|catamaran|yate|lancha|boat|barco)')
        )
        FROM (
            SELECT lower(COALESCE(
                NULLIF(item->>'category', ''),
                NULLIF(item->>'type', ''),
                NULLIF(item->>'tipo', ''),
                NULLIF(item->>'category_name', ''),
                NULLIF(item->>'name', ''),
                ''
            )) AS category_key
            FROM jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(sc.data->'items') = 'array' THEN sc.data->'items'
                    ELSE '[]'::jsonb
                END
            ) AS item
        ) AS catalog_items
    ),
    true
)
WHERE sc.id = 1;
