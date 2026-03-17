/* ============================================================
   Handling Compliance Summary Analysis
   ------------------------------------------------------------
   Purpose:
   Provide aggregated insights on handling compliance over time.

   This query summarizes:
   - total processed items
   - compliant vs non-compliant handling
   - trends across locations and time

   Designed for BI dashboards and monitoring.

   NOTE:
   Dataset names are anonymized for portfolio use.
   ============================================================ */

WITH

/* -----------------------------------------------------------
   FILTERED ORDERS (Recent Data)
----------------------------------------------------------- */
filtered_orders AS (
    SELECT
        order_id,
        origin_location,
        destination_location,
        process_datetime,
        comments,
        shipment_id,
        shipment_type,
        lower(coalesce(comments, '')) AS lc_comments
    FROM dataset_orders
    WHERE process_datetime >= date_add('day', -90, current_date)
      AND shipment_type = 'STANDARD'

      /* Optional BI filters */
      [[ AND {{origin_location}} ]]
      [[ AND {{destination_location}} ]]
),

/* -----------------------------------------------------------
   FILTERED ITEM ATTRIBUTES
----------------------------------------------------------- */
filtered_items AS (
    SELECT
        order_id,
        tracking_id,
        entity_id,
        entity_name,
        item_size,
        dim_length,
        dim_width,
        dim_height
    FROM dataset_item_attributes
),

/* -----------------------------------------------------------
   TAGS (Optional classification)
----------------------------------------------------------- */
tags AS (
    SELECT
        order_id,
        MAX(CASE WHEN lower(tag_name) = 'high_value' THEN 1 ELSE 0 END) AS high_value_flag
    FROM dataset_tags
    GROUP BY order_id
),

/* -----------------------------------------------------------
   JOINED BASE
----------------------------------------------------------- */
scoped AS (
    SELECT
        o.*,
        i.tracking_id,
        i.entity_id,
        i.entity_name,
        i.dim_length,
        i.dim_width,
        i.dim_height,
        coalesce(t.high_value_flag, 0) AS high_value_flag
    FROM filtered_orders o
    JOIN filtered_items i
      ON i.order_id = o.order_id
    LEFT JOIN tags t
      ON t.order_id = o.order_id
),

/* -----------------------------------------------------------
   BASE LOGIC
----------------------------------------------------------- */
base AS (
    SELECT
        sc.process_datetime,
        sc.origin_location,
        sc.destination_location,
        sc.order_id,
        sc.high_value_flag,

        /* Comment-based detection */
        CASE
            WHEN regexp_like(sc.lc_comments, 'box|container|crate')
            THEN 1 ELSE 0
        END AS box_comment_flag,

        CASE
            WHEN regexp_like(sc.lc_comments, 'wrap|plastic|cover')
            THEN 1 ELSE 0
        END AS wrap_comment_flag,

        /* Size-based expectation */
        CASE
            WHEN sc.dim_length IS NOT NULL
             AND sc.dim_width  IS NOT NULL
             AND sc.dim_height IS NOT NULL
             AND greatest(sc.dim_length, sc.dim_width, sc.dim_height) <= 60
            THEN 1 ELSE 0
        END AS box_fit

    FROM scoped sc
),

/* -----------------------------------------------------------
   CLASSIFICATION
----------------------------------------------------------- */
classified AS (
    SELECT
        *,

        CASE
            WHEN box_fit = 1 THEN 'boxed'
            ELSE 'wrapped'
        END AS expected_handling,

        CASE
            WHEN wrap_comment_flag = 1 THEN 'wrapped'
            WHEN box_comment_flag  = 1 THEN 'boxed'
            ELSE 'unknown'
        END AS actual_handling,

        CASE
            WHEN
                (CASE
                    WHEN wrap_comment_flag = 1 THEN 'wrapped'
                    WHEN box_comment_flag  = 1 THEN 'boxed'
                    ELSE 'unknown'
                 END)
                =
                (CASE
                    WHEN box_fit = 1 THEN 'boxed'
                    ELSE 'wrapped'
                 END)
            THEN 'compliant'

            WHEN
                (CASE
                    WHEN wrap_comment_flag = 1 THEN 'wrapped'
                    WHEN box_comment_flag  = 1 THEN 'boxed'
                    ELSE 'unknown'
                 END) IN ('boxed','wrapped')
            THEN 'alternative_handling'

            ELSE 'non_compliant'
        END AS compliance_status

    FROM base
)

/* -----------------------------------------------------------
   FINAL SUMMARY OUTPUT
----------------------------------------------------------- */
SELECT
    date_trunc({{aggregation_level}}, process_datetime) AS period,
    origin_location,
    destination_location,

    COUNT(order_id) AS total_records,

    SUM(CASE WHEN compliance_status = 'compliant' THEN 1 ELSE 0 END) AS compliant,
    SUM(CASE WHEN compliance_status = 'alternative_handling' THEN 1 ELSE 0 END) AS alternative_handling,
    SUM(CASE WHEN compliance_status = 'non_compliant' THEN 1 ELSE 0 END) AS non_compliant

FROM classified

WHERE 1=1
  [[ AND high_value_flag = CAST({{high_value_flag}} AS integer) ]]

GROUP BY
    date_trunc({{aggregation_level}}, process_datetime),
    origin_location,
    destination_location

ORDER BY
    period DESC,
    total_records DESC;
