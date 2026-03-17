/* ============================================================
   Handling Compliance Analysis
   ------------------------------------------------------------
   Purpose:
   Analyze whether items are handled according to expected
   packaging rules based on size/dimensions vs actual handling
   behavior recorded in text comments.

   This query demonstrates:
   - text pattern detection
   - rule-based classification
   - expected vs actual comparison
   - compliance evaluation

   NOTE:
   All dataset names are anonymized for portfolio use.
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
),

/* -----------------------------------------------------------
   FILTERED ITEM ATTRIBUTES
----------------------------------------------------------- */
filtered_items AS (
    SELECT
        order_id,
        tracking_id,
        flag_return,
        entity_id,
        entity_name,
        item_size,
        dim_length,
        dim_width,
        dim_height
    FROM dataset_item_attributes
),

/* -----------------------------------------------------------
   TAGS (Row-level classification)
----------------------------------------------------------- */
tags AS (
    SELECT
        order_id,
        MAX(CASE WHEN lower(tag_name) = 'high_value' THEN 1 ELSE 0 END) AS high_value_flag,
        MAX(CASE WHEN lower(tag_name) = 'business'   THEN 1 ELSE 0 END) AS business_flag
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
        i.item_size,
        i.dim_length,
        i.dim_width,
        i.dim_height,
        coalesce(t.high_value_flag, 0) AS high_value_flag,
        coalesce(t.business_flag, 0)   AS business_flag
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
        sc.*,

        /* Detect keywords in comments */
        CASE
            WHEN regexp_like(sc.lc_comments, 'box|container|crate')
            THEN 1 ELSE 0
        END AS box_comment_flag,

        CASE
            WHEN regexp_like(sc.lc_comments, 'wrap|plastic|cover')
            THEN 1 ELSE 0
        END AS wrap_comment_flag,

        /* Dimension-based classification */
        CASE
            WHEN sc.dim_length IS NOT NULL
             AND sc.dim_width  IS NOT NULL
             AND sc.dim_height IS NOT NULL
             AND (
                    /* Small container fit */
                    greatest(sc.dim_length, sc.dim_width, sc.dim_height) <= 60
                )
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

        /* Expected handling based on size */
        CASE
            WHEN box_fit = 1 THEN 'boxed'
            ELSE 'wrapped'
        END AS expected_handling,

        /* Actual handling from text */
        CASE
            WHEN wrap_comment_flag = 1 THEN 'wrapped'
            WHEN box_comment_flag  = 1 THEN 'boxed'
            ELSE 'unknown'
        END AS actual_handling,

        /* Compliance logic */
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
   FINAL OUTPUT
----------------------------------------------------------- */
SELECT
    process_datetime,
    order_id,
    tracking_id,
    shipment_id,
    origin_location,
    destination_location,
    entity_id,
    entity_name,
    high_value_flag,
    business_flag,
    comments,
    expected_handling,
    actual_handling,
    compliance_status

FROM classified

ORDER BY process_datetime DESC;
