# AR Master Instructions: Oracle Fusion Receivables

**Module:** Accounts Receivable (AR)
**Tag:** `#Finance #AR #Receivables`
**Status:** Active

---

## 1. 🚨 Critical AR Constraints
*Violating these rules results in incorrect financial data.*

1.  **Currency & Exchange Rates (CRITICAL):**
    *   **Problem:** Functional currency transactions often have `NULL` exchange rates.
    *   **Rule:** `NVL(EXCHANGE_RATE, 1)`
    *   **Formula:** `Functional_Amt = Entered_Amt * NVL(Rate, 1)`
    
2.  **Transaction Sign Reversal:**
    *   **CRITICAL UPDATE (v2.0):** `AMOUNT_DUE_ORIGINAL` in `AR_PAYMENT_SCHEDULES_ALL` already has correct sign
    *   **Correct Sign:** Credit Memos are NEGATIVE, Invoices/Debit Memos are POSITIVE
    *   **Rule:** Use `AMOUNT_DUE_ORIGINAL` directly - NO manual sign reversal needed
    *   **Anti-Pattern:** Do NOT multiply CM by -1 when using `AMOUNT_DUE_ORIGINAL`
    *   **Legacy Note:** Old pattern multiplied by -1 based on CLASS, this is no longer needed
    *   **See:** AR_REPOSITORIES.md Section 25 for Customer Ledger pattern with simplified sign handling

3.  **Reverse Receipts:**
    *   **Rule:** Exclude receipts where `STATUS = 'REVERSED'` in History.
    *   **Pattern:** `AND NOT EXISTS (SELECT 1 FROM AR_CASH_RECEIPT_HISTORY_ALL WHERE STATUS='REVERSED'...)`

4.  **XLA Application ID:**
    *   **Rule:** `AND APPLICATION_ID = 222` (Receivables)

5.  **Transaction Type Join:**
    *   **CRITICAL:** Use `CUST_TRX_TYPE_SEQ_ID` NOT `CUST_TRX_TYPE_ID`
    *   **Correct:** `RCTA.CUST_TRX_TYPE_SEQ_ID = RCTT.CUST_TRX_TYPE_SEQ_ID`
    *   **Wrong:** `RCTA.CUST_TRX_TYPE_ID = RCTT.CUST_TRX_TYPE_ID` (This will give incorrect results)

6.  **Customer Site Use:**
    *   **Rule:** Filter by `SITE_USE_CODE = 'BILL_TO'` for billing address
    *   **Pattern:** `AND HCSU.SITE_USE_CODE = 'BILL_TO'`

7.  **Receipt Status:**
    *   **Valid Statuses:** 'APP' (Applied), 'ACC' (Accepted), 'CLEARED' (Cleared)
    *   **Check Reversed:** Use `NOT EXISTS` check against `AR_CASH_RECEIPT_HISTORY_ALL` with `STATUS = 'REVERSED'`

8.  **Transaction Completion:**
    *   **Rule:** `AND COMPLETE_FLAG = 'Y'` for posted transactions only
    *   **Application:** Filter on `RA_CUSTOMER_TRX_ALL.COMPLETE_FLAG = 'Y'`

9.  **Business Unit to Ledger Join (CRITICAL):**
    *   **Problem:** `FUN_ALL_BUSINESS_UNITS_V` does NOT have `SET_OF_BOOKS_ID` or `LEDGER_ID` columns
    *   **Wrong:** `FBU.SET_OF_BOOKS_ID = GLL.LEDGER_ID` ❌
    *   **Wrong:** `FBU.LEDGER_ID = GLL.LEDGER_ID` ❌
    *   **Correct:** Get ledger from transaction level: `RCTA.SET_OF_BOOKS_ID = GLL.LEDGER_ID` ✅
    *   **Pattern:** Join `RA_CUSTOMER_TRX_ALL` to `GL_LEDGERS` using `SET_OF_BOOKS_ID`

10. **Tax Registration Number (CRITICAL):**
    *   **Problem:** `ZX_PARTY_TAX_PROFILE` does NOT have `TAX_REGISTRATION_NUMBER` column
    *   **Wrong:** `ZXPTP.TAX_REGISTRATION_NUMBER` ❌
    *   **Correct:** `ZXPTP.REP_REGISTRATION_NUMBER` ✅
    *   **Column Purpose:** Reporting Registration Number (Tax ID for reporting)

11. **Project Table Selection (CRITICAL):**
    *   **Problem:** `PJF_PROJECTS_ALL_B` (base table) does NOT have `NAME` column
    *   **Base Table (_B):** Has `PROJECT_ID`, `SEGMENT1`, `ATTRIBUTE1-30` (NO NAME)
    *   **View (_VL):** Has `PROJECT_ID`, `SEGMENT1`, `NAME`, `DESCRIPTION`
    *   **Rule:** Use `PJF_PROJECTS_ALL_VL` for `NAME` column ✅
    *   **Rule:** Use `PJF_PROJECTS_ALL_B` only for `ATTRIBUTE` columns or when `NAME` not needed
    *   **Pattern:** `GCC.SEGMENT4 = PJFPAVL.SEGMENT1(+)` where PJFPAVL is `PJF_PROJECTS_ALL_VL`

12. **GL Code Combinations View (CRITICAL):**
    *   **Problem:** `GL_CODE_COMBINATIONS_KFV` view may not exist in all environments
    *   **Wrong:** `GCCK.CONCATENATED_SEGMENTS` ❌ (requires KFV view)
    *   **Correct:** Manual concatenation from base table ✅
    *   **Pattern:** `GCC.SEGMENT1 || '.' || GCC.SEGMENT2 || '.' || GCC.SEGMENT3 || '.' || GCC.SEGMENT4 || '.' || GCC.SEGMENT5 || '.' || GCC.SEGMENT6`
    *   **Reason:** KFV views may not be granted or may not exist in all instances

13. **AR_RECEIVABLE_APPLICATIONS_ALL Exchange Rate (CRITICAL):**
    *   **Problem:** `AR_RECEIVABLE_APPLICATIONS_ALL` does NOT have `EXCHANGE_RATE` column
    *   **Wrong:** `ARA.EXCHANGE_RATE` ❌ (ORA-00904 invalid identifier)
    *   **Correct for Cash Apps:** Use `AR_CASH_RECEIPTS_ALL.EXCHANGE_RATE` ✅
    *   **Correct for CM Apps:** Join to `RA_CUSTOMER_TRX_ALL` and use `EXCHANGE_RATE` ✅
    *   **Pattern for Cash:** 
        ```sql
        SELECT ARA.AMOUNT_APPLIED * NVL(ACRA.EXCHANGE_RATE, 1)
        FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA, AR_CASH_RECEIPTS_ALL ACRA
        WHERE ARA.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID
          AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID  -- CRITICAL for aging
        ```
    *   **Pattern for CM:**
        ```sql
        SELECT ARA.AMOUNT_APPLIED * NVL(RCTA_CM.EXCHANGE_RATE, 1)
        FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA, RA_CUSTOMER_TRX_ALL RCTA_CM
        WHERE ARA.CUSTOMER_TRX_ID = RCTA_CM.CUSTOMER_TRX_ID
          AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID  -- CRITICAL for aging
        ```
    *   **Alternative:** Use `ACCTD_AMOUNT_APPLIED_FROM` or `ACCTD_AMOUNT_APPLIED_TO` (already in functional currency)
    *   **Remember:** Application tables link transactions - they don't store exchange rates
    *   **CRITICAL for Aging:** Always include `PAYMENT_SCHEDULE_ID` join for accurate line-level matching
    *   **Date Added:** 08-JAN-2026 (from Customer Outstanding Balance bug fix)
    *   **Date Enhanced:** 08-JAN-2026 (PAYMENT_SCHEDULE_ID join from AR Aging Report)

---

## 1.1 🔍 Common Invalid Identifier Issues - Quick Reference

> **Purpose:** Prevent ORA-00904 (invalid identifier) and ORA-00942 (table/view not exist) errors

### Decision Matrix: Which Column/Table to Use?

| Need | ❌ WRONG (Common Mistake) | ✅ CORRECT | Table/View |
|------|---------------------------|-----------|------------|
| **Ledger from BU** | `FBU.SET_OF_BOOKS_ID` | `RCTA.SET_OF_BOOKS_ID = GLL.LEDGER_ID` | Get from transaction |
| **Ledger Currency** | `FBU.LEDGER_ID` | `RCTA.SET_OF_BOOKS_ID = GLL.LEDGER_ID` then `GLL.CURRENCY_CODE` | Join at transaction level |
| **Tax Registration** | `ZXPTP.TAX_REGISTRATION_NUMBER` | `ZXPTP.REP_REGISTRATION_NUMBER` | `ZX_PARTY_TAX_PROFILE` |
| **Project Name** | `PJFPAB.NAME` (from _B) | `PJFPAVL.NAME` (from _VL) | Use `PJF_PROJECTS_ALL_VL` |
| **Project Attributes** | `PJFPAVL.ATTRIBUTE1` (from _VL) | `PJFPAB.ATTRIBUTE1` (from _B) | Use `PJF_PROJECTS_ALL_B` |
| **GL Code String** | `GCCK.CONCATENATED_SEGMENTS` | Manual concatenation with `||` | Use `GL_CODE_COMBINATIONS` base |
| **Cash App Exchange Rate** | `ARA.EXCHANGE_RATE` | `ACRA.EXCHANGE_RATE` | `AR_CASH_RECEIPTS_ALL` |
| **CM App Exchange Rate** | `ARA.EXCHANGE_RATE` | `RCTA_CM.EXCHANGE_RATE` via join | `RA_CUSTOMER_TRX_ALL` |

### Detailed Patterns

**1. Business Unit → Ledger (WRONG vs RIGHT)**
```sql
-- ❌ WRONG: FUN_ALL_BUSINESS_UNITS_V doesn't have these columns
BU_MASTER AS (
    SELECT FBU.BU_ID, FBU.BU_NAME, GLL.CURRENCY_CODE
    FROM FUN_ALL_BUSINESS_UNITS_V FBU, GL_LEDGERS GLL
    WHERE FBU.SET_OF_BOOKS_ID = GLL.LEDGER_ID  -- ❌ Column doesn't exist
)

-- ✅ CORRECT: Get ledger from transaction level
BU_MASTER AS (
    SELECT FBU.BU_ID, FBU.BU_NAME
    FROM FUN_ALL_BUSINESS_UNITS_V FBU
    WHERE FBU.BU_ID = :P_BU_ID
)
TRX_HEADER AS (
    SELECT RCTA.*, GLL.CURRENCY_CODE AS LEDGER_CURRENCY
    FROM RA_CUSTOMER_TRX_ALL RCTA, GL_LEDGERS GLL
    WHERE RCTA.SET_OF_BOOKS_ID = GLL.LEDGER_ID  -- ✅ Join at transaction level
)
```

**2. Tax Registration Number (WRONG vs RIGHT)**
```sql
-- ❌ WRONG: Column name doesn't exist
SELECT ZXPTP.TAX_REGISTRATION_NUMBER  -- ❌ Invalid identifier

-- ✅ CORRECT: Use REP_REGISTRATION_NUMBER
SELECT ZXPTP.REP_REGISTRATION_NUMBER AS CUSTOMER_TAX_REG_NO
FROM ZX_PARTY_TAX_PROFILE ZXPTP
WHERE ZXPTP.PARTY_ID = HP.PARTY_ID
  AND ZXPTP.PARTY_TYPE_CODE = 'THIRD_PARTY'
```

**3. Project Name vs Attributes (WRONG vs RIGHT)**
```sql
-- ❌ WRONG: NAME doesn't exist in base table
SELECT PJFPAB.NAME  -- ❌ Invalid identifier
FROM PJF_PROJECTS_ALL_B PJFPAB

-- ✅ CORRECT: Use _VL for NAME
SELECT PJFPAVL.NAME AS PROJECT_NAME
FROM PJF_PROJECTS_ALL_VL PJFPAVL
WHERE GCC.SEGMENT4 = PJFPAVL.SEGMENT1(+)

-- ✅ CORRECT: Use _B for ATTRIBUTE columns
SELECT PJFPAB.ATTRIBUTE1 AS INTERCOMPANY_CODE
FROM PJF_PROJECTS_ALL_B PJFPAB
WHERE GCC.SEGMENT4 = PJFPAB.SEGMENT1(+)
```

**4. GL Code Concatenation (WRONG vs RIGHT)**
```sql
-- ❌ WRONG: KFV view may not exist
SELECT GCCK.CONCATENATED_SEGMENTS AS GL_CODE
FROM GL_CODE_COMBINATIONS_KFV GCCK  -- ❌ ORA-00942 possible

-- ✅ CORRECT: Manual concatenation from base table
SELECT 
    GCC.SEGMENT1 || '.' || GCC.SEGMENT2 || '.' || GCC.SEGMENT3 || '.' || 
    GCC.SEGMENT4 || '.' || GCC.SEGMENT5 || '.' || GCC.SEGMENT6 AS GL_CODE
FROM GL_CODE_COMBINATIONS GCC
```

**5. AR_RECEIVABLE_APPLICATIONS_ALL Exchange Rate (WRONG vs RIGHT)**
```sql
-- ❌ WRONG: ARA doesn't have EXCHANGE_RATE column
SELECT ARA.AMOUNT_APPLIED * NVL(ARA.EXCHANGE_RATE, 1)  -- ❌ ORA-00904
FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA

-- ✅ CORRECT: Cash Applications - Get from AR_CASH_RECEIPTS_ALL
SELECT ARA.AMOUNT_APPLIED * NVL(ACRA.EXCHANGE_RATE, 1)
FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA
    ,AR_CASH_RECEIPTS_ALL ACRA
    ,TRX_DETAILS TD  -- For PAYMENT_SCHEDULE_ID
WHERE ARA.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID
  AND TD.CUSTOMER_TRX_ID = ARA.APPLIED_CUSTOMER_TRX_ID
  AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID  -- CRITICAL for aging
  AND ARA.APPLICATION_TYPE = 'CASH'

-- ✅ CORRECT: CM Applications - Join to RA_CUSTOMER_TRX_ALL
SELECT ARA.AMOUNT_APPLIED * NVL(RCTA_CM.EXCHANGE_RATE, 1)
FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA
    ,RA_CUSTOMER_TRX_ALL RCTA_CM
    ,TRX_DETAILS TD  -- For PAYMENT_SCHEDULE_ID
WHERE ARA.CUSTOMER_TRX_ID = RCTA_CM.CUSTOMER_TRX_ID
  AND TD.CUSTOMER_TRX_ID = ARA.APPLIED_CUSTOMER_TRX_ID
  AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID  -- CRITICAL for aging
  AND ARA.APPLICATION_TYPE = 'CM'

-- ✅ ALTERNATIVE: Use functional currency columns (no conversion needed)
SELECT ARA.ACCTD_AMOUNT_APPLIED_FROM  -- Already in functional currency
FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA
```

### Validation Checklist

Before running AR queries, verify:
- [ ] No `FBU.SET_OF_BOOKS_ID` or `FBU.LEDGER_ID` references
- [ ] Using `ZXPTP.REP_REGISTRATION_NUMBER` (not `TAX_REGISTRATION_NUMBER`)
- [ ] Using `PJF_PROJECTS_ALL_VL` for `NAME` column
- [ ] Using `PJF_PROJECTS_ALL_B` only for `ATTRIBUTE` columns
- [ ] Manual GL code concatenation (not `GL_CODE_COMBINATIONS_KFV`)
- [ ] No `ARA.EXCHANGE_RATE` references (use ACRA or RCTA_CM instead)
- [ ] Applications include `PAYMENT_SCHEDULE_ID` join for accurate matching (critical for aging)

---

## 2. ⚡ Performance Optimization

| Object | Optimal Access Path | Hint Syntax |
|--------|---------------------|-------------|
| **Payment Schedule** | CUSTOMER_TRX_ID | `/*+ INDEX(APS AR_PAYMENT_SCHEDULES_N1) */` |
| **Transaction** | TRX_NUMBER + ORG | `/*+ INDEX(RCTA RA_CUSTOMER_TRX_U1) */` |
| **Receipts** | RECEIPT_NUMBER | `/*+ INDEX(ACRA AR_CASH_RECEIPTS_U2) */` |
| **Applications** | RECEIVABLE_APP_ID | `/*+ INDEX(ARA AR_RECEIVABLE_APPLICATIONS_U1) */` |

---

## 3. 🗺️ Schema Map (Key Tables)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **RCTA** | `RA_CUSTOMER_TRX_ALL` | Transaction Header (Invoice/Memo) |
| **RCTL** | `RA_CUSTOMER_TRX_LINES_ALL` | Transaction Lines |
| **RCTLA** | `RA_CUSTOMER_TRX_LINE_GL_DIST_ALL` | Line-level GL distributions |
| **RCTT** | `RA_CUST_TRX_TYPES_ALL` | Transaction Type definitions (Invoice, CM, DM) |
| **PSA** | `AR_PAYMENT_SCHEDULES_ALL` | Balances, Due Dates, Aging Source |
| **ACRA** | `AR_CASH_RECEIPTS_ALL` | Receipt Header |
| **ACRH** | `AR_CASH_RECEIPT_HISTORY_ALL` | Receipt History & Status Tracking |
| **ARA** | `AR_RECEIVABLE_APPLICATIONS_ALL` | Links Receipt to Invoice |
| **ARM** | `AR_RECEIPT_METHODS` | Receipt Method definitions |
| **ARAA** | `AR_ADJUSTMENTS_ALL` | Invoice adjustments |
| **HCA** | `HZ_CUST_ACCOUNTS` | Customer Account Master |
| **HP** | `HZ_PARTIES` | Party Master (Name) |
| **HCAS** | `HZ_CUST_ACCT_SITES_ALL` | Customer Account Sites |
| **HCSU** | `HZ_CUST_SITE_USES_ALL` | Customer Site Uses (Bill-To, Ship-To) |
| **HPS** | `HZ_PARTY_SITES` | Party Site information |
| **HL** | `HZ_LOCATIONS` | Physical Location details |
| **RBS** | `RA_BATCH_SOURCES_ALL` | Batch Source definitions |
| **FBU** | `FUN_ALL_BUSINESS_UNITS_V` | Business Unit Master |
| **XTE** | `XLA_TRANSACTION_ENTITIES` | Subledger Accounting Entities |
| **XE** | `XLA_EVENTS` | Subledger Accounting Events |
| **XAH** | `XLA_AE_HEADERS` | Accounting Entry Headers |
| **XAL** | `XLA_AE_LINES` | Accounting Entry Lines |
| **XDL** | `XLA_DISTRIBUTION_LINKS` | Links between source and SLA |
| **GCC** | `GL_CODE_COMBINATIONS` | Chart of accounts combinations |
| **GJL** | `GL_JE_LINES` | Journal entry lines |
| **GJH** | `GL_JE_HEADERS` | Journal entry headers |
| **GIR** | `GL_IMPORT_REFERENCES` | GL import references |
| **GLL** | `GL_LEDGERS` | Ledger master |
| **GLLEV** | `GL_LEDGER_LE_V` | Ledger legal entity view |
| **XLE** | `XLE_ENTITY_PROFILES` | Legal entity profiles |
| **ZXL** | `ZX_LINES_V` | Tax lines view |
| **ZXP** | `ZX_PARTY_TAX_PROFILE` | Party tax profiles |
| **PJF** | `PJF_PROJECTS_ALL_B` / `PJF_PROJECTS_ALL_VL` | Projects base/view |
| **PJBIL** | `PJB_INVOICE_LINES` | Project invoice lines |
| **PJBILD** | `PJB_INV_LINE_DISTS` | Project invoice line distributions |
| **PJBCPL** | `PJB_CNTRCT_PROJ_LINKS` | Contract project links |
| **OKC** | `OKC_K_HEADERS_ALL_B` | Contract headers |
| **RTTL** | `RA_TERMS_TL` | Payment terms (translated) |
| **RTL** | `RA_TERMS_LINES` | Payment terms lines |
| **FSP** | `FINANCIALS_SYSTEM_PARAMS_ALL` | Financial system parameters |

> **Updated by AR team** - Additional tables added from SQL analysis

---

## 4. 🔗 Standard Join Patterns
> **Updated by AR team** - Comprehensive join patterns extracted from SQL files

### 4.1 Core AR Transaction Joins

```sql
-- Transaction to Payment Schedule
AR_PAYMENT_SCHEDULES_ALL.CUSTOMER_TRX_ID = RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID

-- Transaction to Customer
RA_CUSTOMER_TRX_ALL.BILL_TO_CUSTOMER_ID = HZ_CUST_ACCOUNTS.CUST_ACCOUNT_ID
HZ_CUST_ACCOUNTS.PARTY_ID = HZ_PARTIES.PARTY_ID

-- Transaction Type
RA_CUSTOMER_TRX_ALL.CUST_TRX_TYPE_SEQ_ID = RA_CUST_TRX_TYPES_ALL.CUST_TRX_TYPE_SEQ_ID
RA_CUSTOMER_TRX_ALL.ORG_ID = RA_CUST_TRX_TYPES_ALL.ORG_ID

-- Organization
RA_CUSTOMER_TRX_ALL.ORG_ID = HR_ALL_ORGANIZATION_UNITS.ORGANIZATION_ID
RA_CUSTOMER_TRX_ALL.ORG_ID = FUN_ALL_BUSINESS_UNITS_V.BU_ID
```

### 4.2 GL Distribution Joins

```sql
-- Transaction Line to GL Distribution
RA_CUST_TRX_LINE_GL_DIST_ALL.CUSTOMER_TRX_ID = RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID
RA_CUST_TRX_LINE_GL_DIST_ALL.CUSTOMER_TRX_LINE_ID = RA_CUSTOMER_TRX_LINES_ALL.CUSTOMER_TRX_LINE_ID

-- GL Distribution to Code Combination
RA_CUST_TRX_LINE_GL_DIST_ALL.CODE_COMBINATION_ID = GL_CODE_COMBINATIONS.CODE_COMBINATION_ID
```

### 4.3 XLA to GL Link Joins

```sql
-- XLA Entity Link (Application ID 222 for Receivables)
XLA_TRANSACTION_ENTITIES.APPLICATION_ID = 222
XLA_TRANSACTION_ENTITIES.ENTITY_CODE = 'TRANSACTIONS'  -- For transactions
XLA_TRANSACTION_ENTITIES.ENTITY_CODE = 'ADJUSTMENTS'    -- For adjustments
XLA_TRANSACTION_ENTITIES.SOURCE_ID_INT_1 = RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID
XLA_TRANSACTION_ENTITIES.SOURCE_ID_INT_1 = AR_ADJUSTMENTS_ALL.ADJUSTMENT_ID  -- For adjustments

-- XLA Header and Lines
XLA_TRANSACTION_ENTITIES.ENTITY_ID = XLA_AE_HEADERS.ENTITY_ID
XLA_AE_HEADERS.AE_HEADER_ID = XLA_AE_LINES.AE_HEADER_ID
XLA_AE_HEADERS.APPLICATION_ID = 222
XLA_AE_LINES.APPLICATION_ID = 222

-- XLA to GL Link
XLA_AE_LINES.GL_SL_LINK_ID = GL_IMPORT_REFERENCES.GL_SL_LINK_ID
XLA_AE_LINES.GL_SL_LINK_TABLE = GL_IMPORT_REFERENCES.GL_SL_LINK_TABLE
GL_IMPORT_REFERENCES.JE_HEADER_ID = GL_JE_LINES.JE_HEADER_ID
GL_IMPORT_REFERENCES.JE_LINE_NUM = GL_JE_LINES.JE_LINE_NUM
GL_JE_LINES.JE_HEADER_ID = GL_JE_HEADERS.JE_HEADER_ID
GL_JE_LINES.CODE_COMBINATION_ID = GL_CODE_COMBINATIONS.CODE_COMBINATION_ID
```

### 4.4 Project Joins

```sql
-- Project from GL Distribution (Segment4)
RA_CUST_TRX_LINE_GL_DIST_ALL.CODE_COMBINATION_ID = GL_CODE_COMBINATIONS.CODE_COMBINATION_ID
GL_CODE_COMBINATIONS.SEGMENT4 = PJF_PROJECTS_ALL_B.SEGMENT1

-- Project from Invoice Lines
PJB_INVOICE_LINES.RA_CUST_TRX_ID = RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID
PJB_INVOICE_LINES.RA_CUST_TRX_LINE_ID = RA_CUSTOMER_TRX_LINES_ALL.CUSTOMER_TRX_LINE_ID
PJB_INVOICE_LINES.INVOICE_LINE_ID = PJB_INV_LINE_DISTS.INVOICE_LINE_ID
PJB_INV_LINE_DISTS.TRANSACTION_PROJECT_ID = PJF_PROJECTS_ALL_VL.PROJECT_ID

-- Project from Contracts
RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_CONTEXT = 'CONTRACT INVOICES'
RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_ATTRIBUTE2 = OKC_K_HEADERS_ALL_B.ID
OKC_K_HEADERS_ALL_B.ID = PJB_CNTRCT_PROJ_LINKS.CONTRACT_ID
PJB_CNTRCT_PROJ_LINKS.PROJECT_ID = PJF_PROJECTS_ALL_VL.PROJECT_ID
```

### 4.5 Tax Joins

```sql
-- Tax Lines
RA_CUSTOMER_TRX_LINES_ALL.CUSTOMER_TRX_ID = ZX_LINES_V.TRX_ID
RA_CUSTOMER_TRX_LINES_ALL.LINE_NUMBER = ZX_LINES_V.TRX_LINE_NUMBER
ZX_LINES_V.APPLICATION_ID = 222

-- Party Tax Profile
HZ_PARTIES.PARTY_ID = ZX_PARTY_TAX_PROFILE.PARTY_ID
ZX_PARTY_TAX_PROFILE.PARTY_TYPE_CODE = 'THIRD_PARTY'
```

### 4.6 Ledger Joins

```sql
-- Ledger from Transaction
RA_CUSTOMER_TRX_ALL.SET_OF_BOOKS_ID = GL_LEDGERS.LEDGER_ID

-- Ledger from Legal Entity
GL_LEDGER_LE_V.LEGAL_ENTITY_ID = (SELECT LEGAL_ENTITY_ID 
                                   FROM FUN_ALL_BUSINESS_UNITS_V 
                                   WHERE BU_ID = :P_ORG_ID)
GL_LEDGER_LE_V.LEDGER_ID = GL_LEDGERS.LEDGER_ID
```

### 4.7 Batch Source Joins

```sql
-- Batch Source
RA_CUSTOMER_TRX_ALL.BATCH_SOURCE_SEQ_ID = ra_batch_sources_all.BATCH_SOURCE_SEQ_ID
```

---

## 5. 📋 Standard Conditions
> **Updated by AR team** - Comprehensive condition patterns extracted from SQL files

### 5.1 Transaction Status Conditions

```sql
-- Complete Transactions
RA_CUSTOMER_TRX_ALL.COMPLETE_FLAG = 'Y'

-- Transaction Class
AR_PAYMENT_SCHEDULES_ALL.CLASS IN ('INV', 'CM', 'DM')
AR_PAYMENT_SCHEDULES_ALL.CLASS != 'PMT'  -- Exclude payments

-- Transaction Type
RA_CUST_TRX_TYPES_ALL.TYPE IN ('INV', 'CM', 'DM')
```

### 5.2 Application Status Conditions

```sql
-- Application Status
AR_RECEIVABLE_APPLICATIONS_ALL.STATUS = 'APP'
AR_RECEIVABLE_APPLICATIONS_ALL.DISPLAY = 'Y'
AR_RECEIVABLE_APPLICATIONS_ALL.APPLICATION_TYPE IN ('CASH', 'CM')

-- Adjustment Status
AR_ADJUSTMENTS_ALL.STATUS = 'A'
```

### 5.3 Accounting Conditions

```sql
-- XLA Application ID (Always 222 for Receivables)
XLA_TRANSACTION_ENTITIES.APPLICATION_ID = 222
XLA_AE_HEADERS.APPLICATION_ID = 222
XLA_AE_LINES.APPLICATION_ID = 222

-- XLA Entity Codes
XLA_TRANSACTION_ENTITIES.ENTITY_CODE = 'TRANSACTIONS'  -- For invoices/CMs
XLA_TRANSACTION_ENTITIES.ENTITY_CODE = 'ADJUSTMENTS'    -- For adjustments

-- Accounting Class
RA_CUST_TRX_LINE_GL_DIST_ALL.ACCOUNT_CLASS IN ('REV', 'REC', 'TAX', 'FREIGHT', 'UNBILLED')
XLA_AE_LINES.ACCOUNTING_CLASS_CODE IN ('RECEIVABLE', 'REVENUE', 'TAX', 'FREIGHT')

-- GL Journal Conditions
GL_JE_HEADERS.JE_SOURCE = 'Receivables'
GL_JE_HEADERS.JE_CATEGORY IN ('Sales Invoices', 'Credit Memos', 'Adjustment')
```

### 5.4 Date Range Conditions

```sql
-- Transaction Date
RA_CUSTOMER_TRX_ALL.TRX_DATE BETWEEN :P_FROM_DATE AND :P_TO_DATE
RA_CUSTOMER_TRX_ALL.TRX_DATE <= :P_AS_OF_DATE

-- GL Date (Use for accounting date filters, not TRX_DATE)
AR_PAYMENT_SCHEDULES_ALL.GL_DATE <= :P_AS_OF_DATE
AR_PAYMENT_SCHEDULES_ALL.GL_DATE BETWEEN :P_GL_FROM_DATE AND :P_GL_TO_DATE
NVL(RA_CUST_TRX_LINE_GL_DIST_ALL.GL_POSTED_DATE, RA_CUST_TRX_LINE_GL_DIST_ALL.GL_DATE) BETWEEN :P_GL_FROM_DATE AND :P_GL_TO_DATE

-- Application Date
AR_RECEIVABLE_APPLICATIONS_ALL.APPLY_DATE <= :P_AS_OF_DATE
AR_RECEIVABLE_APPLICATIONS_ALL.GL_DATE <= :P_AS_OF_DATE

-- Adjustment Date
AR_ADJUSTMENTS_ALL.GL_DATE <= :P_AS_OF_DATE
AR_ADJUSTMENTS_ALL.APPLY_DATE <= :P_AS_OF_DATE
```

### 5.5 Organization Conditions

```sql
-- Organization Filter
RA_CUSTOMER_TRX_ALL.ORG_ID = :P_ORG_ID
RA_CUSTOMER_TRX_ALL.ORG_ID IN (:P_ORG_ID)
(RA_CUSTOMER_TRX_ALL.ORG_ID IN (:P_ORG_ID) OR 'All' IN (:P_ORG_ID || 'All'))

-- Business Unit
FUN_ALL_BUSINESS_UNITS_V.BU_ID = :P_ORG_ID
```

### 5.6 Customer Conditions

```sql
-- Customer Filter
HZ_PARTIES.PARTY_ID = :P_CUSTOMER_ID
HZ_PARTIES.PARTY_ID = NVL(:P_CUSTOMER_ID, HZ_PARTIES.PARTY_ID)
HZ_PARTIES.PARTY_ID IN (:P_CUSTOMER_ID)
(HZ_PARTIES.PARTY_ID IN (:P_CUSTOMER_ID) OR 'All' IN (:P_CUSTOMER_ID || 'All'))

-- Customer Status
HZ_CUST_ACCOUNTS.STATUS = 'A'
```

### 5.7 Line Type Conditions

```sql
-- Transaction Line Type
RA_CUSTOMER_TRX_LINES_ALL.LINE_TYPE IN ('LINE', 'TAX', 'FREIGHT')
RA_CUSTOMER_TRX_LINES_ALL.LINE_TYPE = 'LINE'  -- For revenue lines
RA_CUSTOMER_TRX_LINES_ALL.LINE_TYPE = 'TAX'   -- For tax lines

-- Tax Line Link
RA_CUSTOMER_TRX_LINES_ALL.LINK_TO_CUST_TRX_LINE_ID = RA_CUSTOMER_TRX_LINES_ALL.CUSTOMER_TRX_LINE_ID
```

### 5.8 Amount Conditions

```sql
-- Non-zero Amounts
AR_PAYMENT_SCHEDULES_ALL.AMOUNT_DUE_ORIGINAL != 0
RA_CUSTOMER_TRX_LINES_ALL.EXTENDED_AMOUNT != 0
NVL(RA_CUSTOMER_TRX_LINES_ALL.EXTENDED_AMOUNT, 0) != 0

-- Balance Conditions
AR_PAYMENT_SCHEDULES_ALL.AMOUNT_DUE_REMAINING != 0
```

### 5.9 Currency Conditions

```sql
-- Currency Code
RA_CUSTOMER_TRX_ALL.INVOICE_CURRENCY_CODE = :P_CURRENCY_CODE
GL_JE_HEADERS.CURRENCY_CODE = :P_CURRENCY_CODE

-- Exchange Rate
NVL(RA_CUSTOMER_TRX_ALL.EXCHANGE_RATE, 1)  -- Default to 1 if null
```

### 5.10 Project Conditions

```sql
-- Project Segment
GL_CODE_COMBINATIONS.SEGMENT4 <> '0000'  -- Exclude default project
GL_CODE_COMBINATIONS.SEGMENT4 = :P_PROJECT_CODE
```

### 5.11 Tax Conditions

```sql
-- Tax Classification
RA_CUSTOMER_TRX_LINES_ALL.TAX_CLASSIFICATION_CODE = :P_TAX_CLASS

-- Tax Rate Type
ZX_LINES_V.TAX_RATE_TYPE = :P_TAX_RATE_TYPE

-- Tax Cancel Flag
NVL(ZX_LINES_V.CANCEL_FLAG, 'N') != 'Y'
```

### 5.12 GL Distribution Conditions

```sql
-- Latest Record Flag
NVL(RA_CUST_TRX_LINE_GL_DIST_ALL.LATEST_REC_FLAG, 'Y') = 'Y'

-- GL Posted Date
NVL(RA_CUST_TRX_LINE_GL_DIST_ALL.GL_POSTED_DATE, RA_CUST_TRX_LINE_GL_DIST_ALL.GL_DATE)
```

### 5.13 Contract Conditions

```sql
-- Contract Invoices
RA_CUSTOMER_TRX_ALL.INTERFACE_HEADER_CONTEXT = 'CONTRACT INVOICES'
OKC_K_HEADERS_ALL_B.VERSION_TYPE = 'C'
PJB_CNTRCT_PROJ_LINKS.VERSION_TYPE = 'C'
PJB_CNTRCT_PROJ_LINKS.ACTIVE_FLAG = 'Y'
```

---

## 6. 🔍 Common Query Patterns
> **Updated by AR team** - Reusable query patterns extracted from SQL files

### 6.1 Exclude Credit Memos Applied
> **Updated by AR team** - Pattern to exclude fully applied credit memos (v1.3)

**📚 Reference:** Complete SQL pattern in **AR_REPOSITORIES.md Section 18** (Exclude Credit Memos Applied)

#### **Quick Decision Guide**

| Your Need | Use Pattern | Reference |
|-----------|-------------|-----------|
| **Exclude fully applied credit memos** | NOT EXISTS in WHERE clause | AR_REPOSITORIES.md Section 18 |
| **Point-in-time exclusion** | Include GL_DATE filter | AR_REPOSITORIES.md Section 18 |

#### **Key Points**

- ✅ **Use NOT EXISTS, not NOT IN** - Better NULL handling, early termination, more efficient
- ✅ **Filter APPLICATION_TYPE = 'CM'** - Only credit memo applications
- ✅ **Include GL_DATE filter** - Point-in-time accuracy (e.g., `GL_DATE <= :P_AS_OF_DATE`)
- ✅ **No CTE needed** - Can be used directly in WHERE clause
- ✅ **Early termination** - Stops at first match (faster than NOT IN)

#### **Common Scenarios**

**Scenario 1: Exclude Fully Applied Credit Memos**
- See: AR_REPOSITORIES.md Section 18 (NOT EXISTS pattern)

**Scenario 2: Point-in-Time Exclusion**
- See: AR_REPOSITORIES.md Section 18 (Includes GL_DATE filter)

**❌ ANTI-PATTERN: NOT IN**
```sql
-- AVOID: Poor NULL handling, less efficient
WHERE CUSTOMER_TRX_ID NOT IN (
    SELECT CUSTOMER_TRX_ID FROM AR_RECEIVABLE_APPLICATIONS_ALL
    WHERE APPLICATION_TYPE = 'CM'
)
```
✅ **DO: Use NOT EXISTS** - See AR_REPOSITORIES.md Section 18

---

### 6.2 Term Due Date Calculation
> **Updated by AR team** - Calculate due date from payment terms (v1.3)

**📚 Reference:** Complete SQL pattern in **AR_REPOSITORIES.md Section 20** (Due Date Calculation from Terms)

#### **Quick Decision Guide**

| Your Need | Use Pattern | Reference |
|-----------|-------------|-----------|
| **Calculate due date from terms** | Direct join to RA_TERMS_LINES | AR_REPOSITORIES.md Section 20 |
| **Handle transactions without terms** | Outer join with NVL fallback | AR_REPOSITORIES.md Section 20 |
| **Use existing TERM_DUE_DATE** | NVL with TERM_DUE_DATE first | AR_REPOSITORIES.md Section 20 |

#### **Key Points**

- ✅ **Use direct join, not scalar subquery** - Executes once instead of N times (70-80% faster)
- ✅ **Outer join RA_TERMS_LINES** - Handle transactions without terms gracefully
- ✅ **Use TERM_DUE_DATE first** - If available, use it; otherwise calculate from TRX_DATE + DUE_DAYS
- ✅ **TRUNC date result** - Remove time component for consistent date comparisons
- ✅ **NVL fallback chain** - `NVL(TERM_DUE_DATE, TRX_DATE + NVL(DUE_DAYS, 0))`

#### **Common Scenarios**

**Scenario 1: Standard Due Date Calculation**
- See: AR_REPOSITORIES.md Section 20 (Direct join pattern)

**Scenario 2: Transactions Without Terms**
- See: AR_REPOSITORIES.md Section 20 (Outer join handles NULL terms)

**❌ ANTI-PATTERN: Correlated Subquery**
```sql
-- AVOID: Executes once per row (slow)
SELECT 
    TRX_DATE + (SELECT DUE_DAYS FROM RA_TERMS_LINES 
                WHERE TERM_ID = RCTA.TERM_ID) AS DUE_DATE
FROM RA_CUSTOMER_TRX_ALL RCTA
```
✅ **DO: Use Direct Join** - See AR_REPOSITORIES.md Section 20

### 6.3 Accounting Status Check
> **Updated by AR team** - Optimized accounting status patterns with EXISTS and CTE approaches (v1.3)

**📚 Document Structure:**
- **AR_MASTER.md (This Section):** Decision guidance, quick snippets, when to use which method
- **AR_REPOSITORIES.md Section 19:** Complete SQL patterns, CTE structures, usage examples
- **Quick Reference Below:** Inline code snippets for simple cases (Methods 1 & 3)
- **AR_REPOSITORIES.md:** Full CTE patterns for complex cases (Methods 2 & 4)

#### **Quick Decision Guide**

| Your Need | Dataset Size | Use Method | Why | Reference |
|-----------|--------------|------------|-----|-----------|
| **Show "Accounted/Unaccounted" column** | < 1000 rows | Method 1 | Fast inline, simple | Quick Reference below |
| **Show "Accounted/Unaccounted" column** | > 1000 rows | Method 2 | Pre-compute once, reusable | AR_REPOSITORIES.md Section 19.1 |
| **Filter transactions only** | Any size | Method 3 | Fastest filter, no calculation | Quick Reference below |
| **Show detailed status (FINAL/DRAFT/etc.)** | Any size | Method 4 | Full XLA status details | AR_REPOSITORIES.md Section 19.2 |
| **Need accounting date/period** | Any size | Method 2 or 4 | Includes XLA dates | AR_REPOSITORIES.md Section 19.1 or 19.2 |

#### **Decision Tree**

```
Need to check accounting status?
│
├─► Only FILTER transactions (no status display)?
│   └─► Method 3: WHERE EXISTS/NOT EXISTS ⚡⚡⚡⚡⚡ FASTEST
│       → See: Quick Reference below (inline snippets)
│
├─► Need DETAILED status (FINAL, DRAFT, INCOMPLETE, INVALID)?
│   └─► Method 4: XLA System Status 🎯 MOST DETAILED
│       → See: AR_REPOSITORIES.md Section 19.2 (Full CTE pattern)
│
└─► Need simple "Accounted/Unaccounted"?
    │
    ├─► < 1000 transactions?
    │   └─► Method 1: EXISTS inline ⚡⚡⚡ FAST
    │       → See: Quick Reference below (inline snippet)
    │
    └─► > 1000 transactions OR need accounting date?
        └─► Method 2: CTE pre-compute ⚡⚡⚡⚡ VERY FAST
            → See: AR_REPOSITORIES.md Section 19.1 (CTE pattern)
```

#### **Quick Reference Snippets**

**Copy-Paste Ready Code:**

```sql
-- Method 1: Simple status column (inline)
,CASE WHEN EXISTS (
    SELECT 1 FROM XLA_TRANSACTION_ENTITIES XTE
    WHERE XTE.APPLICATION_ID = 222
      AND XTE.ENTITY_CODE = 'TRANSACTIONS'
      AND XTE.SOURCE_ID_INT_1 = RCTA.CUSTOMER_TRX_ID
) THEN 'Accounted' ELSE 'Unaccounted' END AS ACCOUNTING_STATUS

-- Method 3: Filter only accounted
WHERE EXISTS (
    SELECT 1 FROM XLA_TRANSACTION_ENTITIES XTE
    WHERE XTE.APPLICATION_ID = 222
      AND XTE.ENTITY_CODE = 'TRANSACTIONS'
      AND XTE.SOURCE_ID_INT_1 = RCTA.CUSTOMER_TRX_ID
)

-- Method 3: Filter only unaccounted
WHERE NOT EXISTS (
    SELECT 1 FROM XLA_TRANSACTION_ENTITIES XTE
    WHERE XTE.APPLICATION_ID = 222
      AND XTE.ENTITY_CODE = 'TRANSACTIONS'
      AND XTE.SOURCE_ID_INT_1 = RCTA.CUSTOMER_TRX_ID
)

-- For Adjustments: Change ENTITY_CODE and SOURCE_ID
WHERE XTE.APPLICATION_ID = 222
  AND XTE.ENTITY_CODE = 'ADJUSTMENTS'
  AND XTE.SOURCE_ID_INT_1 = ARAA.ADJUSTMENT_ID

-- For Receipts: Change ENTITY_CODE
WHERE XTE.APPLICATION_ID = 222
  AND XTE.ENTITY_CODE = 'RECEIPTS'
  AND XTE.SOURCE_ID_INT_1 = ACRA.CASH_RECEIPT_ID
```

#### **Method Reference Guide**

**For complete SQL patterns, see AR_REPOSITORIES.md:**

- **Method 1 (Inline EXISTS):** Use Quick Reference snippets below (simple inline code)
- **Method 2 (CTE Simple Status):** See **AR_REPOSITORIES.md Section 19.1** (CTE pattern with accounting date/period)
- **Method 3 (Filter Only):** Use Quick Reference snippets below (WHERE EXISTS/NOT EXISTS)
- **Method 4 (XLA System Status):** See **AR_REPOSITORIES.md Section 19.2** (Full detailed status with FINAL/DRAFT/etc.)

**Additional Resources:**
- **Usage Examples:** AR_REPOSITORIES.md Section 19.3 (4 complete examples)
- **Pattern Selection Guide:** AR_REPOSITORIES.md Section 19.4 (When to use which pattern)

#### **XLA Accounting Status Values**

| Status Code | Meaning | Description |
|------------|---------|-------------|
| **'F'** | FINAL | Accounting complete, transferred to GL |
| **'D'** | DRAFT | Accounting created but not finalized |
| **'I'** | INCOMPLETE | Accounting rules incomplete |
| **'N'** | INVALID | Accounting has errors |
| **NULL** | Unaccounted | No accounting created |

#### **Common Scenarios & Solutions**

| Scenario | Solution | Method | Reference |
|----------|----------|--------|-----------|
| **Report column: "Accounted/Unaccounted"** | EXISTS in SELECT | Method 1 | Quick Reference below |
| **Filter: Show only unaccounted transactions** | WHERE NOT EXISTS | Method 3 | Quick Reference below |
| **Filter: Show only accounted transactions** | WHERE EXISTS | Method 3 | Quick Reference below |
| **Large dataset (>1000 rows) with status** | CTE pre-compute | Method 2 | AR_REPOSITORIES.md Section 19.1 |
| **Need accounting date/period** | CTE with XLA_AE_HEADERS | Method 2 | AR_REPOSITORIES.md Section 19.1 |
| **Need detailed status (FINAL/DRAFT/etc.)** | XLA System Status | Method 4 | AR_REPOSITORIES.md Section 19.2 |
| **Check adjustments status** | Change ENTITY_CODE | Method 1/3 | Quick Reference below |
| **Check receipts status** | Change ENTITY_CODE | Method 1/3 | Quick Reference below |
| **Filter: Only FINAL transactions** | Method 4 + WHERE | Method 4 | AR_REPOSITORIES.md Section 19.3 Example 3 |

#### **Common Mistakes to Avoid**

❌ **DON'T: Use scalar subquery with DISTINCT**
```sql
-- WRONG: Slow, executes N times
CASE WHEN (SELECT DISTINCT SOURCE_ID_INT_1 FROM XLA_TRANSACTION_ENTITIES ...) IS NOT NULL
     THEN 'Accounted' ELSE 'Unaccounted' END
```
✅ **DO: Use EXISTS (stops at first match)**
```sql
CASE WHEN EXISTS (SELECT 1 FROM XLA_TRANSACTION_ENTITIES ...)
     THEN 'Accounted' ELSE 'Unaccounted' END
```

❌ **DON'T: Forget ENTITY_CODE filter**
```sql
-- WRONG: May return wrong results
WHERE XTE.APPLICATION_ID = 222
  AND XTE.SOURCE_ID_INT_1 = RCTA.CUSTOMER_TRX_ID
```
✅ **DO: Always include ENTITY_CODE**
```sql
WHERE XTE.APPLICATION_ID = 222
  AND XTE.ENTITY_CODE = 'TRANSACTIONS'  -- Required!
  AND XTE.SOURCE_ID_INT_1 = RCTA.CUSTOMER_TRX_ID
```

❌ **DON'T: Use scalar subquery for large datasets**
```sql
-- WRONG: Executes once per row (slow)
SELECT ..., (SELECT ... FROM XLA_TRANSACTION_ENTITIES WHERE ...) AS STATUS
FROM RA_CUSTOMER_TRX_ALL
```
✅ **DO: Use CTE for large datasets**
```sql
-- RIGHT: Executes once, then join
WITH ACCT_STATUS AS (SELECT ...), ...
SELECT ..., ACCT.STATUS FROM RCTA, ACCT_STATUS ACCT
```

#### **Critical Implementation Rules**

**🔴 REQUIRED for All Methods:**
- ✅ **APPLICATION_ID = 222** - Always required (Receivables module)
- ✅ **ENTITY_CODE** - Required for Methods 1-3:
  - `'TRANSACTIONS'` → Invoices, Credit Memos, Debit Memos
  - `'ADJUSTMENTS'` → Adjustments
  - `'RECEIPTS'` → Receipts

**⚡ Performance Rules:**
- ✅ **Use EXISTS, not scalar subquery** - EXISTS stops at first match (30-40% faster)
- ✅ **Use CTE for large datasets** - Pre-compute once vs N times (60-70% faster)
- ✅ **Filter early** - Use WHERE EXISTS for filter-only queries (fastest)

**🎯 Method 4 (XLA System Status) Specific:**
- ✅ **Use XLA_DISTRIBUTION_LINKS** - More accurate than XLA_TRANSACTION_ENTITIES
- ✅ **ACCOUNT_CLASS = 'REC'** - Focus on receivable impact (determines main status)
- ✅ **LATEST_REC_FLAG = 'Y'** - Latest distributions only
- ✅ **Use MAX() in GROUP BY** - Handle multiple distributions per transaction

#### **XLA Status Code Reference (Method 4)**

| Code | Status | Meaning | Use Case |
|------|--------|---------|----------|
| **'F'** | FINAL | Fully accounted, transferred to GL | ✅ Production ready |
| **'D'** | DRAFT | Created but not finalized | ⚠️ Needs review |
| **'I'** | INCOMPLETE | Accounting rules incomplete | ⚠️ Configuration issue |
| **'N'** | INVALID | Has accounting errors | ❌ Needs correction |
| **NULL** | Unaccounted | No accounting created | ⚠️ Not yet accounted |

#### **Quick Checklist Before Using**

- [ ] Included `APPLICATION_ID = 222`?
- [ ] Included correct `ENTITY_CODE` ('TRANSACTIONS', 'ADJUSTMENTS', or 'RECEIPTS')?
- [ ] Using EXISTS (not scalar subquery)?
- [ ] For large datasets, using CTE (not inline)?
- [ ] For Method 4, included `ACCOUNT_CLASS = 'REC'` and `LATEST_REC_FLAG = 'Y'`?

### 6.4 Tax Amount Calculation Patterns
> **Updated by AR team** - Tax calculation decision guide (v1.3)

**📚 Reference:** Complete SQL patterns in **AR_REPOSITORIES.md Section 13** (Tax Calculation Master)

#### **Quick Decision Guide**

| Your Need | Use Pattern | Reference |
|-----------|-------------|-----------|
| **Calculate VAT amount** | CTE with account segment filter | AR_REPOSITORIES.md Section 13 |
| **Calculate GST (IGST/CGST/SGST)** | CTE with multiple CASE statements | AR_REPOSITORIES.md Section 13 |
| **Total tax per transaction** | Aggregate tax CTE by CUSTOMER_TRX_ID | AR_REPOSITORIES.md Section 13 |
| **Tax per line item** | Tax CTE grouped by CUSTOMER_TRX_LINE_ID | AR_REPOSITORIES.md Section 13 |

#### **Key Points**

- ✅ **Use CTE, not scalar subquery** - Pre-compute tax amounts once (70-80% faster)
- ✅ **Link tax lines to revenue lines** - Use `LINK_TO_CUST_TRX_LINE_ID` and `LINE_TYPE = 'TAX'`
- ✅ **Filter by ACCOUNT_CLASS = 'TAX'** - Isolate tax distributions from revenue
- ✅ **Identify tax types by account segment** - Use `GCC.SEGMENT2` or `GCC.SEGMENT3` based on your COA
- ✅ **Handle multiple tax types** - Use separate CASE statements for VAT, IGST, CGST, SGST

#### **Common Tax Scenarios**

**Scenario 1: Simple VAT Calculation**
- See: AR_REPOSITORIES.md Section 13 (VAT_AMOUNT calculation)

**Scenario 2: GST Calculation (IGST + CGST + SGST)**
- See: AR_REPOSITORIES.md Section 13 (IGST_TAX, CGST_TAX, SGST_TAX)

**Scenario 3: Total Tax per Transaction**
- See: AR_REPOSITORIES.md Section 13 (Group by CUSTOMER_TRX_ID)

**❌ ANTI-PATTERN: Scalar Subquery**
```sql
-- AVOID: Executes once per row (slow)
(SELECT SUM(NVL(X.AMOUNT, 0))
 FROM RA_CUSTOMER_TRX_LINES_ALL AA, ...
 WHERE AA.LINK_TO_CUST_TRX_LINE_ID = RCTL.CUSTOMER_TRX_LINE_ID)
```
✅ **DO: Use CTE Pattern** - See AR_REPOSITORIES.md Section 13

---

### 6.5 Receipt Date and Amount Patterns
> **Updated by AR team** - Receipt application decision guide (v1.3)

**📚 Reference:** Complete SQL patterns in **AR_REPOSITORIES.md Section 15** (Receipt Application Details)

#### **Quick Decision Guide**

| Your Need | Use Pattern | Reference |
|-----------|-------------|-----------|
| **First receipt date for transaction** | MIN(APPLY_DATE) in CTE | AR_REPOSITORIES.md Section 15 |
| **Total receipt amount for transaction** | SUM(AMOUNT_APPLIED) in CTE | AR_REPOSITORIES.md Section 15 |
| **Receipt details per transaction** | CTE with both date and amount | AR_REPOSITORIES.md Section 15 |

#### **Key Points**

- ✅ **Use CTE, not scalar subquery** - Pre-compute receipt data once (60-70% faster)
- ✅ **Filter APPLICATION_TYPE = 'CASH'** - Only cash applications (not credit memos)
- ✅ **Include DISPLAY = 'Y'** - Latest application records only
- ✅ **Include STATUS = 'APP'** - Applied receipts only
- ✅ **Use MIN(APPLY_DATE)** - First receipt date (not receipt date from header)

#### **Common Scenarios**

**Scenario 1: First Receipt Date**
- See: AR_REPOSITORIES.md Section 15 (FIRST_RECEIPT_DATE)

**Scenario 2: Total Receipt Amount**
- See: AR_REPOSITORIES.md Section 15 (TOTAL_RECEIPT_AMOUNT)

**Scenario 3: Both Date and Amount**
- See: AR_REPOSITORIES.md Section 15 (Complete CTE pattern)

**❌ ANTI-PATTERN: Scalar Subquery**
```sql
-- AVOID: Executes once per row (slow)
(SELECT MIN(X.APPLY_DATE) FROM AR_RECEIVABLE_APPLICATIONS_ALL X, ...
 WHERE X.APPLIED_CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID)
```
✅ **DO: Use CTE Pattern** - See AR_REPOSITORIES.md Section 15

---

### 6.6 Adjustment Amount Patterns
> **Updated by AR team** - Adjustment calculation decision guide (v1.3)

**📚 Reference:** Complete SQL patterns in **AR_REPOSITORIES.md Section 14** (Adjustment Master)

#### **Quick Decision Guide**

| Your Need | Use Pattern | Reference |
|-----------|-------------|-----------|
| **Tax withheld amount** | CTE with TYPE='TAX' and REASON_CODE='TAX' | AR_REPOSITORIES.md Section 14 |
| **Bank charges amount** | CTE with TYPE='LINE' and REASON_CODE='CHARGES' | AR_REPOSITORIES.md Section 14 |
| **All adjustment details** | Complete adjustment CTE | AR_REPOSITORIES.md Section 14 |
| **Adjustments by type** | CTE with CASE statements for each type | AR_REPOSITORIES.md Section 14 |

#### **Key Points**

- ✅ **Use CTE, not scalar subquery** - Pre-compute adjustment amounts once (60-70% faster)
- ✅ **Filter STATUS = 'A'** - Active adjustments only
- ✅ **Identify by TYPE and REASON_CODE** - Different combinations for different adjustment types
- ✅ **Common Types:**
  - `TYPE = 'TAX'` + `REASON_CODE = 'TAX'` → Tax Withheld
  - `TYPE = 'LINE'` + `REASON_CODE = 'CHARGES'` → Bank Charges
  - `TYPE = 'LINE'` + `REASON_CODE = 'DISCOUNT'` → Discounts

#### **Common Scenarios**

**Scenario 1: Tax Withheld by Client**
- See: AR_REPOSITORIES.md Section 14 (TAX_WITHHELD calculation)

**Scenario 2: Bank Charges**
- See: AR_REPOSITORIES.md Section 14 (BANK_CHARGES calculation)

**Scenario 3: Multiple Adjustment Types**
- See: AR_REPOSITORIES.md Section 14 (Complete CTE with multiple CASE statements)

**❌ ANTI-PATTERN: Scalar Subquery**
```sql
-- AVOID: Executes once per row (slow)
(SELECT SUM(AAA.AMOUNT) FROM AR_ADJUSTMENTS_ALL AAA
 WHERE AAA.CUSTOMER_TRX_ID = RCTA.CUSTOMER_TRX_ID
   AND AAA.TYPE = 'TAX')
```
✅ **DO: Use CTE Pattern** - See AR_REPOSITORIES.md Section 14

---

### 6.7 Customer Ledger Pattern (Comprehensive)
> **Updated by AR team** - Production-validated customer ledger with running balance (v2.0)

**📚 Reference:** Complete SQL pattern in **AR_REPOSITORIES.md Section 25** (Customer Ledger)

#### **Quick Decision Guide**

| Your Need | Use Pattern | Reference |
|-----------|-------------|-----------|
| **Customer ledger with opening balance** | 7-CTE structure with OPENING_BAL pattern | AR_REPOSITORIES.md Section 25 |
| **Running balance calculation** | Window function with PARTITION BY customer | AR_REPOSITORIES.md Section 25 |
| **Transaction consolidation** | UNION ALL of 3 components (Invoices, Receipts, Adjustments) | AR_REPOSITORIES.md Section 25 |
| **Debit/Credit split** | CASE logic based on amount sign | AR_REPOSITORIES.md Section 25 |

#### **Key Points**

- ✅ **AMOUNT_DUE_ORIGINAL Sign Handling (CRITICAL):** AMOUNT_DUE_ORIGINAL already has correct sign - CM is negative, INV/DM is positive
- ✅ **No Manual Sign Reversal:** Do NOT multiply CM by -1 when using AMOUNT_DUE_ORIGINAL
- ✅ **No CLASS Filter Needed:** Do NOT filter `APSA.CLASS IN ('INV', 'DM', 'CM')` when using AMOUNT_DUE_ORIGINAL
- ✅ **Opening Balance Components:** 3 types (Invoices/DMs/CMs, Receipts, Adjustments) before FROM_DATE
- ✅ **Detailed Transactions:** Same 3 types within FROM_DATE to TO_DATE
- ✅ **Running Balance:** Window function with PARTITION BY customer, ORDER BY date
- ✅ **Debit/Credit Logic:** Based on sign of AMOUNT_DUE_ORIGINAL, not CLASS

#### **Critical Discovery: AMOUNT_DUE_ORIGINAL Sign Behavior**

```sql
-- ✅ CORRECT: AMOUNT_DUE_ORIGINAL already has correct sign
SUM(NVL(APSA.AMOUNT_DUE_ORIGINAL * NVL(RCTA.EXCHANGE_RATE, 1), 0))

-- ❌ WRONG: Do NOT manually reverse CM sign
SUM(
    CASE WHEN APSA.CLASS = 'CM' 
         THEN (APSA.AMOUNT_DUE_ORIGINAL * NVL(RCTA.EXCHANGE_RATE, 1) * -1)
         ELSE (APSA.AMOUNT_DUE_ORIGINAL * NVL(RCTA.EXCHANGE_RATE, 1))
    END
)
```

#### **Common Scenarios**

**Scenario 1: Customer Ledger with Opening Balance**
- See: AR_REPOSITORIES.md Section 25 (Complete 7-CTE pattern)

**Scenario 2: Debit/Credit Split**
- See: AR_REPOSITORIES.md Section 25 (Debit/Credit CASE logic)

**Scenario 3: Running Balance Calculation**
- See: AR_REPOSITORIES.md Section 25 (Window function pattern)

**Scenario 4: Multi-Select Customer Parameter**
- See: AR_REPOSITORIES.md Section 25 (Multi-select with 'All' support)

#### **CTE Structure (7 CTEs)**

1. **PARAMS** - Parameter context
2. **CUSTOMER_MASTER** - Customer details with multi-select filter
3. **OPENING_BAL_UNION** - 3-component opening balance (before FROM_DATE)
4. **OPENING_BAL_SUMMARY** - Aggregated opening balance per customer
5. **TRX_DETAIL_UNION** - 3-component detailed transactions (within period)
6. **GL_DIST_MASTER** - GL distributions for COA segments
7. **TRX_WITH_GL** - Join transactions with GL distributions

#### **Performance Characteristics**

- **100K transactions:** < 15 seconds
- **500K transactions:** < 45 seconds
- **1M transactions:** < 90 seconds

#### **Validation Checklist**

- [ ] Using AMOUNT_DUE_ORIGINAL without manual sign reversal
- [ ] No `APSA.CLASS IN (...)` filter for invoices/CMs
- [ ] Receipt reversal exclusion with NOT EXISTS
- [ ] Adjustment STATUS = 'A' filter
- [ ] Window function for running balance
- [ ] PARTITION BY customer, ORDER BY date
- [ ] Multi-select customer parameter with 'All' support
- [ ] CUST_TRX_TYPE_SEQ_ID join (not CUST_TRX_TYPE_ID)

**❌ ANTI-PATTERN: Manual CM Sign Reversal**
```sql
-- WRONG: Unnecessary sign handling
CASE WHEN APSA.CLASS = 'CM' THEN (APSA.AMOUNT_DUE_ORIGINAL * -1)
     ELSE APSA.AMOUNT_DUE_ORIGINAL END
```
✅ **DO: Use AMOUNT_DUE_ORIGINAL directly** - See AR_REPOSITORIES.md Section 25

---

## 7. 📊 Aging Bucket Conditions
> **Updated by AR team** - Aging bucket patterns extracted from SQL files

### 7.1 Due Date Aging

```sql
-- Aging Buckets based on Due Date
CASE
    WHEN AS_OF_DATE - DUE_DATE BETWEEN CASE :P_ADD_NO
        WHEN 'Yes' THEN -60
        ELSE 0
    END AND 30 THEN AMOUNT
    WHEN AS_OF_DATE - DUE_DATE BETWEEN 31 AND 60 THEN AMOUNT
    WHEN AS_OF_DATE - DUE_DATE BETWEEN 61 AND 90 THEN AMOUNT
    WHEN AS_OF_DATE - DUE_DATE BETWEEN 91 AND 120 THEN AMOUNT
    WHEN AS_OF_DATE - DUE_DATE > 120 THEN AMOUNT
    ELSE 0
END
```

### 7.2 Invoice Date Aging

```sql
-- Aging Buckets based on Invoice Date
CASE
    WHEN AS_OF_DATE - TRX_DATE BETWEEN CASE :P_ADD_NO
        WHEN 'Yes' THEN -60
        ELSE 0
    END AND 30 THEN AMOUNT
    WHEN AS_OF_DATE - TRX_DATE BETWEEN 31 AND 60 THEN AMOUNT
    WHEN AS_OF_DATE - TRX_DATE BETWEEN 61 AND 90 THEN AMOUNT
    WHEN AS_OF_DATE - TRX_DATE BETWEEN 91 AND 120 THEN AMOUNT
    WHEN AS_OF_DATE - TRX_DATE > 120 THEN AMOUNT
    ELSE 0
END
```

### 7.3 Receipt Date Aging

```sql
-- Similar pattern using receipt date
-- Use AR_RECEIVABLE_APPLICATIONS_ALL.APPLY_DATE or AR_CASH_RECEIPTS_ALL.RECEIPT_DATE
```

---

## 8. 💡 Best Practices
> **Updated by AR team** - Additional best practices extracted from SQL analysis

1. **Always use `_ALL` tables** in multi-org environments
2. **Application ID 222** is always used for Receivables in XLA
3. **Use GL_DATE** for accounting date filters, not TRX_DATE
4. **Check DISPLAY = 'Y'** for latest application records
5. **Use STATUS = 'APP'** for applied receipts and adjustments
6. **Exclude CLASS = 'PMT'** when querying payment schedules for invoices
7. **Use NVL()** for exchange rates (default to 1)
8. **Check COMPLETE_FLAG = 'Y'** for complete transactions
9. **Use LATEST_REC_FLAG = 'Y'** for latest GL distributions
10. **Account Class values**: 'REV' (Revenue), 'REC' (Receivable), 'TAX' (Tax), 'FREIGHT', 'UNBILLED'
11. **Date Parameter Handling (CRITICAL)**: Use `TRUNC(NVL(:P_DATE, SYSDATE))` instead of `TO_DATE(:P_DATE, 'format')` to prevent ORA-01830 errors and support multiple parameter types (DATE, VARCHAR2, TIMESTAMP)
12. **Date Comparisons**: Always use `TRUNC(GL_DATE) <= P.AS_OF_DATE` to remove time components and ensure consistent date-only comparisons

---

## 9. 🔧 Common Parameter Patterns
> **Updated by AR team** - Standard parameter filter patterns

```sql
-- Organization Filter Pattern
(ORG_ID IN (:P_ORG_ID) OR 'All' IN (:P_ORG_ID || 'All'))

-- Customer Filter Pattern
(PARTY_ID = NVL(:P_CUSTOMER_ID, PARTY_ID))
(PARTY_ID IN (:P_CUSTOMER_ID) OR 'All' IN (:P_CUSTOMER_ID || 'All'))

-- Date Range Pattern
DATE_COLUMN BETWEEN NVL(:P_FROM_DATE, DATE_COLUMN) AND NVL(:P_TO_DATE, DATE_COLUMN)
DATE_COLUMN <= NVL(:P_AS_OF_DATE, DATE_COLUMN)
```

---

## 10. 🎯 AR Transaction Aging Patterns
> **Updated by AR Team** - Production-validated AR Aging query patterns (v2.0.0)

**⚠️ CRITICAL: ALL 6 COMPONENTS ARE MANDATORY FOR AR AGING QUERIES**
- Component 5 (Earned Discounts) MUST always be included
- Component 6 (Exchange Gain/Loss) MUST always be included for multi-currency environments
- Omitting earned discounts results in overstated outstanding balances
- Omitting exchange gain/loss results in currency mismatch between AR aging and GL balances
- See AR_REPOSITORIES.md Section 21 for complete implementation

### 10.1 Transaction Consolidation Pattern (6 Components)

```sql
-- Consolidate 6 Transaction Types: Invoices, Cash Apps, CM Apps, Adjustments, Earned Discounts, Exchange Gain/Loss
-- Pattern: UNION ALL with consistent column structure
-- ALL 6 COMPONENTS MANDATORY - DO NOT OMIT ANY COMPONENT

-- 1. Invoices (Original Amounts) - Exclude fully applied CMs
-- ⭐ MANDATORY COMPONENT - DO NOT OMIT IN AR AGING QUERIES
SELECT CUSTOMER_TRX_ID, ..., AMOUNT_DUE_ORIGINAL AS AMOUNT
FROM TRX_DETAILS TD, PARAM P
WHERE NOT EXISTS (
    SELECT 1
    FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA
    WHERE ARA.CUSTOMER_TRX_ID = TD.CUSTOMER_TRX_ID
      AND ARA.APPLICATION_TYPE = 'CM'
      AND ARA.GL_DATE <= P.AS_OF_DATE
)

UNION ALL

-- 2. Cash Applications (Reductions) - Multiply by -1
-- ⭐ MANDATORY COMPONENT - DO NOT OMIT IN AR AGING QUERIES
-- ✅ Production-Validated: Matches System Values
SELECT CUSTOMER_TRX_ID, ..., 
    CASE P.CURRENCY_TYPE
        WHEN 'Entered Currency' THEN (-1 * ARA.AMOUNT_APPLIED)
        ELSE  CASE 
                WHEN TD.EXCH_RATE = 1 
                THEN  (-1 * NVL(ACRA.EXCHANGE_RATE,1) * NVL(ARA.TRANS_TO_RECEIPT_RATE,1) * ARA.AMOUNT_APPLIED)
                ELSE (-1 * COALESCE(ACRA.EXCHANGE_RATE,ARA.TRANS_TO_RECEIPT_RATE,1) * ARA.AMOUNT_APPLIED)
              END
     END AS AMOUNT
FROM TRX_DETAILS TD, AR_RECEIVABLE_APPLICATIONS_ALL ARA, AR_CASH_RECEIPTS_ALL ACRA, PARAM P
WHERE TD.CUSTOMER_TRX_ID = ARA.APPLIED_CUSTOMER_TRX_ID
  AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID
  AND ARA.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID
  AND ARA.GL_DATE <= P.AS_OF_DATE
  AND ARA.APPLICATION_TYPE = 'CASH'
  AND ARA.DISPLAY = 'Y'
  AND ARA.STATUS = 'APP'

UNION ALL

-- 3. Credit Memo Applications (Reductions) - Multiply by -1
-- ⭐ MANDATORY COMPONENT - DO NOT OMIT IN AR AGING QUERIES
SELECT CUSTOMER_TRX_ID, ..., (-1 * ARA.AMOUNT_APPLIED) AS AMOUNT
FROM TRX_DETAILS TD, AR_RECEIVABLE_APPLICATIONS_ALL ARA, PARAM P
WHERE TD.CUSTOMER_TRX_ID = ARA.APPLIED_CUSTOMER_TRX_ID
  AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID
  AND ARA.GL_DATE <= P.AS_OF_DATE
  AND ARA.APPLICATION_TYPE = 'CM'
  AND ARA.DISPLAY = 'Y'
  AND ARA.STATUS = 'APP'

UNION ALL

-- 4. Adjustments (Additions/Reductions) - Use as-is
-- ⭐ MANDATORY COMPONENT - DO NOT OMIT IN AR AGING QUERIES
SELECT CUSTOMER_TRX_ID, ..., AAA.AMOUNT AS AMOUNT
FROM TRX_DETAILS TD, AR_ADJUSTMENTS_ALL AAA, PARAM P
WHERE TD.CUSTOMER_TRX_ID = AAA.CUSTOMER_TRX_ID
  AND AAA.GL_DATE <= P.AS_OF_DATE
  AND AAA.STATUS = 'A'

UNION ALL

-- 5. Earned Discounts (Reductions) - Multiply by -1
-- ⭐ MANDATORY COMPONENT - DO NOT OMIT IN AR AGING QUERIES
SELECT CUSTOMER_TRX_ID, ..., (-1 * ARA.ACCTD_EARNED_DISCOUNT_TAKEN) AS AMOUNT
FROM TRX_DETAILS TD, AR_RECEIVABLE_APPLICATIONS_ALL ARA, PARAM P
WHERE TD.CUSTOMER_TRX_ID = ARA.APPLIED_CUSTOMER_TRX_ID
  AND ARA.GL_DATE <= P.AS_OF_DATE
  AND ARA.ACCTD_EARNED_DISCOUNT_TAKEN IS NOT NULL
  AND ARA.ACCTD_EARNED_DISCOUNT_TAKEN <> 0

UNION ALL

-- 6. Exchange Gain/Loss (Additions/Reductions) - Use as-is
-- ⭐ MANDATORY COMPONENT - DO NOT OMIT IN AR AGING QUERIES
-- ⚠️ SPECIAL CURRENCY LOGIC: Returns 0 for Entered Currency, calculates for Ledger Currency
SELECT CUSTOMER_TRX_ID, ..., 
    CASE P.CURRENCY_TYPE
        WHEN 'Entered Currency' THEN 0  -- Exchange differences don't apply
        ELSE (ARA.ACCTD_AMOUNT_APPLIED_FROM - ARA.ACCTD_AMOUNT_APPLIED_TO)
    END AS AMOUNT
FROM TRX_DETAILS TD, AR_RECEIVABLE_APPLICATIONS_ALL ARA, PARAM P
WHERE TD.CUSTOMER_TRX_ID = ARA.APPLIED_CUSTOMER_TRX_ID
  AND TD.PAYMENT_SCHEDULE_ID = ARA.APPLIED_PAYMENT_SCHEDULE_ID
  AND ARA.GL_DATE <= P.AS_OF_DATE
  AND ARA.ACCTD_AMOUNT_APPLIED_FROM <> ARA.ACCTD_AMOUNT_APPLIED_TO
  AND ARA.STATUS = 'APP'
  AND ARA.DISPLAY = 'Y'
```

**Key Points:**
- ALL 6 components are mandatory for accurate aging calculations
- Component 5 tracks payment discounts taken by customers
- Component 6 tracks currency exchange differences between invoice date and payment date
- **Component 6 Special Logic:** Returns **0** for Entered Currency (no exchange impact when reporting in transaction currency), calculates difference for Ledger Currency only
- Without earned discounts, outstanding balances will be overstated
- Without exchange gain/loss, aging won't match GL balances in multi-currency environments
- Net Amount = Invoice - Cash Apps - CM Apps +/- Adjustments - Earned Discounts +/- Exchange Gain/Loss

### 10.2 Aging Bucket Calculation Pattern

```sql
-- Aging Buckets based on Due Date (5 Buckets: 0-30, 31-60, 61-90, 91-120, 121+)
-- Pattern: CASE statements at detail level, aggregate later

SELECT
     CUSTOMER_TRX_ID
    ,TRX_NUMBER
    ,DUE_DATE
    ,AMOUNT
    
    -- Bucket 0-30 Days
    ,CASE 
        WHEN AS_OF_DATE - DUE_DATE BETWEEN 0 AND 30 
        THEN AMOUNT 
        ELSE 0 
     END AS B_00_030
     
    -- Bucket 31-60 Days
    ,CASE 
        WHEN AS_OF_DATE - DUE_DATE BETWEEN 31 AND 60 
        THEN AMOUNT 
        ELSE 0 
     END AS B_31_060
     
    -- Bucket 61-90 Days
    ,CASE 
        WHEN AS_OF_DATE - DUE_DATE BETWEEN 61 AND 90 
        THEN AMOUNT 
        ELSE 0 
     END AS B_61_090
     
    -- Bucket 91-120 Days
    ,CASE 
        WHEN AS_OF_DATE - DUE_DATE BETWEEN 91 AND 120 
        THEN AMOUNT 
        ELSE 0 
     END AS B_91_120
     
    -- Bucket 121+ Days
    ,CASE 
        WHEN AS_OF_DATE - DUE_DATE > 120 
        THEN AMOUNT 
        ELSE 0 
     END AS B_120_PL
     
FROM TRX_UNION TU, PARAM P

-- Then aggregate by transaction:
GROUP BY CUSTOMER_TRX_ID, TRX_NUMBER, TRX_DATE, DUE_DATE, ...
-- Note: Zero balance filtering (HAVING clause) is optional - add only if needed
```

### 10.3 Due Date Calculation Pattern

```sql
-- Calculate Due Date from Terms (Direct Join, No Subquery)
-- Pattern: Join RA_TERMS_LINES directly, use outer join

FROM 
     RA_CUSTOMER_TRX_ALL      RCTA
    ,AR_PAYMENT_SCHEDULES_ALL APSA
    ,RA_TERMS_LINES RTL
    ,PARAM P
WHERE 
        RCTA.CUSTOMER_TRX_ID = APSA.CUSTOMER_TRX_ID
    AND RCTA.TERM_ID = RTL.TERM_ID(+)  -- Outer join for transactions without terms
    ...

SELECT
    TRUNC(NVL(RCTA.TERM_DUE_DATE, 
        (RCTA.TRX_DATE + NVL(RTL.DUE_DAYS, 0)))) AS DUE_DATE
```

### 10.4 Currency Conversion Pattern (Aging Reports)

```sql
-- Currency Conversion: Entered Currency vs Ledger Currency
-- Pattern: Simple CASE with ELSE (no redundant conditions)

CASE P.CURRENCY_TYPE
    WHEN 'Entered Currency' THEN AMOUNT
    ELSE (EXCH_RATE * AMOUNT)
END

-- Apply to Components 1-5 (Invoices, Cash, CM, Adjustments, Earned Discounts)
-- Always use NVL(EXCHANGE_RATE, 1) for EXCH_RATE calculation
```

**⚠️ EXCEPTION: Exchange Gain/Loss (Component 6) - Special Currency Logic**

```sql
-- Component 6 has DIFFERENT currency logic - Returns 0 for Entered Currency
CASE P.CURRENCY_TYPE
    WHEN 'Entered Currency' THEN 0  -- Exchange differences don't apply
    ELSE (ARA.ACCTD_AMOUNT_APPLIED_FROM - ARA.ACCTD_AMOUNT_APPLIED_TO)
END

-- Why: Exchange rate differences only exist when reporting in functional/ledger currency
-- In transaction currency (Entered), there's no exchange rate impact by definition
```

### 10.5 NOT EXISTS Pattern for CM Exclusion

```sql
-- Exclude Fully Applied Credit Memos (Better than NOT IN)
-- Pattern: NOT EXISTS with point-in-time GL_DATE filter

WHERE NOT EXISTS (
    SELECT 1
    FROM AR_RECEIVABLE_APPLICATIONS_ALL ARA
    WHERE ARA.CUSTOMER_TRX_ID = TD.CUSTOMER_TRX_ID
      AND ARA.APPLICATION_TYPE = 'CM'
      AND ARA.GL_DATE <= P.AS_OF_DATE  -- Point-in-time accuracy
)

-- Benefits over NOT IN:
-- 1. Better NULL handling
-- 2. Early termination (stops at first match)
-- 3. More efficient execution plan
-- 4. Less memory usage
```

### 10.6 Point-in-Time Accuracy Pattern

```sql
-- Point-in-Time Reporting: Use GL_DATE filters consistently
-- Pattern: Apply GL_DATE <= AS_OF_DATE to all transaction components

-- Base Transactions
AND APSA.GL_DATE <= P.AS_OF_DATE

-- Cash Applications
AND ARA.GL_DATE <= P.AS_OF_DATE

-- Credit Memo Applications
AND ARA.GL_DATE <= P.AS_OF_DATE

-- Adjustments
AND AAA.GL_DATE <= P.AS_OF_DATE

-- CM Exclusion (in NOT EXISTS)
AND ARA.GL_DATE <= P.AS_OF_DATE
```

### 10.7 Multi-Select Parameter Pattern

```sql
-- Multi-Select with 'All' Support
-- Pattern: Use IN clause with OR condition for 'All'

-- Organization Filter
(RCTA.ORG_ID IN (:P_ORG_ID) OR 'All' IN (:P_ORG_ID || 'All'))

-- Customer Filter
(HP.PARTY_ID IN (:P_CUSTOMER_ID) OR 'All' IN (:P_CUSTOMER_ID || 'All'))

-- Usage Examples:
-- Single: :P_ORG_ID = '101'
-- Multiple: :P_ORG_ID = ('101', '102', '103')
-- All: :P_ORG_ID = 'All'
```

### 10.8 CTE Optimization for Aging Reports

```sql
-- Efficient CTE Structure (9 CTEs for AR Aging)
-- Pattern: MATERIALIZE for reused CTEs, PARALLEL for large scans

WITH 
-- 1. Parameters (Always first, no hints needed)
PARAM AS (
    SELECT TO_DATE(:P_ACCT_DATE, 'yyyy-mm-dd') AS AS_OF_DATE, ... FROM DUAL
),

-- 2. Base Transactions (MATERIALIZE + PARALLEL for large dataset)
TRX_DETAILS AS (
    SELECT /*+ MATERIALIZE PARALLEL(4) */ ... FROM RCTA, APSA, RTL, PARAM
),

-- 3-5. Master Data (MATERIALIZE for reuse)
CUST_MASTER AS (SELECT /*+ MATERIALIZE */ ... FROM HCA, HP),
BU_MASTER AS (SELECT /*+ MATERIALIZE */ ... FROM FABUV),
PROJECT_DETAILS AS (SELECT /*+ PARALLEL(4) */ ... FROM RCTLGDA, GCC, PJFPAB),

-- 6. Transaction Union (PARALLEL for each UNION block)
TRX_UNION AS (
    SELECT /*+ PARALLEL(4) */ ... FROM TRX_DETAILS  -- Invoices
    UNION ALL
    SELECT /*+ PARALLEL(4) */ ... FROM TRX_DETAILS, ARA  -- Cash
    UNION ALL
    SELECT /*+ PARALLEL(4) */ ... FROM TRX_DETAILS, ARA  -- CM
    UNION ALL
    SELECT /*+ PARALLEL(4) */ ... FROM TRX_DETAILS, AAA  -- Adjustments
),

-- 7-8. Bucketing and Aggregation (No hints, let optimizer decide)
AGING_BUCKETS AS (...),
TRX_SUMMARY AS (...)

-- 9. Final SELECT with joins
SELECT ... FROM TRX_SUMMARY, CUST_MASTER, BU_MASTER, PROJECT_DETAILS
```

### 10.9 Oracle BI Tools Compatibility

> [!CRITICAL]
> **AMPERSAND RULE:** NEVER use ampersand (&) symbol anywhere in SQL queries, including comments. Ampersand triggers lexical parameter prompts in Oracle BI Tools (OTBI, BI Publisher) causing query failures.

```sql
-- Critical Rules for Oracle BI Tools (OTBI, BI Publisher)

-- 1. NO AMPERSAND anywhere (including comments) - CRITICAL
-- WRONG: -- PROJECT & INTERCOMPANY
-- WRONG: -- Currency & Amounts
-- WRONG: -- Balance & Charges
-- CORRECT: -- PROJECT AND INTERCOMPANY
-- CORRECT: -- Currency AND Amounts
-- CORRECT: -- Balance AND Charges
-- Reason: Ampersand triggers lexical parameter prompts and causes query failures

-- 2. NO SEMICOLON at end of query
-- WRONG: ORDER BY ... ;
-- CORRECT: ORDER BY ...

-- 3. Use BIND VARIABLES with :P_ prefix
-- CORRECT: :P_ORG_ID, :P_ACCT_DATE, :P_CUSTOMER_ID, :P_LEDGER_CURR

-- 4. Non-ANSI Oracle syntax preferred
-- Use comma-separated tables with WHERE clause joins
-- Use (+) for outer joins, not LEFT JOIN
```

**Common Ampersand Violations to Avoid:**
- Comments: `Currency & Amounts` → Use `Currency AND Amounts`
- Comments: `Balance & Charges` → Use `Balance AND Charges`
- Comments: `Retention & Adjustments` → Use `Retention AND Adjustments`
- Comments: `PROJECT & INTERCOMPANY` → Use `PROJECT AND INTERCOMPANY`

### 10.10 Performance Best Practices (AR Aging)

```sql
-- 1. Direct Joins over Correlated Subqueries
-- AVOID: (SELECT MAX(DUE_DAYS) FROM RA_TERMS_LINES WHERE TERM_ID = RCTA.TERM_ID)
-- USE: Direct join with outer join operator (+)

-- 2. NOT EXISTS over NOT IN
-- AVOID: WHERE CUSTOMER_TRX_ID NOT IN (SELECT ... FROM ...)
-- USE: WHERE NOT EXISTS (SELECT 1 FROM ... WHERE ...)

-- 3. Remove Unused CTEs
-- Only define CTEs that are actually used in the query

-- 4. Simplify CASE Logic
-- AVOID: CASE WHEN 'A' THEN X WHEN 'B' THEN Y ELSE Y END
-- USE: CASE WHEN 'A' THEN X ELSE Y END

-- 5. Filter Early in CTE Chain
-- Apply ORG_ID, GL_DATE filters in base CTE (TRX_DETAILS)
-- Don't wait until final SELECT

-- 6. Use HAVING for Aggregate Filters
-- Filter out zero balances at aggregation level, not final SELECT
-- HAVING (SUM(...)) > 0 is more efficient than WHERE in outer query
```

### 10.11 AR Unapplied Receipts Aging Pattern (Production-Validated)
> **Updated by AR team** - Production-validated unapplied receipts aging pattern (v1.1)
> **Status:** ✅ Production Validated - Working perfectly, matches system values

**📚 Reference:** Complete SQL pattern in **AR_REPOSITORIES.md Section 26** (AR Unapplied Receipts Aging Report)

#### **Quick Decision Guide**

|| Your Need | Use Pattern | Reference |
||-----------|-------------|-----------|
|| **Track on-account receipts** | 11-CTE split architecture | AR_REPOSITORIES.md Section 26 |
|| **Cash application prioritization** | 8 aging buckets (vs 5 for Outstanding) | AR_REPOSITORIES.md Section 26 |
|| **Combined with Outstanding Balance** | Compare reports for net balance | AR_REPOSITORIES.md Section 26 |
|| **Customer categorization** | Date-effective customer profile | AR_REPOSITORIES.md Section 26 |

#### **Business Use Case**

```
Customer XYZ Balance Analysis:
- Outstanding Balance: +100 USD (customer owes)
- Unapplied Receipts: -100 USD (cash on-account)
- Net Balance: 0 USD → No collection call needed ✓
```

**Benefits:**
- Avoid unnecessary collection calls
- Prioritize aged unapplied receipt applications
- Identify customers with available cash
- Improve working capital management

#### **Key Differences from Outstanding Balance Aging**

| Aspect | Outstanding Balance | Unapplied Receipts |
|--------|--------------------|--------------------|
| **Amount Sign** | Positive (+) | Negative (-) |
| **Represents** | Customer owes company | Company holds customer cash |
| **Transaction Types** | 5 components (Inv, Cash, CM, Adj, Disc) | 1 component (Receipts only) |
| **Status Filter** | `APSA.CLASS != 'PMT'` | `ARAA.STATUS IN ('UNAPP','ACC','UNID')` |
| **Aging Buckets** | 5 (0-30, 31-60, 61-90, 91-120, 121+) | 8 (Current, 1-30, 31-60, 61-90, 91-120, 121-180, 181-365, 365+) |
| **Business Purpose** | Collections/Credit management | Cash application management |
| **CTE Structure** | 8 CTEs | 11 CTEs (split architecture) |
| **Reference** | AR_REPOSITORIES.md Section 21 | AR_REPOSITORIES.md Section 26 |

#### **Critical Receipt Status Filters (Production-Validated)**

```sql
-- Receipt Header (AR_CASH_RECEIPTS_ALL)
WHERE ACRA.STATUS NOT IN ('APP')  -- Exclude fully applied receipts

-- Application Status (AR_RECEIVABLE_APPLICATIONS_ALL)
WHERE ARAA.STATUS IN ('UNAPP','ACC','UNID')
  -- UNAPP = Unapplied (on-account payment)
  -- ACC = On-account (accounting synonym)
  -- UNID = Unidentified receipt

-- Receipt History (AR_CASH_RECEIPT_HISTORY_ALL)
WHERE ACRH.CURRENT_RECORD_FLAG = 'Y'

-- Payment Schedule (AR_PAYMENT_SCHEDULES_ALL)
WHERE APSA.CLASS = 'PMT'  -- Receipts have PMT class

-- Receipt Reversal Exclusion (CRITICAL)
AND NOT EXISTS (
    SELECT 1
    FROM AR_CASH_RECEIPT_HISTORY_ALL H
    WHERE H.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID
      AND H.STATUS = 'REVERSED'
)

-- Point-in-Time Filter
WHERE ARAA.GL_DATE <= P.AS_OF_DATE
```

#### **Amount Sign Handling (CRITICAL)**

```sql
-- Unapplied receipts ALWAYS shown as NEGATIVE
-- Represents cash that REDUCES customer balance
,CASE 
    WHEN URD.AGING_DAYS BETWEEN 1 AND 30 
    THEN (URD.AMOUNT_APPLIED * -1)  -- Multiply by -1
    ELSE 0 
 END AS B_01_030

-- Why Negative:
-- Outstanding: +100 (customer owes)
-- Unapplied: -100 (cash on-account)
-- Net: 0 (no payment needed)
```

#### **8 Aging Buckets (vs 5 for Outstanding)**

```sql
-- More granular bucketing for cash application prioritization
-- Pattern: CASE statements at detail level, aggregate later

,CASE WHEN AGING_DAYS <= 0 THEN (AMOUNT * -1) ELSE 0 END AS B_CURRENT
,CASE WHEN AGING_DAYS BETWEEN 1 AND 30 THEN (AMOUNT * -1) ELSE 0 END AS B_01_030
,CASE WHEN AGING_DAYS BETWEEN 31 AND 60 THEN (AMOUNT * -1) ELSE 0 END AS B_31_060
,CASE WHEN AGING_DAYS BETWEEN 61 AND 90 THEN (AMOUNT * -1) ELSE 0 END AS B_61_090
,CASE WHEN AGING_DAYS BETWEEN 91 AND 120 THEN (AMOUNT * -1) ELSE 0 END AS B_91_120
,CASE WHEN AGING_DAYS BETWEEN 121 AND 180 THEN (AMOUNT * -1) ELSE 0 END AS B_121_180
,CASE WHEN AGING_DAYS BETWEEN 181 AND 365 THEN (AMOUNT * -1) ELSE 0 END AS B_181_365
,CASE WHEN AGING_DAYS > 365 THEN (AMOUNT * -1) ELSE 0 END AS B_OVER_1_YEAR
```

**Why 8 Buckets:**
- Receipts aged 121-180 days need attention
- Receipts aged 181-365 days are high priority
- Receipts over 1 year may indicate disputes/system issues

#### **Split CTE Architecture (11 CTEs)**

```sql
-- Better maintainability through separation of concerns
-- Pattern: Break down large CTE into smaller logical units

1.  PARAM                     → All parameters (AS_OF_DATE, ORG_ID, CUSTOMER_ID)
2.  CUST_MASTER              → Customer with profile class (date-effective)
3.  BU_MASTER                → Business units
4.  RCPT_HEADER              → Base receipts (with reversal exclusion)
5.  RCPT_HISTORY             → Current record filter
6.  RCPT_APPLICATIONS        → Unapplied status filter (UNAPP/ACC/UNID)
7.  RCPT_PAYMENT_SCHEDULE    → Due date source (CLASS='PMT')
8.  UNAPPLIED_RCPT_DETAILS   → Consolidated view (joins 4-7)
9.  AGING_BUCKETS            → 8 bucket calculations
10. RCPT_SUMMARY             → Aggregation by receipt
11. Final SELECT             → Output with all joins
```

**Benefits:**
- Each CTE handles one specific data source
- Better testability (test each CTE independently)
- Easier debugging (isolate issues to specific CTE)
- Better maintainability (changes isolated to specific CTEs)

#### **Date-Effective Customer Profile Pattern**

```sql
-- Customer categorization with proper date handling
-- Pattern: Date-effective table requires START/END date filters

FROM HZ_CUST_ACCOUNTS HCA
    ,HZ_CUSTOMER_PROFILES_F HCPF  -- _F suffix = date-effective
    ,HZ_CUST_PROFILE_CLASSES HCPC
WHERE HCA.CUST_ACCOUNT_ID = HCPF.CUST_ACCOUNT_ID(+)
  AND HCPF.PROFILE_CLASS_ID = HCPC.PROFILE_CLASS_ID(+)
  -- CRITICAL: Date-effective filter
  AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(HCPF.EFFECTIVE_START_DATE, SYSDATE - 1))
                         AND TRUNC(NVL(HCPF.EFFECTIVE_END_DATE, SYSDATE + 1))
```

#### **All Parameters in PARAM CTE Pattern**

```sql
-- Capture ALL parameters in PARAM CTE (not just dates)
-- Pattern: Single source of truth for all parameter values

PARAM AS (
    SELECT 
         TO_DATE(SUBSTR(:P_ACCT_DATE, 1, 10), 'yyyy-mm-dd') AS AS_OF_DATE
        ,:P_ORG_ID                                          AS ORG_ID
        ,:P_CUSTOMER_ID                                     AS CUSTOMER_ID
    FROM DUAL
)

-- Then reference P.ORG_ID and P.CUSTOMER_ID in all subsequent CTEs
WHERE (ACRA.ORG_ID IN (P.ORG_ID) OR 'All' IN (P.ORG_ID || 'All'))
```

**Benefits:**
- Single source of truth for parameters
- Easier debugging (check PARAM CTE)
- Better BI tool integration
- Consistent parameter usage across all CTEs

#### **Common Scenarios**

**Scenario 1: Unapplied Receipts Aging Report**
- See: AR_REPOSITORIES.md Section 26 (Complete 11-CTE pattern)

**Scenario 2: Identify Aged Unapplied Receipts**
- See: AR_REPOSITORIES.md Section 26 (8 aging buckets)

**Scenario 3: Customer Category Analysis**
- See: AR_REPOSITORIES.md Section 26 (Date-effective customer profile)

**Scenario 4: Combined with Outstanding Balance**
- Run: AR_Aging_Report_Detailed.sql (Outstanding)
- Run: AR_Unapplied_Receipts_Aging_Report.sql (Unapplied)
- Compare: Outstanding + Unapplied = Net Balance

#### **Performance Characteristics**

- **100K receipts:** < 10 seconds
- **500K receipts:** < 30 seconds
- **1M receipts:** < 60 seconds

**Optimization:**
- MATERIALIZE on reusable CTEs (CUST_MASTER, BU_MASTER, RCPT_HEADER)
- PARALLEL(4) on large scans (RCPT_HEADER, RCPT_APPLICATIONS)
- Early filtering (ORG_ID and date in base CTEs)

#### **Critical Implementation Rules**

**🔴 REQUIRED for Unapplied Receipts Aging:**
- ✅ **All parameters in PARAM CTE** - ORG_ID, CUSTOMER_ID, AS_OF_DATE
- ✅ **Split CTE architecture** - 11 CTEs for better maintainability
- ✅ **Receipt status:** `ACRA.STATUS NOT IN ('APP')`
- ✅ **Application status:** `ARAA.STATUS IN ('UNAPP','ACC','UNID')`
- ✅ **Receipt history:** `ACRH.CURRENT_RECORD_FLAG = 'Y'`
- ✅ **Payment schedule:** `APSA.CLASS = 'PMT'`
- ✅ **Negative amount sign** - Multiply by -1 in bucket calculations
- ✅ **8 aging buckets** - Current, 1-30, 31-60, 61-90, 91-120, 121-180, 181-365, 365+
- ✅ **Receipt reversal exclusion** - NOT EXISTS with STATUS = 'REVERSED'
- ✅ **Point-in-time filter** - ARAA.GL_DATE <= AS_OF_DATE
- ✅ **Date-effective customer profile** - EFFECTIVE_START_DATE and EFFECTIVE_END_DATE

#### **Quick Checklist Before Using**

- [ ] All parameters in PARAM CTE (AS_OF_DATE, ORG_ID, CUSTOMER_ID)
- [ ] Split CTE architecture (11 CTEs)
- [ ] Receipt status: `ACRA.STATUS NOT IN ('APP')`
- [ ] Application status: `ARAA.STATUS IN ('UNAPP','ACC','UNID')`
- [ ] Receipt history: `ACRH.CURRENT_RECORD_FLAG = 'Y'`
- [ ] Payment schedule: `APSA.CLASS = 'PMT'`
- [ ] Negative amount sign: `(AMOUNT_APPLIED * -1)`
- [ ] 8 aging buckets (not 5)
- [ ] Receipt reversal exclusion with NOT EXISTS
- [ ] Point-in-time filter: `ARAA.GL_DATE <= AS_OF_DATE`
- [ ] Date-effective customer profile with EFFECTIVE_START_DATE and EFFECTIVE_END_DATE

**❌ ANTI-PATTERN: Single Large CTE**
```sql
-- AVOID: Large monolithic CTE with all logic
UNAPPLIED_RCPT_DETAILS AS (
    SELECT ... 20+ columns ...
    FROM ACRA, ARAA, ACRH, APSA  -- All tables in one CTE
    WHERE ... complex filters ...  -- All filters mixed together
)
```

✅ **DO: Use Split CTE Architecture** - See AR_REPOSITORIES.md Section 26

**Production Status:**
- ✅ Validated against system values
- ✅ Working perfectly
- ✅ Ready for production use

**References:**
- **Complete Pattern:** AR_REPOSITORIES.md Section 26

---

### 10.12 AR Aging with Unapplied Receipts Integration Pattern (Production-Validated)
> **Updated by AR team** - Production-validated integrated aging with unapplied receipts (v2.2.0)
> **Status:** ✅ Production Validated - Working perfectly, matches system values

**📚 Reference:** Complete SQL pattern in **AR_REPOSITORIES.md Section 27** (AR Aging with Unapplied Receipts Integration)

#### **Quick Decision Guide**

|| Your Need | Use Pattern | Reference |
||-----------|-------------|-----------|
|| **True customer net balance** | 7-component pattern with unapplied receipts | AR_REPOSITORIES.md Section 27 |
|| **Collections with cash visibility** | Combined outstanding + unapplied in one report | AR_REPOSITORIES.md Section 27 |
|| **Not-yet-due invoices** | 6 aging buckets (+ Not Due Yet) | AR_REPOSITORIES.md Section 27 |
|| **Standard aging only** | Use 6-component pattern instead | AR_REPOSITORIES.md Section 21 |

#### **Business Use Case**

```
Customer ABC Outstanding Analysis:
Component                    Amount
─────────────────────────────────────
Outstanding Invoices         +15,000 USD
Less: Unapplied Receipts     -10,000 USD
─────────────────────────────────────
Net Balance (Collections)     5,000 USD ✓

Insight: Customer has cash on-account, reduce collection pressure
```

**Benefits:**
- True net customer balance (not just gross outstanding)
- Avoid unnecessary collection calls (customer has cash)
- Prioritize which unapplied receipts to apply first
- Better working capital visibility
- Separate "Not Due Yet" bucket for future invoices

#### **Key Differences from Standard AR Aging**

|| Aspect | Standard AR Aging (Section 21) | Aging with Unapplied Receipts (Section 27) |
||--------|-------------------------------|------------------------------------------|
|| **Components** | 6 (Inv, Cash, CM, Adj, Disc, Exch Gain/Loss) | 7 (+ Unapplied Receipts) |
|| **Balance Type** | Gross Outstanding | Net Outstanding |
|| **Aging Buckets** | 5 (0-30, 31-60, 61-90, 91-120, 121+) | 6 (+ Not Due Yet) |
|| **Transaction Type** | Not shown | Shows type name from RA_CUST_TRX_TYPES_ALL |
|| **Use Case** | Collections priority | True cash position AND collections |
|| **CTE Structure** | 8 CTEs | 11 CTEs (split architecture) |
|| **Unapplied Impact** | Not included | Reduces balance (negative amounts) |
|| **Reference** | AR_REPOSITORIES.md Section 21 | AR_REPOSITORIES.md Section 27 |

#### **Critical Component 6: Unapplied Receipts (MANDATORY)**

```sql
-- Component 6 is a SEPARATE CTE (not in TRX_UNION)
-- Pattern: Split architecture for better maintainability

UNAPPLIED_RECEIPTS AS (
    SELECT 
         ACRA.CASH_RECEIPT_ID AS TRANSACTION_ID
        ,ACRA.RECEIPT_NUMBER AS TRX_NUMBER
        ,'Unapplied Receipts' AS TRANSACTION_TYPE
        ,(-1 * ARAA.AMOUNT_APPLIED) AS AMOUNT  -- NEGATIVE reduces balance
    FROM AR_CASH_RECEIPTS_ALL ACRA
        ,AR_RECEIVABLE_APPLICATIONS_ALL ARAA
        ,AR_PAYMENT_SCHEDULES_ALL APSA_RCPT
        ,PARAM P
    WHERE ACRA.CASH_RECEIPT_ID = ARAA.CASH_RECEIPT_ID
      AND ACRA.CASH_RECEIPT_ID = APSA_RCPT.CASH_RECEIPT_ID
      AND APSA_RCPT.CLASS = 'PMT'
      -- CRITICAL STATUS FILTERS:
      AND ARAA.STATUS IN ('UNAPP','ACC','UNID')
      AND ACRA.STATUS NOT IN ('APP')
      AND ARAA.GL_DATE <= P.AS_OF_DATE
      -- Receipt Reversal Exclusion:
      AND NOT EXISTS (
          SELECT 1 FROM AR_CASH_RECEIPT_HISTORY_ALL ACRH
          WHERE ACRH.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID
            AND ACRH.STATUS = 'REVERSED'
      )
)

-- Then combine with invoice transactions:
COMBINED_TRANSACTIONS AS (
    SELECT * FROM TRX_UNION      -- Components 1-5
    UNION ALL
    SELECT * FROM UNAPPLIED_RECEIPTS  -- Component 6
)
```

**Why Negative Sign:**
- Outstanding invoices = +100 (customer owes)
- Unapplied receipts = -100 (cash on-account)
- Net balance = 0 (no collection action needed)

#### **Not Due Yet Bucket (NEW)**

```sql
-- Bucket for future-dated invoices (AS_OF_DATE < DUE_DATE)
-- Pattern: Shows "No Due Yet (X days left)" in separate column

-- In AGING_BUCKETS CTE:
,CASE 
    WHEN P.AS_OF_DATE - CT.DUE_DATE < 0 
    THEN CT.AMOUNT 
    ELSE 0 
 END AS B_NOT_DUE

,CASE 
    WHEN P.AS_OF_DATE - CT.DUE_DATE < 0 
    THEN 'No Due Yet (' || ABS(P.AS_OF_DATE - CT.DUE_DATE) || ' days left)'
    ELSE NULL 
 END AS NO_DUE_YET_STATUS

-- In final SELECT (last column):
,TS.NO_DUE_YET_STATUS AS "NO_DUE_YET_STATUS"
```

**Benefits:**
- Separate future receivables from overdue
- Better cash flow forecasting
- Clearer aging analysis

#### **11-CTE Split Architecture**

```sql
-- Better maintainability through separation of concerns

1.  PARAM                    → All parameters
2.  TRX_DETAILS              → Base transactions + TRANSACTION_TYPE join
3.  CUST_MASTER              → Customer master
4.  BU_MASTER                → Business units
5.  PROJECT_DETAILS          → Project and intercompany
6.  TRX_UNION                → Components 1-5 (invoice-related)
7.  UNAPPLIED_RECEIPTS       → Component 6 (receipts - separate CTE)
8.  COMBINED_TRANSACTIONS    → UNION ALL of TRX_UNION + UNAPPLIED_RECEIPTS
9.  AGING_BUCKETS            → 6 bucket calculations + NO_DUE_YET_STATUS
10. TRX_SUMMARY              → Aggregation by transaction
11. Final SELECT             → Output with all joins
```

**Why Split Architecture:**
- Invoice transactions (TRX_UNION) use RA_CUSTOMER_TRX_ALL as base
- Receipt transactions (UNAPPLIED_RECEIPTS) use AR_CASH_RECEIPTS_ALL as base
- Different table structures require different join patterns
- Easier to test and debug each component independently

#### **Transaction Type Integration**

```sql
-- TRANSACTION_TYPE column from RA_CUST_TRX_TYPES_ALL
-- Pattern: Join in TRX_DETAILS, hardcode in UNAPPLIED_RECEIPTS

-- In TRX_DETAILS CTE:
FROM RA_CUSTOMER_TRX_ALL RCTA
    ,RA_CUST_TRX_TYPES_ALL RCTT
WHERE RCTA.CUST_TRX_TYPE_SEQ_ID = RCTT.CUST_TRX_TYPE_SEQ_ID

SELECT RCTT.NAME AS TRANSACTION_TYPE

-- In UNAPPLIED_RECEIPTS CTE:
SELECT 'Unapplied Receipts' AS TRANSACTION_TYPE

-- Result in report:
-- "Invoice", "Credit Memo", "Debit Memo", "Unapplied Receipts"
```

#### **When to Use This Pattern**

✅ **Use When:**
- Need accurate net customer balance (not just gross outstanding)
- Collections team needs to see available on-account cash
- Cash application team prioritizes which receipts to apply
- Management reporting requires true working capital position
- Customer disputes "we already paid" - verify unapplied cash exists
- Credit hold decisions need net exposure calculation
- Need to separate not-yet-due invoices from overdue

❌ **Don't Use When:**
- Only need standard aging (use AR_REPOSITORIES.md Section 21 instead)
- Only need unapplied receipts (use AR_REPOSITORIES.md Section 26 instead)
- Performance is critical and unapplied receipts not needed
- Don't need transaction type visibility

#### **Common Scenarios**

**Scenario 1: Collections with Cash Visibility**
- See: AR_REPOSITORIES.md Section 27 (Complete 11-CTE pattern)

**Scenario 2: Not-Yet-Due Invoice Analysis**
- See: AR_REPOSITORIES.md Section 27 (NOT_DUE_YET bucket)

**Scenario 3: Transaction Type Breakdown**
- See: AR_REPOSITORIES.md Section 27 (TRANSACTION_TYPE column)

**Scenario 4: Net Balance Calculation**
- Outstanding: Run AR_REPOSITORIES.md Section 21
- With Unapplied: Run AR_REPOSITORIES.md Section 27
- Compare: See impact of unapplied receipts on customer balance

#### **Performance Characteristics**

- **10K transactions:** < 5 seconds
- **50K transactions:** < 15 seconds
- **100K transactions:** < 30 seconds
- **500K transactions:** < 90 seconds

**Optimization:**
- MATERIALIZE on reusable CTEs (TRX_DETAILS, CUST_MASTER, BU_MASTER)
- PARALLEL(4) on large scans (all UNION ALL blocks)
- Early filtering (ORG_ID, CUSTOMER_ID, GL_DATE in base CTEs)

#### **Critical Implementation Rules**

**🔴 REQUIRED for All 7 Components:**
- ✅ **Component 5 (Earned Discounts)** - MANDATORY, use ACCTD_EARNED_DISCOUNT_TAKEN
- ✅ **Component 6 (Exchange Gain/Loss)** - MANDATORY, use (ACCTD_AMOUNT_APPLIED_FROM - ACCTD_AMOUNT_APPLIED_TO)
- ✅ **Component 7 (Unapplied Receipts)** - MANDATORY, separate CTE with negative amounts
- ✅ **Status filters:** `ARAA.STATUS IN ('UNAPP','ACC','UNID')` and `ACRA.STATUS NOT IN ('APP')`
- ✅ **Amount source:** Use `ARAA.AMOUNT_APPLIED` (not `AMOUNT_DUE_REMAINING`)
- ✅ **Negative sign:** Multiply by -1 in UNAPPLIED_RECEIPTS CTE
- ✅ **Split architecture:** TRX_UNION (1-5) + UNAPPLIED_RECEIPTS (6) + COMBINED_TRANSACTIONS
- ✅ **Transaction type:** Join RA_CUST_TRX_TYPES_ALL using CUST_TRX_TYPE_SEQ_ID
- ✅ **Not Due Yet bucket:** Calculate for AS_OF_DATE < DUE_DATE
- ✅ **Receipt reversal exclusion:** NOT EXISTS with STATUS = 'REVERSED'
- ✅ **Point-in-time filter:** GL_DATE <= AS_OF_DATE on all components
- ✅ **All parameters in PARAM CTE:** AS_OF_DATE, ORG_ID, CUSTOMER_ID, CURRENCY_TYPE

#### **Quick Checklist Before Using**

- [ ] All 7 components present (including Components 5, 6, and 7)
- [ ] Component 6 (Exchange Gain/Loss) in TRX_UNION CTE
- [ ] Component 7 (Unapplied Receipts) in separate UNAPPLIED_RECEIPTS CTE
- [ ] COMBINED_TRANSACTIONS unions TRX_UNION + UNAPPLIED_RECEIPTS
- [ ] Unapplied receipt status: `ARAA.STATUS IN ('UNAPP','ACC','UNID')`
- [ ] Receipt status: `ACRA.STATUS NOT IN ('APP')`
- [ ] Negative sign: `(-1 * ARAA.AMOUNT_APPLIED)` in UNAPPLIED_RECEIPTS
- [ ] Transaction type join: `CUST_TRX_TYPE_SEQ_ID = RCTT.CUST_TRX_TYPE_SEQ_ID`
- [ ] Not Due Yet bucket: `B_NOT_DUE` and `NO_DUE_YET_STATUS`
- [ ] Receipt reversal exclusion with NOT EXISTS
- [ ] Point-in-time filter: `GL_DATE <= AS_OF_DATE` on all components
- [ ] All parameters in PARAM CTE

**❌ ANTI-PATTERN: Using AMOUNT_DUE_REMAINING for Unapplied Receipts**
```sql
-- WRONG: Payment schedule remaining (not unapplied amount)
APSA.AMOUNT_DUE_REMAINING
```

✅ **DO: Use ARAA.AMOUNT_APPLIED** - See AR_REPOSITORIES.md Section 27

**❌ ANTI-PATTERN: Mixing Unapplied Receipts in TRX_UNION**
```sql
-- WRONG: Different base tables cause join complexity
TRX_UNION AS (
    SELECT ... FROM TRX_DETAILS ...  -- Invoice base
    UNION ALL
    SELECT ... FROM AR_CASH_RECEIPTS_ALL ...  -- Receipt base (different structure)
)
```

✅ **DO: Use Split Architecture** - See AR_REPOSITORIES.md Section 27

**Production Status:**
- ✅ Validated against system values
- ✅ Working perfectly
- ✅ Ready for production use
- ✅ Matches Oracle Fusion system output exactly

**References:**
- **Complete Pattern:** AR_REPOSITORIES.md Section 27 (Full SQL + Documentation)
- **Standard Aging (5 components):** AR_REPOSITORIES.md Section 21
- **Unapplied Receipts Only:** AR_REPOSITORIES.md Section 26

---
