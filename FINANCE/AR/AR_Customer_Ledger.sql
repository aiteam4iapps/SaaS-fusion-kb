/*
Title: AR Customer Ledger Report
Description: Detailed chronological ledger of only invoices and Applied receipts per customer.
MD050 Reference: FUSION_SAAS/FINANCE/AR/MD050_AR_Customer_Ledger_Report.md
*/

WITH
-- 1. Parameters
PARAMS AS (
    SELECT :P_ORG_ID AS ORG_ID
          ,(:P_FROM_DATE) AS FROM_DATE
          ,(:P_TO_DATE) AS TO_DATE
          ,:P_CUSTOMER_ID AS CUSTOMER_ID
    FROM DUAL
),

-- 2. Repositories (Standard Lego Bricks)
-- [REPO] Customer Master
AR_CUST_MASTER AS (
    SELECT /*+ qb_name(CUST) MATERIALIZE */
           HCA.CUST_ACCOUNT_ID
          ,HCA.ACCOUNT_NUMBER
          ,HP.PARTY_NAME AS CUSTOMER_NAME
          ,HP.PARTY_ID
    FROM   HZ_CUST_ACCOUNTS HCA
          ,HZ_PARTIES HP
    WHERE  HCA.PARTY_ID = HP.PARTY_ID
      AND  HCA.STATUS = 'A'
),

-- [REPO] Transaction Master
AR_TRX_MASTER AS (
    SELECT /*+ qb_name(AR_TRX) MATERIALIZE */
           RCTA.CUSTOMER_TRX_ID
          ,RCTA.TRX_NUMBER
          ,RCTA.TRX_DATE
          ,RCTA.ORG_ID
          ,RCTA.BILL_TO_CUSTOMER_ID AS CUSTOMER_ID 
           -- Currency Logic
          ,RCTA.INVOICE_CURRENCY_CODE
          ,NVL(RCTA.EXCHANGE_RATE, 1) AS EXCH_RATE
           -- Sign Logic
          ,CASE WHEN PSA.CLASS IN ('CM', 'PMT') THEN -1 ELSE 1 END AS SIGN_FACTOR
          ,PSA.AMOUNT_DUE_ORIGINAL
          ,PSA.AMOUNT_DUE_REMAINING
          ,RCTT.NAME AS TRX_TYPE_NAME
          ,'INVOICE' AS SOURCE
    FROM   RA_CUSTOMER_TRX_ALL RCTA
          ,AR_PAYMENT_SCHEDULES_ALL PSA
          ,RA_CUST_TRX_TYPES_ALL RCTT
    WHERE  RCTA.CUSTOMER_TRX_ID = PSA.CUSTOMER_TRX_ID
      AND  RCTA.CUST_TRX_TYPE_SEQ_ID = RCTT.CUST_TRX_TYPE_SEQ_ID
      AND  RCTA.COMPLETE_FLAG = 'Y'
      AND  RCTA.ORG_ID = PSA.ORG_ID
),

-- [REPO] Receipt Master (Modified for Join)
AR_RCPT_MASTER AS (
    SELECT /*+ qb_name(RCPT) MATERIALIZE */
           ACRA.CASH_RECEIPT_ID
          ,ACRA.RECEIPT_NUMBER
          ,ACRA.RECEIPT_DATE
          ,ACRA.AMOUNT
          ,ACRA.ORG_ID
          ,ACRA.PAY_FROM_CUSTOMER AS CUSTOMER_ID
          ,'RECEIPT' AS SOURCE
          ,'Payment' AS TRX_TYPE_NAME
    FROM   AR_CASH_RECEIPTS_ALL ACRA
    WHERE  ACRA.ORG_ID IN (SELECT ORG_ID FROM PARAMS)
      AND  NOT EXISTS (
           SELECT 1 FROM AR_CASH_RECEIPT_HISTORY_ALL H 
           WHERE H.CASH_RECEIPT_ID = ACRA.CASH_RECEIPT_ID 
           AND H.STATUS = 'REVERSED'
      )
      AND ACRA.STATUS = 'APP'
),

-- 3. Logic & Transformation
UNION_DATA AS (
    -- Invoices / CMs
    SELECT T.ORG_ID
          ,T.CUSTOMER_ID
          ,T.TRX_DATE AS GL_DATE 
          ,T.TRX_NUMBER
          ,T.SOURCE
          ,T.TRX_TYPE_NAME AS TYPE
          -- Debit Logic: CM is negative Debit
          ,CASE 
             WHEN T.SIGN_FACTOR = -1 THEN (T.AMOUNT_DUE_ORIGINAL * -1) -- CM
             ELSE T.AMOUNT_DUE_ORIGINAL -- Invoice
           END AS DEBIT_AMT
          ,0 AS CREDIT_AMT
    FROM   AR_TRX_MASTER T
    WHERE  T.ORG_ID = (SELECT ORG_ID FROM PARAMS)
    
    UNION ALL
    
    -- Receipts
    SELECT R.ORG_ID
          ,R.CUSTOMER_ID
          ,R.RECEIPT_DATE AS GL_DATE
          ,R.RECEIPT_NUMBER AS TRX_NUMBER
          ,R.SOURCE
          ,R.TRX_TYPE_NAME AS TYPE
          ,0 AS DEBIT_AMT
          ,R.AMOUNT AS CREDIT_AMT
    FROM   AR_RCPT_MASTER R
),

DETAILS AS (
    SELECT U.*
          ,C.CUSTOMER_NAME
          ,C.ACCOUNT_NUMBER
    FROM   UNION_DATA U
          ,AR_CUST_MASTER C
          ,PARAMS P
    WHERE  U.CUSTOMER_ID = C.CUST_ACCOUNT_ID
      AND  U.GL_DATE BETWEEN P.FROM_DATE AND P.TO_DATE
      AND  (P.CUSTOMER_ID IS NULL OR C.CUST_ACCOUNT_ID = P.CUSTOMER_ID)
)

-- 4. Final Output with Running Balance
SELECT D.CUSTOMER_NAME
      ,D.ACCOUNT_NUMBER
      ,D.GL_DATE
      ,D.TRX_NUMBER
      ,D.SOURCE
      ,D.TYPE
      ,D.DEBIT_AMT
      ,D.CREDIT_AMT
      -- Running Balance Calculation
      ,SUM(NVL(D.DEBIT_AMT,0) - NVL(D.CREDIT_AMT,0)) OVER (
          PARTITION BY D.CUSTOMER_NAME 
          ORDER BY D.GL_DATE, D.TRX_NUMBER
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS RUNNING_BALANCE
FROM   DETAILS D
ORDER BY D.CUSTOMER_NAME, D.GL_DATE, D.TRX_NUMBER
