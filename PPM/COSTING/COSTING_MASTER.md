# Costing Master Instructions

**Module:** Project Costing (PPM)
**Tag:** `#PPM #Costing #PJC`
**Status:** Active  
**Last Updated:** 22-12-25  
**Validation:** ✅ COMPLETED - All reference queries analyzed

---

## 1. 🚨 Critical Costing Constraints

### A. Billable Status
- **Rule:** Check `BILLABLE_FLAG = 'Y'` for revenue-generating costs.
- **Values:** `'Y'` (Billable), `'N'` (Non-Billable)
- **Usage:** Affects WIP and revenue recognition

### B. Revenue Recognition
- **Rule:** Check `REVENUE_RECOGNIZED_FLAG` to determine revenue status.
- **Values:**
  - `'F'` - Fully Recognized
  - `'A'` - Partially Recognized
  - `'U'` - Unrecognized
  - `'P'` - Pending Adjustment
- **Display Logic:**
  ```sql
  CASE WHEN REVENUE_RECOGNIZED_FLAG = 'F' THEN 'Fully Recognized'
       WHEN REVENUE_RECOGNIZED_FLAG = 'U' THEN 'Unrecognized'
       ELSE REVENUE_RECOGNIZED_FLAG END
  ```

### C. Invoicing Status
- **Rule:** Check `INVOICED_FLAG` to determine billing status.
- **Values:**
  - `'F'` - Fully Invoiced
  - `'P'` - Partially Invoiced
  - `'U'` - Uninvoiced
- **Display Logic:**
  ```sql
  CASE WHEN INVOICED_FLAG = 'U' THEN 'Uninvoiced'
       WHEN INVOICED_FLAG = 'F' THEN 'Fully Invoiced'
       WHEN INVOICED_FLAG = 'P' THEN 'Partially Invoiced'
       ELSE INVOICED_FLAG END
  ```
- **Lookup Type:** `'PJB_EVT_INVOICED_FLAG'` for meanings

### D. Overhead Allocation Exclusion
- **CRITICAL:** Special expenditure type for overhead
- **Expenditure Type ID:** `300000126235407` (Overhead Allocation)
- **Rule:** Exclude this type when calculating raw cost
- **Pattern:**
  ```sql
  WHERE EXPENDITURE_TYPE_ID <> 300000126235407  -- Exclude Overhead
  ```
- **Two CTE Approach:**
  - CTE 1: Costs WITHOUT overhead allocation
  - CTE 2: Costs WITH ONLY overhead allocation
  - Separate reporting for raw cost vs. burden

### E. Cost Distribution to GL
- **Rule:** Costs flow to GL through `PJC_COST_DIST_LINES_ALL`
- **GL Date:** Use `PRVDR_GL_DATE` for period filtering
- **GL Period:** Use `PRVDR_GL_PERIOD_NAME`
- **Currencies:**
  - `DENOM_CURRENCY_CODE` - Transaction currency
  - `DENOM_RAW_COST` - Cost in transaction currency
  - `ACCT_RAW_COST` - Cost in accounting (entity) currency
  - `PROJFUNC_RAW_COST` - Cost in project functional currency
  - `PROJFUNC_BURDENED_COST` - Burdened cost in project functional currency

### F. Date Filtering
- **Transaction Date:** `EXPENDITURE_ITEM_DATE` from `PJC_EXP_ITEMS_ALL`
- **GL Date:** `PRVDR_GL_DATE` from `PJC_COST_DIST_LINES_ALL`
- **Standard Pattern:** `TRUNC(PRVDR_GL_DATE) <= LAST_DAY(:P_REPORT_PERIOD)`
- **Period Calculations:**
  - **ITD (Inception-to-Date):** `<= LAST_DAY(:P_REPORT_PERIOD)`
  - **YTD (Year-to-Date):** `BETWEEN TRUNC(:P_REPORT_PERIOD,'YEAR') AND LAST_DAY(:P_REPORT_PERIOD)`
  - **PTD (Period-to-Date):** `BETWEEN TRUNC(:P_REPORT_PERIOD,'MM') AND LAST_DAY(:P_REPORT_PERIOD)`

### G. Cost Calculation Logic
- **Raw Cost:** Sum of `PROJFUNC_RAW_COST` (excluding overhead type)
- **Burden/Overhead Cost:** Sum of burdened cost for overhead type OR (Burdened - Raw)
- **Total Burdened Cost:** Sum of `PROJFUNC_BURDENED_COST` (all types)
- **Formula:** `TOTAL_BURDENED_COST = RAW_COST + BURDEN_COST`

### H. Integration with Expenditure Items
- **Join Pattern:**
  ```sql
  PJC_COST_DIST_LINES_ALL.EXPENDITURE_ITEM_ID = PJC_EXP_ITEMS_ALL.EXPENDITURE_ITEM_ID
  AND PJC_COST_DIST_LINES_ALL.PROJECT_ID = PJC_EXP_ITEMS_ALL.PROJECT_ID
  AND PJC_COST_DIST_LINES_ALL.TASK_ID = PJC_EXP_ITEMS_ALL.TASK_ID
  ```
- **EXISTS Check:** Use for overhead filtering

### I. Category Mapping
- **Pattern:** Map expenditure categories to reporting categories
- **Mappings:**
  ```sql
  DECODE(PECV.DESCRIPTION,
         'Direct Labor', 'Staff Cost',
         'Other Expenses', 'Expenses',
         'Subcontractors', 'Expenses',
         'Overhead Allocation', 'Burden',
         'Software', 'Expenses',
         'Construction', 'Expenses')
  ```

### J. Cost Breakdown by Category
- **Pattern:** Separate CTEs for each category
- **Use CASE Statements:**
  ```sql
  SUM(CASE WHEN CATEGORY_TYPE = 'Staff Cost' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_STAFF
  SUM(CASE WHEN CATEGORY_TYPE = 'Burden' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_BURDEN
  SUM(CASE WHEN CATEGORY_TYPE = 'Expenses' THEN PROJFUNC_RAW_COST ELSE 0 END) AS RAW_COST_EXPENSES
  ```

---

## 2. 🗺️ Schema Map

### **Core Costing Tables**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PEIA** | `PJC_EXP_ITEMS_ALL` | Expenditure Items (Transaction) | `EXPENDITURE_ITEM_ID`, `PROJECT_ID`, `TASK_ID`, `EXPENDITURE_TYPE_ID`, `EXPENDITURE_ITEM_DATE`, `QUANTITY`, `PROJFUNC_RAW_COST`, `PROJFUNC_BURDENED_COST`, `BILLABLE_FLAG`, `REVENUE_RECOGNIZED_FLAG`, `INVOICED_FLAG`, `INCURRED_BY_PERSON_ID`, `ORIGINAL_HEADER_ID`, `ORIGINAL_DIST_ID`, `ORIGINAL_LINE_NUMBER` |
| **PCDLA** | `PJC_COST_DIST_LINES_ALL` | Cost Distribution Lines (GL) | `COST_DIST_LINE_ID`, `EXPENDITURE_ITEM_ID`, `PROJECT_ID`, `TASK_ID`, `PRVDR_GL_DATE`, `PRVDR_GL_PERIOD_NAME`, `DENOM_CURRENCY_CODE`, `DENOM_RAW_COST`, `ACCT_RAW_COST`, `PROJFUNC_RAW_COST`, `PROJFUNC_BURDENED_COST`, `QUANTITY` |
| **PEC** | `PJC_EXP_COMMENTS` | Expenditure Comments | `EXPENDITURE_ITEM_ID`, `EXPENDITURE_COMMENT` |

### **Expenditure Types**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PETV** | `PJF_EXP_TYPES_VL` | Expenditure Types (View) | `EXPENDITURE_TYPE_ID`, `EXPENDITURE_TYPE_NAME`, `UNIT_OF_MEASURE`, `EXPENDITURE_CATEGORY_ID`, `REVENUE_CATEGORY_CODE`, `START_DATE_ACTIVE`, `END_DATE_ACTIVE` |
| **PETB** | `PJF_EXP_TYPES_B_V` | Expenditure Types (Base View) | Same as VL |
| **PETT** | `PJF_EXP_TYPES_TL` | Expenditure Types (Translatable) | `EXPENDITURE_TYPE_ID`, `EXPENDITURE_TYPE_NAME`, `LANGUAGE` |
| **PECV** | `PJF_EXP_CATEGORIES_VL` | Expenditure Categories | `EXPENDITURE_CATEGORY_ID`, `DESCRIPTION` |

**Revenue Category Lookup:**
- Lookup Type: `'PJF_REVENUE_CATEGORY'`
- Join: `FND_LOOKUPS.LOOKUP_CODE = PJF_EXP_TYPES_B_V.REVENUE_CATEGORY_CODE`

### **AP Integration (Supplier Invoices)**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **AIA** | `AP_INVOICES_ALL` | AP Invoice Headers | `INVOICE_ID`, `INVOICE_NUM`, `VENDOR_ID`, `ORG_ID`, `PO_HEADER_ID`, `CANCELLED_DATE`, `PAYMENT_STATUS_FLAG` |
| **AILA** | `AP_INVOICE_LINES_ALL` | AP Invoice Lines | `INVOICE_ID`, `LINE_NUMBER`, `INVOICE_LINE_NUMBER`, `RCV_TRANSACTION_ID`, `PO_LINE_ID`, `PO_DISTRIBUTION_ID`, `QUANTITY_INVOICED` |
| **AIDA** | `AP_INVOICE_DISTRIBUTIONS_ALL` | AP Invoice Distributions | `INVOICE_ID`, `INVOICE_LINE_NUMBER`, `INVOICE_DISTRIBUTION_ID`, `DISTRIBUTION_LINE_NUMBER`, `PJC_PROJECT_ID`, `PO_DISTRIBUTION_ID` |
| **APSA** | `AP_PAYMENT_SCHEDULES_ALL` | AP Payment Schedules | `INVOICE_ID`, `AMOUNT_REMAINING`, `PAYMENT_STATUS_FLAG` |

**AP to Project Link:**
```sql
PJC_EXP_ITEMS_ALL.ORIGINAL_HEADER_ID = AP_INVOICES_ALL.INVOICE_ID
AND PJC_EXP_ITEMS_ALL.ORIGINAL_DIST_ID = AP_INVOICE_DISTRIBUTIONS_ALL.INVOICE_DISTRIBUTION_ID
AND PJC_EXP_ITEMS_ALL.ORIGINAL_LINE_NUMBER = AP_INVOICE_DISTRIBUTIONS_ALL.DISTRIBUTION_LINE_NUMBER
```

### **PO Integration**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PHA** | `PO_HEADERS_ALL` | PO Headers | `PO_HEADER_ID`, `SEGMENT1` (PO Number), `VENDOR_ID`, `AGENT_ID`, `PRC_BU_ID`, `DOCUMENT_STATUS`, `CANCEL_FLAG` |
| **PLA** | `PO_LINES_ALL` | PO Lines | `PO_LINE_ID`, `PO_HEADER_ID`, `LINE_NUM`, `ITEM_DESCRIPTION`, `QUANTITY`, `UNIT_PRICE`, `AMOUNT`, `UOM_CODE`, `CANCEL_FLAG`, `CANCEL_DATE` |
| **PDA** | `PO_DISTRIBUTIONS_ALL` | PO Distributions | `PO_DISTRIBUTION_ID`, `PO_HEADER_ID`, `PO_LINE_ID`, `PJC_PROJECT_ID`, `PJC_TASK_ID`, `PJC_EXPENDITURE_TYPE_ID`, `PJC_EXPENDITURE_ITEM_DATE`, `PJC_ORGANIZATION_ID`, `CODE_COMBINATION_ID`, `GL_CANCELLED_DATE` |

**PO to Project Link:**
```sql
PJC_EXP_ITEMS_ALL.PARENT_DIST_ID = PO_DISTRIBUTIONS_ALL.PO_DISTRIBUTION_ID
```

### **Receiving Integration**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **RSH** | `RCV_SHIPMENT_HEADERS` | Receipt Headers | `SHIPMENT_HEADER_ID`, `RECEIPT_NUM`, `PACKING_SLIP`, `VENDOR_ID` |
| **RSL** | `RCV_SHIPMENT_LINES` | Receipt Lines | `SHIPMENT_LINE_ID`, `SHIPMENT_HEADER_ID`, `PO_HEADER_ID`, `PO_LINE_ID`, `QUANTITY_RECEIVED`, `EMPLOYEE_ID` |
| **RCT** | `RCV_TRANSACTIONS` | Receiving Transactions | `TRANSACTION_ID`, `SHIPMENT_HEADER_ID`, `SHIPMENT_LINE_ID`, `PO_HEADER_ID`, `PO_LINE_ID`, `TRANSACTION_TYPE`, `TRANSACTION_DATE`, `PARENT_TRANSACTION_ID` |

**Transaction Types:**
- `'RECEIVE'` - Physical receipt
- `'DELIVER'` - Delivery to inventory/project

**Receipt to Project Link:**
```sql
AP_INVOICE_LINES_ALL.RCV_TRANSACTION_ID = RCV_TRANSACTIONS.PARENT_TRANSACTION_ID
AND RCV_TRANSACTIONS.TRANSACTION_ID = PJC_EXP_ITEMS_ALL.ORIGINAL_HEADER_ID
```

### **Person/Employee (for Incurred By)**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PAPF** | `PER_ALL_PEOPLE_F` | People | `PERSON_ID`, `PERSON_NUMBER`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **PPN** | `PER_PERSON_NAMES_F` | Person Names | `PERSON_ID`, `DISPLAY_NAME`, `FULL_NAME`, `NAME_TYPE`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |

**Incurred By Pattern:**
```sql
WHERE EXPENDITURE_ITEM.INCURRED_BY_PERSON_ID = PERSON.PERSON_ID
  AND NAME_TYPE = 'GLOBAL'
  AND ROWNUM = 1
  AND TRUNC(EXP.EXPENDITURE_ITEM_DATE) BETWEEN TRUNC(PERSON.EFFECTIVE_START_DATE)
                                            AND NVL(TRUNC(PERSON.EFFECTIVE_END_DATE), TRUNC(SYSDATE))
```

### **Supplier Information**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PS** | `POZ_SUPPLIERS_V` | Suppliers | `VENDOR_ID`, `VENDOR_NAME` |

**Supplier Lookup from Expenditure:**
```sql
SELECT MAX(PS.VENDOR_NAME)
FROM   POZ_SUPPLIERS_V PS, AP_INVOICES_ALL AIA, AP_INVOICE_DISTRIBUTIONS_ALL AIDA
WHERE  PS.VENDOR_ID = AIA.VENDOR_ID
  AND  AIA.ORG_ID = EXP.ORG_ID
  AND  AIA.INVOICE_ID = AIDA.INVOICE_ID
  AND  AIDA.INVOICE_DISTRIBUTION_ID = EXP.ORIGINAL_DIST_ID
```

### **GL Code Combinations**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **GCC** | `GL_CODE_COMBINATIONS` | Chart of Accounts | `CODE_COMBINATION_ID`, `SEGMENT1-8` (Accounting flexfield) |

**Account String Formatting:**
```sql
GCC.SEGMENT1 || '-' || GCC.SEGMENT2 || '-' || GCC.SEGMENT3 || '-' ||
GCC.SEGMENT4 || '-' || GCC.SEGMENT5 || '-' || GCC.SEGMENT6 || '-' ||
GCC.SEGMENT7 || '-' || GCC.SEGMENT8
```

---

## 3. 📊 Critical Patterns & Business Rules

### **A. Actual Cost Calculation Pattern (Cumulative):**
```sql
-- Base CTE for all costs
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

-- Cumulative Actual (excluding overhead)
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

### **B. YTD and PTD Cost Calculation:**
```sql
-- Year-to-Date Actuals
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

-- Period-to-Date Actuals
PRJ_ACTUAL_MONTH AS (
    SELECT PROJECT_ID
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

### **C. Cost WITHOUT Overhead Allocation:**
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

### **D. Cost WITH ONLY Overhead Allocation:**
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

### **E. Quantity (Hours Only):**
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

### **F. Cost Breakdown by Category:**
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
      AND  TRUNC(PCDLA.PRVDR_GL_DATE)        <= LAST_DAY(:P_REPORT_PERIOD)
)

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

### **G. AP Outstanding Balance:**
```sql
-- AP invoices not yet paid
SELECT SUM(APSA.AMOUNT_REMAINING) AS AP_REM_AMOUNT
FROM   PJC_EXP_ITEMS_ALL PEIA
      ,AP_INVOICE_DISTRIBUTIONS_ALL AIDA
      ,(SELECT AIA.INVOICE_ID, APSA.AMOUNT_REMAINING
        FROM   AP_INVOICES_ALL AIA, AP_PAYMENT_SCHEDULES_ALL APSA
        WHERE  AIA.INVOICE_ID = APSA.INVOICE_ID
          AND  AIA.CANCELLED_DATE IS NULL
          AND  AIA.PAYMENT_STATUS_FLAG IN ('N', 'P')  -- Not Paid, Partially Paid
       ) APSA
WHERE  PEIA.ORIGINAL_HEADER_ID               = AIDA.INVOICE_ID
  AND  PEIA.PROJECT_ID                       = AIDA.PJC_PROJECT_ID
  AND  PEIA.ORIGINAL_DIST_ID                 = AIDA.INVOICE_DISTRIBUTION_ID
  AND  PEIA.ORIGINAL_LINE_NUMBER             = AIDA.DISTRIBUTION_LINE_NUMBER
  AND  AIDA.INVOICE_ID                       = APSA.INVOICE_ID
  AND  PEIA.PROJECT_ID                       = :P_PROJECT_ID
```

---

## 4. 🔗 Cross-Module Integration

### **Integration with AP (Supplier Invoices):**
- Link: `PJC_EXP_ITEMS_ALL` → `AP_INVOICE_DISTRIBUTIONS_ALL` → `AP_INVOICES_ALL`
- Key Fields: `ORIGINAL_HEADER_ID`, `ORIGINAL_DIST_ID`, `ORIGINAL_LINE_NUMBER`

### **Integration with PO (Purchase Orders):**
- Link: `PJC_EXP_ITEMS_ALL` → `PO_DISTRIBUTIONS_ALL`
- Key Field: `PARENT_DIST_ID`

### **Integration with Receiving:**
- Link: `AP_INVOICE_LINES_ALL` → `RCV_TRANSACTIONS` → `PJC_EXP_ITEMS_ALL`
- Key Field: `RCV_TRANSACTION_ID`

### **Integration with Projects:**
- All cost tables include: `PROJECT_ID`, `TASK_ID`
- Link to: `PJF_PROJECTS_ALL_B`, `PJF_TASKS_V`

### **Integration with Revenue:**
- Cost transactions drive revenue: `PJC_EXP_ITEMS_ALL.EXPENDITURE_ITEM_ID` → `PJB_REV_DISTRIBUTIONS.TRANSACTION_ID`
- Billing: `PJC_EXP_ITEMS_ALL.EXPENDITURE_ITEM_ID` → `PJB_BILL_TRXS.TRANSACTION_ID`

---

## 5. ⚡ Performance Optimization

### **Recommended Hints:**
```sql
/*+ qb_name(CTE_NAME) PARALLEL(PJC_COST_DIST_LINES_ALL,4) */
/*+ qb_name(CTE_NAME) PARALLEL(PJC_EXP_ITEMS_ALL,4) */
```

### **Large Tables (Use Parallelism):**
- `PJC_COST_DIST_LINES_ALL` → PARALLEL(4)
- `PJC_EXP_ITEMS_ALL` → PARALLEL(2-4)
- `AP_INVOICE_DISTRIBUTIONS_ALL` → PARALLEL(2-4)

### **Use EXISTS for Filtering:**
- More efficient than joins when only checking existence
- Use for overhead allocation filtering

---

## 6. 🚨 Common Pitfalls

### **❌ AVOID:**
1. **Including Overhead in Raw Cost** - Always exclude `EXPENDITURE_TYPE_ID = 300000126235407`
2. **Using Wrong Date** - Use `PRVDR_GL_DATE` for period filtering, not `EXPENDITURE_ITEM_DATE`
3. **Missing Multi-Tenant Filter** - Always include `ORG_ID` filtering
4. **Ignoring Cancelled Costs** - Filter `GL_CANCELLED_DATE IS NULL` for PO distributions
5. **Wrong Currency** - Use `PROJFUNC_RAW_COST` for project functional currency
6. **Missing EXISTS Check** - Use EXISTS for overhead filtering instead of joins

### **✅ ALWAYS:**
1. Use Oracle Traditional Join Syntax
2. Add `/*+ qb_name() */` to all CTEs
3. Separate CTEs for costs with/without overhead
4. Include ORG_ID filtering
5. Use `LAST_DAY(:P_REPORT_PERIOD)` for period cut-off
6. Round amounts to 2 decimal places
7. Use `NVL()` for NULL handling in calculations
8. Filter cancelled PO distributions

---

**END OF COSTING_MASTER.md**
