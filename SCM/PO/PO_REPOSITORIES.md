# Purchasing Repository Patterns

**Purpose:** Standardized CTEs for extracting PO data.

---

## 1. PO Master (Headers & Suppliers)
*Retrieves all PO Headers with Supplier details.*

```sql
PO_MASTER AS (
    SELECT /*+ qb_name(PO_MST) MATERIALIZE */
           PHA.PO_HEADER_ID
          ,PHA.SEGMENT1 AS PO_NUMBER
          ,PHA.TYPE_LOOKUP_CODE
          ,PHA.PRC_BU_ID
          ,POS.VENDOR_NAME
          ,PHA.CURRENCY_CODE
          ,PHA.CREATION_DATE
    FROM   PO_HEADERS_ALL PHA
          ,POZ_SUPPLIERS_V POS
    WHERE  PHA.VENDOR_ID = POS.VENDOR_ID
      AND  (PHA.PRC_BU_ID IN (:P_BU_ID) OR 'All' IN (:P_BU_ID || 'All'))
)
```

---

## 2. Open PO Lines (Shipments)
*Retrieves lines with open quantity to receive.*

```sql
PO_OPEN_LINES AS (
    SELECT /*+ qb_name(PO_OPEN) MATERIALIZE */
           PLLA.PO_HEADER_ID
          ,PLLA.PO_LINE_ID
          ,PLLA.LINE_LOCATION_ID
          ,PLA.ITEM_DESCRIPTION
          ,PLLA.QUANTITY
          ,PLLA.QUANTITY_RECEIVED
          ,PLLA.QUANTITY_BILLED
          ,(PLLA.QUANTITY - NVL(PLLA.QUANTITY_RECEIVED, 0)) AS QTY_REMAINING
    FROM   PO_LINES_ALL PLA
          ,PO_LINE_LOCATIONS_ALL PLLA
    WHERE  PLA.PO_LINE_ID = PLLA.PO_LINE_ID
      AND  NVL(PLLA.CANCEL_FLAG, 'N') = 'N'
      AND  PLLA.CLOSED_CODE NOT IN ('CLOSED', 'FINALLY CLOSED')
)
```

---

## 3. Receiving Master
*Retrieves Receipts and Deliveries. Two patterns available based on use case.*

### Pattern A: Basic Receipt (Standard)
*For standard receiving reports.*

```sql
PO_RCV_MASTER AS (
    SELECT /*+ qb_name(RCV) MATERIALIZE */
           RSH.RECEIPT_NUM
          ,RT.TRANSACTION_DATE
          ,RT.QUANTITY
          ,RT.PO_HEADER_ID
          ,RT.PO_LINE_ID
    FROM   RCV_TRANSACTIONS RT
          ,RCV_SHIPMENT_HEADERS RSH
    WHERE  RT.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
      AND  RT.TRANSACTION_TYPE = 'DELIVER' -- Put away to stock
)
```

### Pattern B: Receipt with Amount and RCV Link (P2P)
*For P2P reports linking Receipts to Invoices via RCV_TRANSACTION_ID.*

```sql
RECEIPT_MASTER AS (
    SELECT /*+ qb_name(RCV_MST) MATERIALIZE PARALLEL(2) */
           RT.PO_HEADER_ID
          ,RT.PO_LINE_ID
          ,RT.PO_LINE_LOCATION_ID
          ,RSH.RECEIPT_NUM AS RECEIPT_NUMBER
          ,TO_CHAR(RT.TRANSACTION_DATE, 'YYYY-MM-DD') AS RECEIPT_DATE
          ,ROUND(CASE 
              WHEN RSL.QUANTITY_DELIVERED > 0 
              THEN (RT.QUANTITY * RT.PO_UNIT_PRICE)
              ELSE NVL(RSL.AMOUNT_RECEIVED, 0)
            END, 2) AS RECEIPT_AMOUNT
          ,RT.TRANSACTION_ID
    FROM   RCV_TRANSACTIONS RT
          ,RCV_SHIPMENT_HEADERS RSH
          ,RCV_SHIPMENT_LINES RSL
    WHERE  RT.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
      AND  RT.SHIPMENT_LINE_ID = RSL.SHIPMENT_LINE_ID
      AND  RT.TRANSACTION_TYPE = 'RECEIVE' -- Receipt transaction (NOT 'DELIVER')
)
```

**Key Differences:**
- **Transaction Type:** `'RECEIVE'` for P2P (links to invoices), `'DELIVER'` for standard receiving
- **RCV_SHIPMENT_LINES:** Required for accurate receipt amounts in P2P
- **TRANSACTION_ID:** Critical for linking receipts to invoices via `AP_INVOICE_LINES_ALL.RCV_TRANSACTION_ID`

---

## 4. Supplier Contact Master
*Retrieves supplier contacts (name and email) with one contact per vendor/site.*

```sql
SUPPLIER_CONTACT_MASTER AS (
    SELECT /*+ qb_name(SUPP_CONT) MATERIALIZE */
           VENDOR_ID
          ,VENDOR_SITE_ID
          ,CONTACT_NAME
          ,SUPPLIER_EMAIL
    FROM   (
        SELECT PSC.VENDOR_ID
              ,PSC.VENDOR_SITE_ID
              ,PSC.FULL_NAME AS CONTACT_NAME
              ,PSC.EMAIL_ADDRESS AS SUPPLIER_EMAIL
              ,ROW_NUMBER() OVER (PARTITION BY PSC.VENDOR_ID, PSC.VENDOR_SITE_ID ORDER BY PSC.VENDOR_ID, PSC.VENDOR_SITE_ID) AS RN
        FROM   POZ_SUPPLIER_CONTACTS_V PSC
        WHERE  NVL(PSC.INACTIVE_DATE, SYSDATE + 1) > SYSDATE
    )
    WHERE  RN = 1
)
```

---

## 5. PR Distribution Master (PO to PR Link)
*Links PO distributions to PR via POR_REQ_DISTRIBUTIONS_ALL.*

```sql
PR_DISTRIBUTION_MASTER AS (
    SELECT /*+ qb_name(PR_DIST) MATERIALIZE */
           PRDA.DISTRIBUTION_ID
          ,PRLA.REQUISITION_HEADER_ID
          ,PRLA.REQUISITION_LINE_ID
          ,PRLA.REQUESTER_ID
          ,ROW_NUMBER() OVER (PARTITION BY PRDA.DISTRIBUTION_ID ORDER BY PRLA.REQUISITION_HEADER_ID) AS RN
    FROM   POR_REQ_DISTRIBUTIONS_ALL PRDA
          ,POR_REQUISITION_LINES_ALL PRLA
    WHERE  PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
)
```

---

## 6. PO Tax Aggregate
*Sums recoverable tax from distributions per line location.*

```sql
PO_TAX_AGGREGATE AS (
    SELECT /*+ qb_name(PO_TAX) MATERIALIZE */
           PDA.PO_HEADER_ID
          ,PDA.PO_LINE_ID
          ,PDA.LINE_LOCATION_ID
          ,SUM(NVL(PDA.RECOVERABLE_TAX, 0)) AS TOTAL_RECOVERABLE_TAX
    FROM   PO_DISTRIBUTIONS_ALL PDA
    GROUP BY PDA.PO_HEADER_ID
            ,PDA.PO_LINE_ID
            ,PDA.LINE_LOCATION_ID
)
```

---

## 7. PR Master (Header with Date Filter)
*Retrieves PR headers filtered by creation date range.*

```sql
PR_MASTER AS (
    SELECT /*+ qb_name(PR_MST) MATERIALIZE PARALLEL(2) */
           PRHA.REQUISITION_HEADER_ID
          ,PRHA.REQUISITION_NUMBER
          ,PRHA.DESCRIPTION AS PR_DESCRIPTION
          ,PRHA.CREATION_DATE AS PR_CREATION_DATE
          ,PRHA.DOCUMENT_STATUS AS PR_STATUS_CODE
    FROM   POR_REQUISITION_HEADERS_ALL PRHA
    WHERE  TRUNC(PRHA.CREATION_DATE) BETWEEN TRUNC(:P_PR_FROM_DATE) 
                                        AND TRUNC(:P_PR_TO_DATE)
)
```

---

## 8. PR Lines with Amount Calculation
*Retrieves PR lines with calculated amounts using ASSESSABLE_VALUE with fallback logic.*

```sql
PR_LINES AS (
    SELECT /*+ qb_name(PR_LN) MATERIALIZE PARALLEL(2) */
           PRLA.REQUISITION_HEADER_ID
          ,PRLA.REQUISITION_LINE_ID
          ,PRLA.LINE_NUMBER
          ,PRLA.REQUESTER_ID
          ,PRLA.PO_HEADER_ID
          ,ROUND(NVL(PRLA.ASSESSABLE_VALUE, 
                CASE 
                    WHEN PRLA.CURRENCY_UNIT_PRICE IS NOT NULL AND PRLA.QUANTITY IS NOT NULL 
                    THEN (PRLA.CURRENCY_UNIT_PRICE * PRLA.QUANTITY * NVL(PRLA.RATE, 1))
                    ELSE NVL(PRLA.CURRENCY_AMOUNT, 0) * NVL(PRLA.RATE, 1)
                END), 2) AS REQUISITION_AMOUNT
    FROM   POR_REQUISITION_LINES_ALL PRLA
)
```

---

## 9. PR Distributions (Charge Account)
*Retrieves PR distributions with charge account (CODE_COMBINATION_ID).*

```sql
PR_DISTRIBUTIONS AS (
    SELECT /*+ qb_name(PR_DIST) MATERIALIZE */
           PRDA.REQUISITION_LINE_ID
          ,PRDA.DISTRIBUTION_NUMBER
          ,PRDA.CODE_COMBINATION_ID
    FROM   POR_REQ_DISTRIBUTIONS_ALL PRDA
)
```

---

## 10. PR Requester Master (Date-Effective)
*Retrieves requester names with date-effective filtering. Supports both FULL_NAME and FIRST_NAME || LAST_NAME patterns.*

```sql
REQUESTER_MASTER AS (
    SELECT /*+ qb_name(REQ_MST) MATERIALIZE */
           PPNF.PERSON_ID
          ,PPNF.FIRST_NAME || ' ' || PPNF.LAST_NAME AS REQUESTER_NAME
    FROM   PER_PERSON_NAMES_F PPNF
    WHERE  PPNF.NAME_TYPE = 'GLOBAL'
      AND  TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) 
                              AND TRUNC(PPNF.EFFECTIVE_END_DATE)
)
```

---

## 11. PR Status Lookup
*Retrieves PR status meanings from FND lookup.*

```sql
PR_STATUS_LOOKUP AS (
    SELECT /*+ qb_name(PR_STAT) MATERIALIZE */
           FLVT.LOOKUP_CODE
          ,FLVT.MEANING AS PR_STATUS
    FROM   FND_LOOKUP_VALUES_TL FLVT
    WHERE  FLVT.LOOKUP_TYPE = 'POR_DOCUMENT_STATUS'
      AND  FLVT.VIEW_APPLICATION_ID = 0
      AND  FLVT.SET_ID = 0
      AND  FLVT.LANGUAGE = USERENV('LANG')
)
```

---

## 12. Supplier Master (Header)
*Retrieves supplier header information filtered by creation date.*

```sql
SUPPLIER_MASTER AS (
    SELECT /*+ qb_name(SUPP_MST) MATERIALIZE PARALLEL(2) */
           PSV.VENDOR_ID
          ,PSV.SEGMENT1 AS SUPPLIER_NUMBER
          ,PSV.VENDOR_NAME AS SUPPLIER_NAME
          ,PSV.VENDOR_TYPE_LOOKUP_CODE AS VENDOR_TYPE_CODE
          ,PSV.CREATION_DATE AS SUPPLIER_CREATION_DATE
          ,PSV.PARTY_ID
    FROM   POZ_SUPPLIERS_V PSV
    WHERE  TRUNC(PSV.CREATION_DATE) BETWEEN TRUNC(:P_SUPPLIER_CREATION_DATE_FROM)
                                       AND TRUNC(:P_SUPPLIER_CREATION_DATE_TO)
)
```

---

## 13. Supplier Sites Master
*Retrieves supplier site information.*

```sql
SUPPLIER_SITES AS (
    SELECT /*+ qb_name(SUPP_SITES) MATERIALIZE */
           PSSV.VENDOR_ID
          ,PSSV.VENDOR_SITE_ID
          ,PSSV.PARTY_SITE_NAME AS SITE_NAME
          ,PSSV.PARTY_SITE_ID
          ,PSSV.TERMS_ID
          ,PSSV.PRC_BU_ID
    FROM   POZ_SUPPLIER_SITES_V PSSV
)
```

---

## 14. Supplier Address Master
*Retrieves supplier address details from separate address view.*

```sql
SUPPLIER_ADDRESS AS (
    SELECT /*+ qb_name(SUPP_ADDR) MATERIALIZE */
           PSAV.VENDOR_ID
          ,PSAV.PARTY_SITE_ID
          ,PSAV.ADDRESS1 AS ADDRESS_LINE1
          ,PSAV.ADDRESS2 AS ADDRESS_LINE2
          ,PSAV.CITY
          ,PSAV.PHONE_NUMBER
    FROM   POZ_SUPPLIER_ADDRESS_V PSAV
)
```

---

## 15. Vendor Type Lookup
*Retrieves vendor type meanings from FND lookup.*

```sql
VENDOR_TYPE_LOOKUP AS (
    SELECT /*+ qb_name(VEND_TYPE) MATERIALIZE */
           FLVT.LOOKUP_CODE
          ,FLVT.MEANING AS VENDOR_TYPE
    FROM   FND_LOOKUP_VALUES_TL FLVT
    WHERE  FLVT.LOOKUP_TYPE = 'ORA_POZ_VENDOR_TYPE'
      AND  FLVT.VIEW_APPLICATION_ID = 0
      AND  FLVT.SET_ID = 0
      AND  FLVT.LANGUAGE = USERENV('LANG')
)
```

---

## 16. Vendor Status Lookup
*Retrieves vendor status from HZ_PARTIES table.*

```sql
VENDOR_STATUS_LOOKUP AS (
    SELECT /*+ qb_name(VEND_STAT) MATERIALIZE */
           HP.PARTY_ID
          ,HP.STATUS AS STATUS_CODE
          ,DECODE(HP.STATUS, 'A', 'Active', 'I', 'Inactive', 'Inactive') AS VENDOR_STATUS
    FROM   HZ_PARTIES HP
)
```

---

## 17. Tax Profile Master
*Retrieves tax registration and classification from party tax profile.*

```sql
TAX_PROFILE AS (
    SELECT /*+ qb_name(TAX_PROF) MATERIALIZE */
           ZPTP.PARTY_ID
          ,ZPTP.REP_REGISTRATION_NUMBER AS TAX_REGISTRATION_NUMBER
          ,ZPTP.TAX_CLASSIFICATION_CODE
    FROM   ZX_PARTY_TAX_PROFILE ZPTP
)
```

---

## 18. Business Classifications Master
*Retrieves trade license number from business classifications.*

```sql
BUSINESS_CLASSIFICATIONS AS (
    SELECT /*+ qb_name(BUS_CLASS) MATERIALIZE */
           PBCV.VENDOR_ID
          ,MAX(CASE 
                  WHEN UPPER(PBCV.DISPLAYED_FIELD) LIKE '%TRADE%LICENSE%' 
                     OR UPPER(PBCV.DISPLAYED_FIELD) LIKE '%LICENSE%'
                     OR UPPER(PBCV.CERTIFYING_AGENCY) LIKE '%TRADE%LICENSE%'
                     OR UPPER(PBCV.CERTIFYING_AGENCY) LIKE '%LICENSE%'
                  THEN PBCV.CERTIFICATE_NUMBER
                  ELSE NULL
              END) AS TRADE_LICENSE_NUMBER
    FROM   POZ_BUSINESS_CLASSIFICATIONS_V PBCV
    WHERE  PBCV.STATUS = 'A'
    GROUP BY PBCV.VENDOR_ID
)
```

---

## 19. Supplier Bank Account Master
*Retrieves primary supplier bank account with bank details. Requires complex join through IBY tables.*

```sql
BANK_MASTER AS (
    SELECT /*+ qb_name(BANK_MST) MATERIALIZE */
           IAO.ACCOUNT_OWNER_PARTY_ID
          ,IEBA.BANK_ACCOUNT_NUM AS BANK_ACCOUNT_NUMBER
          ,IEBA.BANK_ACCOUNT_NAME
          ,CE.BANK_NAME
          ,CE.BANK_NUMBER
          ,IEPA.SUPPLIER_SITE_ID
    FROM   IBY_EXT_BANK_ACCOUNTS IEBA
          ,IBY_ACCOUNT_OWNERS IAO
          ,IBY_EXTERNAL_PAYEES_ALL IEPA
          ,IBY_PMT_INSTR_USES_ALL IPIUA
          ,CE_BANKS_V CE
    WHERE  IEBA.EXT_BANK_ACCOUNT_ID = IAO.EXT_BANK_ACCOUNT_ID
      AND  IAO.PRIMARY_FLAG = 'Y'
      AND  IAO.ACCOUNT_OWNER_PARTY_ID = IEPA.PAYEE_PARTY_ID
      AND  IAO.EXT_BANK_ACCOUNT_ID = IPIUA.INSTRUMENT_ID
      AND  IEPA.EXT_PAYEE_ID = IPIUA.EXT_PMT_PARTY_ID
      AND  IEBA.BANK_ID = CE.BANK_PARTY_ID(+)
)
```

---

## 20. Payment Terms Master (Translated)
*Retrieves payment terms from translated table for multilingual support.*

```sql
PAYMENT_TERMS_MASTER AS (
    SELECT /*+ qb_name(PAY_TERMS) MATERIALIZE */
           APT.TERM_ID
          ,APT.NAME AS PAYMENT_TERM
    FROM   AP_TERMS_TL APT
    WHERE  APT.LANGUAGE = USERENV('LANG')
)
```
