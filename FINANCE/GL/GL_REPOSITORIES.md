# GL Repository Patterns

**Purpose:** Standardized CTEs for General Ledger data.

---

## 1. Account Balances
*Retrieves Period-to-Date (PTD) and Year-To-Date (YTD) balances.*

```sql
GL_BALANCES_MASTER AS (
    SELECT /*+ qb_name(GL_BAL) MATERIALIZE */
           GB.LEDGER_ID
          ,GB.CODE_COMBINATION_ID
          ,GB.PERIOD_NAME
          ,GB.CURRENCY_CODE
          ,GB.PERIOD_NET_DR
          ,GB.PERIOD_NET_CR
          ,(NVL(GB.PERIOD_NET_DR,0) - NVL(GB.PERIOD_NET_CR,0)) AS PTD_BALANCE
          ,(NVL(GB.BEGIN_BALANCE_DR,0) - NVL(GB.BEGIN_BALANCE_CR,0) + 
            NVL(GB.PERIOD_NET_DR,0) - NVL(GB.PERIOD_NET_CR,0)) AS YTD_BALANCE
    FROM   GL_BALANCES GB
    WHERE  GB.ACTUAL_FLAG = 'A' -- Actuals only
      AND  GB.LEDGER_ID IN (:P_LEDGER_ID)
      AND  GB.PERIOD_NAME IN (:P_PERIOD)
)
```

---

## 2. Journal Entries (Basic)
*Retrieves detailed journal lines.*

```sql
GL_JE_MASTER AS (
    SELECT /*+ qb_name(GL_JE) MATERIALIZE */
           GJH.JE_HEADER_ID
          ,GJH.NAME AS JE_NAME
          ,GJH.JE_SOURCE
          ,GJH.JE_CATEGORY
          ,GJH.POSTED_DATE
          ,GJL.JE_LINE_NUM
          ,GJL.CODE_COMBINATION_ID
          ,GJL.ACCOUNTED_DR
          ,GJL.ACCOUNTED_CR
          ,GJL.DESCRIPTION
    FROM   GL_JE_HEADERS GJH
          ,GL_JE_LINES GJL
    WHERE  GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
      AND  GJH.STATUS = 'P' -- Posted
      AND  GJH.LEDGER_ID IN (:P_LEDGER_ID)
      AND  GJH.PERIOD_NAME IN (:P_PERIOD)
)
```

---

## 3. Journal Entries (Complete with Batch and User Details)
*Enhanced journal entry extraction with batch info, user details, and source tracking.*

```sql
GL_JE_MASTER_FULL AS (
    SELECT /*+ qb_name(GL_JE_FULL) MATERIALIZE */
           -- Batch Details
           GJB.JE_BATCH_ID
          ,GJB.NAME BATCH_NAME
          ,GJB.DEFAULT_PERIOD_NAME BATCH_PERIOD
          ,GJB.STATUS BATCH_STATUS
          ,GJB.DESCRIPTION BATCH_DESCRIPTION
          -- Header Details
          ,GJH.JE_HEADER_ID
          ,GJH.NAME JE_NAME
          ,GJH.PERIOD_NAME
          ,GJH.DEFAULT_EFFECTIVE_DATE EFFECTIVE_DATE
          ,GJH.JE_SOURCE
          ,GJH.JE_CATEGORY
          ,GJH.CURRENCY_CODE
          ,GJH.STATUS JE_STATUS
          ,GJH.POSTED_DATE
          ,GJH.DOC_SEQUENCE_VALUE VOUCHER_NUMBER
          ,GJH.DESCRIPTION JE_DESCRIPTION
          -- Line Details
          ,GJL.JE_LINE_NUM
          ,GCCK.CONCATENATED_SEGMENTS ACCOUNT_STRING
          ,GCCK.SEGMENT1 COMPANY
          ,GCCK.SEGMENT2 ACCOUNT
          ,GCCK.SEGMENT3 COST_CENTER
          ,GCCK.SEGMENT4 NATURAL_ACCOUNT
          ,GJL.ENTERED_DR
          ,GJL.ENTERED_CR
          ,GJL.ACCOUNTED_DR
          ,GJL.ACCOUNTED_CR
          ,GJL.DESCRIPTION LINE_DESCRIPTION
          -- Ledger Details
          ,GLL.NAME LEDGER_NAME
          ,GLL.CURRENCY_CODE LEDGER_CURRENCY
          ,XLE.NAME LEGAL_ENTITY_NAME
          -- User Details
          ,FU.USER_NAME CREATED_BY
          ,GJH.CREATION_DATE
    FROM   GL_JE_BATCHES GJB
          ,GL_JE_HEADERS GJH
          ,GL_JE_LINES GJL
          ,GL_CODE_COMBINATIONS_KFV GCCK
          ,GL_LEDGERS GLL
          ,GL_LEDGER_LE_V GLLV
          ,XLE_ENTITY_PROFILES XLE
          ,FND_USER FU
    WHERE  GJB.JE_BATCH_ID = GJH.JE_BATCH_ID
      AND  GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
      AND  GJL.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
      AND  GJH.LEDGER_ID = GLL.LEDGER_ID
      AND  GLL.LEDGER_ID = GLLV.LEDGER_ID
      AND  GLLV.LEGAL_ENTITY_ID = XLE.LEGAL_ENTITY_ID
      AND  GJH.CREATED_BY = FU.USER_ID(+)
      AND  GJH.STATUS = 'P'
      AND  GJH.LEDGER_ID = :P_LEDGER_ID
      AND  TRUNC(GJH.POSTED_DATE) BETWEEN :P_FROM_DATE AND :P_TO_DATE
)
```

---

## 4. Source Document Tracking
*Links GL entries back to source transactions.*

```sql
GL_SOURCE_DOCS AS (
    SELECT /*+ qb_name(GL_SRC) */
           GJH.JE_HEADER_ID
          ,GJL.JE_LINE_NUM
          ,GIR.GL_SL_LINK_ID
          ,GIR.GL_SL_LINK_TABLE
          ,GIR.JE_HEADER_ID SOURCE_HEADER_ID
          ,GIR.JE_LINE_NUM SOURCE_LINE_NUM
          -- Subledger Application Details
          ,CASE GIR.GL_SL_LINK_TABLE
             WHEN 'AP_INVOICES' THEN 'Payables Invoice'
             WHEN 'AR_DISTRIBUTIONS' THEN 'Receivables Transaction'
             WHEN 'XLA_AE_LINES' THEN 'Subledger Accounting'
             ELSE GIR.GL_SL_LINK_TABLE
           END SOURCE_TYPE
    FROM   GL_JE_HEADERS GJH
          ,GL_JE_LINES GJL
          ,GL_IMPORT_REFERENCES GIR
    WHERE  GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
      AND  GJL.GL_SL_LINK_ID = GIR.GL_SL_LINK_ID(+)
      AND  GJL.GL_SL_LINK_TABLE = GIR.GL_SL_LINK_TABLE(+)
      AND  GJH.STATUS = 'P'
      AND  GJH.LEDGER_ID = :P_LEDGER_ID
)
```

---

## 5. Account Hierarchy (Segment-wise)
*Account segmentation for hierarchical reporting.*

```sql
GL_ACCOUNT_HIERARCHY AS (
    SELECT /*+ qb_name(GL_ACCT_HIER) */
           GCC.CODE_COMBINATION_ID
          ,GCC.SEGMENT1 COMPANY_SEGMENT
          ,GCC.SEGMENT2 ACCOUNT_SEGMENT
          ,GCC.SEGMENT3 COST_CENTER_SEGMENT
          ,GCC.SEGMENT4 NATURAL_ACCOUNT_SEGMENT
          ,GCC.SEGMENT5 INTERCOMPANY_SEGMENT
          ,GCCK.CONCATENATED_SEGMENTS FULL_ACCOUNT
          ,GCCK.DESCRIPTION ACCOUNT_DESCRIPTION
          -- Account Type Classification
          ,CASE 
             WHEN GCC.SEGMENT4 BETWEEN '1000' AND '1999' THEN 'Assets'
             WHEN GCC.SEGMENT4 BETWEEN '2000' AND '2999' THEN 'Liabilities'
             WHEN GCC.SEGMENT4 BETWEEN '3000' AND '3999' THEN 'Equity'
             WHEN GCC.SEGMENT4 BETWEEN '4000' AND '4999' THEN 'Revenue'
             WHEN GCC.SEGMENT4 BETWEEN '5000' AND '9999' THEN 'Expense'
             ELSE 'Other'
           END ACCOUNT_TYPE
    FROM   GL_CODE_COMBINATIONS GCC
          ,GL_CODE_COMBINATIONS_KFV GCCK
    WHERE  GCC.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
      AND  GCC.ENABLED_FLAG = 'Y'
)
```

---

## 6. Period Balances with YTD
*Complete balance extraction with Period and YTD calculations.*

```sql
GL_BALANCE_MASTER AS (
    SELECT /*+ qb_name(GL_BAL_MAST) MATERIALIZE */
           GB.LEDGER_ID
          ,GB.CODE_COMBINATION_ID
          ,GCCK.CONCATENATED_SEGMENTS ACCOUNT_STRING
          ,GCCK.SEGMENT1 COMPANY
          ,GCCK.SEGMENT4 NATURAL_ACCOUNT
          ,GB.PERIOD_NAME
          ,GB.CURRENCY_CODE
          -- Period Activity
          ,NVL(GB.PERIOD_NET_DR, 0) PTD_DR
          ,NVL(GB.PERIOD_NET_CR, 0) PTD_CR
          ,NVL(GB.PERIOD_NET_DR, 0) - NVL(GB.PERIOD_NET_CR, 0) PTD_NET
          -- Beginning Balance
          ,NVL(GB.BEGIN_BALANCE_DR, 0) BEGIN_BAL_DR
          ,NVL(GB.BEGIN_BALANCE_CR, 0) BEGIN_BAL_CR
          ,NVL(GB.BEGIN_BALANCE_DR, 0) - NVL(GB.BEGIN_BALANCE_CR, 0) BEGIN_BAL_NET
          -- Year-to-Date
          ,NVL(GB.BEGIN_BALANCE_DR, 0) + NVL(GB.PERIOD_NET_DR, 0) YTD_DR
          ,NVL(GB.BEGIN_BALANCE_CR, 0) + NVL(GB.PERIOD_NET_CR, 0) YTD_CR
          ,NVL(GB.BEGIN_BALANCE_DR, 0) - NVL(GB.BEGIN_BALANCE_CR, 0) + 
           NVL(GB.PERIOD_NET_DR, 0) - NVL(GB.PERIOD_NET_CR, 0) YTD_NET
          -- Ending Balance
          ,NVL(GB.BEGIN_BALANCE_DR, 0) + NVL(GB.PERIOD_NET_DR, 0) END_BAL_DR
          ,NVL(GB.BEGIN_BALANCE_CR, 0) + NVL(GB.PERIOD_NET_CR, 0) END_BAL_CR
          ,NVL(GB.BEGIN_BALANCE_DR, 0) - NVL(GB.BEGIN_BALANCE_CR, 0) + 
           NVL(GB.PERIOD_NET_DR, 0) - NVL(GB.PERIOD_NET_CR, 0) END_BAL_NET
    FROM   GL_BALANCES GB
          ,GL_CODE_COMBINATIONS_KFV GCCK
    WHERE  GB.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
      AND  GB.ACTUAL_FLAG = 'A'
      AND  GB.LEDGER_ID = :P_LEDGER_ID
      AND  GB.PERIOD_NAME = :P_PERIOD
)
```
