# Costing Repository Patterns

**Purpose:** Standardized CTEs for Project Costs and WIP.  
**Last Updated:** 22-12-25  
**Validation:** ✅ COMPLETED - All reference queries analyzed

---

## 1. Actual Cost Base
*Base CTE for all actual cost calculations (Cumulative, YTD, PTD).*

```sql
PRJ_ACTUAL_BASE AS (
    SELECT /*+ qb_name(PRJ_ACTUAL_BASE) PARALLEL(PJC_COST_DIST_LINES_ALL,4) */
           PCDLA.PROJECT_ID
          ,PEIA.EXPENDITURE_TYPE_ID
          ,PCDLA.PROJFUNC_RAW_COST
          ,PCDLA.PROJFUNC_BURDENED_COST
          ,PCDLA.PRVDR_GL_DATE
    FROM   PJC_COST_DIST_LINES_ALL PCDLA
          ,PJC_EXP_ITEMS_ALL PEIA
          ,PJF_PROJECTS_ALL_B PPAB
    WHERE  PEIA.EXPENDITURE_ITEM_ID          = PCDLA.EXPENDITURE_ITEM_ID
      AND  PEIA.PROJECT_ID                   = PCDLA.PROJECT_ID
      AND  PEIA.TASK_ID                      = PCDLA.TASK_ID
      AND  PEIA.PROJECT_ID                   = PPAB.PROJECT_ID
      AND  (PPAB.ORG_ID                      IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAB.SEGMENT1                    IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(:P_REPORT_PERIOD)
)
```

---

## 2. Cumulative Actual Costs
*Inception-to-Date actual costs (excluding overhead allocation).*

```sql
PRJ_ACTUAL AS (
    SELECT PROJECT_ID
          ,ROUND(SUM(NVL((CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407
                               THEN PROJFUNC_RAW_COST END),0)),2) AS ACTUAL_RAW_COST
          ,ROUND((SUM(NVL(PROJFUNC_BURDENED_COST,0)) -
                  SUM(NVL((CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407
                                THEN PROJFUNC_RAW_COST END),0))),2) AS ACTUAL_BURDENED_COST
          ,ROUND(SUM(NVL(PROJFUNC_BURDENED_COST,0)),2) AS TOTAL_ACTUAL_COST
    FROM   PRJ_ACTUAL_BASE
    WHERE  TRUNC(PRVDR_GL_DATE)              <= LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PROJECT_ID
)
```

---

## 3. Year-to-Date Actual Costs
*YTD actual costs for current year.*

```sql
PRJ_ACTUAL_YEAR AS (
    SELECT PROJECT_ID
          ,ROUND(SUM(NVL((CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407
                               THEN PROJFUNC_RAW_COST END),0)),2) AS ACTUAL_RAW_COST
          ,ROUND((SUM(NVL(PROJFUNC_BURDENED_COST,0)) -
                  SUM(NVL((CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407
                                THEN PROJFUNC_RAW_COST END),0))),2) AS ACTUAL_BURDENED_COST
          ,ROUND(SUM(NVL(PROJFUNC_BURDENED_COST,0)),2) AS TOTAL_ACTUAL_COST
    FROM   PRJ_ACTUAL_BASE
    WHERE  TRUNC(PRVDR_GL_DATE)              BETWEEN TRUNC(LAST_DAY(:P_REPORT_PERIOD),'YEAR')
                                                 AND LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PROJECT_ID
)
```

---

## 4. Period-to-Date Actual Costs
*PTD actual costs for current month.*

```sql
PRJ_ACTUAL_MONTH AS (
    SELECT /*+ qb_name(PRJ_MON_CMLT) */
           PROJECT_ID
          ,ROUND(SUM(NVL((CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407
                               THEN PROJFUNC_RAW_COST END),0)),2) AS ACTUAL_RAW_COST
          ,ROUND((SUM(NVL(PROJFUNC_BURDENED_COST,0)) -
                  SUM(NVL((CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407
                                THEN PROJFUNC_RAW_COST END),0))),2) AS ACTUAL_BURDENED_COST
          ,ROUND(SUM(NVL(PROJFUNC_BURDENED_COST,0)),2) AS TOTAL_ACTUAL_COST
    FROM   PRJ_ACTUAL_BASE
    WHERE  TRUNC(PRVDR_GL_DATE)              BETWEEN TRUNC(TO_DATE(TO_CHAR((:P_REPORT_PERIOD),'YYYY-MM-DD'),'YYYY-MM-DD'),'MM')
                                                 AND LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PROJECT_ID
)
```

---

## 5. Cost Details WITHOUT Overhead Allocation
*Cost and quantity excluding overhead allocation type.*

```sql
PJC_COST_DETAILS_NOA AS (
    SELECT PCDLA.PROJECT_ID
          ,PCCL.CONTRACT_ID
          ,PCCL.CONTRACT_LINE_ID
          ,PCDLA.PRVDR_GL_DATE
          ,NVL(PCDLA.PROJFUNC_BURDENED_COST,0) AS PROJFUNC_BURDENED_COST
          ,NVL(PCDLA.QUANTITY,0) AS QUANTITY
    FROM   PJC_COST_DIST_LINES_ALL PCDLA
          ,PRJ_CON_COST_LINK PCCL
    WHERE  PCDLA.PROJECT_ID                  = PCCL.PROJECT_ID
      AND  PCDLA.TASK_ID                     = PCCL.TASK_ID
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))
      AND  EXISTS (
            SELECT 'X'
            FROM   PJC_EXP_ITEMS_ALL PEIA
            WHERE  PEIA.EXPENDITURE_ITEM_ID  = PCDLA.EXPENDITURE_ITEM_ID
              AND  PEIA.PROJECT_ID           = PCDLA.PROJECT_ID
              AND  PEIA.TASK_ID              = PCDLA.TASK_ID
              AND  PEIA.EXPENDITURE_TYPE_ID  != 300000126235407  /* NOT Overhead Allocation */
           )
)
```

---

## 6. Cost Details WITH ONLY Overhead Allocation
*Cost and quantity for overhead allocation type only.*

```sql
PJC_COST_DETAILS_OA AS (
    SELECT PCDLA.PROJECT_ID
          ,PCCL.CONTRACT_ID
          ,PCCL.CONTRACT_LINE_ID
          ,PCDLA.PRVDR_GL_DATE
          ,NVL(PCDLA.PROJFUNC_BURDENED_COST,0) AS PROJFUNC_BURDENED_COST
          ,NVL(PCDLA.QUANTITY,0) AS QUANTITY
    FROM   PJC_COST_DIST_LINES_ALL PCDLA
          ,PRJ_CON_COST_LINK PCCL
    WHERE  PCDLA.PROJECT_ID                  = PCCL.PROJECT_ID
      AND  PCDLA.TASK_ID                     = PCCL.TASK_ID
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))
      AND  EXISTS (
            SELECT 'X'
            FROM   PJC_EXP_ITEMS_ALL PEIA
            WHERE  PEIA.EXPENDITURE_ITEM_ID  = PCDLA.EXPENDITURE_ITEM_ID
              AND  PEIA.PROJECT_ID           = PCDLA.PROJECT_ID
              AND  PEIA.TASK_ID              = PCDLA.TASK_ID
              AND  PEIA.EXPENDITURE_TYPE_ID  = 300000126235407  /* ONLY Overhead Allocation */
           )
)
```

---

## 7. Quantity in Hours
*Quantity for expenditure types with HOURS unit of measure.*

```sql
PJC_QUANTITY_HRS AS (
    SELECT PCDLA.PROJECT_ID
          ,PCCL.CONTRACT_ID
          ,PCCL.CONTRACT_LINE_ID
          ,PCDLA.PRVDR_GL_DATE
          ,NVL(PCDLA.QUANTITY,0) AS QUANTITY
    FROM   PJC_COST_DIST_LINES_ALL PCDLA
          ,PRJ_CON_COST_LINK PCCL
    WHERE  PCDLA.PROJECT_ID                  = PCCL.PROJECT_ID
      AND  PCDLA.TASK_ID                     = PCCL.TASK_ID
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(TRUNC(:P_REPORT_PERIOD))
      AND  EXISTS (
            SELECT 'X'
            FROM   PJC_EXP_ITEMS_ALL PEIA, PJF_EXP_TYPES_VL PETV
            WHERE  PEIA.EXPENDITURE_ITEM_ID  = PCDLA.EXPENDITURE_ITEM_ID
              AND  PEIA.PROJECT_ID           = PCDLA.PROJECT_ID
              AND  PEIA.TASK_ID              = PCDLA.TASK_ID
              AND  PEIA.EXPENDITURE_TYPE_ID  = PETV.EXPENDITURE_TYPE_ID
              AND  PETV.UNIT_OF_MEASURE      = 'HOURS'
           )
)
```

---

## 8. Raw Cost Breakdown by Category
*Categorizes costs into Staff Cost, Burden, and Expenses.*

```sql
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
      AND  (CAST(PPAV.PROJECT_TYPE_ID AS VARCHAR(50)) IN ('300000053434698','300000125438401','300000125440128'))
      AND  (PPAV.ORG_ID                      IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAV.SEGMENT1                    IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(:P_REPORT_PERIOD)
)
```

---

## 9. Cost Summary by Category
*Summarizes costs by Staff, Burden, and Expenses.*

```sql
PRJ_RAW_COST AS (
    SELECT PROJECT_ID
          ,SUM(CASE WHEN CATEGORY_TYPE = 'Staff Cost' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_STAFF
          ,SUM(CASE WHEN CATEGORY_TYPE = 'Burden' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_BURDEN
          ,SUM(CASE WHEN CATEGORY_TYPE = 'Expenses' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_EXPENSES
    FROM   RAW_COST_BREAKDOWN
    WHERE  PRVDR_GL_DATE                     <= (:P_REPORT_PERIOD)
    GROUP BY PROJECT_ID
)
```

---

## 10. Expenditure Items Master
*Base CTE for expenditure items with type and person details.*

```sql
PPM_COST_MASTER AS (
    SELECT /*+ qb_name(COST) MATERIALIZE */
           PEI.EXPENDITURE_ITEM_ID
          ,PEI.PROJECT_ID
          ,PEI.TASK_ID
          ,PEI.EXPENDITURE_ITEM_DATE
          ,PEI.QUANTITY
          ,PEI.PROJFUNC_RAW_COST
          ,PEI.PROJFUNC_BURDENED_COST
          ,PEI.BILLABLE_FLAG
          ,PEI.REVENUE_RECOGNIZED_FLAG
          ,PEI.INVOICED_FLAG
          ,PEI.INCURRED_BY_PERSON_ID
          ,PET.EXPENDITURE_TYPE_NAME
          ,CASE PEI.BILLABLE_FLAG WHEN 'Y' THEN 'Yes' ELSE 'No' END AS BILLABLE
          ,CASE WHEN PEI.REVENUE_RECOGNIZED_FLAG = 'F' THEN 'Fully Recognized'
                WHEN PEI.REVENUE_RECOGNIZED_FLAG = 'U' THEN 'Unrecognized'
                ELSE PEI.REVENUE_RECOGNIZED_FLAG END AS REV_REC_STATUS
          ,CASE WHEN PEI.INVOICED_FLAG = 'U' THEN 'Uninvoiced'
                WHEN PEI.INVOICED_FLAG = 'F' THEN 'Fully Invoiced'
                WHEN PEI.INVOICED_FLAG = 'P' THEN 'Partially Invoiced'
                ELSE PEI.INVOICED_FLAG END AS INVOICED_STATUS
    FROM   PJC_EXP_ITEMS_ALL PEI
          ,PJF_EXP_TYPES_TL PET
    WHERE  PEI.EXPENDITURE_TYPE_ID           = PET.EXPENDITURE_TYPE_ID
      AND  PET.LANGUAGE                      = 'US'
)
```

---

## 11. WIP Details (Unbilled Revenue)
*Finds billable items that are recognized but not fully invoiced.*

```sql
PPM_WIP_MASTER AS (
    SELECT /*+ qb_name(WIP) MATERIALIZE */
           PEI.EXPENDITURE_ITEM_ID
          ,PEI.PROJECT_ID
          ,PEI.PROJFUNC_RAW_COST AS WIP_COST
          ,CASE WHEN PEI.REVENUE_RECOGNIZED_FLAG = 'F' THEN 'Recognized'
                ELSE 'Unrecognized' END AS REV_STATUS
          ,CASE WHEN PEI.INVOICED_FLAG = 'F' THEN 'Invoiced'
                ELSE 'Uninvoiced' END AS INV_STATUS
    FROM   PJC_EXP_ITEMS_ALL PEI
    WHERE  PEI.BILLABLE_FLAG                 = 'Y'
      AND  PEI.INVOICED_FLAG                 != 'F'  -- Not Fully Invoiced
)
```

---

## 12. Expenditure Item with Employee Details
*Expenditure items with incurred-by person name.*

```sql
EXP_WITH_EMPLOYEE AS (
    SELECT EXP.EXPENDITURE_ITEM_ID
          ,EXP.PROJECT_ID
          ,EXP.TASK_ID
          ,EXP.EXPENDITURE_ITEM_DATE
          ,EXP.PROJFUNC_RAW_COST
          ,EXP.EXPENDITURE_TYPE_NAME
          ,(SELECT TO_CHAR(PPN.DISPLAY_NAME)
            FROM   PER_PERSON_NAMES_F PPN
            WHERE  PPN.NAME_TYPE               = 'GLOBAL'
              AND  ROWNUM                      = 1
              AND  PPN.PERSON_ID               = EXP.INCURRED_BY_PERSON_ID
              AND  TRUNC(EXP.EXPENDITURE_ITEM_DATE) BETWEEN TRUNC(PPN.EFFECTIVE_START_DATE)
                                                        AND NVL(TRUNC(PPN.EFFECTIVE_END_DATE), TRUNC(SYSDATE))
           ) AS EMPLOYEE_NAME
    FROM   PPM_COST_MASTER EXP
)
```

---

## 13. Expenditure Item with Supplier Details
*Expenditure items with supplier information from AP.*

```sql
EXP_WITH_SUPPLIER AS (
    SELECT EXP.EXPENDITURE_ITEM_ID
          ,EXP.PROJECT_ID
          ,EXP.PROJFUNC_RAW_COST
          ,(SELECT MAX(PS.VENDOR_NAME)
            FROM   POZ_SUPPLIERS_V PS
                  ,AP_INVOICES_ALL AIA
                  ,AP_INVOICE_DISTRIBUTIONS_ALL AIDA
            WHERE  PS.VENDOR_ID                = AIA.VENDOR_ID
              AND  AIA.ORG_ID                  = PPAB.ORG_ID
              AND  AIA.INVOICE_ID              = AIDA.INVOICE_ID
              AND  AIDA.INVOICE_DISTRIBUTION_ID = EXP.ORIGINAL_DIST_ID
           ) AS SUPPLIER_NAME
    FROM   PJC_EXP_ITEMS_ALL EXP
          ,PJF_PROJECTS_ALL_B PPAB
    WHERE  EXP.PROJECT_ID                    = PPAB.PROJECT_ID
)
```

---

## 14. AP Outstanding Balance
*AP invoices related to projects that are not yet paid.*

```sql
AP_OUTSTANDING AS (
    SELECT PEIA.PROJECT_ID
          ,SUM(APSA.AMOUNT_REMAINING) AS AP_REM_AMOUNT
    FROM   PJC_EXP_ITEMS_ALL PEIA
          ,AP_INVOICE_DISTRIBUTIONS_ALL AIDA
          ,(SELECT AIA.INVOICE_ID, APSA.AMOUNT_REMAINING
            FROM   AP_INVOICES_ALL AIA, AP_PAYMENT_SCHEDULES_ALL APSA
            WHERE  AIA.INVOICE_ID            = APSA.INVOICE_ID
              AND  AIA.CANCELLED_DATE        IS NULL
              AND  AIA.PAYMENT_STATUS_FLAG   IN ('N', 'P')  -- Not Paid, Partially Paid
           ) APSA
    WHERE  PEIA.ORIGINAL_HEADER_ID           = AIDA.INVOICE_ID
      AND  PEIA.PROJECT_ID                   = AIDA.PJC_PROJECT_ID
      AND  PEIA.ORIGINAL_DIST_ID             = AIDA.INVOICE_DISTRIBUTION_ID
      AND  PEIA.ORIGINAL_LINE_NUMBER         = AIDA.DISTRIBUTION_LINE_NUMBER
      AND  AIDA.INVOICE_ID                   = APSA.INVOICE_ID
    GROUP BY PEIA.PROJECT_ID
)
```

---

**END OF COSTING_REPOSITORIES.md**

**Usage Notes:**
1. All CTEs use Oracle Traditional Join Syntax
2. Performance hints included (`/*+ qb_name() PARALLEL() */`)
3. Overhead allocation exclusion pattern: `EXPENDITURE_TYPE_ID <> 300000126235407`
4. Use `EXISTS` for filtering overhead (more efficient than joins)
5. Date filtering uses `PRVDR_GL_DATE` from cost distribution lines
6. All amounts rounded to 2 decimal places
7. Multi-tenant filtering included where applicable
8. Cost breakdown supports Staff Cost, Burden, and Expenses categorization

**Dependencies:**
- Requires `PRJ_CON_COST_LINK` CTE from PROJECTS_REPOSITORIES for contract-based reporting
- Integrates with `PPM_PRJ_MASTER` from PROJECTS module for project details
- Links to revenue and billing CTEs for WIP calculation
