# Purchasing Report Templates

**Purpose:** Ready-to-use SQL skeletons for PO reporting.

---

## 1. Open PO Report
*Detailed listing of POs with remaining open quantity.*

```sql
/*
TITLE: Open Purchase Orders
PURPOSE: Track POs not yet fully received
*/

WITH
-- 1. Get Headers
HEADERS AS (
    SELECT /*+ qb_name(H) MATERIALIZE */
           PHA.PO_HEADER_ID, PHA.PO_NUMBER, PHA.VENDOR_NAME
    FROM   PO_HEADERS_ALL PHA, POZ_SUPPLIERS_V POS
    WHERE  PHA.VENDOR_ID = POS.VENDOR_ID
      AND  PHA.CLOSED_CODE = 'OPEN'
),

-- 2. Get Open Lines
LINES AS (
    SELECT /*+ qb_name(L) MATERIALIZE */
           PLLA.PO_HEADER_ID, PLLA.QUANTITY, PLLA.QUANTITY_RECEIVED
          ,(PLLA.QUANTITY - NVL(PLLA.QUANTITY_RECEIVED, 0)) AS QTY_OPEN
           ,PLA.ITEM_DESCRIPTION
    FROM   PO_LINES_ALL PLA, PO_LINE_LOCATIONS_ALL PLLA
    WHERE  PLA.PO_LINE_ID = PLLA.PO_LINE_ID
      AND  NVL(PLLA.CANCEL_FLAG, 'N') = 'N'
      AND  PLLA.CLOSED_CODE != 'CLOSED'
)

-- 3. Final Select
SELECT H.PO_NUMBER
      ,H.VENDOR_NAME
      ,L.ITEM_DESCRIPTION
      ,L.QUANTITY AS QTY_ORDERED
      ,L.QTY_OPEN
FROM   HEADERS H
      ,LINES L
WHERE  H.PO_HEADER_ID = L.PO_HEADER_ID
  AND  L.QTY_OPEN > 0
ORDER BY H.PO_NUMBER
```

---

## 2. PO Detailed Report
*Comprehensive purchase order details with supplier, buyer, requisition, and line-level information.*

```sql
/*
TITLE: PO Detailed Report
PURPOSE: Comprehensive purchase order details with supplier, buyer, requisition, and line-level information
AUTHOR: AI Agent
PARAMETERS: P_BU_NAME, P_SUPPLIER_NAME, P_BUYER_NAME, P_PO_NUMBER, P_CREATION_DATE_FROM, P_CREATION_DATE_TO
*/

WITH
-- 1. Parameters CTE
PARAMS AS (
    SELECT /*+ qb_name(PARAMS) */
           :P_BU_NAME AS BU_NAME
          ,:P_SUPPLIER_NAME AS SUPPLIER_NAME
          ,:P_BUYER_NAME AS BUYER_NAME
          ,:P_PO_NUMBER AS PO_NUMBER
          ,TRUNC(:P_CREATION_DATE_FROM) AS CREATION_DATE_FROM
          ,TRUNC(:P_CREATION_DATE_TO) AS CREATION_DATE_TO
    FROM   DUAL
),

-- 2. PO Header Master
PO_HEADER_MASTER AS (
    SELECT /*+ qb_name(PO_HDR) MATERIALIZE PARALLEL(2) */
           PHA.PO_HEADER_ID
          ,PHA.SEGMENT1 AS PO_NUMBER
          ,PHA.CREATION_DATE
          ,PHA.TYPE_LOOKUP_CODE AS PO_STATUS
          ,PHA.CURRENCY_CODE
          ,PHA.PRC_BU_ID
          ,PHA.VENDOR_ID
          ,PHA.VENDOR_SITE_ID
          ,PHA.AGENT_ID
          ,PHA.TERMS_ID
    FROM   PO_HEADERS_ALL PHA
          ,PARAMS P
    WHERE  1=1
      AND  (P.BU_NAME IS NULL OR EXISTS (
              SELECT 1 FROM HR_ALL_ORGANIZATION_UNITS HAOU
              WHERE HAOU.ORGANIZATION_ID = PHA.PRC_BU_ID
                AND UPPER(HAOU.NAME) = UPPER(P.BU_NAME)
            ))
      AND  (P.PO_NUMBER IS NULL OR PHA.SEGMENT1 = P.PO_NUMBER)
      AND  (P.CREATION_DATE_FROM IS NULL OR TRUNC(PHA.CREATION_DATE) >= P.CREATION_DATE_FROM)
      AND  (P.CREATION_DATE_TO IS NULL OR TRUNC(PHA.CREATION_DATE) <= P.CREATION_DATE_TO)
),

-- 3. Supplier Master
SUPPLIER_MASTER AS (
    SELECT /*+ qb_name(SUPP_MST) MATERIALIZE */
           POS.VENDOR_ID
          ,POS.VENDOR_NAME
          ,POS.SEGMENT1 AS SUPPLIER_NUMBER
    FROM   POZ_SUPPLIERS_V POS
          ,PARAMS P
    WHERE  (P.SUPPLIER_NAME IS NULL OR UPPER(POS.VENDOR_NAME) = UPPER(P.SUPPLIER_NAME))
),

-- 4. Supplier Site Master (Address)
SUPPLIER_SITE_MASTER AS (
    SELECT /*+ qb_name(SUPP_SITE) MATERIALIZE */
           PSS.VENDOR_ID
          ,PSS.VENDOR_SITE_ID
          ,PSS.PRC_BU_ID
          ,TRIM(
              RTRIM(
                NVL(PSS.ADDRESS_LINE1 || CHR(10), '') ||
                NVL(PSS.ADDRESS_LINE2 || CHR(10), '') ||
                NVL(PSS.ADDRESS_LINE3 || CHR(10), '') ||
                NVL(PSS.CITY || ', ', '') ||
                NVL(PSS.STATE || ', ', '') ||
                NVL(PSS.COUNTRY, '')
              , CHR(10))
          ) AS SUPPLIER_ADDRESS
    FROM   POZ_SUPPLIER_SITES_V PSS
),

-- 5. Supplier Contact Master
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
),

-- 6. Payment Terms Master
PAYMENT_TERMS_MASTER AS (
    SELECT /*+ qb_name(PAY_TERMS) MATERIALIZE */
           AT.TERM_ID
          ,AT.NAME AS PAYMENT_TERM
    FROM   AP_TERMS AT
),

-- 7. Business Unit Master
BU_MASTER AS (
    SELECT /*+ qb_name(BU_MST) MATERIALIZE */
           HAOU.ORGANIZATION_ID
          ,HAOU.NAME AS BU_NAME
    FROM   HR_ALL_ORGANIZATION_UNITS HAOU
),

-- 8. Buyer Master (Date-Effective)
BUYER_MASTER AS (
    SELECT /*+ qb_name(BUYER_MST) MATERIALIZE */
           PAPF.PERSON_ID
          ,PNAME.FULL_NAME AS BUYER_NAME
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F PNAME
          ,PARAMS P
    WHERE  TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
      AND  TRUNC(SYSDATE) BETWEEN PNAME.EFFECTIVE_START_DATE AND PNAME.EFFECTIVE_END_DATE
      AND  PNAME.NAME_TYPE = 'GLOBAL'
      AND  PAPF.PERSON_ID = PNAME.PERSON_ID
      AND  (P.BUYER_NAME IS NULL OR UPPER(PNAME.FULL_NAME) = UPPER(P.BUYER_NAME))
),

-- 9. Buyer Email Master
BUYER_EMAIL_MASTER AS (
    SELECT /*+ qb_name(BUYER_EMAIL) MATERIALIZE */
           PERSON_ID
          ,BUYER_EMAIL
    FROM   (
        SELECT PEMAIL.PERSON_ID
              ,PEMAIL.EMAIL_ADDRESS AS BUYER_EMAIL
              ,ROW_NUMBER() OVER (PARTITION BY PEMAIL.PERSON_ID ORDER BY 
                  CASE WHEN PEMAIL.EMAIL_TYPE = 'W1' THEN 1 ELSE 2 END, PEMAIL.EMAIL_ADDRESS_ID) AS RN
        FROM   PER_EMAIL_ADDRESSES PEMAIL
    )
    WHERE  RN = 1
),

-- 10. PO Line Master
PO_LINE_MASTER AS (
    SELECT /*+ qb_name(PO_LINE) MATERIALIZE */
           PLA.PO_HEADER_ID
          ,PLA.PO_LINE_ID
          ,PLA.LINE_NUM
          ,PLA.UNIT_PRICE
          ,PLA.ITEM_DESCRIPTION
          ,PLA.UOM_CODE
    FROM   PO_LINES_ALL PLA
),

-- 10A. PO Distribution Master (for PR link)
PO_DISTRIBUTION_MASTER AS (
    SELECT /*+ qb_name(PO_DIST) MATERIALIZE */
           PDA.PO_HEADER_ID
          ,PDA.PO_LINE_ID
          ,PDA.LINE_LOCATION_ID
          ,PDA.REQ_HEADER_ID
          ,ROW_NUMBER() OVER (PARTITION BY PDA.PO_HEADER_ID, PDA.PO_LINE_ID, PDA.LINE_LOCATION_ID ORDER BY PDA.REQ_HEADER_ID) AS RN
    FROM   PO_DISTRIBUTIONS_ALL PDA
    WHERE  PDA.REQ_HEADER_ID IS NOT NULL
),

-- 11. PO Line Location Master (Shipments)
PO_LINE_LOCATION_MASTER AS (
    SELECT /*+ qb_name(PO_LINE_LOC) MATERIALIZE */
           PLLA.PO_HEADER_ID
          ,PLLA.PO_LINE_ID
          ,PLLA.LINE_LOCATION_ID
          ,PLLA.QUANTITY
          ,NVL(PLLA.AMOUNT, PLA.UNIT_PRICE * PLLA.QUANTITY) AS LINE_AMOUNT
          ,NVL(PLLA.TAX_RECOVERABLE, 0) AS TAX_RECOVERABLE
          ,PLLA.NEED_BY_DATE
    FROM   PO_LINE_LOCATIONS_ALL PLLA
          ,PO_LINE_MASTER PLA
    WHERE  PLLA.PO_LINE_ID = PLA.PO_LINE_ID
      AND  PLLA.PO_HEADER_ID = PLA.PO_HEADER_ID
      AND  NVL(PLLA.CANCEL_FLAG, 'N') = 'N'
),

-- 12. PR Master
PR_MASTER AS (
    SELECT /*+ qb_name(PR_MST) MATERIALIZE */
           PRHA.REQUISITION_HEADER_ID
          ,PRHA.SEGMENT1 AS PR_NUMBER
          ,PRHA.REQUESTER_ID
    FROM   POR_REQUISITION_HEADERS_ALL PRHA
),

-- 13. PR Requester Master (Date-Effective)
PR_REQUESTER_MASTER AS (
    SELECT /*+ qb_name(PR_REQ) MATERIALIZE */
           PAPF.PERSON_ID
          ,PNAME.FULL_NAME AS PR_REQUESTER_NAME
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F PNAME
    WHERE  TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
      AND  TRUNC(SYSDATE) BETWEEN PNAME.EFFECTIVE_START_DATE AND PNAME.EFFECTIVE_END_DATE
      AND  PNAME.NAME_TYPE = 'GLOBAL'
      AND  PAPF.PERSON_ID = PNAME.PERSON_ID
),

-- 14. Final Detailed Report
PO_DETAILED_FINAL AS (
    SELECT /*+ qb_name(PO_FINAL) */
           PHM.PO_NUMBER
          ,PHM.CREATION_DATE AS PO_CREATION_DATE
          ,PHM.PO_STATUS
          ,PHM.CURRENCY_CODE AS PO_CURRENCY_CODE
          ,PLM.LINE_NUM AS PO_LINE_NUMBER
          ,PLM.UNIT_PRICE AS PO_UNIT_PRICE
          ,PLLM.QUANTITY AS PO_QUANTITY
          ,PLLM.LINE_AMOUNT AS PO_LINE_AMOUNT
          ,PLLM.TAX_RECOVERABLE AS PO_RECOVERABLE_TAX_AMOUNT
          ,PLLM.NEED_BY_DATE
          ,PLM.ITEM_DESCRIPTION
          ,PTM.PAYMENT_TERM
          ,PLM.UOM_CODE AS UNIT_OF_MEASUREMENT
          ,SM.VENDOR_NAME AS SUPPLIER_NAME
          ,SM.SUPPLIER_NUMBER
          ,SSM.SUPPLIER_ADDRESS
          ,SSCM.CONTACT_NAME AS SUPPLIER_CONTACT_NAME
          ,SSCM.SUPPLIER_EMAIL AS SUPPLIER_EMAIL_ADDRESS
          ,BUM.BU_NAME AS PROCUREMENT_BU
          ,BM.BUYER_NAME
          ,BEM.BUYER_EMAIL
          ,PRM.PR_NUMBER
          ,PRRM.PR_REQUESTER_NAME
    FROM   PO_HEADER_MASTER PHM
          ,SUPPLIER_MASTER SM
          ,SUPPLIER_SITE_MASTER SSM
          ,SUPPLIER_CONTACT_MASTER SSCM
          ,PAYMENT_TERMS_MASTER PTM
          ,BU_MASTER BUM
          ,BUYER_MASTER BM
          ,BUYER_EMAIL_MASTER BEM
          ,PO_LINE_MASTER PLM
          ,PO_LINE_LOCATION_MASTER PLLM
          ,PO_DISTRIBUTION_MASTER PDM
          ,PR_MASTER PRM
          ,PR_REQUESTER_MASTER PRRM
    WHERE  PHM.VENDOR_ID = SM.VENDOR_ID
      AND  PHM.VENDOR_ID = SSM.VENDOR_ID(+)
      AND  PHM.VENDOR_SITE_ID = SSM.VENDOR_SITE_ID(+)
      AND  PHM.PRC_BU_ID = SSM.PRC_BU_ID(+)
      AND  PHM.VENDOR_ID = SSCM.VENDOR_ID(+)
      AND  PHM.VENDOR_SITE_ID = SSCM.VENDOR_SITE_ID(+)
      AND  PHM.TERMS_ID = PTM.TERM_ID(+)
      AND  PHM.PRC_BU_ID = BUM.ORGANIZATION_ID(+)
      AND  PHM.AGENT_ID = BM.PERSON_ID(+)
      AND  PHM.AGENT_ID = BEM.PERSON_ID(+)
      AND  PHM.PO_HEADER_ID = PLM.PO_HEADER_ID
      AND  PLM.PO_LINE_ID = PLLM.PO_LINE_ID
      AND  PHM.PO_HEADER_ID = PLLM.PO_HEADER_ID
      AND  PLLM.PO_HEADER_ID = PDM.PO_HEADER_ID(+)
      AND  PLLM.PO_LINE_ID = PDM.PO_LINE_ID(+)
      AND  PLLM.LINE_LOCATION_ID = PDM.LINE_LOCATION_ID(+)
      AND  PDM.RN(+) = 1
      AND  PDM.REQ_HEADER_ID = PRM.REQUISITION_HEADER_ID(+)
      AND  PRM.REQUESTER_ID = PRRM.PERSON_ID(+)
)

-- Final Select
SELECT /*+ LEADING(PDF) */
       PDF.PO_NUMBER
      ,PDF.PO_CREATION_DATE
      ,PDF.PO_STATUS
      ,PDF.PO_CURRENCY_CODE
      ,PDF.PO_LINE_NUMBER
      ,PDF.PO_UNIT_PRICE
      ,PDF.PO_QUANTITY
      ,PDF.PO_LINE_AMOUNT
      ,PDF.PO_RECOVERABLE_TAX_AMOUNT
      ,PDF.NEED_BY_DATE
      ,PDF.ITEM_DESCRIPTION
      ,PDF.PAYMENT_TERM
      ,PDF.UNIT_OF_MEASUREMENT
      ,PDF.SUPPLIER_NAME
      ,PDF.SUPPLIER_NUMBER
      ,PDF.SUPPLIER_ADDRESS
      ,PDF.SUPPLIER_CONTACT_NAME
      ,PDF.SUPPLIER_EMAIL_ADDRESS
      ,PDF.PROCUREMENT_BU
      ,PDF.BUYER_NAME
      ,PDF.BUYER_EMAIL
      ,PDF.PR_NUMBER
      ,PDF.PR_REQUESTER_NAME
FROM   PO_DETAILED_FINAL PDF
ORDER BY PDF.PO_NUMBER
        ,PDF.PO_LINE_NUMBER
```

**Key Patterns:**
- Join PO to PR via: `PO_DISTRIBUTIONS_ALL.REQ_HEADER_ID` = `POR_REQUISITION_HEADERS_ALL.REQUISITION_HEADER_ID` (direct link)
- Buyer via: `PO_HEADERS_ALL.AGENT_ID` (NOT `BUYER_ID`) - links to `PER_ALL_PEOPLE_F.PERSON_ID`
- Payment Terms: `AP_TERMS.NAME` (NOT `AP_TERMS_NAME.TERM_NAME`)
- Tax: `PO_LINE_LOCATIONS_ALL.TAX_RECOVERABLE` (alternative: can also sum from `PO_DISTRIBUTIONS_ALL.RECOVERABLE_TAX`)
- PR Number: `POR_REQUISITION_HEADERS_ALL.SEGMENT1` (alternative: can also use `REQUISITION_NUMBER`)
- Business Unit: `HR_ALL_ORGANIZATION_UNITS` (HR Org view) - join via `ORGANIZATION_ID = PRC_BU_ID`
- Supplier Address: Concatenated from `POZ_SUPPLIER_SITES_V` (ADDRESS_LINE1, ADDRESS_LINE2, ADDRESS_LINE3, CITY, STATE, COUNTRY)
- Supplier Contact: `POZ_SUPPLIER_CONTACTS_V.FULL_NAME` and `EMAIL_ADDRESS` - filter by `INACTIVE_DATE`
- Buyer Email: `PER_EMAIL_ADDRESSES.EMAIL_ADDRESS` - prioritize `EMAIL_TYPE = 'W1'` (work email)
- Row Structure: One row per PO Line Location (Shipment) - one PO line can have multiple shipments
- Optional Parameters: Use NULL check pattern `(P.PARAMETER IS NULL OR ...)` for optional filters
- Date-Effective: Buyer and PR Requester names require date-effective filtering from `PER_PERSON_NAMES_F`

---

## 3. PR Detail Report
*Detailed Purchase Requisition listing with Requisition Number, Requester Name, Description, Creation Date, Status, Amount, PO Number, Charge Account, and Supplier Name.*

```sql
/*
TITLE: PR Detail Report
PURPOSE: Detailed Purchase Requisition listing with Requisition Number, Requester Name, Description, Creation Date, Status, Amount, PO Number, Charge Account, and Supplier Name
PARAMETERS:
  - :P_PR_FROM_DATE - Requisition Creation From Date (Required)
  - :P_PR_TO_DATE - Requisition Creation To Date (Required)
  - :P_REQUESTER_NAME - Requester Name (Optional, uses NVL for filtering)
AUTHOR: AI Agent
DATE: 19-01-2026
*/

WITH
-- 1. Requisition Master (filtered by date range)
PR_MASTER AS (
    SELECT /*+ qb_name(PR_MST) MATERIALIZE PARALLEL(2) */
           PRHA.REQUISITION_HEADER_ID
          ,PRHA.REQUISITION_NUMBER
          ,PRHA.DESCRIPTION AS PR_DESCRIPTION
          ,PRHA.CREATION_DATE AS PR_CREATION_DATE
          ,PRHA.DOCUMENT_STATUS AS PR_STATUS_CODE
          ,PRHA.REQ_BU_ID
    FROM   POR_REQUISITION_HEADERS_ALL PRHA
    WHERE  TRUNC(PRHA.CREATION_DATE) BETWEEN TRUNC(:P_PR_FROM_DATE) 
                                        AND TRUNC(:P_PR_TO_DATE)
),

-- 2. Requisition Lines with Amounts
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
),

-- 3. Requisition Distributions
PR_DISTRIBUTIONS AS (
    SELECT /*+ qb_name(PR_DIST) MATERIALIZE */
           PRDA.REQUISITION_LINE_ID
          ,PRDA.DISTRIBUTION_NUMBER
          ,PRDA.CODE_COMBINATION_ID
          ,PRDA.REQ_BU_ID
    FROM   POR_REQ_DISTRIBUTIONS_ALL PRDA
),

-- 4. Requester Master (Date-Effective)
REQUESTER_MASTER AS (
    SELECT /*+ qb_name(REQ_MST) MATERIALIZE */
           PPNF.PERSON_ID
          ,PPNF.FIRST_NAME || ' ' || PPNF.LAST_NAME AS REQUESTER_NAME
    FROM   PER_PERSON_NAMES_F PPNF
    WHERE  PPNF.NAME_TYPE = 'GLOBAL'
      AND  TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) 
                              AND TRUNC(PPNF.EFFECTIVE_END_DATE)
),

-- 5. PR Status Lookup
PR_STATUS_LOOKUP AS (
    SELECT /*+ qb_name(PR_STAT) MATERIALIZE */
           FLVT.LOOKUP_CODE
          ,FLVT.MEANING AS PR_STATUS
    FROM   FND_LOOKUP_VALUES_TL FLVT
    WHERE  FLVT.LOOKUP_TYPE = 'POR_DOCUMENT_STATUS'
      AND  FLVT.VIEW_APPLICATION_ID = 0
      AND  FLVT.SET_ID = 0
      AND  FLVT.LANGUAGE = USERENV('LANG')
),

-- 6. PO Master (for PO Number and Supplier)
PO_MASTER AS (
    SELECT /*+ qb_name(PO_MST) MATERIALIZE */
           PHA.PO_HEADER_ID
          ,PHA.SEGMENT1 AS PO_NUMBER
          ,PHA.VENDOR_ID
    FROM   PO_HEADERS_ALL PHA
),

-- 7. Supplier Master
SUPPLIER_MASTER AS (
    SELECT /*+ qb_name(SUPP_MST) MATERIALIZE */
           PSV.VENDOR_ID
          ,PSV.VENDOR_NAME AS SUPPLIER_NAME
    FROM   POZ_SUPPLIERS_V PSV
),

-- 8. COA Master (Manual Concatenation - safer than CONCATENATED_SEGMENTS)
COA_MASTER AS (
    SELECT /*+ qb_name(COA_MST) MATERIALIZE */
           GCC.CODE_COMBINATION_ID
          ,GCC.SEGMENT1 || '.' || GCC.SEGMENT2 || '.' || GCC.SEGMENT3 || '.' 
           || GCC.SEGMENT4 || '.' || GCC.SEGMENT5 || '.' || GCC.SEGMENT6 || '.' 
           || NVL(GCC.SEGMENT7, '') || '.' || NVL(GCC.SEGMENT8, '') AS CHARGE_ACCOUNT
    FROM   GL_CODE_COMBINATIONS GCC
)

-- 9. Final SELECT
SELECT /*+ LEADING(PRM PRL) USE_HASH(PRL PRD) */
       PRM.REQUISITION_NUMBER AS "Requisition Number"
      ,NVL(REQM.REQUESTER_NAME, 'Unknown') AS "Requester Name"
      ,REGEXP_REPLACE(PRM.PR_DESCRIPTION, '[[:space:]]+', ' ') AS "Requisition Header Description"
      ,TO_CHAR(PRM.PR_CREATION_DATE, 'YYYY-MM-DD') AS "Requisition Creation Date"
      ,NVL(PRSL.PR_STATUS, PRM.PR_STATUS_CODE) AS "Requisition Status"
      ,NVL(PRL.REQUISITION_AMOUNT, 0) AS "Requisition Amount"
      ,POM.PO_NUMBER AS "Purchase Order Number"
      ,NVL(COAM.CHARGE_ACCOUNT, 'N/A') AS "Charge Account"
      ,NVL(SUPM.SUPPLIER_NAME, 'N/A') AS "Supplier Name"
FROM   PR_MASTER PRM
      ,PR_LINES PRL
      ,PR_DISTRIBUTIONS PRD
      ,REQUESTER_MASTER REQM
      ,PR_STATUS_LOOKUP PRSL
      ,PO_MASTER POM
      ,SUPPLIER_MASTER SUPM
      ,COA_MASTER COAM
WHERE  PRM.REQUISITION_HEADER_ID = PRL.REQUISITION_HEADER_ID
  AND  PRL.REQUISITION_LINE_ID = PRD.REQUISITION_LINE_ID(+)
  AND  PRM.REQ_BU_ID = PRD.REQ_BU_ID(+)  -- Multi-tenant join
  AND  PRL.REQUESTER_ID = REQM.PERSON_ID(+)
  AND  PRM.PR_STATUS_CODE = PRSL.LOOKUP_CODE(+)
  AND  PRL.PO_HEADER_ID = POM.PO_HEADER_ID(+)
  AND  POM.VENDOR_ID = SUPM.VENDOR_ID(+)
  AND  PRD.CODE_COMBINATION_ID = COAM.CODE_COMBINATION_ID(+)
  -- Requester Name Filter with NVL (optional parameter)
  AND  REQM.REQUESTER_NAME = NVL(:P_REQUESTER_NAME, REQM.REQUESTER_NAME)
ORDER BY PRM.REQUISITION_NUMBER
        ,PRL.LINE_NUMBER
        ,NVL(PRD.DISTRIBUTION_NUMBER, 0)
```

**Key Patterns:**
- **PR Table:** Use `POR_REQUISITION_HEADERS_ALL` (NOT `PO_REQUISITION_HEADERS_ALL`)
- **PR Number:** `POR_REQUISITION_HEADERS_ALL.REQUISITION_NUMBER` (NOT `SEGMENT1`)
- **PR Status:** `POR_REQUISITION_HEADERS_ALL.DOCUMENT_STATUS` (NOT `STATUS_CODE`)
- **PR Amount:** Use `POR_REQUISITION_LINES_ALL.ASSESSABLE_VALUE` with fallback calculation
- **PR to PO Link:** `POR_REQUISITION_LINES_ALL.PO_HEADER_ID` provides direct link (if PR converted to PO)
- **Charge Account:** `POR_REQ_DISTRIBUTIONS_ALL.CODE_COMBINATION_ID` (at distribution level)
- **COA Display:** Manual concatenation from `GL_CODE_COMBINATIONS` segments (safer than `CONCATENATED_SEGMENTS`)
- **Requester Name:** Date-effective from `PER_PERSON_NAMES_F` with `NAME_TYPE = 'GLOBAL'`
- **Requester Filter:** NVL pattern `REQM.REQUESTER_NAME = NVL(:P_REQUESTER_NAME, REQM.REQUESTER_NAME)` for optional parameter
- **Multi-Tenant:** Include `REQ_BU_ID` join between PR_MASTER and PR_DISTRIBUTIONS
- **PR Status Lookup:** Use `FND_LOOKUP_VALUES_TL` with `LOOKUP_TYPE = 'POR_DOCUMENT_STATUS'`

---

## 4. Supplier Master Report
*Comprehensive supplier master data report capturing supplier details, sites, addresses, bank accounts, tax information, and business classifications.*

```sql
/*
TITLE: Supplier Master Report
PURPOSE: Comprehensive supplier details with contacts, bank accounts, tax information, and classifications
MODULES: SCM - Supplier Management
PARAMETERS:
  - :P_BUSINESS_UNIT_NAME - Business Unit Name (Optional)
  - :P_SUPPLIER_STATUS - Supplier Status (Optional: 'Active' or 'Inactive')
  - :P_SUPPLIER_TYPE - Supplier Type/Vendor Type (Optional)
  - :P_SUPPLIER_CREATION_DATE_FROM - Supplier Creation Date From (Optional)
  - :P_SUPPLIER_CREATION_DATE_TO - Supplier Creation Date To (Optional)
AUTHOR: AI Agent
DATE: 19-01-2026
*/

WITH
-- 1. Parameters CTE
PARAMS AS (
    SELECT /*+ qb_name(PARAMS) */
           TRUNC(:P_SUPPLIER_CREATION_DATE_FROM) P_CREATION_DATE_FROM
          ,TRUNC(:P_SUPPLIER_CREATION_DATE_TO) P_CREATION_DATE_TO
          ,:P_BUSINESS_UNIT_NAME P_BUSINESS_UNIT_NAME
          ,:P_SUPPLIER_STATUS P_SUPPLIER_STATUS
          ,:P_SUPPLIER_TYPE P_SUPPLIER_TYPE
    FROM   DUAL
),

-- 2. Supplier Master (filtered by creation date) - from PO_REPOSITORIES.md Section 12
SUPPLIER_MASTER AS (
    SELECT /*+ qb_name(SUPP_MST) MATERIALIZE PARALLEL(2) */
           PSV.VENDOR_ID
          ,PSV.SEGMENT1 AS SUPPLIER_NUMBER
          ,PSV.VENDOR_NAME AS SUPPLIER_NAME
          ,PSV.VENDOR_TYPE_LOOKUP_CODE AS VENDOR_TYPE_CODE
          ,PSV.VENDOR_TYPE_LOOKUP_CODE AS SUPPLIER_CATEGORY
          ,PSV.CREATION_DATE AS SUPPLIER_CREATION_DATE
          ,PSV.PARTY_ID
    FROM   POZ_SUPPLIERS_V PSV
          ,PARAMS P
    WHERE  (P.P_CREATION_DATE_FROM IS NULL OR TRUNC(PSV.CREATION_DATE) >= P.P_CREATION_DATE_FROM)
      AND  (P.P_CREATION_DATE_TO IS NULL OR TRUNC(PSV.CREATION_DATE) <= P.P_CREATION_DATE_TO)
),

-- 3. Supplier Sites - from PO_REPOSITORIES.md Section 13
SUPPLIER_SITES AS (
    SELECT /*+ qb_name(SUPP_SITES) MATERIALIZE */
           PSSV.VENDOR_ID
          ,PSSV.VENDOR_SITE_ID
          ,PSSV.PARTY_SITE_NAME AS SITE_NAME
          ,PSSV.PARTY_SITE_ID
          ,PSSV.TERMS_ID
          ,PSSV.PRC_BU_ID
    FROM   POZ_SUPPLIER_SITES_V PSSV
),

-- 4. Supplier Address - from PO_REPOSITORIES.md Section 14
SUPPLIER_ADDRESS AS (
    SELECT /*+ qb_name(SUPP_ADDR) MATERIALIZE */
           PSAV.VENDOR_ID
          ,PSAV.PARTY_SITE_ID
          ,PSAV.ADDRESS1 AS ADDRESS_LINE1
          ,PSAV.ADDRESS2 AS ADDRESS_LINE2
          ,PSAV.CITY
          ,PSAV.PHONE_NUMBER
    FROM   POZ_SUPPLIER_ADDRESS_V PSAV
),

-- 5. Vendor Type Lookup - from PO_REPOSITORIES.md Section 15
VENDOR_TYPE_LOOKUP AS (
    SELECT /*+ qb_name(VEND_TYPE) MATERIALIZE */
           FLVT.LOOKUP_CODE
          ,FLVT.MEANING AS VENDOR_TYPE
    FROM   FND_LOOKUP_VALUES_TL FLVT
    WHERE  FLVT.LOOKUP_TYPE = 'ORA_POZ_VENDOR_TYPE'
      AND  FLVT.VIEW_APPLICATION_ID = 0
      AND  FLVT.SET_ID = 0
      AND  FLVT.LANGUAGE = USERENV('LANG')
),

-- 6. Vendor Status Lookup - from PO_REPOSITORIES.md Section 16
VENDOR_STATUS_LOOKUP AS (
    SELECT /*+ qb_name(VEND_STAT) MATERIALIZE */
           HP.PARTY_ID
          ,HP.STATUS AS STATUS_CODE
          ,DECODE(HP.STATUS, 'A', 'Active', 'I', 'Inactive', 'Inactive') AS VENDOR_STATUS
    FROM   HZ_PARTIES HP
),

-- 7. Tax Profile - from PO_REPOSITORIES.md Section 17
TAX_PROFILE AS (
    SELECT /*+ qb_name(TAX_PROF) MATERIALIZE */
           ZPTP.PARTY_ID
          ,ZPTP.REP_REGISTRATION_NUMBER AS TAX_REGISTRATION_NUMBER
          ,ZPTP.TAX_CLASSIFICATION_CODE
    FROM   ZX_PARTY_TAX_PROFILE ZPTP
),

-- 8. Business Classifications (for Trade License only) - from PO_REPOSITORIES.md Section 18
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
),

-- 9. Bank Master (Primary Bank Account Only) - from PO_REPOSITORIES.md Section 19
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
),

-- 10. Business Unit Master
BUSINESS_UNIT_MASTER AS (
    SELECT /*+ qb_name(BU_MST) MATERIALIZE */
           FABUV.BU_ID
          ,FABUV.BU_NAME
    FROM   FUN_ALL_BUSINESS_UNITS_V FABUV
),

-- 11. Payment Terms Master - from PO_REPOSITORIES.md Section 20
PAYMENT_TERMS_MASTER AS (
    SELECT /*+ qb_name(PAY_TERMS) MATERIALIZE */
           APT.TERM_ID
          ,APT.NAME AS PAYMENT_TERM
    FROM   AP_TERMS_TL APT
    WHERE  APT.LANGUAGE = USERENV('LANG')
)

-- 12. Final SELECT
SELECT /*+ LEADING(SM SS) USE_HASH(SS SA) */
       SM.SUPPLIER_NAME AS "Supplier Name"
      ,SM.SUPPLIER_NUMBER AS "Supplier Number"
      ,NVL(VTL.VENDOR_TYPE, SM.VENDOR_TYPE_CODE) AS "Vendor Type"
      ,NVL(VTL.VENDOR_TYPE, SM.SUPPLIER_CATEGORY) AS "Supplier Category"
      ,TO_CHAR(SM.SUPPLIER_CREATION_DATE, 'DD-MON-YYYY') AS "Supplier Creation Date"
      ,NVL(SS.SITE_NAME, 'N/A') AS "Supplier Site Name"
      ,NVL(SS.SITE_NAME, 'N/A') AS "Address Name"
      ,NVL(SA.ADDRESS_LINE1, 'N/A') AS "Address Line 1"
      ,NVL(SA.ADDRESS_LINE2, 'N/A') AS "Address Line 2"
      ,NVL(SA.CITY, 'N/A') AS "City"
      ,NVL(SA.PHONE_NUMBER, 'N/A') AS "Phone Number"
      ,NVL(VSL.VENDOR_STATUS, 'Inactive') AS "Vendor Status"
      ,NVL(BM.BANK_ACCOUNT_NUMBER, 'N/A') AS "Bank Account Number"
      ,NVL(BM.BANK_ACCOUNT_NAME, 'N/A') AS "Bank Account Name"
      ,NVL(BM.BANK_NAME, 'N/A') AS "Bank Name"
      ,NVL(BM.BANK_NUMBER, 'N/A') AS "Bank Number"
      ,NVL(BUM.BU_NAME, 'N/A') AS "Business Unit Name"
      ,NVL(TP.TAX_REGISTRATION_NUMBER, 'N/A') AS "Tax Registration Number"
      ,NVL(TP.TAX_CLASSIFICATION_CODE, 'N/A') AS "Tax Classification"
      ,NVL(PTM.PAYMENT_TERM, 'N/A') AS "Payment Term"
      ,NVL(BC.TRADE_LICENSE_NUMBER, 'N/A') AS "Trade License Number"
FROM   SUPPLIER_MASTER SM
      ,SUPPLIER_SITES SS
      ,SUPPLIER_ADDRESS SA
      ,VENDOR_TYPE_LOOKUP VTL
      ,VENDOR_STATUS_LOOKUP VSL
      ,TAX_PROFILE TP
      ,BUSINESS_CLASSIFICATIONS BC
      ,BANK_MASTER BM
      ,BUSINESS_UNIT_MASTER BUM
      ,PAYMENT_TERMS_MASTER PTM
      ,PARAMS P
WHERE  SM.VENDOR_ID = SS.VENDOR_ID(+)
  AND  SS.PARTY_SITE_ID = SA.PARTY_SITE_ID(+)
  AND  SM.VENDOR_TYPE_CODE = VTL.LOOKUP_CODE(+)
  AND  SM.PARTY_ID = VSL.PARTY_ID(+)
  AND  SM.PARTY_ID = TP.PARTY_ID(+)
  AND  SM.VENDOR_ID = BC.VENDOR_ID(+)
  AND  SM.PARTY_ID = BM.ACCOUNT_OWNER_PARTY_ID(+)
  AND  SS.VENDOR_SITE_ID = BM.SUPPLIER_SITE_ID(+)
  AND  SS.PRC_BU_ID = BUM.BU_ID(+)
  AND  SS.TERMS_ID = PTM.TERM_ID(+)
  AND  (P.P_BUSINESS_UNIT_NAME IS NULL OR BUM.BU_NAME = P.P_BUSINESS_UNIT_NAME)
  AND  NVL(P.P_SUPPLIER_STATUS, NVL(VSL.VENDOR_STATUS, 'Inactive')) = NVL(VSL.VENDOR_STATUS, 'Inactive')
  AND  NVL(P.P_SUPPLIER_TYPE, NVL(VTL.VENDOR_TYPE, SM.VENDOR_TYPE_CODE)) = NVL(VTL.VENDOR_TYPE, SM.VENDOR_TYPE_CODE)
ORDER BY SM.SUPPLIER_NUMBER
        ,SM.SUPPLIER_NAME
        ,SS.SITE_NAME
        ,BUM.BU_NAME
```

**Key Patterns:**
- **Supplier Category:** Currently uses `VENDOR_TYPE_LOOKUP_CODE` as proxy - may require validation for DFF attributes or category assignment tables
- **Vendor Status:** Use `HZ_PARTIES.STATUS` (NOT `POZ_SUPPLIERS_V.ENABLED_FLAG`) - decode to 'Active'/'Inactive'
- **Vendor Type Lookup:** Use `FND_LOOKUP_VALUES_TL` with `LOOKUP_TYPE = 'ORA_POZ_VENDOR_TYPE'` (NOT `'VENDOR_TYPE'`)
- **Bank Account Join:** Complex join through IBY tables - `IBY_EXT_BANK_ACCOUNTS` → `IBY_ACCOUNT_OWNERS` → `IBY_EXTERNAL_PAYEES_ALL` → `IBY_PMT_INSTR_USES_ALL` - filter by `PRIMARY_FLAG = 'Y'`
- **Tax Profile:** Use `ZX_PARTY_TAX_PROFILE` (NOT `ZX_REGISTRATIONS`) - join via `PARTY_ID`
- **Trade License:** Pattern match in `POZ_BUSINESS_CLASSIFICATIONS_V` - search for 'TRADE LICENSE' or 'LICENSE' in `DISPLAYED_FIELD` or `CERTIFYING_AGENCY`
- **Payment Terms:** Use `AP_TERMS_TL` (translated table) with `LANGUAGE = USERENV('LANG')`
- **Supplier Address:** Use `POZ_SUPPLIER_ADDRESS_V` (separate from `POZ_SUPPLIER_SITES_V`) - join via `PARTY_SITE_ID`
- **Business Unit:** Use `FUN_ALL_BUSINESS_UNITS_V` (Financial BU view) - join via `PRC_BU_ID = BU_ID`
- **Optional Parameter Filters:** Use NVL pattern `NVL(:P_PARAMETER, COLUMN_VALUE) = COLUMN_VALUE` for optional parameters
- **Date Formatting:** Use `TO_CHAR(date, 'DD-MON-YYYY')` for date columns
- **Row Structure:** One row per Supplier Site (one supplier can have multiple sites)
- **Left Outer Joins:** All optional data uses `(+)` operator (sites, address, bank account, tax profile, payment terms, trade license)
