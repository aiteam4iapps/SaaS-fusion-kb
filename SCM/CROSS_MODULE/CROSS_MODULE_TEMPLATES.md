# Cross-Module Report Templates

**Purpose:** Ready-to-use SQL skeletons for cross-module reporting  
**Scope:** Queries spanning multiple SCM modules

---

## 1. Procure to Pay (P2P) Report - Requirements-Based Implementation
*Complete P2P cycle from requisition to payment with all 23 required columns.*

**Reference:** See `.cursor/19-01-2026/P2P_Report_Requirements.md` for complete requirements documentation.

**Key Features:**
- 23 output columns (Requisition → PO → Receipt → Invoice → Payment)
- 3 parameters: Business Unit Name (optional), PR From/To Date
- One row per PR Distribution
- Left outer joins for optional stages
- Multiple payments per invoice (separate rows)
- Date formatting: DD-MON-YYYY
- NVL pattern for optional Business Unit filter

```sql
/*
TITLE: Procure to Pay (P2P) Report
PURPOSE: Complete P2P cycle tracking from Requisition to Payment with all key columns
MODULES: PO (PR + PO) → INV (Receipt) → AP (Invoice + Payment)
PARAMETERS:
  - :P_BUSINESS_UNIT_NAME - Business Unit Name (Optional, uses NVL pattern)
  - :P_PR_FROM_DATE - PR Creation From Date (Required)
  - :P_PR_TO_DATE - PR Creation To Date (Required)
AUTHOR: AI Agent
DATE: 19-01-2026
*/

WITH
-- 1. PR Master (Headers filtered by date range)
PR_MASTER AS (
    SELECT /*+ qb_name(PR_MST) MATERIALIZE PARALLEL(2) */
           PRHA.REQUISITION_HEADER_ID
          ,PRHA.REQUISITION_NUMBER
          ,PRHA.CREATION_DATE AS PR_CREATION_DATE
          ,PRHA.DOCUMENT_STATUS AS PR_STATUS_CODE
          ,PRHA.REQ_BU_ID
          ,PRHA.REQUESTER_ID
    FROM   POR_REQUISITION_HEADERS_ALL PRHA
    WHERE  TRUNC(PRHA.CREATION_DATE) BETWEEN TRUNC(:P_PR_FROM_DATE) 
                                        AND TRUNC(:P_PR_TO_DATE)
),

-- 2. PR Lines (with amount calculation)
PR_LINES AS (
    SELECT /*+ qb_name(PR_LN) MATERIALIZE */
           PRLA.REQUISITION_HEADER_ID
          ,PRLA.REQUISITION_LINE_ID
          ,PRLA.PO_HEADER_ID
          ,ROUND(NVL(PRLA.ASSESSABLE_VALUE, 
                CASE 
                    WHEN PRLA.CURRENCY_UNIT_PRICE IS NOT NULL AND PRLA.QUANTITY IS NOT NULL 
                    THEN (PRLA.CURRENCY_UNIT_PRICE * PRLA.QUANTITY * NVL(PRLA.RATE, 1))
                    ELSE NVL(PRLA.CURRENCY_AMOUNT, 0) * NVL(PRLA.RATE, 1)
                END), 2) AS REQUISITION_AMOUNT
    FROM   POR_REQUISITION_LINES_ALL PRLA
),

-- 3. PR Distributions (one row per distribution)
PR_DISTRIBUTIONS AS (
    SELECT /*+ qb_name(PR_DIST) MATERIALIZE */
           PRDA.REQUISITION_LINE_ID
          ,PRDA.DISTRIBUTION_ID
          ,PRDA.DISTRIBUTION_NUMBER
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

-- 6. PO Master (Headers with key fields)
PO_MASTER AS (
    SELECT /*+ qb_name(PO_MST) MATERIALIZE PARALLEL(2) */
           PHA.PO_HEADER_ID
          ,PHA.SEGMENT1 AS PO_NUMBER
          ,PHA.DOCUMENT_STATUS AS PO_STATUS_CODE
          ,PHA.CURRENCY_CODE AS PO_CURRENCY
          ,PHA.AGENT_ID
          ,PHA.PRC_BU_ID
          ,PHA.VENDOR_ID
          ,PHA.RATE AS PO_EXCHANGE_RATE
    FROM   PO_HEADERS_ALL PHA
),

-- 7. PO Amounts (Aggregated by PO_HEADER_ID - sum all lines and distributions)
PO_AMOUNTS AS (
    SELECT /*+ qb_name(PO_AMT) MATERIALIZE */
           PDA.PO_HEADER_ID
          ,ROUND(SUM((NVL(PDA.NONRECOVERABLE_TAX, 0) + NVL(PDA.TAX_EXCLUSIVE_AMOUNT, 0)) * NVL(PHA.RATE, 1)), 2) AS PO_AMOUNT
    FROM   PO_DISTRIBUTIONS_ALL PDA
          ,PO_HEADERS_ALL PHA
    WHERE  PDA.PO_HEADER_ID = PHA.PO_HEADER_ID
    GROUP BY PDA.PO_HEADER_ID
),

-- 8. PO Status Lookup
PO_STATUS_LOOKUP AS (
    SELECT /*+ qb_name(PO_STAT) MATERIALIZE */
           FLVT.LOOKUP_CODE
          ,FLVT.MEANING AS PO_STATUS
    FROM   FND_LOOKUP_VALUES_TL FLVT
    WHERE  FLVT.LOOKUP_TYPE = 'DOCUMENT_STATUS'
      AND  FLVT.VIEW_APPLICATION_ID = 0
      AND  FLVT.SET_ID = 0
      AND  FLVT.LANGUAGE = USERENV('LANG')
),

-- 9. Buyer Master (Date-Effective, from AGENT_ID)
BUYER_MASTER AS (
    SELECT /*+ qb_name(BUYER_MST) MATERIALIZE */
           PAPF.PERSON_ID
          ,PPNF.DISPLAY_NAME AS BUYER_NAME
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F PPNF
    WHERE  PAPF.PERSON_ID = PPNF.PERSON_ID
      AND  PPNF.NAME_TYPE = 'GLOBAL'
      AND  TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE) 
                              AND TRUNC(PAPF.EFFECTIVE_END_DATE)
      AND  TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) 
                              AND TRUNC(PPNF.EFFECTIVE_END_DATE)
),

-- 10. Supplier Master
SUPPLIER_MASTER AS (
    SELECT /*+ qb_name(SUPP_MST) MATERIALIZE */
           PSV.VENDOR_ID
          ,PSV.VENDOR_NAME AS SUPPLIER_NAME
    FROM   POZ_SUPPLIERS_V PSV
),

-- 11. Business Unit Master
BU_MASTER AS (
    SELECT /*+ qb_name(BU_MST) MATERIALIZE */
           FABUV.BU_ID
          ,FABUV.BU_NAME
    FROM   FUN_ALL_BUSINESS_UNITS_V FABUV
),

-- 12. Receipt Master (with amount calculation and transaction ID for invoice link)
RECEIPT_MASTER AS (
    SELECT /*+ qb_name(RCV_MST) MATERIALIZE PARALLEL(2) */
           RT.PO_HEADER_ID
          ,RT.PO_LINE_ID
          ,RSH.RECEIPT_NUM AS RECEIPT_NUMBER
          ,RT.TRANSACTION_DATE AS RECEIPT_DATE
          ,ROUND(NVL(RSL.AMOUNT, 
                CASE 
                    WHEN RT.QUANTITY IS NOT NULL AND RT.UNIT_PRICE IS NOT NULL 
                    THEN (RT.QUANTITY * RT.UNIT_PRICE)
                    ELSE 0
                END), 2) AS RECEIPT_AMOUNT
          ,RT.TRANSACTION_ID
    FROM   RCV_TRANSACTIONS RT
          ,RCV_SHIPMENT_HEADERS RSH
          ,RCV_SHIPMENT_LINES RSL
    WHERE  RT.SHIPMENT_HEADER_ID = RSH.SHIPMENT_HEADER_ID
      AND  RT.SHIPMENT_LINE_ID = RSL.SHIPMENT_LINE_ID
      AND  RT.TRANSACTION_TYPE = 'RECEIVE'
),

-- 13. Invoice Master (Headers linked via receipt transaction)
INVOICE_MASTER AS (
    SELECT /*+ qb_name(INV_MST) MATERIALIZE PARALLEL(2) */
           AIA.INVOICE_ID
          ,AIA.INVOICE_NUM AS INVOICE_NUMBER
          ,AIA.INVOICE_DATE
          ,AIA.APPROVAL_STATUS AS INVOICE_STATUS_CODE
          ,AIA.INVOICE_CURRENCY_CODE AS INVOICE_CURRENCY
          ,ROUND(AIA.INVOICE_AMOUNT, 2) AS INVOICE_AMOUNT
          ,AILA.RCV_TRANSACTION_ID
          ,AILA.PO_HEADER_ID
          ,AILA.PO_LINE_ID
    FROM   AP_INVOICES_ALL AIA
          ,AP_INVOICE_LINES_ALL AILA
    WHERE  AIA.INVOICE_ID = AILA.INVOICE_ID
      AND  AIA.CANCELLED_DATE IS NULL
      AND  AILA.RCV_TRANSACTION_ID IS NOT NULL
),

-- 14. Invoice Status Lookup (using decode pattern from AP_MASTER)
INVOICE_STATUS_DECODE AS (
    SELECT /*+ qb_name(INV_STAT) MATERIALIZE */
           'FULL' AS STATUS_CODE, 'FULLY APPLIED' AS INVOICE_STATUS FROM DUAL
    UNION ALL
    SELECT 'NEVER APPROVED', 'NEVER VALIDATED' FROM DUAL
    UNION ALL
    SELECT 'NEEDS REAPPROVAL', 'NEEDS REVALIDATION' FROM DUAL
    UNION ALL
    SELECT 'CANCELLED', 'CANCELLED' FROM DUAL
    UNION ALL
    SELECT 'UNPAID', 'UNPAID' FROM DUAL
    UNION ALL
    SELECT 'AVAILABLE', 'AVAILABLE' FROM DUAL
    UNION ALL
    SELECT 'UNAPPROVED', 'UNVALIDATED' FROM DUAL
    UNION ALL
    SELECT 'APPROVED', 'VALIDATED' FROM DUAL
    UNION ALL
    SELECT 'PERMANENT', 'PERMANENT PREPAYMENT' FROM DUAL
),

-- 15. Payment Master (with amount from AP_INVOICE_PAYMENTS_ALL)
PAYMENT_MASTER AS (
    SELECT /*+ qb_name(PAY_MST) MATERIALIZE */
           AIPA.INVOICE_ID
          ,ACA.CHECK_NUMBER AS PAYMENT_NUMBER
          ,ACA.CHECK_DATE AS PAYMENT_DATE
          ,ROUND(AIPA.AMOUNT, 2) AS PAYMENT_AMOUNT
    FROM   AP_INVOICE_PAYMENTS_ALL AIPA
          ,AP_CHECKS_ALL ACA
    WHERE  AIPA.CHECK_ID = ACA.CHECK_ID
      AND  ACA.VOID_DATE IS NULL
      AND  ACA.STATUS_LOOKUP_CODE <> 'VOIDED'
),

-- 16. PR Detail (Base with PR, Lines, Distributions)
PR_DETAIL AS (
    SELECT /*+ qb_name(PR_DTL) MATERIALIZE */
           PRM.REQUISITION_HEADER_ID
          ,PRM.REQUISITION_NUMBER
          ,PRM.PR_CREATION_DATE
          ,PRM.PR_STATUS_CODE
          ,PRM.REQ_BU_ID
          ,PRM.REQUESTER_ID
          ,PRL.REQUISITION_LINE_ID
          ,PRL.PO_HEADER_ID
          ,PRL.REQUISITION_AMOUNT
          ,PRD.DISTRIBUTION_ID
          ,PRD.DISTRIBUTION_NUMBER
    FROM   PR_MASTER PRM
          ,PR_LINES PRL
          ,PR_DISTRIBUTIONS PRD
    WHERE  PRM.REQUISITION_HEADER_ID = PRL.REQUISITION_HEADER_ID
      AND  PRL.REQUISITION_LINE_ID = PRD.REQUISITION_LINE_ID
),

-- 17. P2P Detail (All stages joined)
P2P_DETAIL AS (
    SELECT /*+ qb_name(P2P_DTL) MATERIALIZE */
           PRD.REQUISITION_NUMBER
          ,PRD.PR_CREATION_DATE
          ,PRD.PR_STATUS_CODE
          ,PRD.REQUISITION_AMOUNT
          ,PRD.PO_HEADER_ID
          ,PRD.REQ_BU_ID
          ,PRD.REQUESTER_ID
          ,POM.PO_NUMBER
          ,POM.PO_STATUS_CODE
          ,POM.PO_CURRENCY
          ,POM.AGENT_ID
          ,POM.PRC_BU_ID
          ,POM.VENDOR_ID
          ,POA.PO_AMOUNT
          ,RCVM.RECEIPT_NUMBER
          ,RCVM.RECEIPT_DATE
          ,RCVM.RECEIPT_AMOUNT
          ,INVM.INVOICE_ID
          ,INVM.INVOICE_NUMBER
          ,INVM.INVOICE_DATE
          ,INVM.INVOICE_STATUS_CODE
          ,INVM.INVOICE_CURRENCY
          ,INVM.INVOICE_AMOUNT
    FROM   PR_DETAIL PRD
          ,PO_MASTER POM
          ,PO_AMOUNTS POA
          ,RECEIPT_MASTER RCVM
          ,INVOICE_MASTER INVM
    WHERE  PRD.PO_HEADER_ID = POM.PO_HEADER_ID(+)
      AND  POM.PO_HEADER_ID = POA.PO_HEADER_ID(+)
      AND  POM.PO_HEADER_ID = RCVM.PO_HEADER_ID(+)
      AND  RCVM.TRANSACTION_ID = INVM.RCV_TRANSACTION_ID(+)
)

-- 18. Final SELECT with all lookups and payments
SELECT /*+ LEADING(P2P) USE_HASH(P2P REQM BUYM SUPM BUM PAYM) */
       P2P.REQUISITION_NUMBER AS "Requisition Number"
      ,NVL(REQM.REQUESTER_NAME, 'Unknown') AS "Requester Name"
      ,TO_CHAR(P2P.PR_CREATION_DATE, 'DD-MON-YYYY') AS "Requisition Creation Date"
      ,NVL(PRSL.PR_STATUS, P2P.PR_STATUS_CODE) AS "Requisition Status"
      ,NVL(P2P.REQUISITION_AMOUNT, 0) AS "Requisition Amount"
      ,P2P.PO_NUMBER AS "PO Number"
      ,NVL(SUPM.SUPPLIER_NAME, 'N/A') AS "Supplier Name"
      ,NVL(BUM.BU_NAME, 'N/A') AS "Business Unit Name"
      ,NVL(POSL.PO_STATUS, P2P.PO_STATUS_CODE) AS "PO Status"
      ,NVL(P2P.PO_CURRENCY, 'N/A') AS "PO Currency"
      ,NVL(P2P.PO_AMOUNT, 0) AS "PO Amount"
      ,NVL(BUYM.BUYER_NAME, 'N/A') AS "Buyer Name"
      ,P2P.RECEIPT_NUMBER AS "Receipt Number"
      ,CASE WHEN P2P.RECEIPT_DATE IS NOT NULL THEN TO_CHAR(P2P.RECEIPT_DATE, 'DD-MON-YYYY') ELSE NULL END AS "Receipt Date"
      ,NVL(P2P.RECEIPT_AMOUNT, 0) AS "Receipt Amount"
      ,P2P.INVOICE_NUMBER AS "Invoice Number"
      ,CASE WHEN P2P.INVOICE_DATE IS NOT NULL THEN TO_CHAR(P2P.INVOICE_DATE, 'DD-MON-YYYY') ELSE NULL END AS "Invoice Date"
      ,NVL(INVSD.INVOICE_STATUS, P2P.INVOICE_STATUS_CODE) AS "Invoice Status"
      ,NVL(P2P.INVOICE_AMOUNT, 0) AS "Invoice Amount"
      ,NVL(P2P.INVOICE_CURRENCY, 'N/A') AS "Invoice Currency"
      ,PAYM.PAYMENT_NUMBER AS "Payment Number"
      ,CASE WHEN PAYM.PAYMENT_DATE IS NOT NULL THEN TO_CHAR(PAYM.PAYMENT_DATE, 'DD-MON-YYYY') ELSE NULL END AS "Payment Date"
      ,NVL(PAYM.PAYMENT_AMOUNT, 0) AS "Payment Amount"
FROM   P2P_DETAIL P2P
      ,REQUESTER_MASTER REQM
      ,PR_STATUS_LOOKUP PRSL
      ,PO_MASTER POM2
      ,PO_STATUS_LOOKUP POSL
      ,BUYER_MASTER BUYM
      ,SUPPLIER_MASTER SUPM
      ,BU_MASTER BUM
      ,INVOICE_STATUS_DECODE INVSD
      ,PAYMENT_MASTER PAYM
WHERE  P2P.REQUESTER_ID = REQM.PERSON_ID(+)
  AND  P2P.PR_STATUS_CODE = PRSL.LOOKUP_CODE(+)
  AND  P2P.PO_HEADER_ID = POM2.PO_HEADER_ID(+)
  AND  POM2.PO_STATUS_CODE = POSL.LOOKUP_CODE(+)
  AND  POM2.AGENT_ID = BUYM.PERSON_ID(+)
  AND  POM2.VENDOR_ID = SUPM.VENDOR_ID(+)
  AND  NVL(P2P.REQ_BU_ID, POM2.PRC_BU_ID) = BUM.BU_ID(+)
  AND  P2P.INVOICE_STATUS_CODE = INVSD.STATUS_CODE(+)
  AND  P2P.INVOICE_ID = PAYM.INVOICE_ID(+)
  AND  NVL(:P_BUSINESS_UNIT_NAME, BUM.BU_NAME) = BUM.BU_NAME
ORDER BY P2P.REQUISITION_NUMBER
        ,P2P.PO_NUMBER
        ,P2P.RECEIPT_NUMBER
        ,P2P.INVOICE_NUMBER
        ,PAYM.PAYMENT_NUMBER
```

---

## 2. Goods Received Notes (GRN) Report
*Receipt tracking with PO and Invoice matching.*

```sql
/*
TITLE: Goods Received Notes (GRN) Report
PURPOSE: Track receipts and match with POs and Invoices (2-way, 3-way match)
NOTE: This query shows GRN status for work confirmation and standard POs
*/

-- See detailed implementation in Procure to Pay template above
-- Key differences:
-- 1. Focus on GRN status logic
-- 2. Work confirmation integration
-- 3. Match validation (validated vs pending)
```

---

## 3. Supplier Evaluation Report
*Supplier qualification and performance tracking.*

```sql
/*
TITLE: Supplier Evaluation Report
PURPOSE: Track supplier qualifications and performance evaluation
MODULES: Supplier Qualification
PARAMETERS: None (shows all suppliers)
*/

SELECT 
       PABUV.BU_NAME AS PROCUREMENT_BU
      ,PI.INITIATIVE_NUMBER
      ,PI.TITLE AS INITIATIVE_TITLE
      ,PI.LAUNCH_DATE AS INITIATIVE_LAUNCH_DATE
      ,PQ.STATUS
      ,PSV.SEGMENT1 AS SUPPLIER_NUMBER
      ,PSV.VENDOR_NAME AS SUPPLIER_NAME
      ,PSSAM.VENDOR_SITE_CODE AS SUPPLIER_SITE
      ,PPNF2.FULL_NAME AS INTERNAL_REPONDER
      ,PQ.QUALIFICATION_NUMBER
      ,PQ.QUALIFICATION_NAME
      ,PQ.EFFECTIVE_START_DATE AS QUALIFICATION_START_DATE
      ,PQ.EFFECTIVE_END_DATE AS QUALIFICATION_END_DATE
      ,PQ.QUALIFICATION_SCORE
      ,PQ.QUALIFICATION_OUTCOME
      ,PQ.QUALIFICATION_COMMENTS AS COMMENTS
      ,PPNF1.DISPLAY_NAME AS EVALUATED_BY
      ,PQ.EVALUATION_DATE
      ,PIS.INTERNAL_RESPONDER_ID
FROM   POQ_INITIATIVES PI
      ,POQ_QUALIFICATIONS PQ
      ,POQ_INITIATIVE_SUPPLIERS PIS
      ,POZ_SUPPLIERS_V PSV
      ,POZ_SUPPLIER_SITES_ALL_M PSSAM
      ,PER_PERSON_NAMES_F PPNF1
      ,FUN_ALL_BUSINESS_UNITS_V PABUV
      ,PER_PERSON_NAMES_F PPNF2
WHERE  PI.INITIATIVE_ID = PQ.INITIATIVE_ID
  AND  PQ.SUPPLIER_ID = PIS.SUPPLIER_ID
  AND  PQ.INITIATIVE_ID = PIS.INITIATIVE_ID
  AND  PIS.SUPPLIER_ID = PSV.VENDOR_ID
  AND  PSV.VENDOR_ID = PSSAM.VENDOR_ID(+)
  AND  PQ.SUPPLIER_SITE_ID = PSSAM.VENDOR_SITE_ID(+)
  AND  PQ.EVALUATED_BY = PPNF1.PERSON_ID
  AND  PQ.PRC_BU_ID = PABUV.BU_ID
  AND  PIS.INTERNAL_RESPONDER_ID = PPNF2.PERSON_ID(+)
  AND  PPNF1.NAME_TYPE = 'GLOBAL'
  AND  PPNF2.NAME_TYPE = 'GLOBAL'
  AND  TRUNC(SYSDATE) BETWEEN PSSAM.EFFECTIVE_START_DATE(+) AND PSSAM.EFFECTIVE_END_DATE(+)
  AND  TRUNC(SYSDATE) BETWEEN PPNF1.EFFECTIVE_START_DATE AND PPNF1.EFFECTIVE_END_DATE
  AND  TRUNC(SYSDATE) BETWEEN PPNF2.EFFECTIVE_START_DATE AND PPNF2.EFFECTIVE_END_DATE
ORDER BY PI.INITIATIVE_NUMBER, PSV.VENDOR_NAME
```

---

## 4. Work Confirmation Tracking Report
*Track work confirmation for service-based POs with receipts and invoices.*

```sql
/*
TITLE: Work Confirmation Tracking Report
PURPOSE: Track work confirmations with GRN matching
NOTE: See Work Confirmation Report in PO_TEMPLATES.md for detailed implementation
*/

-- Key Integration:
-- PO → Work Confirmation → Receipt → Invoice
-- Uses WORK_CONFIRMATION_MASTER CTE from PO_REPOSITORIES.md
```

---

**Templates Count:** 3 primary cross-module templates  
**Coverage:** P2P, GRN, Supplier Evaluation  
**Last Updated:** 22-12-25

