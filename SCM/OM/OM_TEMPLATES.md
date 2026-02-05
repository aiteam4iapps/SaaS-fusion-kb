# OM Report Templates

**Purpose:** Ready-to-use SQL skeletons for OM reporting.

---

## 1. Sales Order Detail
*List Orders with Line Status.*

```sql
/*
TITLE: Sales Order Detail
PURPOSE: Track order fulfillment status
*/

WITH
-- 1. Headers
HDR AS (
    SELECT /*+ qb_name(H) MATERIALIZE */
           DHA.HEADER_ID, DHA.ORDER_NUMBER, HP.PARTY_NAME
    FROM   DOO_HEADERS_ALL DHA, HZ_PARTIES HP
    WHERE  DHA.BUYING_PARTY_ID = HP.PARTY_ID
),

-- 2. Lines
LNS AS (
    SELECT /*+ qb_name(L) MATERIALIZE */
           DFLA.HEADER_ID, DFLA.ORDERED_QTY, DFLA.STATUS_CODE
    FROM   DOO_FULFILL_LINES_ALL DFLA
)

-- 3. Final Select
SELECT H.ORDER_NUMBER
      ,H.PARTY_NAME
      ,L.ORDERED_QTY
      ,L.STATUS_CODE
FROM   HDR H
      ,LNS L
WHERE  H.HEADER_ID = L.HEADER_ID
```
