# Costing Report Templates

**Purpose:** Ready-to-use SQL skeletons for Cost reporting.  
**Last Updated:** 22-12-25  
**Validation:** ✅ COMPLETED - All reference queries analyzed

---

## Template Index

1. [Project Cost Detail Report](#1-project-cost-detail-report)
2. [Project Cost Summary by Category](#2-project-cost-summary-by-category)
3. [Project Contract Cost Performance](#3-project-contract-cost-performance)
4. [Project WIP Analysis Report](#4-project-wip-analysis-report)

---

## 1. Project Cost Detail Report

**Purpose:** Detailed transaction-level cost listing with type, employee, and dates.

**Parameters:**
- `:P_BU_NAME` - Business Unit
- `:P_PRJ_NUM` - Project Number
- `:P_START_DATE` - Start Date
- `:P_END_DATE` - End Date

```sql
/*
TITLE: Project Cost Detail Report
PURPOSE: Detailed transaction listing with costs
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH
-- 1. Expenditure Items
COSTS AS (
    SELECT /*+ qb_name(C) MATERIALIZE */
           PEI.EXPENDITURE_ITEM_ID
          ,PEI.PROJECT_ID
          ,PEI.TASK_ID
          ,PEI.EXPENDITURE_ITEM_DATE
          ,PEI.QUANTITY
          ,PEI.PROJFUNC_RAW_COST
          ,PEI.PROJFUNC_BURDENED_COST
          ,PEI.BILLABLE_FLAG
          ,PEI.INCURRED_BY_PERSON_ID
          ,PET.EXPENDITURE_TYPE_NAME
          ,(SELECT MAX(EXC.EXPENDITURE_COMMENT)
            FROM   PJC_EXP_COMMENTS EXC
            WHERE  EXC.EXPENDITURE_ITEM_ID   = PEI.EXPENDITURE_ITEM_ID
           ) AS TRX_DESCRIPTION
    FROM   PJC_EXP_ITEMS_ALL PEI
          ,PJF_EXP_TYPES_TL PET
          ,PJF_PROJECTS_ALL_B PPAB
    WHERE  PEI.EXPENDITURE_TYPE_ID           = PET.EXPENDITURE_TYPE_ID
      AND  PET.LANGUAGE                      = 'US'
      AND  PEI.PROJECT_ID                    = PPAB.PROJECT_ID
      AND  (PPAB.ORG_ID                      IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAB.SEGMENT1                    IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  PEI.EXPENDITURE_ITEM_DATE         BETWEEN :P_START_DATE AND :P_END_DATE
)

-- 2. Cost Distribution (GL Date)
,COST_DIST AS (
    SELECT /*+ qb_name(CD) MATERIALIZE */
           PCDLA.EXPENDITURE_ITEM_ID
          ,PCDLA.PRVDR_GL_DATE
          ,PCDLA.PRVDR_GL_PERIOD_NAME
          ,PCDLA.DENOM_CURRENCY_CODE           AS TRX_CURRENCY
          ,PCDLA.DENOM_RAW_COST                AS RAW_COST_TRX_CURR
          ,PCDLA.ACCT_RAW_COST                 AS RAW_COST_ENTITY_CURR
    FROM   PJC_COST_DIST_LINES_ALL PCDLA
    WHERE  PCDLA.EXPENDITURE_ITEM_ID IN (SELECT EXPENDITURE_ITEM_ID FROM COSTS)
)

-- 3. Employee Names
,EMPLOYEES AS (
    SELECT /*+ qb_name(EMP) MATERIALIZE */
           C.INCURRED_BY_PERSON_ID
          ,MAX(PPN.DISPLAY_NAME) AS EMPLOYEE_NAME
    FROM   COSTS C
          ,PER_PERSON_NAMES_F PPN
    WHERE  C.INCURRED_BY_PERSON_ID           = PPN.PERSON_ID(+)
      AND  PPN.NAME_TYPE(+)                  = 'GLOBAL'
      AND  TRUNC(C.EXPENDITURE_ITEM_DATE)    BETWEEN TRUNC(PPN.EFFECTIVE_START_DATE(+))
                                                 AND NVL(TRUNC(PPN.EFFECTIVE_END_DATE(+)), TRUNC(SYSDATE))
    GROUP BY C.INCURRED_BY_PERSON_ID
)

-- MAIN QUERY
SELECT P.PROJECT_NUMBER
      ,P.PROJECT_NAME
      ,T.TASK_NUMBER
      ,C.EXPENDITURE_TYPE_NAME
      ,TO_CHAR(C.EXPENDITURE_ITEM_DATE, 'YYYY-MM-DD') AS EXPENDITURE_DATE
      ,REGEXP_REPLACE(C.TRX_DESCRIPTION,'[[:space:]]',' ') AS DESCRIPTION
      ,C.QUANTITY
      ,ROUND(C.PROJFUNC_RAW_COST, 2) AS RAW_COST
      ,ROUND(C.PROJFUNC_BURDENED_COST, 2) AS BURDENED_COST
      ,CASE C.BILLABLE_FLAG WHEN 'Y' THEN 'Yes' ELSE 'No' END AS BILLABLE
      ,E.EMPLOYEE_NAME
      ,TO_CHAR(CD.PRVDR_GL_DATE, 'YYYY-MM-DD') AS GL_DATE
      ,CD.PRVDR_GL_PERIOD_NAME AS GL_PERIOD
      ,CD.TRX_CURRENCY
      ,ROUND(CD.RAW_COST_TRX_CURR, 2) AS RAW_COST_TRX_CURR
      ,ROUND(CD.RAW_COST_ENTITY_CURR, 2) AS RAW_COST_ENTITY_CURR
FROM   COSTS C
      ,COST_DIST CD
      ,PJF_PROJECTS_ALL_B P
      ,PJF_TASKS_V T
      ,EMPLOYEES E
WHERE  C.PROJECT_ID                          = P.PROJECT_ID
  AND  C.PROJECT_ID                          = T.PROJECT_ID(+)
  AND  C.TASK_ID                             = T.TASK_ID(+)
  AND  C.EXPENDITURE_ITEM_ID                 = CD.EXPENDITURE_ITEM_ID(+)
  AND  C.INCURRED_BY_PERSON_ID               = E.INCURRED_BY_PERSON_ID(+)
ORDER BY P.PROJECT_NUMBER, C.EXPENDITURE_ITEM_DATE
```

---

## 2. Project Cost Summary by Category

**Purpose:** Summarizes project costs by category (Staff, Burden, Expenses).

**Parameters:**
- `:P_BU_NAME` - Business Unit
- `:P_PRJ_NUM` - Project Number
- `:P_REPORT_PERIOD` - Report Period Date

```sql
/*
TITLE: Project Cost Summary by Category
PURPOSE: Cost breakdown by Staff, Burden, Expenses
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH
-- 1. Raw Cost Breakdown (see REPOSITORIES for full implementation)
RAW_COST_BREAKDOWN AS (
    SELECT /*+ PARALLEL(PJC_EXP_ITEMS_ALL,4) */
           PEIA.PROJECT_ID
          ,PCDLA.PROJFUNC_RAW_COST
          ,PCDLA.PRVDR_GL_DATE
          ,DECODE(PECV.DESCRIPTION,
                  'Direct Labor', 'Staff Cost',
                  'Other Expenses', 'Expenses',
                  'Subcontractors', 'Expenses',
                  'Overhead Allocation', 'Burden',
                  'Software', 'Expenses',
                  'Construction', 'Expenses') AS CATEGORY_TYPE
    FROM   PJC_COST_DIST_LINES_ALL PCDLA
          ,PJC_EXP_ITEMS_ALL PEIA
          ,PJF_PROJECTS_ALL_VL PPAV
          ,PJF_EXP_TYPES_VL PETV
          ,PJF_EXP_CATEGORIES_VL PECV
    WHERE  PCDLA.EXPENDITURE_ITEM_ID         = PEIA.EXPENDITURE_ITEM_ID
      AND  PCDLA.PROJECT_ID                  = PEIA.PROJECT_ID
      AND  PCDLA.TASK_ID                     = PEIA.TASK_ID
      AND  PEIA.PROJECT_ID                   = PPAV.PROJECT_ID
      AND  PEIA.EXPENDITURE_TYPE_ID          = PETV.EXPENDITURE_TYPE_ID
      AND  PETV.EXPENDITURE_CATEGORY_ID      = PECV.EXPENDITURE_CATEGORY_ID
      AND  (PPAV.ORG_ID                      IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAV.SEGMENT1                    IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(:P_REPORT_PERIOD)
)

-- 2. Cost Summary
,PRJ_RAW_COST AS (
    SELECT PROJECT_ID
          ,SUM(CASE WHEN CATEGORY_TYPE = 'Staff Cost' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_STAFF
          ,SUM(CASE WHEN CATEGORY_TYPE = 'Burden' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_BURDEN
          ,SUM(CASE WHEN CATEGORY_TYPE = 'Expenses' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_EXPENSES
    FROM   RAW_COST_BREAKDOWN
    WHERE  PRVDR_GL_DATE                     <= (:P_REPORT_PERIOD)
    GROUP BY PROJECT_ID
)

-- MAIN QUERY
SELECT PPAV.SEGMENT1 AS PROJECT_NUMBER
      ,PPAV.NAME AS PROJECT_NAME
      ,ROUND(NVL(PRC.RAW_COST_STAFF, 0), 2) AS STAFF_COST
      ,ROUND(NVL(PRC.RAW_COST_BURDEN, 0), 2) AS BURDEN_COST
      ,ROUND(NVL(PRC.RAW_COST_EXPENSES, 0), 2) AS EXPENSES
      ,ROUND((NVL(PRC.RAW_COST_STAFF, 0) + NVL(PRC.RAW_COST_BURDEN, 0) + NVL(PRC.RAW_COST_EXPENSES, 0)), 2) AS TOTAL_COST
FROM   PJF_PROJECTS_ALL_VL PPAV
      ,PRJ_RAW_COST PRC
WHERE  PPAV.PROJECT_ID                       = PRC.PROJECT_ID
  AND  (PPAV.ORG_ID                          IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
  AND  (PPAV.SEGMENT1                        IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
ORDER BY PPAV.SEGMENT1
```

---

## 3. Project Contract Cost Performance

**Purpose:** Cost performance by contract with separate reporting for overhead.

**Parameters:**
- `:P_PRJ_BU` - Project Business Unit
- `:P_PRJ_NUM` - Project ID
- `:P_REPORT_PERIOD` - Report Period Date

```sql
/*
TITLE: Project Contract Cost Performance
PURPOSE: Cost by contract with overhead breakdown
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH
-- 1. Project-Contract Links
PRJ_CON_COST_LINK AS (
    -- See PROJECTS_REPOSITORIES for full implementation
    SELECT PCPL.CONTRACT_ID, PCPL.CONTRACT_LINE_ID, PPAB.PROJECT_ID, PPEB.PROJ_ELEMENT_ID AS TASK_ID
    FROM   PJB_CNTRCT_PROJ_LINKS PCPL, PJF_PROJECTS_ALL_B PPAB, PJF_PROJ_ELEMENTS_B PPEB
    WHERE  PPAB.PROJECT_ID                   = PCPL.PROJECT_ID
      AND  PPEB.PROJECT_ID                   = PPAB.PROJECT_ID
      AND  NVL(PPAB.CLIN_LINKED_CODE,'P')    = 'P'
      AND  PCPL.BILLING_TYPE_CODE            IN ('EX', 'IP')
      AND  PCPL.VERSION_TYPE                 = 'C'
      AND  (PPAB.ORG_ID                      IN (:P_PRJ_BU) OR 'All' IN (:P_PRJ_BU || 'All'))
      AND  (PCPL.PROJECT_ID                  IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
)

-- 2. Costs WITHOUT Overhead (see REPOSITORIES: PJC_COST_DETAILS_NOA)
,PJC_COST_DETAILS_NOA AS (
    SELECT PCDLA.PROJECT_ID, PCCL.CONTRACT_ID, PCCL.CONTRACT_LINE_ID
          ,NVL(PCDLA.PROJFUNC_BURDENED_COST,0) AS PROJFUNC_BURDENED_COST
    FROM   PJC_COST_DIST_LINES_ALL PCDLA, PRJ_CON_COST_LINK PCCL
    WHERE  PCDLA.PROJECT_ID                  = PCCL.PROJECT_ID
      AND  PCDLA.TASK_ID                     = PCCL.TASK_ID
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))
      AND  EXISTS (SELECT 'X' FROM PJC_EXP_ITEMS_ALL PEIA
                   WHERE  PEIA.EXPENDITURE_ITEM_ID = PCDLA.EXPENDITURE_ITEM_ID
                     AND  PEIA.PROJECT_ID = PCDLA.PROJECT_ID
                     AND  PEIA.TASK_ID = PCDLA.TASK_ID
                     AND  PEIA.EXPENDITURE_TYPE_ID != 300000126235407)
)

-- 3. Costs WITH ONLY Overhead (see REPOSITORIES: PJC_COST_DETAILS_OA)
,PJC_COST_DETAILS_OA AS (
    SELECT PCDLA.PROJECT_ID, PCCL.CONTRACT_ID, PCCL.CONTRACT_LINE_ID
          ,NVL(PCDLA.PROJFUNC_BURDENED_COST,0) AS PROJFUNC_BURDENED_COST
    FROM   PJC_COST_DIST_LINES_ALL PCDLA, PRJ_CON_COST_LINK PCCL
    WHERE  PCDLA.PROJECT_ID                  = PCCL.PROJECT_ID
      AND  PCDLA.TASK_ID                     = PCCL.TASK_ID
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))
      AND  EXISTS (SELECT 'X' FROM PJC_EXP_ITEMS_ALL PEIA
                   WHERE  PEIA.EXPENDITURE_ITEM_ID = PCDLA.EXPENDITURE_ITEM_ID
                     AND  PEIA.PROJECT_ID = PCDLA.PROJECT_ID
                     AND  PEIA.TASK_ID = PCDLA.TASK_ID
                     AND  PEIA.EXPENDITURE_TYPE_ID = 300000126235407)
)

-- MAIN QUERY
SELECT PPAV.SEGMENT1 AS PRJ_NUMBER
      ,PPAV.NAME AS PRJ_NAME
      ,(SELECT MAX(OKHV.CONTRACT_NUMBER) FROM OKC_K_HEADERS_VL OKHV
        WHERE  OKHV.ID = PCCL.CONTRACT_ID) AS CONTRACT_NUMBER
      ,(SELECT MAX(OKLV.LINE_NUMBER) FROM OKC_K_LINES_VL OKLV
        WHERE  OKLV.ID = PCCL.CONTRACT_LINE_ID AND OKLV.CHR_ID = PCCL.CONTRACT_ID) AS CONTRACT_LINE_NUMBER
      ,ROUND(SUM(NVL(PCD_NOA.PROJFUNC_BURDENED_COST, 0)), 2) AS CUMULATIVE_COST
      ,ROUND(SUM(NVL(PCD_OA.PROJFUNC_BURDENED_COST, 0)), 2) AS CUMULATIVE_COST_OA
      ,ROUND((SUM(NVL(PCD_NOA.PROJFUNC_BURDENED_COST, 0)) + SUM(NVL(PCD_OA.PROJFUNC_BURDENED_COST, 0))), 2) AS CUMULATIVE_TOTAL_COST
FROM   PJF_PROJECTS_ALL_VL PPAV
      ,PRJ_CON_COST_LINK PCCL
      ,PJC_COST_DETAILS_NOA PCD_NOA
      ,PJC_COST_DETAILS_OA PCD_OA
WHERE  PPAV.PROJECT_ID                       = PCCL.PROJECT_ID
  AND  PPAV.PROJECT_ID                       = PCD_NOA.PROJECT_ID(+)
  AND  PCCL.CONTRACT_ID                      = PCD_NOA.CONTRACT_ID(+)
  AND  PCCL.CONTRACT_LINE_ID                 = PCD_NOA.CONTRACT_LINE_ID(+)
  AND  PPAV.PROJECT_ID                       = PCD_OA.PROJECT_ID(+)
  AND  PCCL.CONTRACT_ID                      = PCD_OA.CONTRACT_ID(+)
  AND  PCCL.CONTRACT_LINE_ID                 = PCD_OA.CONTRACT_LINE_ID(+)
GROUP BY PPAV.SEGMENT1, PPAV.NAME, PCCL.CONTRACT_ID, PCCL.CONTRACT_LINE_ID
ORDER BY PPAV.SEGMENT1
```

---

## 4. Project WIP Analysis Report

**Purpose:** Work-in-progress analysis with billable costs not yet invoiced.

**Parameters:**
- `:P_BU_NAME` - Business Unit
- `:P_PRJ_NUM` - Project Number

```sql
/*
TITLE: Project WIP Analysis Report
PURPOSE: Analyze work-in-progress (billable but uninvoiced costs)
AUTHOR: PPM Validation Team
DATE: 22-12-25
*/

WITH
-- 1. Expenditure Items (Billable Only)
EXP_ITEMS AS (
    SELECT /*+ qb_name(EXP) MATERIALIZE */
           PEI.EXPENDITURE_ITEM_ID
          ,PEI.PROJECT_ID
          ,PEI.TASK_ID
          ,PEI.EXPENDITURE_ITEM_DATE
          ,PEI.PROJFUNC_RAW_COST
          ,PEI.BILLABLE_FLAG
          ,PEI.REVENUE_RECOGNIZED_FLAG
          ,PEI.INVOICED_FLAG
          ,PEI.INVOICED_PERCENTAGE
          ,PET.EXPENDITURE_TYPE_NAME
          ,CASE WHEN PEI.REVENUE_RECOGNIZED_FLAG = 'F' THEN 'Fully Recognized'
                WHEN PEI.REVENUE_RECOGNIZED_FLAG = 'U' THEN 'Unrecognized'
                ELSE PEI.REVENUE_RECOGNIZED_FLAG END AS REV_REC_STATUS
          ,CASE WHEN PEI.INVOICED_FLAG = 'U' THEN 'Uninvoiced'
                WHEN PEI.INVOICED_FLAG = 'F' THEN 'Fully Invoiced'
                WHEN PEI.INVOICED_FLAG = 'P' THEN 'Partially Invoiced'
                ELSE PEI.INVOICED_FLAG END AS INV_STATUS
    FROM   PJC_EXP_ITEMS_ALL PEI
          ,PJF_EXP_TYPES_TL PET
          ,PJF_PROJECTS_ALL_B PPAB
    WHERE  PEI.EXPENDITURE_TYPE_ID           = PET.EXPENDITURE_TYPE_ID
      AND  PET.LANGUAGE                      = 'US'
      AND  PEI.PROJECT_ID                    = PPAB.PROJECT_ID
      AND  PEI.BILLABLE_FLAG                 = 'Y'
      AND  PEI.INVOICED_FLAG                 != 'F'  -- Not Fully Invoiced
      AND  (PPAB.ORG_ID                      IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAB.SEGMENT1                    IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
)

-- 2. Revenue for these expenditures
,EXP_REVENUE AS (
    SELECT /*+ qb_name(REV) MATERIALIZE */
           PRD.TRANSACTION_ID AS EXPENDITURE_ITEM_ID
          ,SUM(NVL(PRD.LEDGER_CURR_REVENUE_AMT, 0)) AS REVENUE_AMOUNT
    FROM   PJB_REV_DISTRIBUTIONS PRD
    WHERE  PRD.TRANSACTION_ID IN (SELECT EXPENDITURE_ITEM_ID FROM EXP_ITEMS)
      AND  PRD.BILL_TRANSACTION_TYPE_CODE    = 'EI'  -- Expenditure Item
    GROUP BY PRD.TRANSACTION_ID
)

-- 3. Invoice Amount for these expenditures
,EXP_INVOICE AS (
    SELECT /*+ qb_name(INV) MATERIALIZE */
           T.TRANSACTION_ID AS EXPENDITURE_ITEM_ID
          ,SUM(NVL(LD.LEDGER_CURR_BILLED_AMT, 0)) AS INVOICE_AMOUNT
    FROM   PJB_BILL_TRXS T
          ,PJB_INV_LINE_DISTS LD
          ,PJB_INVOICE_HEADERS H
    WHERE  T.TRANSACTION_ID IN (SELECT EXPENDITURE_ITEM_ID FROM EXP_ITEMS)
      AND  T.BILL_TRX_ID                     = LD.BILL_TRX_ID
      AND  LD.INVOICE_ID                     = H.INVOICE_ID
    GROUP BY T.TRANSACTION_ID
)

-- MAIN QUERY
SELECT P.PROJECT_NUMBER
      ,P.PROJECT_NAME
      ,T.TASK_NUMBER
      ,E.EXPENDITURE_TYPE_NAME
      ,TO_CHAR(E.EXPENDITURE_ITEM_DATE, 'YYYY-MM-DD') AS EXPENDITURE_DATE
      ,ROUND(E.PROJFUNC_RAW_COST, 2) AS COST
      ,ROUND(NVL(R.REVENUE_AMOUNT, 0), 2) AS REVENUE_AMOUNT
      ,ROUND(NVL(I.INVOICE_AMOUNT, 0), 2) AS INVOICE_AMOUNT
      ,ROUND((NVL(R.REVENUE_AMOUNT, 0) - NVL(I.INVOICE_AMOUNT, 0)), 2) AS WIP_AMOUNT
      ,E.REV_REC_STATUS
      ,E.INV_STATUS
      ,NVL(E.INVOICED_PERCENTAGE, 0) AS INVOICED_PERCENTAGE
FROM   EXP_ITEMS E
      ,PJF_PROJECTS_ALL_B P
      ,PJF_TASKS_V T
      ,EXP_REVENUE R
      ,EXP_INVOICE I
WHERE  E.PROJECT_ID                          = P.PROJECT_ID
  AND  E.PROJECT_ID                          = T.PROJECT_ID(+)
  AND  E.TASK_ID                             = T.TASK_ID(+)
  AND  E.EXPENDITURE_ITEM_ID                 = R.EXPENDITURE_ITEM_ID(+)
  AND  E.EXPENDITURE_ITEM_ID                 = I.EXPENDITURE_ITEM_ID(+)
  AND  (NVL(R.REVENUE_AMOUNT, 0) - NVL(I.INVOICE_AMOUNT, 0)) <> 0  -- Only show WIP items
ORDER BY P.PROJECT_NUMBER, E.EXPENDITURE_ITEM_DATE
```

---

**END OF COSTING_TEMPLATES.md**

**Usage Notes:**
1. All templates use Oracle Traditional Join Syntax
2. Performance hints included for large tables
3. Overhead allocation logic: `EXPENDITURE_TYPE_ID <> 300000126235407` for raw cost
4. Separate CTEs for costs with and without overhead
5. Multi-tenant filtering included
6. Date filtering uses `PRVDR_GL_DATE` from cost distribution
7. All amounts rounded to 2 decimal places
8. WIP calculation: Revenue - Invoice Amount

**Dependencies:**
- Requires CTEs from COSTING_REPOSITORIES for complex calculations
- Integrates with PROJECTS module for project/task details
- Links to billing and revenue tables for WIP analysis
- Uses person tables for employee details (with date-effectiveness)

**Performance Considerations:**
- Use PARALLEL hints for `PJC_COST_DIST_LINES_ALL` and `PJC_EXP_ITEMS_ALL`
- Use EXISTS for overhead filtering (more efficient than joins)
- Filter by project and date range as early as possible
- Use MATERIALIZE hint for reused CTEs
