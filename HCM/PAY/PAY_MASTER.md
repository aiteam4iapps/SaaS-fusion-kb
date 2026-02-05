# Payroll Master Instructions

**Module:** Global Payroll  
**Tag:** `#HCM #PAY #Payroll`  
**Status:** Production-Ready  
**Last Updated:** 13-Jan-2026  
**Version:** 2.0 (Merged with update file)

---

## 1. 🚨 Critical Payroll Constraints

*Violating these rules breaks payroll calculations.*

### 1.1 Action Type Filtering
**Rule:** Always filter by `ACTION_TYPE` to get correct payroll results

```sql
AND PPA.ACTION_TYPE IN ('Q', 'R')  -- QuickPay or Run
-- OR specific type:
AND PPA.ACTION_TYPE = 'R'  -- Regular Run only
```

**Action Types:**
- `'R'` - Regular Payroll Run
- `'Q'` - QuickPay (off-cycle)
- `'V'` - Void
- `'P'` - Prepayment

**Why:** Without this filter, you get ALL actions including voids, prepayments, reversals.

### 1.2 Action Status Filtering
**Rule:** Only include COMPLETED payroll actions

```sql
AND PPA.ACTION_STATUS IN ('C')  -- Completed only
```

**Why:** Prevents including in-progress or failed runs.

### 1.3 Retro Component Exclusion
**Rule:** Exclude retroactive adjustments unless specifically needed

```sql
AND PPRA.RETRO_COMPONENT_ID IS NULL
```

**Why:** Retro entries duplicate amounts and create incorrect totals.

### 1.4 Time Period Context
**Rule:** Always join to `PAY_TIME_PERIODS` for date context

```sql
AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
```

**Why:** Payroll results exist within specific processing windows.

### 1.5 Element Classification
**Rule:** Filter by `CLASSIFICATION_NAME` to separate earnings, deductions, information

```sql
AND PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
AND PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings')
-- OR
AND PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions')
-- OR
AND PEC.BASE_CLASSIFICATION_NAME IN ('Information')
```

**Classifications:**
- `'Standard Earnings'` - Salary, allowances, bonuses
- `'Voluntary Deductions'` - Deductions that reduce net pay
- `'Social Insurance Deductions'` - Social security, insurance
- `'Involuntary Deductions'` - Court orders, garnishments
- `'Information'` - Informational elements (no payment impact)

**Why:** Without this, you mix earnings and deductions incorrectly.

### 1.6 Input Value Selection
**Rule:** Use `BASE_NAME = 'Pay Value'` for monetary amounts

```sql
AND PIVF.BASE_NAME = 'Pay Value'
-- OR
AND UPPER(TRIM(PIVF.BASE_NAME)) = 'PAY VALUE'
```

**Common Input Values:**
- `'Pay Value'` - The monetary result
- `'Amount'` - Entry amount (for element entries)
- `'Rate'` - Rate value
- `'Hours'` - Hour value
- `'Percentage'` - Percentage value

---

## 2. ⚡ Performance Optimization

| Object | Optimal Access Path | Hint Syntax |
|--------|---------------------|-------------|
| **Payroll Action** | PAYROLL_ACTION_ID | `/*+ INDEX(PPA PAY_PAYROLL_ACTIONS_PK) */` |
| **Run Results** | ASSIGNMENT_ACTION_ID | `/*+ INDEX(PRR PAY_RUN_RESULTS_N1) */` |
| **Element Entry** | ASSIGNMENT_ID | `/*+ INDEX(PEE PAY_ELEMENT_ENTRIES_F_N50) */` |
| **Element Type** | ELEMENT_TYPE_ID | `/*+ INDEX(PETF PAY_ELEMENT_TYPES_F_PK) */` |

---

## 3. 🗺️ Schema Map

### 3.1 Payroll Run Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PPA** | `PAY_PAYROLL_ACTIONS` | Payroll Run Header (Batch, Date, Status) |
| **PAA** | `PAY_ASSIGNMENT_ACTIONS` | Assignment-level Actions |
| **PPRA** | `PAY_PAYROLL_REL_ACTIONS` | Payroll Relationship Actions |
| **PRR** | `PAY_RUN_RESULTS` | Run Results Header |
| **PRRV** | `PAY_RUN_RESULT_VALUES` | Individual Result Values ($$) |
| **PPRD** | `PAY_PAY_RELATIONSHIPS_DN` | Pay Relationships |
| **PAC** | `PAY_ACTION_CLASSES` | Action Classifications |

### 3.2 Element Definition Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PETF** | `PAY_ELEMENT_TYPES_F` | Element Type Definitions (Date-Tracked) |
| **PETT** | `PAY_ELEMENT_TYPES_TL` | Element Type Translations |
| **PETV** | `PAY_ELEMENT_TYPES_VL` | Element Types View |
| **PIVF** | `PAY_INPUT_VALUES_F` | Input Value Definitions (Date-Tracked) |
| **PIVT** | `PAY_INPUT_VALUES_TL` | Input Value Translations |
| **PIVL** | `PAY_INPUT_VALUES_VL` | Input Values View |
| **PEC** | `PAY_ELE_CLASSIFICATIONS` | Element Classifications |
| **PECT** | `PAY_ELE_CLASSIFICATIONS_TL` | Element Classification Translations |

### 3.3 Element Entry Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PEEF** | `PAY_ELEMENT_ENTRIES_F` | Element Entries (Ongoing Assignments) |
| **PEEV** | `PAY_ELEMENT_ENTRIES_VL` | Element Entries View |
| **PEEVF** | `PAY_ELEMENT_ENTRY_VALUES_F` | Entry Values (Date-Tracked) |

### 3.4 Time Period Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PTP** | `PAY_TIME_PERIODS` | Payroll Time Periods |
| **PAP** / **PAPP** | `PAY_ALL_PAYROLLS_F` | Payroll Definitions |

### 3.5 Payment & Bank Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PPA** | `PAY_PAYROLL_ASSIGNMENTS` | Payroll Assignments |
| **PPPMF** | `PAY_PERSONAL_PAYMENT_METHODS_F` | Personal Payment Methods |
| **PBA** | `PAY_BANK_ACCOUNTS` | Bank Account Details |
| **POPM** | `PAY_ORG_PAY_METHODS_VL` | Organization Payment Methods |
| **PPT** | `PAY_PAYMENT_TYPES_VL` | Payment Types |
| **PCPV** | `PAY_CARD_PAYSLIPS_V` | Card Payslips View |

### 3.6 Payroll Relationship Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PPE** / **PPRD** | `PAY_PAY_RELATIONSHIPS_DN` | Pay Relationships |
| **PRG** | `PAY_REL_GROUPS_DN` | Relationship Groups |
| **PAPD** / **AP** | `PAY_ASSIGNED_PAYROLLS_DN` | Assigned Payrolls |
| **PT** | `PAY_PAYROLL_TERMS` | Payroll Terms |

### 3.7 Advanced Payroll Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PCS** | `PAY_CONSOLIDATION_SETS` | Consolidation Sets (Grouping) |
| **PRQ** | `PAY_REQUESTS` | Payroll Requests |
| **PFI** | `PAY_FLOW_INSTANCES` | Payroll Flow Instances (Processing Tracking) |
| **PBT** | `PAY_BALANCE_TYPES_VL` | Balance Type Definitions |
| **PDU** | `PAY_DIMENSION_USAGES_VL` | Dimension Usages |
| **LDG** | `PER_LEGISLATIVE_DATA_GROUPS_VL` | Legislative Data Groups |

---

## 4. 📋 Element Patterns

### 4.1 Hardcoded Element Names Pattern

**Use Case:** When you know exact element names

**Pattern:**
```sql
SUM(CASE WHEN PETF.BASE_ELEMENT_NAME = 'OGH Basic Salary' 
         THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) BASIC
,SUM(CASE WHEN PETF.BASE_ELEMENT_NAME = 'OGH Housing Allowance' 
         THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) HOUSING
```

**Common Prefixes:**
- `'OGH'` - Organization-specific elements (e.g., 'OGH Basic Salary')
- Element names vary by implementation

**Hardcoded Elements (Example from Production):**
- Basic: `'OGH Basic Salary'`, `'Basic'`, `'Basic Salary'`
- Housing: `'OGH Housing Allowance'`, `'Housing Allowance'`, `'HRA'`
- Transport: `'OGH Transportation Allowance'`, `'Transport Allowance'`
- Overtime: `'Holidays Overtime'`, `'Normal Overtime'`, `'Weekend Overtime'`
- Deductions: Element names ending with `'Results'` (e.g., `'Housing Deduction Results'`)

### 4.2 Dynamic Element Loading Pattern

**Use Case:** When element names are not known in advance

**Pattern:**
```sql
,PETT.ELEMENT_NAME  -- Use translations, not BASE
,SUM(TO_NUMBER(PRRV.RESULT_VALUE)) VALUE
,CASE
    WHEN PEC.BASE_CLASSIFICATION_NAME = 'Standard Earnings' THEN 1
    WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions', ...) THEN 2
    ELSE 3
END AS CUSTOM_ORDER  -- For sorting
```

**Key Difference:** Use `ELEMENT_NAME` (translated) instead of `BASE_ELEMENT_NAME`

### 4.3 Classification-Based Aggregation

**Pattern:**
```sql
SUM(CASE WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings')
         THEN TO_NUMBER(PRRV.RESULT_VALUE) END) TOTAL_EARNINGS
,SUM(CASE WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions')
         THEN TO_NUMBER(PRRV.RESULT_VALUE) END) TOTAL_DEDUCTIONS
,(SUM(CASE WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings')
           THEN TO_NUMBER(PRRV.RESULT_VALUE) END) -
  SUM(CASE WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions')
           THEN TO_NUMBER(PRRV.RESULT_VALUE) END)) NET_PAY
```

### 4.4 Reporting Name Pattern (for Accruals)

**Use Case:** For accrual calculations

**Pattern:**
```sql
AND PETF.REPORTING_NAME = 'Gratuity Accrual'
AND PIVTFB.NAME = 'Monthly Amount'
-- NOT BASE_ELEMENT_NAME
```

**Common Reporting Names:**
- `'Gratuity Accrual'`
- `'Gratuity Accrual Payment'`
- `'Gratuity Gain'`
- `'Basic Salary'`
- `'Annual Leave Accrual'`

---

## 5. 🔗 Standard Joins (Copy-Paste Ready)

### 5.1 Payroll Run Results Join

**Full chain from Action to Values:**
```sql
FROM PAY_PAYROLL_ACTIONS PPA,
     PAY_PAYROLL_REL_ACTIONS PPRA,
     PAY_RUN_RESULTS PRR,
     PAY_RUN_RESULT_VALUES PRRV,
     PAY_PAY_RELATIONSHIPS_DN PPRD,
     PAY_TIME_PERIODS PTP,
     PAY_ELEMENT_TYPES_F PETF,
     PAY_INPUT_VALUES_F PIVF,
     PAY_ALL_PAYROLLS_F PAP,
     PAY_ELE_CLASSIFICATIONS PEC
WHERE PPRA.PAYROLL_ACTION_ID = PPA.PAYROLL_ACTION_ID
AND PRR.PAYROLL_REL_ACTION_ID = PPRA.PAYROLL_REL_ACTION_ID(+)
AND PRRV.RUN_RESULT_ID = PRR.RUN_RESULT_ID
AND PPRA.PAYROLL_RELATIONSHIP_ID = PPRD.PAYROLL_RELATIONSHIP_ID
AND PPA.ACTION_TYPE IN ('Q', 'R')
AND PPA.ACTION_STATUS IN ('C')
AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
AND PETF.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
AND PIVF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
AND PIVF.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
AND PPA.PAYROLL_ID = PAP.PAYROLL_ID
AND PPRA.RETRO_COMPONENT_ID IS NULL
AND PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
AND PIVF.BASE_NAME = 'Pay Value'
```

### 5.2 Element Entry Join

**For ongoing element assignments:**
```sql
FROM PAY_ELEMENT_ENTRIES_F PEEF,
     PAY_ELEMENT_ENTRY_VALUES_F PEEV,
     PAY_INPUT_VALUES_F PIVF,
     PAY_ELEMENT_TYPES_F PETF,
     PAY_ELE_CLASSIFICATIONS PEC
WHERE PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID(+)
AND PEEF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID(+)
AND PEEV.INPUT_VALUE_ID = PIVF.INPUT_VALUE_ID(+)
AND PEEF.ELEMENT_TYPE_ID = PIVF.ELEMENT_TYPE_ID(+)
AND PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID(+)
AND PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings')
```

### 5.3 Bank Account Join

**Person → Payroll → Payment Method → Bank:**
```sql
FROM PAY_PAYROLL_ASSIGNMENTS PPA,
     PAY_PERSONAL_PAYMENT_METHODS_F PPPMF,
     PAY_BANK_ACCOUNTS PBA,
     PAY_ORG_PAY_METHODS_VL POPM,
     PAY_PAYMENT_TYPES_VL PPT
WHERE PPA.PAYROLL_RELATIONSHIP_ID = PPPMF.PAYROLL_RELATIONSHIP_ID(+)
AND PPPMF.BANK_ACCOUNT_ID = PBA.BANK_ACCOUNT_ID(+)
AND PPPMF.ORG_PAYMENT_METHOD_ID = POPM.ORG_PAYMENT_METHOD_ID(+)
AND POPM.PAYMENT_TYPE_ID = PPT.PAYMENT_TYPE_ID(+)
AND TO_DATE(:P_PERIOD, 'DDMMYYYY') BETWEEN TRUNC(PPPMF.EFFECTIVE_START_DATE) 
    AND TRUNC(PPPMF.EFFECTIVE_END_DATE)
```

**Payment Method Hierarchy:**
```sql
NVL(PPT.BASE_PAYMENT_TYPE_NAME,
    NVL(PPPMF.NAME,
        NVL(POPM.ORG_PAYMENT_METHOD_NAME,
            PPT.PAYMENT_TYPE_NAME))) PAY_METHOD_NAME
```

### 5.4 Payroll Assignment Join

**Person → Payroll Name:**
```sql
FROM PAY_PAY_RELATIONSHIPS_DN PPE,
     PAY_REL_GROUPS_DN PRG,
     PAY_ASSIGNED_PAYROLLS_DN PAPD,
     PAY_ALL_PAYROLLS_F PAP
WHERE PPE.PAYROLL_RELATIONSHIP_ID = PRG.PAYROLL_RELATIONSHIP_ID
AND PRG.RELATIONSHIP_GROUP_ID = PAPD.PAYROLL_TERM_ID
AND PAPD.PAYROLL_ID = PAP.PAYROLL_ID
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAP.EFFECTIVE_START_DATE) 
    AND TRUNC(PAP.EFFECTIVE_END_DATE)
```

### 5.5 Balance Dimensions Join

**Using TABLE function for balances:**
```sql
FROM PAY_PAYROLL_REL_ACTIONS PRA,
     PAY_PAYROLL_ACTIONS PPA,
     PAY_BALANCE_TYPES_VL PBT,
     TABLE(PAY_BALANCE_VIEW_PKG.GET_BALANCE_DIMENSIONS(
         P_BALANCE_TYPE_ID => PBT.BALANCE_TYPE_ID,
         P_PAYROLL_REL_ACTION_ID => PRA.PAYROLL_REL_ACTION_ID,
         P_PAYROLL_TERM_ID => NULL,
         P_PAYROLL_ASSIGNMENT_ID => NULL
     )) BAL,
     PAY_DIMENSION_USAGES_VL PDU
WHERE PPA.PAYROLL_ACTION_ID = PRA.PAYROLL_ACTION_ID
AND PBT.BALANCE_NAME IN ('Air Fare Provision', 'DYR_Gratuity_Provision')
AND PDU.DIMENSION_NAME = 'Assignment Inception to Date'
AND PDU.BALANCE_DIMENSION_ID = BAL.BALANCE_DIMENSION_ID
AND BAL.BALANCE_VALUE != '0'
```

### 5.6 Flow Instance Join (Dynamic Payroll)

**For payroll processing tracking:**
```sql
FROM PAY_PAYROLL_ACTIONS PPA,
     PAY_REQUESTS PRQ,
     PAY_FLOW_INSTANCES PFI,
     PAY_CONSOLIDATION_SETS PCS
WHERE PPA.PAY_REQUEST_ID = PRQ.PAY_REQUEST_ID
AND PRQ.FLOW_INSTANCE_ID = PFI.FLOW_INSTANCE_ID
AND PPA.CONSOLIDATION_SET_ID = PCS.CONSOLIDATION_SET_ID
AND PFI.INSTANCE_NAME = NVL(:P_FLOW_NAME, PFI.INSTANCE_NAME)
AND PCS.CONSOLIDATION_SET_NAME = NVL(:P_CONSOLIDATE_SET, PCS.CONSOLIDATION_SET_NAME)
```

---

## 6. 📊 Standard Filters

### 6.1 Period Filtering

**Last Day of Month Pattern:**
```sql
AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) = 
    NVL(TO_DATE(:P_PERIOD, 'DDMMYYYY'), TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)))
```

**Date Range Pattern:**
```sql
AND PPA.DATE_EARNED BETWEEN :P_START_DATE AND :P_END_DATE
```

**Effective Date with Element Types:**
```sql
AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) BETWEEN TRUNC(PETF.EFFECTIVE_START_DATE) 
    AND TRUNC(PETF.EFFECTIVE_END_DATE)
AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) BETWEEN TRUNC(PIVF.EFFECTIVE_START_DATE) 
    AND TRUNC(PIVF.EFFECTIVE_END_DATE)
```

### 6.2 Element Name Filters

**For Earnings (Exclude Results):**
```sql
AND PETF.BASE_ELEMENT_NAME NOT LIKE '%Results'
```

**For Deductions (Include Results):**
```sql
AND PETF.BASE_ELEMENT_NAME LIKE '%Results'
```

### 6.3 Processing Type Filter

**For Element Entries:**
```sql
AND PETF.PROCESSING_TYPE = 'R'  -- Recurring
```

**Processing Types:**
- `'R'` - Recurring (ongoing)
- `'N'` - Nonrecurring (one-time)

### 6.4 Termination Date Handling

**For Element Entries with Terminated Employees:**
```sql
AND LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TRUNC(:P_DATE)), TRUNC(:P_DATE)) 
    BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) 
    AND TRUNC(PEEF.EFFECTIVE_END_DATE)
```

### 6.5 Legislative Data Group Filter

**For Multi-Legislation Environments:**
```sql
AND NVL(PBT.LEGISLATION_CODE, LDG.LEGISLATION_CODE) = LDG.LEGISLATION_CODE
AND NVL(PBT.LEGISLATIVE_DATA_GROUP_ID, LDG.LEGISLATIVE_DATA_GROUP_ID) = 
    LDG.LEGISLATIVE_DATA_GROUP_ID
```

---

## 7. ⚠️ Common Pitfalls

### 7.1 Including Voided Runs
**Problem:** Totals are incorrect  
**Cause:** Not filtering `ACTION_STATUS`

**Solution:**
```sql
AND PPA.ACTION_STATUS IN ('C')  -- Completed only
```

### 7.2 Including Retro Adjustments
**Problem:** Duplicate amounts  
**Cause:** Not excluding `RETRO_COMPONENT_ID`

**Solution:**
```sql
AND PPRA.RETRO_COMPONENT_ID IS NULL
```

### 7.3 Missing Time Period Context
**Problem:** Results span multiple periods  
**Cause:** Not filtering by period

**Solution:**
```sql
AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) = :P_PERIOD_END
```

### 7.4 Wrong Input Value
**Problem:** Getting non-monetary values  
**Cause:** Not specifying `BASE_NAME`

**Solution:**
```sql
AND PIVF.BASE_NAME = 'Pay Value'  -- For run results
-- OR
AND PIVF.NAME = 'Amount'  -- For element entries
```

### 7.5 Mixing Element Entry and Run Results
**Problem:** Seeing unexpected values  
**Cause:** Element entries show setup, run results show calculations

**Solution:**
- Use **Element Entries** (`PAY_ELEMENT_ENTRIES_F`) for current assignments/setup
- Use **Run Results** (`PAY_RUN_RESULTS`) for actual payroll calculations

### 7.6 Using BASE_ELEMENT_NAME for Accruals
**Problem:** Accrual elements not found  
**Cause:** Accruals use `REPORTING_NAME`, not `BASE_ELEMENT_NAME`

**Solution:**
```sql
AND PETF.REPORTING_NAME = 'Gratuity Accrual'  -- Not BASE_ELEMENT_NAME
```

### 7.7 Handling Optional/Custom Payroll Tables

**Problem:** Query fails when custom accrual/element tables don't exist  
**Cause:** Hardcoded joins to client-specific tables

**Solution:** Use outer joins and document

**Pattern:**
```sql
-- Define optional CTE
PAY_CUSTOM_ACCRUALS AS (
    SELECT
        PERSON_ID,
        CUSTOM_ACCRUAL_AMOUNT
    FROM CLIENT_CUSTOM_ACCRUALS  -- May not exist
    WHERE ACTIVE_FLAG = 'Y'
)

-- Use outer join
FROM
    PAY_RESULTS_MASTER PRM,
    PAY_CUSTOM_ACCRUALS PCA
WHERE
    PRM.PERSON_ID = PCA.PERSON_ID(+)

-- Handle NULL
SELECT
    PRM.PERSON_NUMBER,
    NVL(PCA.CUSTOM_ACCRUAL_AMOUNT, 0) AS CUSTOM_ACCRUAL
FROM ...
```

**Documentation Template:**
```sql
/*
 * OPTIONAL PAYROLL TABLES
 * ========================
 * The following CTEs use custom/optional tables:
 *
 * 1. PAY_CUSTOM_ACCRUALS (lines 45-60)
 *    Table: CLIENT_CUSTOM_ACCRUALS
 *    If missing: Comment out CTE, fields will show as 0
 *
 * 2. PAY_CLIENT_ELEMENTS (lines 75-90)
 *    Table: CLIENT_ELEMENT_DEFINITIONS
 *    If missing: Comment out CTE, fields will show as NULL
 */
```

---

## 8. 💡 Calculation Patterns

### 8.1 Net Pay Calculation

```sql
(SUM(CASE WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings')
          THEN TO_NUMBER(PRRV.RESULT_VALUE) END) -
 SUM(CASE WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions')
          THEN TO_NUMBER(PRRV.RESULT_VALUE) END)) NET_PAY
```

### 8.2 Gross Salary (from Element Entries)

```sql
(NVL(BASIC, 0) + 
 NVL(HOUSING, 0) + 
 NVL(TRANSPORT, 0) +
 ... all allowances ...) GROSS_SALARY
```

### 8.3 Monthly Basic from Annual

```sql
ROUND(PEEV.SCREEN_ENTRY_VALUE / 12, 2) MONTHLY_BASIC
```

---

## 9. 📅 Parameters

| Parameter | Format | Description | Example | Enhanced Pattern |
|-----------|--------|-------------|---------|------------------|
| `:P_PERIOD` | DDMMYYYY | Period end date | 31122024 | - |
| `:P_PERIOD_NAME` | DD-MM-YYYY | Period name | 31-12-2024 | - |
| `:P_PAYROLL` | Numeric | Payroll ID | 300000123456 | - |
| `:P_PAYROLLNAME` | String | Payroll name | 'UAE Monthly' | - |
| `:P_FLOW_NAME` | String | Flow instance | 'Monthly Payroll Dec 2024' | - |
| `:P_CONSOLIDATE_SET` | String | Consolidation set | 'Standard' | - |
| `:P_START_DATE` | Date | Start date | TO_DATE('01-12-2024','DD-MM-YYYY') | - |
| `:P_END_DATE` | Date | End date | TO_DATE('31-12-2024','DD-MM-YYYY') | - |
| `:P_DATE` | Date | Effective date | TRUNC(SYSDATE) | - |
| `:P_ELEMENT_NAME` | String | Element name filter | 'Basic Salary' | `UPPER(NVL(:P_ELEMENT_NAME, 'ALL'))` |
| `:P_PAYROLL_NAME` | String | Payroll name filter | 'UAE Monthly' | `UPPER(NVL(:P_PAYROLL_NAME, 'ALL'))` |
| `:P_CLASSIFICATION` | String | Classification filter | 'Standard Earnings' | `UPPER(NVL(:P_CLASSIFICATION, 'ALL'))` |

### 9.1 Case-Insensitive Parameter Filtering

**Usage Pattern:**
```sql
WITH PARAMETERS AS (
    SELECT
        UPPER(NVL(:P_ELEMENT_NAME, 'ALL')) AS ELEMENT_NAME,
        UPPER(NVL(:P_PAYROLL_NAME, 'ALL')) AS PAYROLL_NAME
    FROM DUAL
)

-- In WHERE clause
AND (UPPER(PETF.BASE_ELEMENT_NAME) = P.ELEMENT_NAME OR P.ELEMENT_NAME = 'ALL')
AND (UPPER(PAP.PAYROLL_NAME) = P.PAYROLL_NAME OR P.PAYROLL_NAME = 'ALL')
```

**Benefit:** Users can enter "basic salary", "Basic Salary", or "BASIC SALARY" - all work.

---

## 10. 🔍 Advanced Patterns

### 10.1 Scalar Subquery for Single Element

**For Basic Salary:**
```sql
(SELECT ROUND(PEEV.SCREEN_ENTRY_VALUE / 12, 2)
 FROM PAY_ELEMENT_TYPES_VL PETV,
      PAY_ELEMENT_ENTRIES_F PEEF,
      PAY_ELEMENT_ENTRY_VALUES_F PEEV,
      PAY_INPUT_VALUES_VL PIVL
 WHERE PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
 AND PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
 AND PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
 AND PETV.BASE_ELEMENT_NAME = 'Basic'
 AND UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
 AND PEEF.PERSON_ID = PAPF.PERSON_ID
 AND :P_DATE BETWEEN PEEF.EFFECTIVE_START_DATE AND PEEF.EFFECTIVE_END_DATE
 AND ROWNUM = 1) BASIC_SALARY
```

### 10.2 Cost Center Decode (Client-Specific)

**Hardcoded cost center mapping:**
```sql
DECODE(DEPARTMENT_NAME,
    'Business Support', '502',
    'CEO Off', '510',
    'Human Resources', '512',
    'Finance', '501',
    'IT', '508',
    ...) COST_CENTER
```

### 10.3 Component Breakdown for Transparency

**Use Case:** Show how gross/net is calculated

**Pattern:**
```sql
SELECT
    PERSON_NUMBER,
    FULL_NAME,
    -- Component breakdown
    NVL(BASIC_SALARY, 0) AS BASIC,
    NVL(HOUSING, 0) AS HOUSING,
    NVL(TRANSPORT, 0) AS TRANSPORT,
    NVL(OTHER_ALLOWANCES, 0) AS OTHER,
    -- Calculated gross (shows formula)
    (NVL(BASIC_SALARY, 0) + NVL(HOUSING, 0) + 
     NVL(TRANSPORT, 0) + NVL(OTHER_ALLOWANCES, 0)) AS CALC_GROSS,
    -- Deductions
    NVL(TOTAL_DEDUCTIONS, 0) AS DEDUCTIONS,
    -- Calculated net (shows formula)
    ((NVL(BASIC_SALARY, 0) + NVL(HOUSING, 0) + 
      NVL(TRANSPORT, 0) + NVL(OTHER_ALLOWANCES, 0)) - 
     NVL(TOTAL_DEDUCTIONS, 0)) AS CALC_NET_PAY
FROM PAY_RESULTS;
```

**Benefits:**
- Users can verify calculations
- Transparent breakdown
- Easier troubleshooting
- Builds trust in payroll data

**When to Use:**
- Payslips
- Salary statements
- Earning/deduction registers
- Reconciliation reports

---

## 11. 🚀 Advanced Payroll Patterns (07-Jan-2026)

### 11.1 Dynamic Payroll Report (Element-Agnostic)

**Problem:** Create flexible payroll reports that work with any element configuration

**Solution:**

```sql
WITH PER_RES AS (
    SELECT
        PPRD.PERSON_ID,
        PTP.PERIOD_NAME,
        TO_CHAR(PTP.START_DATE, 'YYYY') YEAR,
        DECODE(PTP.PERIOD_NUM,
            '1', 'January', '2', 'February', '3', 'March', '4', 'April',
            '5', 'May', '6', 'June', '7', 'July', '8', 'August',
            '9', 'September', '10', 'October', '11', 'November', '12', 'December'
        ) MONTH,
        PPA.DATE_EARNED,
        PPA.EFFECTIVE_DATE,
        PAP.PAYROLL_NAME,
        PPA.PAYROLL_ID,
        PCS.CONSOLIDATION_SET_NAME,
        PCS.CONSOLIDATION_SET_ID,
        PETT.ELEMENT_NAME,
        
        -- Aggregate by classification
        SUM(CASE 
            WHEN PEC.BASE_CLASSIFICATION_NAME = 'Standard Earnings'
            THEN TO_NUMBER(PRRV.RESULT_VALUE)
            ELSE 0
        END) TOTAL_EARNINGS,
        
        SUM(CASE 
            WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions', 
                                                  'Social Insurance Deductions', 
                                                  'Involuntary Deductions')
            THEN TO_NUMBER(PRRV.RESULT_VALUE)
            ELSE 0
        END) DEDUCTIONS,
        
        -- Custom order for display
        CASE
            WHEN PEC.BASE_CLASSIFICATION_NAME = 'Standard Earnings' THEN 1
            WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions', 
                                                  'Social Insurance Deductions', 
                                                  'Involuntary Deductions') THEN 2
            ELSE 3
        END AS CUSTOM_ORDER
        
    FROM
        PAY_RUN_RESULT_VALUES PRRV,
        PAY_RUN_RESULTS PRR,
        PAY_PAYROLL_REL_ACTIONS PPRA,
        PAY_PAYROLL_ACTIONS PPA,
        PAY_PAY_RELATIONSHIPS_DN PPRD,
        PAY_TIME_PERIODS PTP,
        PAY_ELEMENT_TYPES_F PETF,
        PAY_ELEMENT_TYPES_TL PETT,
        PAY_INPUT_VALUES_F PIVF,
        PAY_ALL_PAYROLLS_F PAP,
        PAY_ELE_CLASSIFICATIONS PEC,
        PAY_CONSOLIDATION_SETS PCS,
        PAY_REQUESTS PRQ,
        PAY_FLOW_INSTANCES PFI
    WHERE
        PRRV.RUN_RESULT_ID = PRR.RUN_RESULT_ID
        AND PRR.PAYROLL_REL_ACTION_ID = PPRA.PAYROLL_REL_ACTION_ID
        AND PPRA.PAYROLL_ACTION_ID = PPA.PAYROLL_ACTION_ID
        AND PPRA.PAYROLL_RELATIONSHIP_ID = PPRD.PAYROLL_RELATIONSHIP_ID
        
        -- Payroll run filters
        AND PPA.ACTION_TYPE IN ('Q', 'R')
        AND PPA.ACTION_STATUS = 'C'
        AND PPRA.RETRO_COMPONENT_ID IS NULL
        
        -- Element linkage
        AND PETF.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
        AND PETF.ELEMENT_TYPE_ID = PETT.ELEMENT_TYPE_ID
        AND PIVF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
        AND PIVF.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
        
        -- Classification filter
        AND PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
        AND PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings', 
                                             'Voluntary Deductions', 
                                             'Social Insurance Deductions', 
                                             'Involuntary Deductions')
        
        -- Pay value only
        AND UPPER(TRIM(PIVF.BASE_NAME)) = 'PAY VALUE'
        
        -- Language
        AND PETT.LANGUAGE = 'US'
        
        -- Period linkage
        AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
        AND PPA.PAYROLL_ID = PAP.PAYROLL_ID
        
        -- Flow instance tracking
        AND PPA.PAY_REQUEST_ID = PRQ.PAY_REQUEST_ID
        AND PRQ.FLOW_INSTANCE_ID = PFI.FLOW_INSTANCE_ID
        AND PPA.CONSOLIDATION_SET_ID = PCS.CONSOLIDATION_SET_ID
        
        -- Date filters
        AND TRUNC(PPA.DATE_EARNED) BETWEEN PETF.EFFECTIVE_START_DATE AND PETF.EFFECTIVE_END_DATE
        AND TRUNC(PPA.DATE_EARNED) BETWEEN PIVF.EFFECTIVE_START_DATE AND PIVF.EFFECTIVE_END_DATE
        AND TRUNC(PPA.DATE_EARNED) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
        
        -- Parameters
        AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) = NVL(TO_DATE(:P_PERIOD_NAME, 'DD-MM-YYYY'), TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)))
        AND PAP.PAYROLL_NAME = NVL(:P_PAYROLLNAME, PAP.PAYROLL_NAME)
        AND PFI.INSTANCE_NAME = NVL(:P_FLOW_NAME, PFI.INSTANCE_NAME)
        
    GROUP BY
        PPRD.PERSON_ID,
        PTP.PERIOD_NAME,
        PPA.DATE_EARNED,
        PPA.EFFECTIVE_DATE,
        PTP.START_DATE,
        PTP.PERIOD_NUM,
        PAP.PAYROLL_NAME,
        TO_CHAR(PTP.START_DATE, 'YYYY'),
        PCS.CONSOLIDATION_SET_NAME,
        PCS.CONSOLIDATION_SET_ID,
        PETT.ELEMENT_NAME,
        PPA.PAYROLL_ID,
        PEC.BASE_CLASSIFICATION_NAME
)
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME EMPLOYEE_NAME,
    
    -- Assignment details
    PAAF.ASSIGNMENT_NUMBER,
    ORG.NAME DEPARTMENT,
    JOB.NAME JOB,
    GRADE.NAME GRADE,
    
    -- Period
    PR.PERIOD_NAME,
    PR.YEAR,
    PR.MONTH,
    
    -- Payroll
    PR.PAYROLL_NAME,
    PR.CONSOLIDATION_SET_NAME,
    
    -- Element name
    PR.ELEMENT_NAME,
    
    -- Values
    NVL(PR.TOTAL_EARNINGS, 0) EARNINGS,
    NVL(PR.DEDUCTIONS, 0) DEDUCTIONS,
    
    -- Net pay (sum over person for all elements)
    SUM(NVL(PR.TOTAL_EARNINGS, 0) - NVL(PR.DEDUCTIONS, 0)) OVER (PARTITION BY PAPF.PERSON_ID) NET_PAY
    
FROM
    PER_RES PR,
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_DEPARTMENTS ORG,
    PER_JOBS_F_VL JOB,
    PER_GRADES_F_VL GRADE
WHERE
    PR.PERSON_ID = PAPF.PERSON_ID
    AND PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    
    AND PAAF.ORGANIZATION_ID = ORG.ORGANIZATION_ID(+)
    AND PAAF.JOB_ID = JOB.JOB_ID(+)
    AND PAAF.GRADE_ID = GRADE.GRADE_ID(+)
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ORG.EFFECTIVE_START_DATE(+) AND ORG.EFFECTIVE_END_DATE(+)
    AND TRUNC(SYSDATE) BETWEEN JOB.EFFECTIVE_START_DATE(+) AND JOB.EFFECTIVE_END_DATE(+)
    AND TRUNC(SYSDATE) BETWEEN GRADE.EFFECTIVE_START_DATE(+) AND GRADE.EFFECTIVE_END_DATE(+)
    
ORDER BY
    CAST(PAPF.PERSON_NUMBER AS NUMBER DEFAULT 9999999999 ON CONVERSION ERROR),
    PR.CUSTOM_ORDER
```

**Benefits:**
- ✅ Works with any element configuration
- ✅ No hardcoded element names
- ✅ Dynamically aggregates by classification
- ✅ Handles multiple payrolls
- ✅ Tracks flow instance for audit

**Key Tables:**
- `PAY_CONSOLIDATION_SETS` - Consolidation set tracking
- `PAY_REQUESTS` - Payroll request
- `PAY_FLOW_INSTANCES` - Specific payroll run instance

### 11.2 Balance Extraction Pattern

**Problem:** Get balance values (gratuity provision, airfare provision, etc.)

**Solution:**

```sql
SELECT
    PPRD.PERSON_ID,
    PPA.EFFECTIVE_DATE,
    PPA.DATE_EARNED,
    PPA.PAYROLL_ACTION_ID,
    
    -- Balance value
    BAL.BALANCE_VALUE,
    
    -- Balance name (mapped)
    CASE
        WHEN PBT.BALANCE_NAME = 'DYR_Gratuity_Provision' THEN 'Gratuity Provision'
        WHEN PBT.BALANCE_NAME = 'Air Fare Provision' THEN 'Airfare Provision'
        ELSE PBT.BALANCE_NAME
    END BALANCE_NAME
    
FROM
    PER_LEGISLATIVE_DATA_GROUPS_VL LDG,
    PAY_PAY_RELATIONSHIPS_DN PPRD,
    PAY_PAYROLL_REL_ACTIONS PRA,
    PAY_PAYROLL_ACTIONS PPA,
    PAY_ACTION_CLASSES PAC,
    PAY_BALANCE_TYPES_VL PBT,
    TABLE(PAY_BALANCE_VIEW_PKG.GET_BALANCE_DIMENSIONS(
        P_BALANCE_TYPE_ID => PBT.BALANCE_TYPE_ID,
        P_PAYROLL_REL_ACTION_ID => PRA.PAYROLL_REL_ACTION_ID,
        P_PAYROLL_TERM_ID => NULL,
        P_PAYROLL_ASSIGNMENT_ID => NULL
    )) BAL,
    PAY_DIMENSION_USAGES_VL PDU,
    PAY_ALL_PAYROLLS_F PAP,
    PER_ALL_PEOPLE_F PAPF1
WHERE
    PPRD.LEGISLATIVE_DATA_GROUP_ID = LDG.LEGISLATIVE_DATA_GROUP_ID
    AND PRA.PAYROLL_RELATIONSHIP_ID = PPRD.PAYROLL_RELATIONSHIP_ID
    AND PRA.RETRO_COMPONENT_ID IS NULL
    
    -- Ensure results exist
    AND EXISTS (
        SELECT 1
        FROM PAY_RUN_RESULTS PRR
        WHERE PRR.PAYROLL_REL_ACTION_ID = PRA.PAYROLL_REL_ACTION_ID
    )
    
    AND PPA.PAYROLL_ACTION_ID = PRA.PAYROLL_ACTION_ID
    AND PAC.ACTION_TYPE = PPA.ACTION_TYPE
    AND PAC.CLASSIFICATION_NAME = 'SEQUENCED'
    AND PPA.PAYROLL_ID = PAP.PAYROLL_ID
    AND PPA.ACTION_TYPE IN ('Q', 'R')
    AND PPA.ACTION_STATUS = 'C'
    
    -- Balance type
    AND NVL(PBT.LEGISLATION_CODE, LDG.LEGISLATION_CODE) = LDG.LEGISLATION_CODE
    AND NVL(PBT.LEGISLATIVE_DATA_GROUP_ID, LDG.LEGISLATIVE_DATA_GROUP_ID) = LDG.LEGISLATIVE_DATA_GROUP_ID
    AND PBT.BALANCE_NAME IN ('Air Fare Provision', 'DYR_Gratuity_Provision')
    
    -- Dimension
    AND PDU.DIMENSION_NAME = 'Assignment Inception to Date'
    AND PDU.BALANCE_DIMENSION_ID = BAL.BALANCE_DIMENSION_ID
    AND NVL(PDU.LEGISLATION_CODE, LDG.LEGISLATION_CODE) = LDG.LEGISLATION_CODE
    AND NVL(PDU.LEGISLATIVE_DATA_GROUP_ID, LDG.LEGISLATIVE_DATA_GROUP_ID) = LDG.LEGISLATIVE_DATA_GROUP_ID
    
    AND PPRD.PERSON_ID = PAPF1.PERSON_ID
    AND BAL.BALANCE_VALUE <> '0'
    
    -- Period filter
    AND PAP.PAYROLL_ID = NVL(:P_PAYROLL, PAP.PAYROLL_ID)
    AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) = NVL(TO_DATE(:P_PERIOD, 'DDMMYYYY'), TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)))
```

**Key Function:**
- `PAY_BALANCE_VIEW_PKG.GET_BALANCE_DIMENSIONS` - Extracts balance values

**Common Balances:**
- `'Air Fare Provision'` - Airfare accrual
- `'DYR_Gratuity_Provision'` / `'Gratuity Provision'` - Gratuity accrual
- `'Annual Leave Accrual'` - Leave liability

**Dimensions:**
- `'Assignment Inception to Date'` - Total since hire
- `'Assignment Run to Date'` - Total in current assignment
- `'Assignment Period to Date'` - Current period only

### 11.3 Information Elements Pattern

**Problem:** Extract information elements (non-monetary values)

**Solution:**

```sql
SELECT
    PPRD.PERSON_ID,
    PTP.PERIOD_NAME,
    PPA.EFFECTIVE_DATE,
    PETF.BASE_ELEMENT_NAME ELEMENT_NAME,
    PRRV.RESULT_VALUE
FROM
    PAY_RUN_RESULT_VALUES PRRV,
    PAY_RUN_RESULTS PRR,
    PAY_PAYROLL_REL_ACTIONS PPRA,
    PAY_PAYROLL_ACTIONS PPA,
    PAY_PAY_RELATIONSHIPS_DN PPRD,
    PAY_TIME_PERIODS PTP,
    PAY_ELEMENT_TYPES_F PETF,
    PAY_INPUT_VALUES_F PIVF,
    PAY_ALL_PAYROLLS_F PAP,
    PAY_ELE_CLASSIFICATIONS PEC
WHERE
    PRRV.RUN_RESULT_ID = PRR.RUN_RESULT_ID
    AND PRR.PAYROLL_REL_ACTION_ID = PPRA.PAYROLL_REL_ACTION_ID
    AND PPRA.PAYROLL_ACTION_ID = PPA.PAYROLL_ACTION_ID
    AND PPRA.PAYROLL_RELATIONSHIP_ID = PPRD.PAYROLL_RELATIONSHIP_ID
    
    AND PPA.ACTION_TYPE IN ('Q', 'R')
    AND PPA.ACTION_STATUS = 'C'
    AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
    
    AND PETF.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
    AND PIVF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
    AND PIVF.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
    AND PPA.PAYROLL_ID = PAP.PAYROLL_ID
    
    AND PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
    
    -- INFORMATION classification only
    AND PEC.BASE_CLASSIFICATION_NAME = 'Information'
    
    AND PIVF.BASE_NAME = 'Pay Value'
    AND PETF.BASE_ELEMENT_NAME NOT LIKE '%Results'
    
    AND PPRA.RETRO_COMPONENT_ID IS NULL
    
    AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) = NVL(TO_DATE(:P_PERIOD, 'DD-MM-YYYY'), TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)))
    AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) BETWEEN PETF.EFFECTIVE_START_DATE AND PETF.EFFECTIVE_END_DATE
    AND TRUNC(LAST_DAY(PPA.EFFECTIVE_DATE)) BETWEEN PIVF.EFFECTIVE_START_DATE AND PIVF.EFFECTIVE_END_DATE
    
    AND PAP.PAYROLL_ID = NVL(:P_PAYROLL, PAP.PAYROLL_ID)
```

**Information Elements (Common):**
- Days worked
- Hours worked
- Working days
- FTE calculations
- Headcount values

### 11.4 Accrual from Payroll Run (YTD)

**Problem:** Get YTD accrual values from payroll runs

**Common Accrual Elements:**

| Element Name | Input Value | Purpose |
|--------------|-------------|---------|
| Annual Leave Salary Accrual | Monthly Accrual Amount | Monthly leave accrual amount |
| Gratuity Liability | Monthly Liability Amount | Monthly gratuity accrual |
| Gratuity Liability | Total Liability Amount Till Date | Total gratuity balance |
| Person Air Ticket Accrual | (Pay Value) | Self airfare provision |
| Spouse Air Ticket Accruals | (Pay Value) | Spouse airfare provision |
| Child Air Ticket Accruals | (Pay Value) | Children airfare provision |

---

**Last Updated:** 13-Jan-2026  
**Version:** 2.0 (Merged with update and advanced patterns files)  
**Status:** Production-Ready  
**Source:** 4 Production Payroll Queries (1,252 lines analyzed) + 10 Advanced Pattern Queries
