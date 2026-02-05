# Sourcing/Negotiations Repository Patterns

**Purpose:** Standardized CTEs for extracting Negotiation/Sourcing data.

---

## 1. Negotiation Header Master
*Retrieves all Negotiation Headers with basic information.*

```sql
NEGOTIATION_HEADER_MASTER AS (
    SELECT /*+ qb_name(NEG_HDR) MATERIALIZE PARALLEL(2) */
           PAH.AUCTION_HEADER_ID
          ,PAH.DOCUMENT_NUMBER AS NEGOTIATION_NUMBER
          ,PAH.AUCTION_TITLE AS NEGOTIATION_TITLE
          ,PAH.AUCTION_STATUS AS NEGOTIATION_STATUS
          ,PAH.OPEN_BIDDING_DATE AS NEGOTIATION_OPEN_DATE
          ,PAH.CLOSE_BIDDING_DATE AS NEGOTIATION_CLOSED_DATE
    FROM   PON_AUCTION_HEADERS_ALL PAH
    WHERE  1=1
      AND  (P.NEGOTIATION_NUMBER IS NULL OR PAH.DOCUMENT_NUMBER = P.NEGOTIATION_NUMBER)
      AND  (P.OPEN_DATE_FROM IS NULL OR TRUNC(PAH.OPEN_BIDDING_DATE) >= P.OPEN_DATE_FROM)
      AND  (P.OPEN_DATE_TO IS NULL OR TRUNC(PAH.OPEN_BIDDING_DATE) <= P.OPEN_DATE_TO)
)
```

---

## 2. Negotiation Line Master
*Retrieves negotiation lines with item details and pricing.*

```sql
NEGOTIATION_LINE_MASTER AS (
    SELECT /*+ qb_name(NEG_LINE) MATERIALIZE */
           PAIP.AUCTION_HEADER_ID
          ,PAIP.LINE_NUMBER AS NEGOTIATION_LINE_NUMBER
          ,PAIP.ITEM_DESCRIPTION AS NEGOTIATION_LINE_DESCRIPTION
          ,PAIP.ORDER_TYPE_LOOKUP_CODE AS LINE_TYPE
          ,PAIP.CATEGORY_ID
          ,PAIP.REQUESTED_DELIVERY_DATE
          ,PAIP.CURRENT_PRICE
          ,PAIP.REQUISITION_NUMBER AS PR_NUMBER
    FROM   PON_AUCTION_ITEM_PRICES_ALL PAIP
)
```

**Key Points:**
- Use `PON_AUCTION_ITEM_PRICES_ALL` (NOT `PON_AUCTION_LINES_ALL`)
- `REQUISITION_NUMBER` is directly available (no join needed)
- Use `ITEM_DESCRIPTION` (NOT `DESCRIPTION`)
- Use `ORDER_TYPE_LOOKUP_CODE` for line type
- Use `REQUESTED_DELIVERY_DATE` (NOT `NEED_BY_DATE`)
- Use `CURRENT_PRICE` (NOT `UNIT_PRICE`)

---

## 3. Category Master
*Retrieves category names for negotiation lines.*

```sql
CATEGORY_MASTER AS (
    SELECT /*+ qb_name(CAT_MST) MATERIALIZE */
           ECV.CATEGORY_ID
          ,ECV.CATEGORY_NAME
    FROM   EGP_CATEGORIES_VL ECV
)
```

---

## 4. PR Header Master (for BU Link)
*Retrieves PR headers for BU filtering and BU name.*

```sql
PR_HEADER_MASTER AS (
    SELECT /*+ qb_name(PR_HDR) MATERIALIZE */
           PRHA.REQUISITION_HEADER_ID
          ,PRHA.REQUISITION_NUMBER AS PR_NUMBER
          ,PRHA.REQ_BU_ID
    FROM   POR_REQUISITION_HEADERS_ALL PRHA
    WHERE  (P.REQ_BU_NAME IS NULL OR EXISTS (
              SELECT 1 FROM HR_ALL_ORGANIZATION_UNITS HAOU
              WHERE HAOU.ORGANIZATION_ID = PRHA.REQ_BU_ID
                AND UPPER(HAOU.NAME) = UPPER(P.REQ_BU_NAME)
            ))
)
```

**Note:** This CTE is only needed when filtering by BU or displaying BU name. PR Number is already available directly from `PON_AUCTION_ITEM_PRICES_ALL`.

---

