/*
Title: AR Customer Aging (5 Buckets) - Point-in-Time
Description: Customer aging with buckets: <0 (Current), 1-30, 31-60, 61-90, >90.
             Supports backdated reporting by calculating balances as of the specified date.
Input Parameter: :P_AS_ON_DATE (Format: YYYY/MM/DD)
*/

WITH
-- 1. Parameters
PARAMS AS (
    SELECT TRUNC(TO_DATE(:P_AS_ON_DATE, 'YYYY/MM/DD')) AS AS_OF_DATE 
    FROM DUAL
),

-- 2. Base Transactions (All Invoices/CMs/DMs)
BASE_TRX AS (
    SELECT /*+ qb_name(BASE_TRX) MATERIALIZE */
           PSA.PAYMENT_SCHEDULE_ID
          ,PSA.CUSTOMER_TRX_ID
          ,PSA.CUSTOMER_ID
          ,PSA.TRX_NUMBER
          ,PSA.DUE_DATE
          ,PSA.AMOUNT_DUE_ORIGINAL
          ,PSA.INVOICE_CURRENCY_CODE
          ,NVL(PSA.EXCHANGE_RATE, 1) AS EXCH_RATE
          ,PSA.CLASS
          ,PSA.ORG_ID
    FROM   AR_PAYMENT_SCHEDULES_ALL PSA
          ,PARAMS P
    WHERE  PSA.TRX_DATE <= P.AS_OF_DATE
      AND  PSA.AMOUNT_DUE_ORIGINAL != 0
),

-- 3. Applications Applied Up To As-Of Date
APPLICATIONS AS (
    SELECT /*+ qb_name(APPS) MATERIALIZE */
           ARA.APPLIED_PAYMENT_SCHEDULE_ID
          ,SUM(ARA.AMOUNT_APPLIED * NVL(ARA.EXCHANGE_RATE, 1)) AS APPLIED_FUNC_AMT
    FROM   AR_RECEIVABLE_APPLICATIONS_ALL ARA
          ,PARAMS P
    WHERE  ARA.GL_DATE <= P.AS_OF_DATE
      AND  ARA.STATUS = 'APP'
      AND  NVL(ARA.DISPLAY, 'Y') = 'Y'
    GROUP BY ARA.APPLIED_PAYMENT_SCHEDULE_ID
),

-- 4. Calculate Remaining Balance as of As-Of Date
BALANCE_CALC AS (
    SELECT BT.PAYMENT_SCHEDULE_ID
          ,BT.CUSTOMER_ID
          ,BT.TRX_NUMBER
          ,BT.DUE_DATE
          ,(BT.AMOUNT_DUE_ORIGINAL * BT.EXCH_RATE) - NVL(A.APPLIED_FUNC_AMT, 0) AS REMAINING_BAL
    FROM   BASE_TRX BT
          ,APPLICATIONS A
    WHERE  BT.PAYMENT_SCHEDULE_ID = A.APPLIED_PAYMENT_SCHEDULE_ID(+)
),

-- 5. Customer Master
CUST_DATA AS (
    SELECT /*+ qb_name(CUST) MATERIALIZE */
           HCA.CUST_ACCOUNT_ID
          ,HCA.ACCOUNT_NUMBER
          ,HP.PARTY_NAME
    FROM   HZ_CUST_ACCOUNTS HCA
          ,HZ_PARTIES HP
    WHERE  HCA.PARTY_ID = HP.PARTY_ID
      AND  HCA.STATUS = 'A'
),

-- 6. Join Customer and Calculate Days Due
DATA_SRC AS (
    SELECT C.ACCOUNT_NUMBER
          ,C.PARTY_NAME
          ,BC.TRX_NUMBER
          ,BC.DUE_DATE
          ,P.AS_OF_DATE - TRUNC(BC.DUE_DATE) AS DAYS_DUE
          ,BC.REMAINING_BAL AS FUNC_BAL
    FROM   BALANCE_CALC BC
          ,CUST_DATA C
          ,PARAMS P
    WHERE  BC.CUSTOMER_ID = C.CUST_ACCOUNT_ID
      AND  BC.REMAINING_BAL != 0
),

-- 7. Bucketing
BUCKETS AS (
    SELECT ACCOUNT_NUMBER
          ,PARTY_NAME
          ,FUNC_BAL
          ,CASE 
             WHEN DAYS_DUE <= 0 THEN 'Current'
             WHEN DAYS_DUE BETWEEN 1 AND 30 THEN '1-30'
             WHEN DAYS_DUE BETWEEN 31 AND 60 THEN '31-60'
             WHEN DAYS_DUE BETWEEN 61 AND 90 THEN '61-90'
             ELSE '>90'
           END AS BUCKET_NAME
    FROM DATA_SRC
)

-- 8. Pivot/Aggregation
SELECT PARTY_NAME
      ,SUM(FUNC_BAL) AS TOTAL_DUE
      ,SUM(CASE WHEN BUCKET_NAME = 'Current' THEN FUNC_BAL ELSE 0 END) AS "Current"
      ,SUM(CASE WHEN BUCKET_NAME = '1-30' THEN FUNC_BAL ELSE 0 END) AS "1-30 Days"
      ,SUM(CASE WHEN BUCKET_NAME = '31-60' THEN FUNC_BAL ELSE 0 END) AS "31-60 Days"
      ,SUM(CASE WHEN BUCKET_NAME = '61-90' THEN FUNC_BAL ELSE 0 END) AS "61-90 Days"
      ,SUM(CASE WHEN BUCKET_NAME = '>90' THEN FUNC_BAL ELSE 0 END) AS ">90 Days"
FROM   BUCKETS
GROUP BY PARTY_NAME
ORDER BY TOTAL_DUE DESC
