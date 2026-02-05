# CM Repository Patterns

**Purpose:** Standardized CTEs for Cash Management.

---

## 1. Bank Account Master (Enhanced)
*Retrieves active internal bank accounts with GL and Legal Entity details.*

```sql
CM_BANK_ACCT_MASTER AS (
    SELECT /*+ qb_name(CM_BA) MATERIALIZE */
           CBA.BANK_ACCOUNT_ID
          ,CBA.BANK_ACCOUNT_NAME
          ,CBA.BANK_ACCOUNT_NUM
          ,CBA.CURRENCY_CODE
          ,CBA.TYPE AS ACCOUNT_TYPE
          ,CBA.ACCOUNT_OWNER_ORG_ID
          ,BB.BANK_NAME
          ,BB.BANK_BRANCH_NAME
          ,BB.BRANCH_NUMBER
          -- GL Account Details
          ,CBA.ASSET_CODE_COMBINATION_ID
          ,GCC.CONCATENATED_SEGMENTS GL_ACCOUNT
          -- Legal Entity
          ,XLE.NAME LEGAL_ENTITY_NAME
    FROM   CE_BANK_ACCOUNTS CBA
          ,CE_BANK_BRANCHES_V BB
          ,GL_CODE_COMBINATIONS_KFV GCC
          ,XLE_ENTITY_PROFILES XLE
    WHERE  CBA.BANK_BRANCH_ID = BB.BRANCH_PARTY_ID
      AND  CBA.ASSET_CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID(+)
      AND  CBA.ACCOUNT_OWNER_ORG_ID = XLE.LEGAL_ENTITY_ID(+)
      AND  NVL(CBA.END_DATE, SYSDATE+1) > SYSDATE
)
```

---

## 2. Bank Statement Master
*Complete bank statement with header and line details.*

```sql
CM_STMT_MASTER AS (
    SELECT /*+ qb_name(CM_STMT) MATERIALIZE */
           CSH.STATEMENT_HEADER_ID
          ,CSH.BANK_ACCOUNT_ID
          ,CSH.STATEMENT_NUMBER
          ,CSH.STATEMENT_DATE
          ,CSH.GL_DATE
          ,CSH.DOC_SEQUENCE_VALUE
          ,CSH.CURRENCY_CODE
          ,CSH.CONTROL_BEGIN_BALANCE
          ,CSH.CONTROL_END_BALANCE
          ,CSH.CONTROL_DR_AMOUNT
          ,CSH.CONTROL_CR_AMOUNT
          ,CSH.CONTROL_LINE_COUNT
          -- Line Details
          ,CSL.STATEMENT_LINE_ID
          ,CSL.LINE_NUMBER
          ,CSL.TRX_DATE
          ,CSL.TRX_CODE
          ,CSL.TRX_TEXT
          ,CSL.EFFECTIVE_DATE
          ,CSL.AMOUNT
          ,CSL.BANK_TRX_NUMBER
          ,CSL.STATUS
          ,CASE CSL.STATUS
             WHEN 'RECONCILED' THEN 'Reconciled'
             WHEN 'UNRECONCILED' THEN 'Unreconciled'
             WHEN 'EXTERNAL' THEN 'External'
             ELSE CSL.STATUS
           END STATUS_DESC
          -- Bank Account Details
          ,CBA.BANK_ACCOUNT_NAME
          ,CBA.BANK_ACCOUNT_NUM
    FROM   CE_STATEMENT_HEADERS CSH
          ,CE_STATEMENT_LINES CSL
          ,CE_BANK_ACCOUNTS CBA
    WHERE  CSH.STATEMENT_HEADER_ID = CSL.STATEMENT_HEADER_ID
      AND  CSH.BANK_ACCOUNT_ID = CBA.BANK_ACCOUNT_ID
      AND  CSH.STATEMENT_HEADER_ID IS NOT NULL
)
```

---

## 3. Payment Transactions with Source Tracking
*Links bank transactions to AP payments.*

```sql
CM_PAYMENT_TRX AS (
    SELECT /*+ qb_name(CM_PAY) MATERIALIZE */
           CPT.PAYMENT_TRANSACTION_ID
          ,CPT.BANK_ACCOUNT_ID
          ,CPT.TRX_DATE
          ,CPT.TRX_CODE
          ,CPT.AMOUNT
          ,CPT.CURRENCY_CODE
          ,CPT.STATUS
          ,CPT.APPLICATION_ID
          ,CPT.SOURCE_TRX_ID
          ,CPT.SOURCE_TRX_TYPE
          -- AP Payment Details (if applicable)
          ,ACA.CHECK_NUMBER
          ,ACA.CHECK_DATE
          ,ACA.VENDOR_NAME
          ,ACA.DESCRIPTION PAYMENT_DESC
          -- Payment Instrument Details
          ,IPA.PAYMENT_REFERENCE_NUMBER
          ,IPA.PAYMENT_METHOD_CODE
          -- GL Details
          ,CPT.GL_DATE
          ,CPT.RECONCILE_FLAG
    FROM   CE_PAYMENT_TRANSACTIONS CPT
          ,AP_CHECKS_ALL ACA
          ,IBY_PAYMENTS_ALL IPA
    WHERE  CPT.SOURCE_TRX_ID = ACA.CHECK_ID(+)
      AND  CPT.APPLICATION_ID = 200 -- Payables
      AND  ACA.PAYMENT_ID = IPA.PAYMENT_ID(+)
)
```

---

## 4. Receipt Transactions with Source Tracking
*Links bank transactions to AR receipts.*

```sql
CM_RECEIPT_TRX AS (
    SELECT /*+ qb_name(CM_RCPT) MATERIALIZE */
           CPT.PAYMENT_TRANSACTION_ID
          ,CPT.BANK_ACCOUNT_ID
          ,CPT.TRX_DATE
          ,CPT.TRX_CODE
          ,CPT.AMOUNT
          ,CPT.CURRENCY_CODE
          ,CPT.STATUS
          ,CPT.APPLICATION_ID
          ,CPT.SOURCE_TRX_ID
          ,CPT.SOURCE_TRX_TYPE
          -- AR Receipt Details (if applicable)
          ,ACRA.RECEIPT_NUMBER
          ,ACRA.RECEIPT_DATE
          ,HP.PARTY_NAME CUSTOMER_NAME
          ,ACRA.COMMENTS RECEIPT_DESC
          -- GL Details
          ,CPT.GL_DATE
          ,CPT.RECONCILE_FLAG
    FROM   CE_PAYMENT_TRANSACTIONS CPT
          ,AR_CASH_RECEIPTS_ALL ACRA
          ,HZ_CUST_ACCOUNTS HCA
          ,HZ_PARTIES HP
    WHERE  CPT.SOURCE_TRX_ID = ACRA.CASH_RECEIPT_ID(+)
      AND  CPT.APPLICATION_ID = 222 -- Receivables
      AND  ACRA.PAY_FROM_CUSTOMER = HCA.CUST_ACCOUNT_ID(+)
      AND  HCA.PARTY_ID = HP.PARTY_ID(+)
)
```

---

## 5. Reconciliation Master
*Complete reconciliation data linking statement lines to payments/receipts.*

```sql
CM_RECONCILE_MASTER AS (
    SELECT /*+ qb_name(CM_REC) MATERIALIZE */
           CSR.STATEMENT_LINE_ID
          ,CSR.REFERENCE_ID
          ,CSR.REFERENCE_TYPE
          ,CSR.RECONCILIATION_DATE
          ,CSR.STATUS
          ,CSR.CLEARED_DATE
          -- Statement Line Details
          ,CSL.LINE_NUMBER STMT_LINE_NUM
          ,CSL.TRX_DATE STMT_TRX_DATE
          ,CSL.AMOUNT STMT_AMOUNT
          ,CSL.TRX_TEXT STMT_TRX_TEXT
          -- Payment/Receipt Details
          ,CPT.TRX_DATE TRX_DATE
          ,CPT.AMOUNT TRX_AMOUNT
          ,CPT.SOURCE_TRX_TYPE
          ,CASE CPT.APPLICATION_ID
             WHEN 200 THEN 'AP Payment'
             WHEN 222 THEN 'AR Receipt'
             ELSE 'Other'
           END SOURCE_MODULE
          -- Variance
          ,CSL.AMOUNT - NVL(CPT.AMOUNT, 0) VARIANCE
    FROM   CE_STATEMENT_RECONCILS_ALL CSR
          ,CE_STATEMENT_LINES CSL
          ,CE_PAYMENT_TRANSACTIONS CPT
    WHERE  CSR.STATEMENT_LINE_ID = CSL.STATEMENT_LINE_ID
      AND  CSR.REFERENCE_ID = CPT.PAYMENT_TRANSACTION_ID(+)
      AND  CSR.REFERENCE_TYPE = 'PAYMENT'
      AND  CSR.STATUS = 'RECONCILED'
)
```

---

## 6. Bank Transactions Union (Both Sides)
*Union of all bank transactions (payments and receipts) for cash analysis.*

```sql
CM_BANK_TRX_UNION AS (
    -- Payments (Outflows)
    SELECT 1 SORT_ORDER
          ,CPT.PAYMENT_TRANSACTION_ID TRX_ID
          ,CPT.TRX_DATE
          ,CPT.BANK_ACCOUNT_ID
          ,'Payment' TRX_TYPE
          ,ACA.CHECK_NUMBER TRX_NUMBER
          ,ACA.VENDOR_NAME PARTY_NAME
          ,CPT.AMOUNT * -1 AMOUNT -- Negative for outflow
          ,CPT.CURRENCY_CODE
          ,CPT.GL_DATE
          ,CPT.RECONCILE_FLAG
    FROM   CE_PAYMENT_TRANSACTIONS CPT
          ,AP_CHECKS_ALL ACA
    WHERE  CPT.SOURCE_TRX_ID = ACA.CHECK_ID(+)
      AND  CPT.APPLICATION_ID = 200
      AND  ACA.VOID_DATE IS NULL
    
    UNION ALL
    
    -- Receipts (Inflows)
    SELECT 2 SORT_ORDER
          ,CPT.PAYMENT_TRANSACTION_ID
          ,CPT.TRX_DATE
          ,CPT.BANK_ACCOUNT_ID
          ,'Receipt' TRX_TYPE
          ,ACRA.RECEIPT_NUMBER
          ,HP.PARTY_NAME
          ,CPT.AMOUNT AMOUNT -- Positive for inflow
          ,CPT.CURRENCY_CODE
          ,CPT.GL_DATE
          ,CPT.RECONCILE_FLAG
    FROM   CE_PAYMENT_TRANSACTIONS CPT
          ,AR_CASH_RECEIPTS_ALL ACRA
          ,HZ_CUST_ACCOUNTS HCA
          ,HZ_PARTIES HP
    WHERE  CPT.SOURCE_TRX_ID = ACRA.CASH_RECEIPT_ID(+)
      AND  CPT.APPLICATION_ID = 222
      AND  ACRA.PAY_FROM_CUSTOMER = HCA.CUST_ACCOUNT_ID(+)
      AND  HCA.PARTY_ID = HP.PARTY_ID(+)
      -- Exclude Reversed Receipts
      AND  NOT EXISTS (
           SELECT 1 
           FROM   AR_CASH_RECEIPT_HISTORY_ALL H
           WHERE  H.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID
             AND  H.STATUS = 'REVERSED'
      )
)
```
