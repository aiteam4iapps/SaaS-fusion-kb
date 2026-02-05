# OM Repository Patterns

**Purpose:** Standardized CTEs for extracting Sales Order data.

---

## 1. Order Header Master
*Retrieves Sales Orders with Customer.*

```sql
OM_HEADER_MASTER AS (
    SELECT /*+ qb_name(OM_HDR) MATERIALIZE */
           DHA.HEADER_ID
          ,DHA.ORDER_NUMBER
          ,DHA.ORDERED_DATE
          ,DHA.SUBMITTED_DATE
          ,DHA.STATUS_CODE
          ,HP.PARTY_NAME AS CUSTOMER_NAME
    FROM   DOO_HEADERS_ALL DHA
          ,HZ_PARTIES HP
    WHERE  DHA.BUYING_PARTY_ID = HP.PARTY_ID
      AND  (DHA.ORG_ID IN (:P_BU_ID) OR 'All' IN (:P_BU_ID || 'All'))
)
```

---

## 2. Fulfillment Lines (Detailed)
*Retrieves line-level status and item details.*

```sql
OM_LINE_MASTER AS (
    SELECT /*+ qb_name(OM_LINE) MATERIALIZE */
           DFLA.HEADER_ID
          ,DFLA.LINE_ID
          ,DFLA.FULFILL_LINE_ID
          ,DFLA.FULFILLMENT_MODE
          ,DFLA.STATUS_CODE AS LINE_STATUS
          ,DFLA.ORDERED_QTY
          ,DFLA.SHIPPED_QTY
    FROM   DOO_FULFILL_LINES_ALL DFLA
)
```
