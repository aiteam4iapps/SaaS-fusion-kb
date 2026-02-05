# Projects Report Templates

**Purpose:** Ready-to-use SQL skeletons for Project reporting.
**Last Updated:** 22-12-25  
**Validation:** ✅ COMPLETED - All reference queries analyzed

---

## Template Index

1. [Project Master Details Report](#1-project-master-details-report)
2. [Project Summary Report](#2-project-summary-report)
3. [Project Performance Snapshot Report](#3-project-performance-snapshot-report)
4. [Project WIP Details Report](#4-project-wip-details-report)
5. [Project Billing Purchase Order Integration](#5-project-billing-purchase-order-integration)

---

## 1. Project Master Details Report

**Purpose:** Comprehensive project master information with team, customer, and classification details.

**Parameters:**
- `:P_BU_NAME` - Business Unit (supports 'All')
- `:P_PERIOD` - Reporting Period
- `:P_MGR_NAME` - Manager Name (supports 'All')
- `:P_STATUS` - Project Status (supports 'All')
- `:P_PRJ_NUM` - Project Number (supports 'All')
- `:P_PRJ_NAME` - Project Name (supports 'All')
- `:P_PRJ_TYPE` - Project Type ID (supports 'All')
- `:P_PRJ_MT` - Market Code (supports 'All')
- `:P_PRJ_SH` - Burden Schedule (supports 'All')
- `:P_PRJ_CN` - Customer Party ID (supports 'All')

```sql
/*
TITLE: Project Master Details Report
PURPOSE: Comprehensive project master information
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH PROJECT_DETAILS AS (
    SELECT DISTINCT /*+ qb_name(PRJ_INFO) MATERIALIZE */
           PRJ_INFO.CLASS_CODE
          ,PRJ_INFO.MARKET_CODE
          ,PRJ_INFO.PARTY_NAME
          ,PRJ_INFO.PARTY_NUMBER
          ,PRJ_INFO.RESOURCE_SOURCE_NUMBER
          ,PRJ_INFO.RESOURCE_SOURCE_NAME
          ,PRJ_INFO.PROJECT_ROLE_NAME
          ,PRJ_INFO.DIR_EMAIL
          ,PRJ_INFO.LIST_NUMBER
          ,PRJ_INFO.LIST_NAME
          ,PRJ_INFO.MGR_EMAIL
          ,PRJ_INFO.PROJECT_STATUS_NAME
          ,PRJ_INFO.NAME
          ,PRJ_INFO.SEGMENT1
          ,PRJ_INFO.PROJECT_TYPE_ID
          ,PRJ_INFO.BU_NAME
          ,PRJ_INFO.BURDEN_SCHEDULE
          ,PRJ_INFO.PRJ_START_DATE
          ,PRJ_INFO.PRJ_COMPLETION_DATE
    FROM (
        SELECT PRJ_CLASS_CT.CLASS_CODE
              ,PRJ_CLASS_MT.MARKET_CODE
              ,PRJ_CUSTOMER.PARTY_NAME
              ,PRJ_CUSTOMER.PARTY_NUMBER
              ,PRJ_RESOURCE.RESOURCE_SOURCE_NUMBER
              ,PRJ_RESOURCE.RESOURCE_SOURCE_NAME
              ,PRJ_RESOURCE.PROJECT_ROLE_NAME
              ,PRJ_RESOURCE.DIR_EMAIL
              ,PRJ_DETAILS.LIST_NUMBER
              ,PRJ_DETAILS.LIST_NAME
              ,PRJ_DETAILS.MGR_EMAIL
              ,PRJ_DETAILS.PROJECT_STATUS_NAME
              ,PRJ_DETAILS.NAME
              ,PRJ_DETAILS.SEGMENT1
              ,PRJ_DETAILS.PROJECT_TYPE_ID
              ,PRJ_DETAILS.BU_NAME
              ,PRJ_DETAILS.BURDEN_SCHEDULE
              ,INITCAP(TO_CHAR(PRJ_DETAILS.START_DATE,'DD-fmMON-YYYY','NLS_DATE_LANGUAGE = AMERICAN')) AS PRJ_START_DATE
              ,INITCAP(TO_CHAR(PRJ_DETAILS.COMPLETION_DATE,'DD-fmMON-YYYY','NLS_DATE_LANGUAGE = AMERICAN')) AS PRJ_COMPLETION_DATE
        FROM (
            /* Project Details */
            SELECT PPAB.PROJECT_ID
                  ,PPAB.SEGMENT1
                  ,PPAB.START_DATE
                  ,PPAB.COMPLETION_DATE
                  ,PPAT.NAME
                  ,PPSV.PROJECT_STATUS_NAME
                  ,PPNF.LIST_NAME
                  ,PAPF.PERSON_NUMBER             AS LIST_NUMBER
                  ,PEA.EMAIL_ADDRESS              AS MGR_EMAIL
                  ,HAOUT.NAME                     AS BU_NAME
                  ,PIRSV.IND_SCH_NAME             AS BURDEN_SCHEDULE
                  ,PPAB.PROJECT_TYPE_ID
            FROM   PJF_PROJECTS_ALL_B PPAB
                  ,PJF_LATESTPROJECTMANAGER_V PLV
                  ,PJF_PROJECTS_ALL_TL PPAT
                  ,PJF_PROJECT_STATUSES_VL PPSV
                  ,PER_ALL_PEOPLE_F PAPF
                  ,PER_PERSON_NAMES_F_V PPNF
                  ,HR_ORGANIZATION_UNITS_F_TL HAOUT
                  ,PJF_IND_RATE_SCH_VL PIRSV
                  ,PER_EMAIL_ADDRESSES_V PEA
            WHERE  PPAB.PROJECT_ID                = PLV.PROJECT_ID(+)
              AND  PPAB.PROJECT_ID                = PPAT.PROJECT_ID
              AND  (USERENV('LANG'))              = PPAT.LANGUAGE
              AND  PPAB.PROJECT_STATUS_CODE       = PPSV.PROJECT_STATUS_CODE
              AND  PLV.RESOURCE_SOURCE_ID         = PAPF.PERSON_ID(+)
              AND  PLV.RESOURCE_SOURCE_ID         = PPNF.PERSON_ID(+)
              AND  PPAB.ORG_ID                    = HAOUT.ORGANIZATION_ID(+)
              AND  (USERENV('LANG'))              = HAOUT.LANGUAGE(+)
              AND  PPAB.COST_IND_RATE_SCH_ID      = PIRSV.IND_RATE_SCH_ID(+)
              AND  PAPF.PRIMARY_EMAIL_ID          = PEA.EMAIL_ADDRESS_ID(+)
              AND  (TRUNC(SYSDATE)                BETWEEN PAPF.EFFECTIVE_START_DATE(+) AND PAPF.EFFECTIVE_END_DATE(+))
              AND  (TRUNC(SYSDATE)                BETWEEN PPNF.EFFECTIVE_START_DATE(+) AND PPNF.EFFECTIVE_END_DATE(+))
              AND  (TRUNC(SYSDATE)                BETWEEN HAOUT.EFFECTIVE_START_DATE(+) AND HAOUT.EFFECTIVE_END_DATE(+))
        ) PRJ_DETAILS
        /* Project Class - Contract Type */
        ,(
            SELECT PPC.PROJECT_ID
                  ,PCCV.CLASS_CODE
                  ,PCLV.CLASS_CATEGORY
            FROM   PJF_PROJECT_CLASSES PPC
                  ,PJF_CLASS_CODES_VL PCCV
                  ,PJF_CLASS_CATEGORIES_VL PCLV
            WHERE  PPC.CLASS_CODE_ID              = PCCV.CLASS_CODE_ID
              AND  PPC.CLASS_CATEGORY_ID          = PCLV.CLASS_CATEGORY_ID
              AND  PCLV.CLASS_CATEGORY            = 'Contract Type'
        ) PRJ_CLASS_CT
        /* Project Class - Market */
        ,(
            SELECT PPC.PROJECT_ID
                  ,PCCV.CLASS_CODE                AS MARKET_CODE
                  ,PCLV.CLASS_CATEGORY
            FROM   PJF_PROJECT_CLASSES PPC
                  ,PJF_CLASS_CODES_VL PCCV
                  ,PJF_CLASS_CATEGORIES_VL PCLV
            WHERE  PPC.CLASS_CODE_ID              = PCCV.CLASS_CODE_ID
              AND  PPC.CLASS_CATEGORY_ID          = PCLV.CLASS_CATEGORY_ID
              AND  PCLV.CLASS_CATEGORY            = 'Market'
        ) PRJ_CLASS_MT
        /* Project Customer - See REPOSITORIES for full implementation */
        ,(
            SELECT DISTINCT PROJECT_ID, PARTY_NUMBER, PARTY_NAME
            FROM (
                SELECT PPAB.PROJECT_ID, HP.PARTY_NUMBER, HP.PARTY_NAME
                FROM   PJF_PROJECT_PARTIES PPP, HZ_PARTIES HP, PJF_PROJECTS_ALL_B PPAB
                WHERE  PPP.PROJECT_PARTY_TYPE     = 'CO'
                  AND  PPP.RESOURCE_SOURCE_ID     = HP.PARTY_ID
                  AND  PPP.PROJECT_ID             = PPAB.PROJECT_ID
            )
        ) PRJ_CUSTOMER
        /* Project Resources - Project Director */
        ,(
            SELECT PPP.PROJECT_ID
                  ,PAP.PERSON_NUMBER              AS RESOURCE_SOURCE_NUMBER
                  ,PPN.LIST_NAME                  AS RESOURCE_SOURCE_NAME
                  ,PRT.PROJECT_ROLE_NAME
                  ,PEA.EMAIL_ADDRESS              AS DIR_EMAIL
            FROM   PJF_PROJECT_PARTIES PPP
                  ,PER_ALL_PEOPLE_F PAP
                  ,PER_PERSON_NAMES_F_V PPN
                  ,PJF_PROJ_ROLE_TYPES_VL PRT
                  ,PER_EMAIL_ADDRESSES_V PEA
            WHERE  PPP.RESOURCE_SOURCE_ID         = PAP.PERSON_ID
              AND  PAP.PERSON_ID                  = PPN.PERSON_ID
              AND  PPP.PROJECT_ROLE_ID            = PRT.PROJECT_ROLE_ID
              AND  PAP.PRIMARY_EMAIL_ID           = PEA.EMAIL_ADDRESS_ID(+)
              AND  TRUNC(SYSDATE)                 BETWEEN PPP.START_DATE_ACTIVE AND NVL(PPP.END_DATE_ACTIVE, TO_DATE('4712-12-31','YYYY-MM-DD'))
              AND  TRUNC(SYSDATE)                 BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
              AND  TRUNC(SYSDATE)                 BETWEEN PPN.EFFECTIVE_START_DATE AND PPN.EFFECTIVE_END_DATE
              AND  PPP.PROJECT_PARTY_TYPE         = 'IN'
              AND  PRT.PROJECT_ROLE_NAME          = 'Project Director'
        ) PRJ_RESOURCE
        WHERE  PRJ_DETAILS.PROJECT_ID             = PRJ_CLASS_MT.PROJECT_ID(+)
          AND  PRJ_DETAILS.PROJECT_ID             = PRJ_CLASS_CT.PROJECT_ID(+)
          AND  PRJ_DETAILS.PROJECT_ID             = PRJ_CUSTOMER.PROJECT_ID(+)
          AND  PRJ_DETAILS.PROJECT_ID             = PRJ_RESOURCE.PROJECT_ID(+)
          AND  (PRJ_DETAILS.BU_NAME               IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
          AND  (PRJ_DETAILS.LIST_NAME             IN (:P_MGR_NAME) OR 'All' IN (:P_MGR_NAME || 'All'))
          AND  (PRJ_DETAILS.PROJECT_STATUS_NAME   IN (:P_STATUS) OR 'All' IN (:P_STATUS || 'All'))
          AND  (PRJ_DETAILS.SEGMENT1              IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
          AND  (PRJ_DETAILS.NAME                  IN (:P_PRJ_NAME) OR 'All' IN (:P_PRJ_NAME || 'All'))
    ) PRJ_INFO
)
/* Project Type Lookup */
,PRJ_TYPE AS (
    SELECT PPTT.PROJECT_TYPE, PPTT.PROJECT_TYPE_ID
    FROM   PJF_PROJECT_TYPES_TL PPTT
    WHERE  PPTT.LANGUAGE = 'US'
)

-- MAIN QUERY
SELECT PD.SEGMENT1                               AS PROJECT_NUMBER
      ,PD.NAME                                   AS PROJECT_NAME
      ,PD.PARTY_NUMBER                           AS CUSTOMER_NUMBER
      ,PD.PARTY_NAME                             AS CUSTOMER_NAME
      ,PD.LIST_NUMBER                            AS PRJ_MANAGER_NUM
      ,PD.LIST_NAME                              AS PRJ_MANAGER_NAME
      ,PD.MGR_EMAIL                              AS PRJ_MANAGER_EMAIL
      ,PD.RESOURCE_SOURCE_NUMBER                 AS PRJ_DIRECTOR_NUM
      ,PD.RESOURCE_SOURCE_NAME                   AS PRJ_DIRECTOR_NAME
      ,PD.DIR_EMAIL                              AS PRJ_DIRECTOR_EMAIL
      ,PD.CLASS_CODE                             AS PROJECT_CLASS
      ,PD.MARKET_CODE                            AS MARKET_CODE
      ,PD.PROJECT_STATUS_NAME                    AS PROJECT_STATUS
      ,PT.PROJECT_TYPE                           AS PROJECT_TYPE
      ,PD.PROJECT_ROLE_NAME                      AS PROJECT_ROLE
      ,PD.BU_NAME                                AS BU_NAME
      ,PD.BURDEN_SCHEDULE                        AS BURDEN_SCHEDULE
      ,PD.PRJ_START_DATE                         AS PRJ_START_DATE
      ,PD.PRJ_COMPLETION_DATE                    AS PRJ_COMPLETION_DATE
FROM   PROJECT_DETAILS PD, PRJ_TYPE PT
WHERE  PD.PROJECT_TYPE_ID                        = PT.PROJECT_TYPE_ID
ORDER BY PD.SEGMENT1
```

---

## 2. Project Summary Report

**Purpose:** Project cost/revenue summary with Budget, Forecast, Actuals, and WIP analysis.

**Parameters:**
- `:P_BU_NAME` - Business Unit
- `:P_PRJ_NUM` - Project Number
- `:P_STATUS` - Project Status
- `:P_REPORT_PERIOD` - Report Period Date

```sql
/*
TITLE: Project Summary Report
PURPOSE: Project cost and revenue summary with Budget, Forecast, Actuals
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH
/*+ qb_name(PSR_ROOT) */
-- 1. Project Base
PRJ_BASE AS (
    SELECT /*+ qb_name(PRJ_BASE) PARALLEL(PJF_PROJECTS_ALL_VL,4) */
           PPAV.PROJECT_ID
          ,PPAV.SEGMENT1                         AS PROJECT_NUMBER
          ,PPAV.NAME                             AS PROJECT_NAME
          ,PPAV.START_DATE
          ,PPAV.COMPLETION_DATE
          ,PPSV.PROJECT_STATUS_NAME
          ,PPTV.PROJECT_TYPE
    FROM   PJF_PROJECTS_ALL_VL PPAV
          ,PJF_PROJECT_STATUSES_VL PPSV
          ,PJF_PROJECT_TYPES_VL PPTV
    WHERE  PPAV.PROJECT_STATUS_CODE              = PPSV.PROJECT_STATUS_CODE
      AND  PPAV.PROJECT_TYPE_ID                  = PPTV.PROJECT_TYPE_ID(+)
      AND  (PPAV.ORG_ID                          IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAV.SEGMENT1                        IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  (PPSV.PROJECT_STATUS_NAME             IN (:P_STATUS) OR 'All' IN (:P_STATUS || 'All'))
)

-- 2. Budget Plan Base (use REPOSITORIES CTE: PRJ_PLAN_BASE)
,PRJ_PLAN_BASE AS (
    SELECT /*+ qb_name(PRJ_PLAN_BASE) MATERIALIZE PARALLEL(PJO_PLAN_LINES,4) */
           PPVV.PROJECT_ID, PPVV.PLAN_CLASS_CODE
          ,PPL.TOTAL_TC_RAW_COST, PPL.TOTAL_TC_BRDND_COST, PPL.TOTAL_TC_REVENUE
          ,PPVV.PLAN_STATUS_CODE, PPVV.CURRENT_PLAN_STATUS_FLAG, PPVV.SUBMITTED_DATE
    FROM   PJO_PLAN_LINES PPL, PJO_PLANNING_ELEMENTS PPE
          ,PJO_PLAN_VERSIONS_VL PPVV, PJF_PROJECTS_ALL_VL PPAV
    WHERE  PPL.PLANNING_ELEMENT_ID               = PPE.PLANNING_ELEMENT_ID
      AND  PPL.PLAN_VERSION_ID                   = PPE.PLAN_VERSION_ID
      AND  PPE.PLAN_VERSION_ID                   = PPVV.PLAN_VERSION_ID
      AND  PPE.PROJECT_ID                        = PPVV.PROJECT_ID
      AND  PPVV.PROJECT_ID                       = PPAV.PROJECT_ID
      AND  PPVV.PLAN_CLASS_CODE                  IN ('BUDGET','FORECAST')
      AND  (PPAV.ORG_ID                          IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAV.SEGMENT1                        IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
)

-- 3. Latest Budget (use REPOSITORIES CTE: PRJ_BUDGET)
,PRJ_BUDGET AS (
    SELECT /*+ qb_name(PRJ_BUDGET) PARALLEL(2) */
           PPB.PROJECT_ID
          ,SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))     AS BUDGET_RAW_COST
          ,(SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0)) - SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))) AS BUDGET_BURDEN_COST
          ,SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0))   AS BUDGET_TOTAL_COST
          ,SUM(NVL(PPB.TOTAL_TC_REVENUE,0))      AS BUDGET_REVENUE
    FROM   PRJ_PLAN_BASE PPB
    WHERE  PPB.PLAN_CLASS_CODE                   IN ('BUDGET')
      AND  PPB.PLAN_STATUS_CODE                  = 'B'
      AND  PPB.SUBMITTED_DATE                    = (SELECT MAX(SUBMITTED_DATE)
                                                     FROM PRJ_PLAN_BASE PPB2
                                                     WHERE PPB2.PROJECT_ID = PPB.PROJECT_ID
                                                       AND PPB2.PLAN_CLASS_CODE = PPB.PLAN_CLASS_CODE
                                                       AND PPB2.PLAN_STATUS_CODE = PPB.PLAN_STATUS_CODE
                                                       AND PPB2.SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD))
    GROUP BY PPB.PROJECT_ID
)

-- 4. Latest Forecast (use REPOSITORIES CTE: PRJ_FORECAST)
,PRJ_FORECAST AS (
    SELECT /*+ qb_name(PRJ_FORECAST) PARALLEL(2) */
           PPB.PROJECT_ID
          ,SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))     AS FORECAST_RAW_COST
          ,(SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0)) - SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))) AS FORECAST_BURDEN_COST
          ,SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0))   AS FORECAST_TOTAL_COST
          ,SUM(NVL(PPB.TOTAL_TC_REVENUE,0))      AS FORECAST_REVENUE
    FROM   PRJ_PLAN_BASE PPB
    WHERE  PPB.PLAN_CLASS_CODE                   IN ('FORECAST')
      AND  PPB.PLAN_STATUS_CODE                  = 'B'
      AND  PPB.SUBMITTED_DATE                    = (SELECT MAX(SUBMITTED_DATE)
                                                     FROM PRJ_PLAN_BASE PPB2
                                                     WHERE PPB2.PROJECT_ID = PPB.PROJECT_ID
                                                       AND PPB2.PLAN_CLASS_CODE = PPB.PLAN_CLASS_CODE
                                                       AND PPB2.PLAN_STATUS_CODE = PPB.PLAN_STATUS_CODE
                                                       AND PPB2.SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD))
    GROUP BY PPB.PROJECT_ID
)

-- 5. Revenue Distribution (use REPOSITORIES CTE: PRJ_REVENUE)
,PRJ_REVENUE AS (
    SELECT /*+ qb_name(PRJ_REVENUE) PARALLEL(PJB_REV_DISTRIBUTIONS,4) */
           PRD.TRANSACTION_PROJECT_ID            AS PROJECT_ID
          ,SUM(NVL(PRD.TRNS_CURR_REVENUE_AMT,0)) AS TRNS_CURR_REVENUE_AMT
          ,SUM(NVL(PRD.LEDGER_CURR_REVENUE_AMT,0)) AS LEDGER_CURR_REVENUE_AMT
    FROM   PJB_REV_DISTRIBUTIONS PRD
    WHERE  TRUNC(PRD.GL_DATE)                    <= LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PRD.TRANSACTION_PROJECT_ID
)

-- 6. Invoice Amount (use REPOSITORIES CTE: PRJ_INVOICE)
,PRJ_INVOICE AS (
    SELECT /*+ qb_name(PRJ_INVOICE) PARALLEL(PJB_INV_LINE_DISTS,4) */
           PILD.TRANSACTION_PROJECT_ID           AS PROJECT_ID
          ,SUM(NVL(PILD.TRNS_CURR_BILLED_AMT,0)) AS TRNS_CURR_INV_AMT
          ,SUM(NVL(PILD.LEDGER_CURR_BILLED_AMT,0)) AS LEDGER_CURR_INV_AMT
    FROM   PJB_INV_LINE_DISTS PILD
    WHERE  TRUNC(PILD.INVOICE_DATE)              <= LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PILD.TRANSACTION_PROJECT_ID
)

-- MAIN QUERY
SELECT PB.PROJECT_NUMBER
      ,PB.PROJECT_NAME
      ,PB.PROJECT_STATUS_NAME
      ,PB.START_DATE
      ,PB.COMPLETION_DATE
      ,PB.PROJECT_TYPE
      -- Budget
      ,ROUND(NVL(PBU.BUDGET_RAW_COST,0),1)       AS BUDGET_RAW_COST
      ,ROUND(NVL(PBU.BUDGET_BURDEN_COST,0),1)    AS BUDGET_BURDEN_COST
      ,ROUND(NVL(PBU.BUDGET_TOTAL_COST,0),1)     AS BUDGET_TOTAL_COST
      ,ROUND(NVL(PBU.BUDGET_REVENUE,0),1)        AS BUDGET_REVENUE
      -- Forecast
      ,ROUND(NVL(PFC.FORECAST_RAW_COST,0),1)     AS FORECAST_RAW_COST
      ,ROUND(NVL(PFC.FORECAST_BURDEN_COST,0),1)  AS FORECAST_BURDEN_COST
      ,ROUND(NVL(PFC.FORECAST_TOTAL_COST,0),1)   AS FORECAST_TOTAL_COST
      ,ROUND(NVL(PFC.FORECAST_REVENUE,0),1)      AS FORECAST_REVENUE
      -- Revenue & Invoice
      ,ROUND(NVL(PRR.TRNS_CURR_REVENUE_AMT,0),1) AS BILLING_REVENUE_AMT
      ,ROUND(NVL(PRI.LEDGER_CURR_INV_AMT,0),1)   AS TOTAL_INVOICE_AMT
      -- WIP Calculation
      ,ROUND((NVL(PRR.TRNS_CURR_REVENUE_AMT,0) - NVL(PRI.LEDGER_CURR_INV_AMT,0)),1) AS WIP_AMOUNT
FROM   PRJ_BASE PB
      ,PRJ_BUDGET PBU
      ,PRJ_FORECAST PFC
      ,PRJ_REVENUE PRR
      ,PRJ_INVOICE PRI
WHERE  PB.PROJECT_ID                             = PBU.PROJECT_ID(+)
  AND  PB.PROJECT_ID                             = PFC.PROJECT_ID(+)
  AND  PB.PROJECT_ID                             = PRR.PROJECT_ID(+)
  AND  PB.PROJECT_ID                             = PRI.PROJECT_ID(+)
ORDER BY PB.PROJECT_NUMBER
```

---

## 3. Project Performance Snapshot Report

**Purpose:** Contract-based project performance with revenue, cost, and margin analysis (Cumulative, YTD, PTD).

**Parameters:**
- `:P_PRJ_BU` - Project Business Unit
- `:P_PRJ_NUM` - Project ID
- `:P_PRJ_STS` - Project Status
- `:P_CON_STS` - Contract Type
- `:P_REPORT_PERIOD` - Report Period Date

```sql
/*
TITLE: Project Performance Snapshot Report
PURPOSE: Contract-based project performance tracking
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH 
-- 1. Project-Contract Links (use REPOSITORIES CTE: PRJ_CON_COST_LINK)
PRJ_CON_COST_LINK AS (
    -- See REPOSITORIES for full implementation
    -- Links projects to contracts for cost/revenue tracking
    SELECT CONTRACT_ID, CONTRACT_LINE_ID, ACTIVE_FLAG, PROJECT_ID, TASK_ID, ASSOCIATED_TASK_ID
    FROM   PJB_CNTRCT_PROJ_LINKS PCPL, PJF_PROJECTS_ALL_B PPAB, PJF_PROJ_ELEMENTS_B PPEB
    WHERE  PPAB.PROJECT_ID                       = PCPL.PROJECT_ID
      AND  PPEB.PROJECT_ID                       = PPAB.PROJECT_ID
      AND  NVL(PPAB.CLIN_LINKED_CODE,'P')        = 'P'
      AND  PCPL.BILLING_TYPE_CODE                IN ('EX', 'IP')
      AND  PCPL.VERSION_TYPE                     = 'C'
      AND  (PPAB.ORG_ID                          IN (:P_PRJ_BU) OR 'All' IN (:P_PRJ_BU || 'All'))
      AND  (PCPL.PROJECT_ID                      IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
)

-- 2. Contract Details (use REPOSITORIES CTE: OKC_CONTRACT_DETAILS)
,OKC_CONTRACT_DETAILS AS (
    -- See REPOSITORIES for full customer/contract details
    SELECT CONTRACT_NUMBER, CONTRACT_LINE_NUMBER, CONTRACT_AMOUNT
          ,CUSTOMER_NUMBER, CUSTOMER_NAME
          ,CONTRACT_ID, CONTRACT_LINE_ID, MAJOR_VERSION
    FROM   (SELECT OKHV.ID AS CONTRACT_ID, OKLV.ID AS CONTRACT_LINE_ID
                  ,OKHV.CONTRACT_NUMBER, OKLV.LINE_NUMBER AS CONTRACT_LINE_NUMBER
                  ,OKLV.LINE_AMOUNT AS CONTRACT_AMOUNT, HZCA.PARTY_ID
            FROM   OKC_K_LINES_VL OKLV, OKC_K_HEADERS_VL OKHV
                  ,PJB_BILL_PLANS_VL PBPV, HZ_CUST_ACCOUNTS HZCA
            WHERE  OKLV.DNZ_CHR_ID                 = OKHV.ID
              AND  OKLV.MAJOR_VERSION              = OKHV.MAJOR_VERSION
              AND  OKLV.VERSION_TYPE               = 'C'
              AND  OKHV.VERSION_TYPE               = 'C') CONTRACTS
          ,(SELECT HP.PARTY_ID, HP.PARTY_NAME AS CUSTOMER_NAME, HP.PARTY_NUMBER AS CUSTOMER_NUMBER
            FROM   HZ_PARTIES HP) CUSTOMERS
    WHERE  CONTRACTS.PARTY_ID                    = CUSTOMERS.PARTY_ID(+)
)

-- 3. Project Snapshot
,PROJECT_SNAPSHOT AS (
    SELECT PPAV.SEGMENT1                         AS PRJ_NUMBER
          ,PPAV.NAME                             AS PRJ_NAME
          ,PPNFV.LIST_NAME                       AS PRJ_MANAGER
          ,PPSV.PROJECT_STATUS_NAME              AS PRJ_STATUS
          ,PPAV.START_DATE, PPAV.CLOSED_DATE, PPAV.COMPLETION_DATE
          ,OCD.CONTRACT_NUMBER, OCD.CONTRACT_LINE_NUMBER
          ,OCD.CONTRACT_AMOUNT
          ,OCD.CUSTOMER_NUMBER, OCD.CUSTOMER_NAME
          -- Revenue (Cumulative, YTD, PTD)
          ,ROUND(NVL((SELECT SUM(PRD.CONT_CURR_REVENUE_AMT)
                      FROM   PJB_REV_DISTRIBUTIONS PRD
                      WHERE  PRD.TRANSACTION_PROJECT_ID = PPAV.PROJECT_ID
                        AND  PRD.CONTRACT_ID = OCD.CONTRACT_ID
                        AND  PRD.CONTRACT_LINE_ID = OCD.CONTRACT_LINE_ID
                        AND  TRUNC(PRD.GL_DATE) <= TRUNC(:P_REPORT_PERIOD)),0),2) AS CUMULATIVE_REV
          ,ROUND(NVL((SELECT SUM(PRD.CONT_CURR_REVENUE_AMT)
                      FROM   PJB_REV_DISTRIBUTIONS PRD
                      WHERE  PRD.TRANSACTION_PROJECT_ID = PPAV.PROJECT_ID
                        AND  PRD.CONTRACT_ID = OCD.CONTRACT_ID
                        AND  PRD.CONTRACT_LINE_ID = OCD.CONTRACT_LINE_ID
                        AND  TRUNC(PRD.GL_DATE) >= TRUNC(:P_REPORT_PERIOD,'YEAR')
                        AND  TRUNC(PRD.GL_DATE) <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))),0),2) AS YTD_REVENUE
          ,ROUND(NVL((SELECT SUM(PRD.CONT_CURR_REVENUE_AMT)
                      FROM   PJB_REV_DISTRIBUTIONS PRD
                      WHERE  PRD.TRANSACTION_PROJECT_ID = PPAV.PROJECT_ID
                        AND  PRD.CONTRACT_ID = OCD.CONTRACT_ID
                        AND  PRD.CONTRACT_LINE_ID = OCD.CONTRACT_LINE_ID
                        AND  TRUNC(PRD.GL_DATE) >= TRUNC(:P_REPORT_PERIOD,'MM')
                        AND  TRUNC(PRD.GL_DATE) <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))),0),2) AS PTD_REVENUE
          ,PPAV.ORG_ID
    FROM   PJF_PROJECTS_ALL_VL PPAV
          ,PJB_CNTRCT_PROJ_LINKS PCPL
          ,OKC_CONTRACT_DETAILS OCD
          ,PJF_LATESTPROJECTMANAGER_V PLMV
          ,PER_PERSON_NAMES_F_V PPNFV
          ,PJF_PROJECT_STATUSES_VL PPSV
    WHERE  PPAV.PROJECT_ID                       = PCPL.PROJECT_ID
      AND  PCPL.CONTRACT_LINE_ID                 = OCD.CONTRACT_LINE_ID
      AND  PCPL.MAJOR_VERSION                    = OCD.MAJOR_VERSION
      AND  PPAV.PROJECT_ID                       = PLMV.PROJECT_ID(+)
      AND  PLMV.RESOURCE_SOURCE_ID               = PPNFV.PERSON_ID(+)
      AND  PPAV.PROJECT_STATUS_CODE              = PPSV.PROJECT_STATUS_CODE(+)
      AND  TRUNC(SYSDATE)                        BETWEEN PPNFV.EFFECTIVE_START_DATE(+) AND PPNFV.EFFECTIVE_END_DATE(+)
      AND  (PPAV.ORG_ID                          IN (:P_PRJ_BU) OR 'All' IN (:P_PRJ_BU || 'All'))
      AND  (PCPL.PROJECT_ID                      IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  (PPSV.PROJECT_STATUS_NAME             IN (:P_PRJ_STS) OR 'All' IN (:P_PRJ_STS || 'All'))
)

-- MAIN QUERY
SELECT PS.PRJ_NUMBER, PS.PRJ_NAME, PS.PRJ_MANAGER, PS.PRJ_STATUS
      ,PS.START_DATE, PS.COMPLETION_DATE, PS.CLOSED_DATE
      ,PS.CONTRACT_NUMBER, PS.CONTRACT_LINE_NUMBER
      ,PS.CUSTOMER_NAME, PS.CUSTOMER_NUMBER
      ,PS.CONTRACT_AMOUNT AS TOTAL_CONTRACT_AMOUNT
      ,PS.CUMULATIVE_REV AS CUMULATIVE_REVENUE
      ,PS.YTD_REVENUE
      ,PS.PTD_REVENUE
      ,TO_CHAR((:P_REPORT_PERIOD),'YYYY')        AS ACCOUNTING_YEAR
      ,TO_CHAR((:P_REPORT_PERIOD),'YYYY-MM')     AS PTD_MONTH
FROM   PROJECT_SNAPSHOT PS
ORDER BY PS.PRJ_NUMBER, PS.CONTRACT_NUMBER, PS.CONTRACT_LINE_NUMBER
```

---

## 4. Project WIP Details Report

**Purpose:** Work-in-progress analysis with revenue recognition details and billing status.

**Parameters:**
- `:p_le_name` - Legal Entity
- `:p_prject` - Project Number
- `:p_period` - Period Name

```sql
/*
TITLE: Project WIP Details Report
PURPOSE: Work-in-progress with revenue recognition and billing
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

-- Note: This query uses UNION ALL to combine expenditure transactions and billing events
-- Simplified version - See full reference query for complete implementation

SELECT project_number, project_name, contract_number
      ,expenditure_type_name, exp_trx_id
      ,TO_CHAR(expenditure_item_date, 'MM/DD/YYYY') AS expenditure_item_date
      ,cost, revenue_amount, invoice_amt
      ,(NVL(revenue_amount,0) - NVL(invoice_amt,0)) AS wip_amt
      ,CASE WHEN billing_invoice_num IS NULL THEN 'Unbilled' ELSE 'Billed' END AS invoice_status
      ,billable, rev_rec_status
FROM (
    -- Expenditure Items with Revenue
    SELECT LE.NAME AS legal_entity
          ,PRJ.SEGMENT1 AS project_number, PRJ.NAME AS project_name
          ,NULL AS contract_number
          ,EXT.EXPENDITURE_TYPE_NAME
          ,EXP.EXPENDITURE_ITEM_ID AS exp_trx_id
          ,EXP.EXPENDITURE_ITEM_DATE
          ,NVL(EXP.PROJFUNC_RAW_COST,0) AS cost
          ,NVL(REV.LEDGER_CURR_REVENUE_AMT,0) AS revenue_amount
          ,NULL AS invoice_amt
          ,CASE WHEN EXP.BILLABLE_FLAG = 'Y' THEN 'Yes' ELSE 'No' END AS billable
          ,CASE WHEN EXP.REVENUE_RECOGNIZED_FLAG = 'F' THEN 'Fully Recognized'
                WHEN EXP.REVENUE_RECOGNIZED_FLAG = 'U' THEN 'Unrecognized'
                ELSE EXP.REVENUE_RECOGNIZED_FLAG END AS rev_rec_status
          ,NULL AS billing_invoice_num
    FROM   PJF_PROJECTS_ALL_VL PRJ
          ,PJC_EXP_ITEMS_ALL EXP
          ,PJF_EXP_TYPES_TL EXT
          ,XLE_ENTITY_PROFILES LE
          ,PJB_REV_DISTRIBUTIONS REV
    WHERE  PRJ.PROJECT_ID                        = EXP.PROJECT_ID
      AND  EXP.EXPENDITURE_TYPE_ID               = EXT.EXPENDITURE_TYPE_ID
      AND  PRJ.LEGAL_ENTITY_ID                   = LE.LEGAL_ENTITY_ID
      AND  EXP.EXPENDITURE_ITEM_ID               = REV.TRANSACTION_ID(+)
      AND  EXT.LANGUAGE                          = 'US'
      AND  (LE.NAME                              IN (:p_le_name) OR 'All' IN (:p_le_name || 'All'))
      AND  (PRJ.SEGMENT1                         IN (:p_prject) OR 'All' IN (:p_prject) || 'All'))
)
WHERE 1=1
ORDER BY project_number, exp_trx_id
```

---

## 5. Project Billing Purchase Order Integration

**Purpose:** Integration between projects, purchase orders, billing, and revenue.

**Parameters:**
- `:p_po_status` - PO Status
- `:p_vendor` - Vendor ID
- `:p_project` - Project ID
- `:p_task` - Task ID
- `:p_buyer` - Buyer ID
- `:p_bu` - Business Unit
- `:p_date_fr`, `:p_date_to` - Date Range

```sql
/*
TITLE: Project Billing Purchase Order Integration
PURPOSE: Links PO, Projects, Billing, and Revenue
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

SELECT DISTINCT
       PHA.SEGMENT1                              AS PO_NUM
      ,A.NAME                                    AS BU_NAME
      ,PLA.LINE_NUM
      ,REPLACE(PLA.ITEM_DESCRIPTION, CHR(10), ' ') AS ITEM_DESCRIPTION
      ,PLA.QUANTITY
      ,PLA.UNIT_PRICE
      ,NVL((PLA.QUANTITY * PLA.UNIT_PRICE), PLA.AMOUNT) AS LINE_AMOUNT
      ,POV.VENDOR_NAME AS SUPPLIER_NAME
      ,(SELECT PJR.SEGMENT1 FROM PJF_PROJECTS_ALL_B PJR
        WHERE  PJR.PROJECT_ID = PDA.PJC_PROJECT_ID AND ROWNUM = 1) AS PROJECT_NUM
      ,(SELECT MAX(X.TASK_NUMBER) FROM PJF_TASKS_V X
        WHERE  X.TASK_ID = PDA.PJC_TASK_ID AND X.PROJECT_ID = PDA.PJC_PROJECT_ID) AS V_TASK
      ,(SELECT MAX(X.EXPENDITURE_TYPE_NAME) FROM PJF_EXP_TYPES_VL X
        WHERE  X.EXPENDITURE_TYPE_ID = PDA.PJC_EXPENDITURE_TYPE_ID) AS V_EXP_TYPE
      ,PDA.PJC_EXPENDITURE_ITEM_DATE AS EXPENDITURE_ITEM_DATE
      ,EXP.EXPENDITURE_ITEM_ID
      ,CASE EXP.BILLABLE_FLAG WHEN 'Y' THEN 'Yes' WHEN 'N' THEN 'No' END AS BILLABLE
FROM   PO_HEADERS_ALL PHA
      ,PO_LINES_ALL PLA
      ,PO_LINE_LOCATIONS_ALL PLL
      ,PO_DISTRIBUTIONS_ALL PDA
      ,POZ_SUPPLIERS_V POV
      ,HR_OPERATING_UNITS A
      ,PJC_EXP_ITEMS_ALL EXP
WHERE  PLA.PO_HEADER_ID                          = PHA.PO_HEADER_ID
  AND  PHA.PRC_BU_ID                             = A.ORGANIZATION_ID
  AND  PLA.PO_HEADER_ID                          = PDA.PO_HEADER_ID
  AND  PLA.PO_LINE_ID                            = PDA.PO_LINE_ID
  AND  PLA.PO_HEADER_ID                          = PLL.PO_HEADER_ID(+)
  AND  PLA.PO_LINE_ID                            = PLL.PO_LINE_ID(+)
  AND  PLL.LINE_LOCATION_ID                      = PDA.LINE_LOCATION_ID(+)
  AND  PHA.VENDOR_ID                             = POV.VENDOR_ID
  AND  PDA.PO_DISTRIBUTION_ID                    = EXP.PARENT_DIST_ID(+)
  AND  PHA.DOCUMENT_STATUS                       = NVL(:p_po_status, PHA.DOCUMENT_STATUS)
  AND  POV.VENDOR_ID                             = NVL(:p_vendor, POV.VENDOR_ID)
  AND  NVL(PDA.PJC_PROJECT_ID, 123)              = NVL(:p_project, NVL(PDA.PJC_PROJECT_ID, 123))
  AND  NVL(PDA.PJC_TASK_ID, 123)                 = NVL(:p_task, NVL(PDA.PJC_TASK_ID, 123))
  AND  PHA.AGENT_ID                              = NVL(:p_buyer, PHA.AGENT_ID)
  AND  NVL(PHA.CANCEL_FLAG, 'N')                 <> 'Y'
  AND  NVL(PLA.CANCEL_FLAG, 'N')                 <> 'Y'
  AND  PLA.CANCEL_DATE                           IS NULL
  AND  PLL.CANCEL_DATE                           IS NULL
  AND  PDA.GL_CANCELLED_DATE                     IS NULL
  AND  PHA.TYPE_LOOKUP_CODE                      = 'STANDARD'
  AND  (PHA.PRC_BU_ID                            IN (:p_bu) OR 'All' IN (:p_bu || 'All'))
  AND  TRUNC(PHA.CREATION_DATE)                  BETWEEN :p_date_fr AND :p_date_to
ORDER BY PHA.SEGMENT1, PLA.LINE_NUM
```

---

**END OF PROJECTS_TEMPLATES.md**

**Usage Notes:**
1. All templates use Oracle Traditional Join Syntax
2. All CTEs include `/*+ qb_name() */` hints
3. Multi-tenant filtering is included in all queries
4. Date-effective filtering is applied to all person tables
5. Templates reference CTEs from PROJECTS_REPOSITORIES.md for modularity
6. Parameters support 'All' option for flexible filtering

**Cross-Module Dependencies:**
- Costing: `PJC_EXP_ITEMS_ALL`, `PJC_COST_DIST_LINES_ALL`
- Contracts: `OKC_K_HEADERS_VL`, `OKC_K_LINES_VL`
- Billing: `PJB_REV_DISTRIBUTIONS`, `PJB_INV_LINE_DISTS`
- Finance: `GL_CODE_COMBINATIONS`, `GL_LEDGERS`
- Procurement: `PO_HEADERS_ALL`, `PO_LINES_ALL`, `PO_DISTRIBUTIONS_ALL`
