# HCM Cross-Module Patterns & Advanced Techniques

**Date:** 07-Jan-2026  
**Purpose:** Document advanced patterns discovered across multiple HCM modules  
**Source:** Analysis of 40 production queries from "Reupdate for knowledge" folder  
**Status:** Production-Ready

---

## 📋 TABLE OF CONTENTS

1. [Overview](#overview)
2. [Advanced Date-Track Filtering (LEAST Pattern)](#advanced-date-track-filtering-least-pattern)
3. [Latest Version Patterns](#latest-version-patterns)
4. [Parameter Handling Patterns](#parameter-handling-patterns)
5. [Payroll Run Results Patterns](#payroll-run-results-patterns)
6. [Element Entry Extraction](#element-entry-extraction)
7. [Transaction History & Workflow](#transaction-history--workflow)
8. [Accrual Calculation Patterns](#accrual-calculation-patterns)
9. [FTE Calculation by Legislation](#fte-calculation-by-legislation)
10. [Public Holiday Integration](#public-holiday-integration)
11. [Cross-Module Integration Patterns](#cross-module-integration-patterns)

---

## 🎯 OVERVIEW

### What Was Analyzed

**Total Files:** 40 SQL queries  
**Modules Covered:**
- ✅ ABSENCE (12 files) - Leave balance, accrual, pending approvals
- ✅ TIME_LABOR (5 files) - Timesheet, missing punch, timecard
- ✅ PAYROLL (10 files) - Payslip, payroll detail, CTC reconciliation
- ✅ HR (8 files) - Employee master, employee details, new joiners
- ✅ COMPENSATION (4 files) - Child allowance, salary components, EOS
- ✅ RECRUITING (1 file) - Candidate lookup

### Key Discoveries

1. **LEAST Pattern** - Handle termination dates in date-track filtering
2. **Latest Version Patterns** - Multiple techniques for getting latest records
3. **Dynamic Payroll Reports** - Element-agnostic payroll queries
4. **UDT Patterns** - Advanced UDT usage for leave entitlement
5. **Transaction History** - HRC_TXN_* tables for workflow tracking
6. **Accrual Calculations** - Complex accrual formulas (gratuity, leave)
7. **FTE by Legislation** - Legislation-specific FTE calculations
8. **Public Holiday** - PER_AVAILABILITY_DETAILS.GET_SCHEDULE_DETAILS
9. **Role-Based Security** - PER_ASG_RESPONSIBILITIES filtering

---

## 🚨 1. ADVANCED DATE-TRACK FILTERING (LEAST PATTERN)

### Problem: Handle Terminated Employees

**Scenario:** Need to query data for both active AND terminated employees at a specific point in time

**Solution: LEAST Pattern**

```sql
-- CRITICAL PATTERN: Use LEAST to handle termination date
LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)

-- Full Pattern:
WHERE
    -- For person
    LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    
    -- For assignment
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    
    -- For person name
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
```

**Why This Works:**
- If employee is **active** (ACTUAL_TERMINATION_DATE is NULL):
  - `NVL(NULL, :P_EFFECTIVE_DATE)` = `:P_EFFECTIVE_DATE`
  - `LEAST(:P_EFFECTIVE_DATE, :P_EFFECTIVE_DATE)` = `:P_EFFECTIVE_DATE`
  - Uses report date for filtering

- If employee is **terminated** (ACTUAL_TERMINATION_DATE = 15-JAN-2024):
  - `NVL(15-JAN-2024, :P_EFFECTIVE_DATE)` = `15-JAN-2024`
  - `LEAST(15-JAN-2024, 01-DEC-2024)` = `15-JAN-2024`
  - Uses termination date for filtering (gets last known state)

**Complete Example:**

```sql
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    PAAF.ASSIGNMENT_NUMBER,
    TO_CHAR(PPOS.ACTUAL_TERMINATION_DATE, 'DD-MON-YYYY') TERM_DATE,
    J.NAME JOB_TITLE,
    G.NAME GRADE
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_PERIODS_OF_SERVICE PPOS,
    PER_JOBS_F J,
    PER_GRADES G
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAPF.PERSON_ID = PPOS.PERSON_ID
    AND PAAF.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
    
    AND PAAF.JOB_ID = J.JOB_ID
    AND PAAF.GRADE_ID = G.GRADE_ID
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    -- CRITICAL: LEAST pattern for terminated employees
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN J.EFFECTIVE_START_DATE AND J.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN G.EFFECTIVE_START_DATE AND G.EFFECTIVE_END_DATE
    
    -- Get latest period of service
    AND PPOS.DATE_START = (
        SELECT MAX(PPOS1.DATE_START)
        FROM PER_PERIODS_OF_SERVICE PPOS1
        WHERE PPOS1.PERSON_ID = PPOS.PERSON_ID
        AND PPOS1.DATE_START <= :P_EFFECTIVE_DATE
    )
```

**When to Use:**
- ✅ Employee master reports (active + terminated)
- ✅ Historical data extraction
- ✅ End-of-service reports
- ✅ Salary extraction for terminated employees
- ✅ Any report requiring "as of" date functionality

**When NOT to Use:**
- ❌ Real-time active employee reports (use SYSDATE instead)
- ❌ Time & Labor (use timecard dates)

---

## 🔄 2. LATEST VERSION PATTERNS

### Pattern 2.1: Latest Accrual Period

**Problem:** Get the most recent accrual period for a plan

**Solution:**

```sql
SELECT
    APAE.PERSON_ID,
    APAE.PLAN_ID,
    APAE.END_BAL ACCRUAL_BALANCE,
    APAE.ACCRUAL_PERIOD
FROM
    ANC_PER_ACCRUAL_ENTRIES APAE
WHERE
    APAE.PERSON_ID = :PERSON_ID
    AND APAE.PLAN_ID = :PLAN_ID
    
    -- Latest accrual period up to report date
    AND APAE.ACCRUAL_PERIOD <= LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
    
    -- Get MAX accrual period
    AND APAE.ACCRUAL_PERIOD = (
        SELECT MAX(ACCRUAL_PERIOD)
        FROM ANC_PER_ACCRUAL_ENTRIES A1
        WHERE A1.PERSON_ID = APAE.PERSON_ID
        AND A1.PLAN_ID = APAE.PLAN_ID
        AND A1.ACCRUAL_PERIOD <= LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
    )
```

**Key Points:**
- Filter by date BEFORE getting MAX
- Use `LAST_DAY()` for month-end reporting

### Pattern 2.2: Latest Salary Component Update

**Problem:** Salary components can be updated multiple times

**Solution:**

```sql
SELECT
    CSSC.PERSON_ID,
    CSSC.COMPONENT_CODE,
    CSSC.AMOUNT,
    CSSC.LAST_UPDATE_DATE
FROM
    CMP_SALARY_SIMPLE_COMPNTS CSSC
WHERE
    CSSC.PERSON_ID = :PERSON_ID
    AND CSSC.COMPONENT_CODE NOT IN ('ORA_OVERALL_SALARY')
    
    -- Current salary period
    AND TRUNC(SYSDATE) BETWEEN CSSC.SALARY_DATE_FROM AND CSSC.SALARY_DATE_TO
    
    -- Latest update only
    AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
        SELECT MAX(TRUNC(LAST_UPDATE_DATE))
        FROM CMP_SALARY_SIMPLE_COMPNTS
        WHERE PERSON_ID = CSSC.PERSON_ID
    )
```

### Pattern 2.3: Latest Timecard Entry (HWM_TM_REC)

**Problem:** Get latest timecard entry for a specific day

**Solution:**

```sql
SELECT
    HTR.TM_REC_ID,
    HTR.START_TIME,
    HTR.STOP_TIME,
    HTR.MEASURE,
    HTR.RESOURCE_ID
FROM
    HWM_TM_REC HTR,
    HWM_TM_REC_GRP_USAGES HTRGU,
    HWM_TM_REC_GRP DTRG
WHERE
    HTR.TM_REC_ID = HTRGU.TM_REC_ID
    AND HTR.TM_REC_VERSION = HTRGU.TM_REC_VERSION
    AND HTRGU.TM_REC_GRP_ID = DTRG.TM_REC_GRP_ID
    AND HTRGU.TM_REC_GRP_VERSION = DTRG.TM_REC_GRP_VERSION
    
    -- Filters
    AND UPPER(HTR.UNIT_OF_MEASURE) IN ('UN', 'HR')
    AND HTR.LATEST_VERSION = 'Y'
    AND HTR.DELETE_FLAG IS NULL
    AND HTR.LAYER_CODE = 'TIME_RPTD'
    
    -- Latest creation date for this day
    AND HTR.CREATION_DATE = (
        SELECT MAX(HTR1.CREATION_DATE)
        FROM
            HWM_TM_REC HTR1,
            HWM_TM_REC_GRP_USAGES HTRGU1,
            HWM_TM_REC_GRP DTRG1
        WHERE
            HTRGU1.TM_REC_GRP_ID = DTRG1.TM_REC_GRP_ID
            AND HTRGU1.TM_REC_GRP_VERSION = DTRG1.TM_REC_GRP_VERSION
            AND HTR1.TM_REC_ID = HTRGU1.TM_REC_ID
            AND HTR1.TM_REC_VERSION = HTRGU1.TM_REC_VERSION
            AND HTR1.RESOURCE_ID = HTR.RESOURCE_ID
            AND DTRG1.TM_REC_GRP_ID = DTRG.TM_REC_GRP_ID
            AND HTR1.LAYER_CODE = 'TIME_RPTD'
            AND HTR1.DELETE_FLAG IS NULL
    )
```

### Pattern 2.4: Latest Assignment Supervisor

**Problem:** Get current line manager

**Solution:**

```sql
SELECT
    ASG.ASSIGNMENT_ID,
    MGR_NAME.DISPLAY_NAME LINE_MANAGER_NAME,
    MGR.PERSON_NUMBER LINE_MANAGER_NUMBER
FROM
    PER_ALL_ASSIGNMENTS_F ASG,
    PER_ASSIGNMENT_SUPERVISORS_F PASF,
    PER_PERSON_NAMES_F MGR_NAME,
    PER_ALL_PEOPLE_F MGR
WHERE
    ASG.ASSIGNMENT_ID = PASF.ASSIGNMENT_ID
    AND PASF.MANAGER_TYPE = 'LINE_MANAGER'
    
    AND PASF.MANAGER_ID = MGR_NAME.PERSON_ID
    AND PASF.MANAGER_ID = MGR.PERSON_ID
    AND MGR_NAME.NAME_TYPE = 'GLOBAL'
    
    -- Get latest supervisor record
    AND PASF.EFFECTIVE_START_DATE = (
        SELECT MAX(S.EFFECTIVE_START_DATE)
        FROM PER_ASSIGNMENT_SUPERVISORS_F S
        WHERE S.ASSIGNMENT_ID = PASF.ASSIGNMENT_ID
    )
    
    AND :P_DATE BETWEEN PASF.EFFECTIVE_START_DATE AND PASF.EFFECTIVE_END_DATE
    AND :P_DATE BETWEEN MGR_NAME.EFFECTIVE_START_DATE AND MGR_NAME.EFFECTIVE_END_DATE
    AND :P_DATE BETWEEN MGR.EFFECTIVE_START_DATE AND MGR.EFFECTIVE_END_DATE
```

---

## 📊 3. PARAMETER HANDLING PATTERNS

### Pattern 3.1: Multi-Value Parameter with NULL Handling

**Problem:** Handle multi-select parameters with "All" option

**Solution:**

```sql
-- Standard multi-value with NULL
WHERE
    (PAAF.LEGAL_ENTITY_ID IN (:P_LEGAL_EMPLOYER) OR LEAST(:P_LEGAL_EMPLOYER) IS NULL)
    AND (PAPF.PERSON_NUMBER IN (:P_EMP) OR LEAST(:P_EMP) IS NULL)
    AND (PAAF.ASSIGNMENT_STATUS_TYPE IN (:P_STATUS) OR LEAST(:P_STATUS) IS NULL)
```

**Alternate: 'ALL' Pattern**

```sql
WHERE
    (PAPF.PERSON_NUMBER IN (:P_PERSON_NO) OR 'ALL' IN (:P_PERSON_NO || 'ALL'))
    AND (PD.NAME IN (:P_DEPT) OR 'ALL' IN (:P_DEPT || 'ALL'))
    AND (HLE.NAME IN (:P_LE_NAME) OR 'ALL' IN (:P_LE_NAME || 'ALL'))
```

**When to Use Each:**
- **LEAST pattern** → When parameter is truly NULL (not passed)
- **'ALL' pattern** → When 'ALL' is an explicit option in parameter list

### Pattern 3.2: COALESCE Parameter Pattern

**Problem:** Handle NULL parameters with IN clause

**Solution:**

```sql
WHERE
    (JOB_FAMILY.JOB_FAMILY_NAME IN (:P_REQUISITION_TYPE) 
     OR COALESCE(:P_REQUISITION_TYPE, NULL) IS NULL)
    
    AND (REQ.REQUISITION_ID IN (:P_REQUISITION_NUMBER) 
         OR COALESCE(:P_REQUISITION_NUMBER, NULL) IS NULL)
```

### Pattern 3.3: Date Range Parameters

**Problem:** Handle optional date ranges

**Solution:**

```sql
-- With BETWEEN
WHERE
    SUB.SUBMISSION_DATE BETWEEN NVL(:P_START_DATE, SUB.SUBMISSION_DATE)
                            AND NVL(:P_END_DATE, SUB.SUBMISSION_DATE)

-- With IN
WHERE
    (LOGISTICS_COMPLETION_DATE IN (:P_LOGISTICS_DATE) 
     OR COALESCE(:P_LOGISTICS_DATE, NULL) IS NULL)
```

---

## 💰 4. PAYROLL RUN RESULTS PATTERNS

### Pattern 4.1: Dynamic Element Extraction

**Problem:** Extract payroll elements without hardcoding element names

**Solution:**

```sql
WITH PER_RES AS (
    SELECT
        PPRD.PERSON_ID,
        PTP.PERIOD_NAME,
        TO_CHAR(PTP.START_DATE, 'YYYY') YEAR,
        TO_CHAR(PTP.START_DATE, 'Month') MONTH,
        PPA.DATE_EARNED,
        PPA.EFFECTIVE_DATE,
        PAP.PAYROLL_NAME,
        PETT.ELEMENT_NAME,
        PEC.BASE_CLASSIFICATION_NAME,
        
        -- Aggregate by classification
        SUM(CASE 
            WHEN PEC.BASE_CLASSIFICATION_NAME = 'Standard Earnings'
            THEN TO_NUMBER(PRRV.RESULT_VALUE)
            ELSE 0
        END) TOTAL_EARNINGS,
        
        SUM(CASE 
            WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions', 'Social Insurance Deductions', 'Involuntary Deductions')
            THEN TO_NUMBER(PRRV.RESULT_VALUE)
            ELSE 0
        END) TOTAL_DEDUCTIONS,
        
        -- Custom ordering
        CASE
            WHEN PEC.BASE_CLASSIFICATION_NAME = 'Standard Earnings' THEN 1
            WHEN PEC.BASE_CLASSIFICATION_NAME IN ('Voluntary Deductions', 'Social Insurance Deductions', 'Involuntary Deductions') THEN 2
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
        AND PPA.ACTION_TYPE IN ('Q', 'R')  -- QuickPay or Regular
        AND PPA.ACTION_STATUS = 'C'  -- Complete
        AND PPRA.RETRO_COMPONENT_ID IS NULL  -- Exclude retro
        
        -- Element linkage
        AND PETF.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
        AND PETF.ELEMENT_TYPE_ID = PETT.ELEMENT_TYPE_ID
        AND PIVF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
        AND PIVF.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
        
        -- Classification
        AND PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
        AND PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings', 'Voluntary Deductions', 'Social Insurance Deductions', 'Involuntary Deductions')
        
        -- Pay value only
        AND UPPER(TRIM(PIVF.BASE_NAME)) = 'PAY VALUE'
        
        -- Language filter
        AND PETT.LANGUAGE = 'US'
        
        -- Period
        AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
        AND PPA.PAYROLL_ID = PAP.PAYROLL_ID
        
        -- Flow instance (for specific payroll run)
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
    PR.PERSON_ID,
    PPNF.DISPLAY_NAME EMPLOYEE_NAME,
    PR.PAYROLL_NAME,
    PR.ELEMENT_NAME,
    PR.TOTAL_EARNINGS,
    PR.TOTAL_DEDUCTIONS,
    (PR.TOTAL_EARNINGS - PR.TOTAL_DEDUCTIONS) NET_PAY
FROM
    PER_RES PR,
    PER_PERSON_NAMES_F PPNF
WHERE
    PR.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
ORDER BY PR.PERSON_ID, PR.CUSTOM_ORDER
```

**Key Components:**
- `PPA.ACTION_TYPE IN ('Q', 'R')` - QuickPay or Regular payroll
- `PPA.ACTION_STATUS = 'C'` - Complete only
- `PPRA.RETRO_COMPONENT_ID IS NULL` - Exclude retro payments
- `PAY_FLOW_INSTANCES` - Track specific payroll run
- `TRUNC(LAST_DAY(EFFECTIVE_DATE))` - Match period end date

### Pattern 4.2: Specific Element Values

**Problem:** Extract specific earning/deduction elements

**Solution:**

```sql
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.FULL_NAME,
    
    -- Specific earnings
    SUM(DECODE(PET_TL.ELEMENT_NAME, 'Basic', TO_NUMBER(PRRV.RESULT_VALUE), 0)) BASIC_PAY,
    SUM(DECODE(PET_TL.ELEMENT_NAME, 'Housing Allowance', TO_NUMBER(PRRV.RESULT_VALUE), 0)) HRA,
    SUM(DECODE(PET_TL.ELEMENT_NAME, 'Transport Allowance', TO_NUMBER(PRRV.RESULT_VALUE), 0)) TRANSPORT,
    SUM(DECODE(PET_TL.ELEMENT_NAME, 'Food Allowance', TO_NUMBER(PRRV.RESULT_VALUE), 0)) FOOD,
    
    -- Total earnings
    SUM(DECODE(PEC.CLASSIFICATION_NAME, 'Standard Earnings', TO_NUMBER(PRRV.RESULT_VALUE), 0)) TOTAL_EARNINGS,
    
    -- Specific deductions
    SUM(DECODE(PET_TL.ELEMENT_NAME, 'Housing Deduction Results', TO_NUMBER(PRRV.RESULT_VALUE), 0)) HOUSING_DED,
    SUM(DECODE(PET_TL.ELEMENT_NAME, 'Fines and Penalties Results', TO_NUMBER(PRRV.RESULT_VALUE), 0)) FINES,
    
    -- Total deductions
    SUM(DECODE(PEC.CLASSIFICATION_NAME, 'Voluntary Deductions', TO_NUMBER(PRRV.RESULT_VALUE), 0)) TOTAL_DEDUCTIONS,
    
    -- Net pay
    (SUM(DECODE(PEC.CLASSIFICATION_NAME, 'Standard Earnings', TO_NUMBER(PRRV.RESULT_VALUE), 0)) -
     SUM(DECODE(PEC.CLASSIFICATION_NAME, 'Voluntary Deductions', TO_NUMBER(PRRV.RESULT_VALUE), 0))) NET_SALARY
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_PERIODS_OF_SERVICE PPOS,
    PAY_PAY_RELATIONSHIPS_DN PPRD,
    PAY_PAYROLL_REL_ACTIONS PPRA,
    PAY_PAYROLL_ACTIONS PPA,
    PAY_RUN_RESULTS PRR,
    PAY_RUN_RESULT_VALUES PRRV,
    PAY_ELEMENT_TYPES_TL PET_TL,
    PAY_ELEMENT_TYPES_F PET,
    PAY_INPUT_VALUES_F PIV,
    PAY_ELE_CLASSIFICATIONS_TL PEC
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PPOS.PERSON_ID
    AND PAPF.PERSON_ID = PPRD.PERSON_ID
    
    AND PPRD.PAYROLL_RELATIONSHIP_ID = PPRA.PAYROLL_RELATIONSHIP_ID
    AND PPRA.PAYROLL_ACTION_ID = PPA.PAYROLL_ACTION_ID
    AND PPRA.PAYROLL_REL_ACTION_ID = PRR.PAYROLL_REL_ACTION_ID
    AND PRR.RUN_RESULT_ID = PRRV.RUN_RESULT_ID
    
    AND PRR.ELEMENT_TYPE_ID = PET.ELEMENT_TYPE_ID
    AND PET.ELEMENT_TYPE_ID = PET_TL.ELEMENT_TYPE_ID
    AND PRRV.INPUT_VALUE_ID = PIV.INPUT_VALUE_ID
    
    AND PET.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PET_TL.LANGUAGE = USERENV('LANG')
    AND PEC.LANGUAGE = 'US'
    
    AND UPPER(PIV_TL.NAME) = UPPER('Pay Value')
    
    -- Payroll run filters
    AND PPA.ACTION_TYPE IN ('Q', 'R')
    AND PPA.DATE_EARNED = :P_DATE
    AND PPRA.RETRO_COMPONENT_ID IS NULL
    
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PET.EFFECTIVE_START_DATE AND PET.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PIV.EFFECTIVE_START_DATE AND PIV.EFFECTIVE_END_DATE
    
GROUP BY
    PAPF.PERSON_NUMBER,
    PPNF.FULL_NAME,
    PPOS.WORKER_NUMBER
```

---

## 🧮 5. ELEMENT ENTRY EXTRACTION

### Pattern 5.1: Basic Salary from Element Entries

**Problem:** Get salary directly from PAY_ELEMENT_ENTRIES (not from payroll run)

**Solution:**

```sql
-- Method 1: Using REPORTING_NAME
SELECT
    PAPF.PERSON_ID,
    PAPF.PERSON_NUMBER,
    SUM(PEEV.SCREEN_ENTRY_VALUE) BASIC_SALARY
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERIODS_OF_SERVICE PPOS,
    PAY_ELEMENT_TYPES_VL PETV,
    PAY_INPUT_VALUES_VL PIVL,
    PAY_ELEMENT_ENTRIES_F PEEF,
    PAY_ELEMENT_ENTRY_VALUES_F PEEV
WHERE
    PAPF.PERSON_ID = PEEF.PERSON_ID
    AND PAPF.PERSON_ID = PPOS.PERSON_ID
    
    AND PETV.ELEMENT_TYPE_ID = PIVL.ELEMENT_TYPE_ID
    AND PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
    AND PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
    AND PIVL.INPUT_VALUE_ID = PEEV.INPUT_VALUE_ID
    
    -- Element identification
    AND PETV.REPORTING_NAME = 'Basic Salary'
    AND PIVL.NAME = 'Amount'
    
    -- Date filters (handle termination)
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PETV.EFFECTIVE_START_DATE AND PETV.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PIVL.EFFECTIVE_START_DATE AND PIVL.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PEEF.EFFECTIVE_START_DATE AND PEEF.EFFECTIVE_END_DATE
    AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, :P_EFFECTIVE_DATE), :P_EFFECTIVE_DATE)
        BETWEEN PEEV.EFFECTIVE_START_DATE AND PEEV.EFFECTIVE_END_DATE
    
    AND PEEV.SCREEN_ENTRY_VALUE IS NOT NULL
    
GROUP BY PAPF.PERSON_ID, PAPF.PERSON_NUMBER
```

**Method 2: Using CLASSIFICATION and Attribute**

```sql
-- For legislation-specific salary extraction
SELECT
    PAPF.PERSON_ID,
    
    -- For India (IN) - Specific elements
    CASE WHEN PAAF.LEGISLATION_CODE = 'IN' THEN
        (SELECT
            SUM(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) * 
                NVL((SELECT TO_NUMBER(PELF.ATTRIBUTE3)
                     FROM PAY_ELEMENT_LINKS_F PELF
                     WHERE PELF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
                     AND :P_DATE BETWEEN PELF.EFFECTIVE_START_DATE AND PELF.EFFECTIVE_END_DATE
                     AND ROWNUM = 1), 1))
         FROM
             PAY_ELEMENT_TYPES_TL PETL,
             PAY_ELEMENT_TYPES_F PETF,
             PAY_INPUT_VALUES_TL PIVL,
             PAY_INPUT_VALUES_F PIVF,
             PAY_ELEMENT_ENTRIES_F PEEF,
             PAY_ELEMENT_ENTRY_VALUES_F PEEV
         WHERE
             PETL.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
             AND PETF.ELEMENT_TYPE_ID = PIVF.ELEMENT_TYPE_ID
             AND PIVL.INPUT_VALUE_ID = PIVF.INPUT_VALUE_ID
             AND PETF.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
             AND PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
             AND PIVF.INPUT_VALUE_ID = PEEV.INPUT_VALUE_ID
             AND PEEF.PERSON_ID = PAPF.PERSON_ID
             
             AND PETL.LANGUAGE = 'US'
             AND PIVL.LANGUAGE = 'US'
             AND PIVF.RESERVED_INPUT_VALUE = 'RESERVED_INPUT_VALUE'
             AND PEEV.SCREEN_ENTRY_VALUE IS NOT NULL
             
             -- India-specific reporting names
             AND PETL.REPORTING_NAME IN ('Basic Salary', 'City Compensatory Allowance', 
                                         'Conveyance Allowance', 'Education Allowance', 
                                         'House Rent Allowance', 'Leave Travel Allowance', 
                                         'Medical Allowance')
             
             AND :P_DATE BETWEEN PETF.EFFECTIVE_START_DATE AND PETF.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PIVF.EFFECTIVE_START_DATE AND PIVF.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PEEF.EFFECTIVE_START_DATE AND PEEF.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PEEV.EFFECTIVE_START_DATE AND PEEV.EFFECTIVE_END_DATE
        )
    
    -- For other legislations - Use element link attribute
    ELSE
        (SELECT
            SUM(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) * 
                NVL((SELECT TO_NUMBER(PELF.ATTRIBUTE3)
                     FROM PAY_ELEMENT_LINKS_F PELF
                     WHERE PELF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
                     AND :P_DATE BETWEEN PELF.EFFECTIVE_START_DATE AND PELF.EFFECTIVE_END_DATE
                     AND ROWNUM = 1), 1))
         FROM
             PAY_ELEMENT_TYPES_TL PETL,
             PAY_ELEMENT_TYPES_F PETF,
             PAY_INPUT_VALUES_TL PIVL,
             PAY_INPUT_VALUES_F PIVF,
             PAY_ELEMENT_ENTRIES_F PEEF,
             PAY_ELEMENT_ENTRY_VALUES_F PEEV,
             PAY_ELEMENT_LINKS_F PELF
         WHERE
             PETL.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
             AND PETF.ELEMENT_TYPE_ID = PIVF.ELEMENT_TYPE_ID
             AND PIVL.INPUT_VALUE_ID = PIVF.INPUT_VALUE_ID
             AND PETF.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
             AND PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
             AND PIVF.INPUT_VALUE_ID = PEEV.INPUT_VALUE_ID
             AND PEEF.PERSON_ID = PAPF.PERSON_ID
             
             -- Element link for attribute
             AND PELF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
             AND PELF.ATTRIBUTE1 = 'Basic Salary'
             
             AND PETL.LANGUAGE = 'US'
             AND PIVL.LANGUAGE = 'US'
             AND PIVF.RESERVED_INPUT_VALUE = 'RESERVED_INPUT_VALUE'
             AND PEEV.SCREEN_ENTRY_VALUE IS NOT NULL
             
             AND :P_DATE BETWEEN PETF.EFFECTIVE_START_DATE AND PETF.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PIVF.EFFECTIVE_START_DATE AND PIVF.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PEEF.EFFECTIVE_START_DATE AND PEEF.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PEEV.EFFECTIVE_START_DATE AND PEEV.EFFECTIVE_END_DATE
             AND :P_DATE BETWEEN PELF.EFFECTIVE_START_DATE AND PELF.EFFECTIVE_END_DATE
        )
    END BASIC_ANNUAL
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_PERIODS_OF_SERVICE PPOS
WHERE
    PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAPF.PERSON_ID = PPOS.PERSON_ID
    AND PAAF.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
    
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND :P_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND :P_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
```

**Key Points:**
- `REPORTING_NAME` → User-friendly element name
- `RESERVED_INPUT_VALUE = 'RESERVED_INPUT_VALUE'` → Primary input value
- `PAY_ELEMENT_LINKS_F.ATTRIBUTE1` → Custom attributes
- `PAY_ELEMENT_LINKS_F.ATTRIBUTE3` → Annualization factor (12 for monthly)

---

## 📅 6. TRANSACTION HISTORY & WORKFLOW

### Pattern 6.1: Pending Approval Tracking

**Problem:** Track pending workflow approvals

**Solution:**

```sql
SELECT
    TXND.TRANSACTION_ID,
    TXND.STATE,
    TXND.STATUS,
    TXNH.MODULE_IDENTIFIER,
    
    -- Submitted by
    TXND.SUBMITTED_BY,
    TO_CHAR(TXND.SUBMITTED_DATE, 'DD-MM-YYYY HH:MM:SS') SUBMISSION_DATE,
    
    -- Get submitter person number
    (SELECT PAPF.PERSON_NUMBER
     FROM PER_USERS PU, PER_ALL_PEOPLE_F PAPF
     WHERE PU.PERSON_ID = PAPF.PERSON_ID
     AND LOWER(TRIM(PU.USERNAME)) = LOWER(TRIM(TXND.SUBMITTED_BY))
     AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    ) SUBMITTED_EMPLOYEE_NUM,
    
    -- Pending approvers (from WFTASK)
    (SELECT LISTAGG(REPLACE(ASSIGNEES, ',user', ''), '; ' ON OVERFLOW TRUNCATE) 
            WITHIN GROUP (ORDER BY IDENTIFICATIONKEY)
     FROM FA_FUSION_SOAINFRA.WFTASK WF
     WHERE WF.ASSIGNEES IS NOT NULL
     AND WF.STATE IN ('ASSIGNED', 'INFO_REQUESTED')
     AND WF.WORKFLOWPATTERN NOT IN ('AGGREGATION', 'FYI')
     AND WF.IDENTIFICATIONKEY = TO_CHAR(TXNH.OBJECT_ID)
    ) PENDING_APPROVERS,
    
    -- Last approved by (from BPM history)
    (SELECT LISTAGG(DISTINCT PPNF.DISPLAY_NAME, '; ')
     FROM
         FND_BPM_TASK_B BPM_TASK,
         FND_BPM_TASK_HISTORY_B BPM_HIST,
         PER_USERS PU,
         PER_PERSON_NAMES_F PPNF
     WHERE
         BPM_TASK.TASK_ID = BPM_HIST.TASK_ID
         AND BPM_HIST.OUTCOME_CODE = 'APPROVE'
         AND BPM_HIST.STATUS_CODE = 'OUTCOME_UPDATED'
         AND BPM_TASK.IDENTIFICATION_KEY = TO_CHAR(TXNH.OBJECT_ID)
         AND LOWER(BPM_HIST.COMPLETED_BY) = LOWER(PU.USERNAME)
         AND PU.PERSON_ID = PPNF.PERSON_ID
         AND BPM_HIST.DOMAIN = 'HCMDomain'
         AND BPM_HIST.VERSION_REASON = 'TASK_VERSION_REASON_OUTCOME_UPDATED'
         AND PPNF.NAME_TYPE = 'GLOBAL'
         AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    ) APPROVED_BY,
    
    -- Transaction details
    HTCE.OBJECT_NAME TRANSACTION_NAME,
    HART.NAME PROCESS_NAME,
    HART.CATEGORY_NAME PROCESS_CATEGORY,
    HART.SUBCATEGORY_NAME PROCESS_SUBCATEGORY,
    HL.MEANING STATUS_MEANING
    
FROM
    HRC_TXN_HEADER TXNH,
    HRC_TXN_DATA TXND,
    HRC_TXN_CONSOLE_ENTRY HTCE,
    HRC_ARM_PROCESS_TL HART,
    HCM_LOOKUPS HL
WHERE
    TXNH.TRANSACTION_ID = TXND.TRANSACTION_ID
    AND TXNH.TRANSACTION_ID = HTCE.TRANSACTION_ID(+)
    AND TXNH.PROCESS_ID = HART.PROCESS_ID(+)
    AND HART.LANGUAGE(+) = 'US'
    AND HART.SOURCE_LANG(+) = 'US'
    
    AND TXNH.FAMILY = 'HCM'
    AND HTCE.CONSOLE_TXN_STATUS = HL.LOOKUP_CODE(+)
    AND HL.LOOKUP_TYPE = 'ORA_HRC_TXN_CON_EXT_TXN_STATUS'
    
    -- Pending only
    AND TXND.STATUS = 'PENDING'
    
    -- Module filter
    AND TXNH.MODULE_IDENTIFIER = 'Global Absence Recording'  -- Or other module
```

**Key Tables:**
- `HRC_TXN_HEADER` - Transaction header
- `HRC_TXN_DATA` - Transaction data
- `HRC_TXN_CONSOLE_ENTRY` - Console status
- `FA_FUSION_SOAINFRA.WFTASK` - Workflow tasks
- `FND_BPM_TASK_B` / `FND_BPM_TASK_HISTORY_B` - BPM workflow history

**Common Module Identifiers:**
- `'Global Absence Recording'`
- `'Make Personal Contribution'`
- `'Individual Compensation'`

---

## 📊 7. ACCRUAL CALCULATION PATTERNS

### Pattern 7.1: Annual Leave Entitlement from UDT

**Problem:** Get annual leave entitlement by grade (varies by grade)

**Solution:**

```sql
WITH ENTITLEMENT_UDT AS (
    SELECT
        T.ROW_LOW_RANGE_OR_NAME GRADE_NAME,
        TO_NUMBER(V.VALUE) ENTITLEMENT_DAYS
    FROM
        FF_USER_TABLES T,
        FF_USER_ROWS_F R,
        FF_USER_COLUMNS C,
        FF_USER_COLUMN_INSTANCES_F V
    WHERE
        T.BASE_USER_TABLE_NAME = 'EPG_ANNUAL_BALANCE'
        AND T.USER_TABLE_ID = R.USER_TABLE_ID
        AND T.USER_TABLE_ID = C.USER_TABLE_ID
        AND C.USER_COLUMN_ID = V.USER_COLUMN_ID
        AND R.USER_ROW_ID = V.USER_ROW_ID
        
        -- Period filter
        AND LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
            BETWEEN TRUNC(R.EFFECTIVE_START_DATE) AND TRUNC(R.EFFECTIVE_END_DATE)
        AND LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
            BETWEEN TRUNC(V.EFFECTIVE_START_DATE) AND TRUNC(V.EFFECTIVE_END_DATE)
)
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    PG.NAME GRADE,
    
    -- Entitlement based on grade
    CASE
        WHEN ACCR1.PLAN_NAME = 'Annual Leave' AND PG.NAME <> '09.RegularVarP Expat'
        THEN UDT.ENTITLEMENT_DAYS
        
        WHEN ACCR1.PLAN_NAME = 'Annual Leave' AND PG.NAME = '09.RegularVarP Expat'
        THEN 22  -- Special case for expat
        
        ELSE 30  -- Default
    END ANNUAL_LEAVE_ENTITLEMENT
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_GRADES PG,
    ENTITLEMENT_UDT UDT,
    ANC_ABSENCE_PLANS_VL ACCR1
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAAF.GRADE_ID = PG.GRADE_ID
    
    AND UPPER(PG.NAME) = UPPER(UDT.GRADE_NAME(+))
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND PAAF.PRIMARY_ASSIGNMENT_FLAG = 'Y'
    
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
        BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
```

### Pattern 7.2: Accrual Balance with Adjustments

**Problem:** Calculate actual available balance (accrual - absences + adjustments + carryover)

**Solution:**

```sql
WITH ACCRUAL_DETAILS AS (
    SELECT
        APAC.PERSON_ID,
        AAPV.NAME PLAN_NAME,
        AAPV.ABSENCE_PLAN_ID,
        
        -- Accrual balance (Forward Looking Days Remaining)
        NVL(SUM(CASE WHEN APAC.TYPE = 'FLDR' THEN ROUND(APAC.VALUE, 2) END), 0) BAL_DAYS,
        
        -- Carryover from previous year
        NVL(SUM(CASE WHEN APAC.TYPE = 'COVR' THEN ROUND(APAC.VALUE, 2) END), 0) CARRY_OVER,
        
        -- Adjustments (manual adjustments + initial balance)
        NVL(SUM(CASE WHEN APAC.TYPE IN ('ADJOTH', 'INIT') THEN ROUND(APAC.VALUE, 2) END), 0) ADJUSTMENT,
        
        -- Absence taken (negative value in accrual table)
        NVL(ABS(SUM(CASE WHEN APAC.TYPE = 'ABS' THEN ROUND(APAC.VALUE, 2) END)), 0) ABSENCE_BAL,
        
        -- Current month absence
        NVL(ABS(SUM(CASE WHEN APAC.TYPE = 'ABS' 
                    AND TO_CHAR(APAC.PROCD_DATE, 'MM') = :P_MONTH 
                    THEN ROUND(APAC.VALUE, 2) END)), 0) CURRENT_MONTH_ABSENCE,
        
        -- Calendar type
        CASE
            WHEN AAPV.NAME = 'Annual Leave' THEN 261  -- Working days
            ELSE 365  -- Calendar days
        END CAL_DAYS
        
    FROM
        ANC_PER_ACRL_ENTRY_DTLS APAC,
        ANC_ABSENCE_PLANS_VL AAPV
    WHERE
        APAC.PL_ID = AAPV.ABSENCE_PLAN_ID
        AND APAC.TYPE IN ('FLDR', 'INIT', 'COVR', 'ADJOTH', 'ABS')
        AND AAPV.NAME IN ('Annual Leave', 'Annual Leave - Calendar Days')
        AND TO_CHAR(APAC.PROCD_DATE, 'YYYY') = :P_YEAR
        AND TRUNC(SYSDATE) BETWEEN AAPV.EFFECTIVE_START_DATE AND AAPV.EFFECTIVE_END_DATE
    GROUP BY
        APAC.PERSON_ID,
        AAPV.NAME,
        AAPV.ABSENCE_PLAN_ID
)
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    
    -- Accrual details
    ACCR.PLAN_NAME,
    ACCR.BAL_DAYS PERIOD_ACCRUAL,
    ACCR.CARRY_OVER,
    ACCR.ADJUSTMENT,
    ACCR.ABSENCE_BAL ABSENCE_TAKEN_YTD,
    ACCR.CURRENT_MONTH_ABSENCE,
    
    -- Available balance
    ((ACCR.BAL_DAYS + ACCR.CARRY_OVER + ACCR.ADJUSTMENT) - ACCR.ABSENCE_BAL) AVAILABLE_BALANCE,
    
    -- Accrual entry end balance (latest period)
    (SELECT END_BAL
     FROM ANC_PER_ACCRUAL_ENTRIES A
     WHERE A.PERSON_ID = PAPF.PERSON_ID
     AND A.PLAN_ID = ACCR.ABSENCE_PLAN_ID
     AND A.ACCRUAL_PERIOD <= LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
     AND A.ACCRUAL_PERIOD = (
         SELECT MAX(ACCRUAL_PERIOD)
         FROM ANC_PER_ACCRUAL_ENTRIES A1
         WHERE A1.PERSON_ID = A.PERSON_ID
         AND A1.PLAN_ID = A.PLAN_ID
         AND A1.ACCRUAL_PERIOD <= LAST_DAY(TO_DATE((:P_YEAR || '-' || :P_MONTH), 'YYYY-MM'))
     )
    ) ACCRUAL_END_BALANCE
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    ACCRUAL_DETAILS ACCR
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = ACCR.PERSON_ID
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
```

**Accrual Entry Types (ANC_PER_ACRL_ENTRY_DTLS.TYPE):**
- `'FLDR'` - Forward Looking Days Remaining (accrual balance)
- `'COVR'` - Carryover from previous period
- `'ADJOTH'` - Other adjustments
- `'INIT'` - Initial balance
- `'ABS'` - Absence taken (negative value)

---

## 🏭 8. FTE CALCULATION BY LEGISLATION

### Problem: Calculate FTE based on legislation-specific standard hours

**Solution:**

```sql
SELECT
    PAPF.PERSON_NUMBER,
    PAAF.LEGISLATION_CODE,
    
    -- Weekly hours worked
    (SELECT ROUND(SUM(LEAST(((ZSPD.DAY_STOP_NUM - ZSPD.DAY_START_NUM) + 1), 7) * 
                          (ZSHV.DURATION_MS_NUM / 3600000)), 2)
     FROM
         ZMM_SR_SCHEDULES_VL ZSS,
         ZMM_SR_SCHEDULE_PATTERNS ZSP,
         ZMM_SR_PATTERN_DTLS ZSPD,
         ZMM_SR_SHIFTS_TL ZSH,
         ZMM_SR_SHIFTS_B ZSHV,
         PER_SCHEDULE_ASSIGNMENTS PSA
     WHERE
         ZSS.SCHEDULE_ID = ZSP.SCHEDULE_ID
         AND ZSP.PATTERN_ID = ZSPD.PATTERN_ID
         AND ZSPD.CHILD_SHIFT_ID = ZSH.SHIFT_ID
         AND ZSH.SHIFT_ID = ZSHV.SHIFT_ID
         AND ZSS.SCHEDULE_ID = PSA.SCHEDULE_ID
         AND ZSH.LANGUAGE = 'US'
         AND PSA.RESOURCE_TYPE = 'ASSIGN'
         AND PSA.PRIMARY_FLAG = 'Y'
         AND PSA.RESOURCE_ID = PAAF.ASSIGNMENT_ID
         AND :P_EFFECTIVE_DATE BETWEEN ZSS.EFFECTIVE_FROM_DATE AND ZSS.EFFECTIVE_TO_DATE
         AND :P_EFFECTIVE_DATE BETWEEN PSA.START_DATE AND PSA.END_DATE
    ) WEEKLY_HOURS,
    
    -- FTE Calculation (legislation-specific)
    LEAST(ROUND(
        CASE
            -- Australia: 38 hours/week
            WHEN PAAF.LEGISLATION_CODE = 'AU' THEN
                (WEEKLY_HOURS / 38)
            
            -- Multiple countries: 40 hours/week
            WHEN PAAF.LEGISLATION_CODE IN ('AZ', 'CA', 'CN', 'CO', 'GB', 'GE', 'IN', 'SG', 'TT', 'US') THEN
                (WEEKLY_HOURS / 40)
            
            -- UAE - Specific entities: 42.5 hours/week
            WHEN PAAF.LEGISLATION_CODE = 'AE' AND PLE.NAME IN ('Kent Global DMCC', 'Kent Group DMCC') THEN
                (WEEKLY_HOURS / 42.5)
            
            -- Kazakhstan OR specific UAE entities: 45 hours/week
            WHEN PAAF.LEGISLATION_CODE = 'KZ' 
              OR PLE.NAME IN ('KENTZ OVERSEAS COMPANY W.L.L (DMCC BRANCH)', 
                            'Kent International Arabia Limited - Abu Dhabi Branch', 
                            'UTS KENT LLC') THEN
                (WEEKLY_HOURS / 45)
            
            -- Iraq, Kuwait, Qatar, Saudi OR specific UAE entities: 48 hours/week
            WHEN PAAF.LEGISLATION_CODE IN ('IQ', 'KW', 'QA', 'SA')
              OR PLE.NAME IN ('Kentech International Limited - Abu Dhabi Branch', 
                            'Kentech International Limited - Dubai Branch') THEN
                (WEEKLY_HOURS / 48)
            
            ELSE 1  -- Default
        END, 2), 1) FTE
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_LEGAL_EMPLOYERS PLE
WHERE
    PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAAF.LEGAL_ENTITY_ID = PLE.ORGANIZATION_ID
    
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND :P_EFFECTIVE_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND :P_EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND :P_EFFECTIVE_DATE BETWEEN PLE.EFFECTIVE_START_DATE AND PLE.EFFECTIVE_END_DATE
```

**Standard Hours by Legislation:**

| Legislation | Standard Hours/Week | Countries |
|-------------|---------------------|-----------|
| 38 hours | Australia | AU |
| 40 hours | Standard | AZ, CA, CN, CO, GB, GE, IN, SG, TT, US |
| 42.5 hours | UAE (specific entities) | AE (Kent Global/Kent Group DMCC) |
| 45 hours | Kazakhstan + UAE entities | KZ, specific AE entities |
| 48 hours | Middle East + UAE entities | IQ, KW, QA, SA, specific AE entities |

**Note:** FTE is capped at 1.0 with `LEAST(..., 1)`

---

## 🏖️ 9. PUBLIC HOLIDAY INTEGRATION

### Pattern 9.1: PER_AVAILABILITY_DETAILS Package

**Problem:** Check if date is a public holiday

**Solution:**

```sql
SELECT
    PAPF.PERSON_NUMBER,
    ASG.ASSIGNMENT_ID,
    TRUNC(:P_DATE) CALENDAR_DATE,
    
    -- Public holiday check
    (SELECT SCH.OBJECT_NAME
     FROM TABLE(PER_AVAILABILITY_DETAILS.GET_SCHEDULE_DETAILS(
         P_RESOURCE_TYPE => 'ASSIGN',
         P_RESOURCE_ID => ASG.ASSIGNMENT_ID,
         P_PERIOD_START => TRUNC(:P_DATE),
         P_PERIOD_END => TRUNC(:P_DATE) + 1
     )) SCH
     WHERE SCH.OBJECT_CATEGORY = 'PH'  -- Public Holiday
     AND ROWNUM = 1
    ) PUBLIC_HOLIDAY_NAME
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_ALL_ASSIGNMENTS_M ASG
WHERE
    PAPF.PERSON_ID = ASG.PERSON_ID
    AND ASG.ASSIGNMENT_TYPE IN ('E', 'C')
    AND ASG.PRIMARY_FLAG = 'Y'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    AND ASG.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
```

**Key Parameters:**
- `P_RESOURCE_TYPE`:
  - `'ASSIGN'` - Assignment-level schedule
  - `'LEGALEMP'` - Legal employer-level schedule (fallback)
- `P_RESOURCE_ID`:
  - `ASSIGNMENT_ID` for 'ASSIGN'
  - `LEGAL_ENTITY_ID` for 'LEGALEMP'
- `P_PERIOD_START` - Start date
- `P_PERIOD_END` - End date (exclusive, use +1)

**Object Categories:**
- `'PH'` - Public Holiday
- `'WO'` - Week-off
- `'SHIFT'` - Shift details

### Pattern 9.2: Timesheet with Public Holiday Union

**Problem:** Show public holidays in timesheet report even if no timecard

**Solution:**

```sql
-- Main timesheet data
SELECT
    TM_REC_GRP_ID,
    PERSON_ID,
    PERSON_NUMBER,
    EMPLOYEE_NAME,
    START_TIME,
    STOP_TIME,
    STATUS,
    RECORDED_HOURS,
    NULL AS PUBLIC_HOLIDAY  -- Not a public holiday
FROM HWM_EXT_TIMECARD_DETAIL_V
WHERE ...

UNION

-- Public holidays (where no timecard exists)
SELECT
    NULL TM_REC_GRP_ID,
    PAPF.PERSON_ID,
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME EMPLOYEE_NAME,
    TO_CHAR(SCH.START_DATE_TIME, 'YYYY-MM-DD') START_TIME,
    NULL STOP_TIME,
    NULL STATUS,
    NULL RECORDED_HOURS,
    SCH.OBJECT_NAME PUBLIC_HOLIDAY
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_M ASG,
    TABLE(PER_AVAILABILITY_DETAILS.GET_SCHEDULE_DETAILS(
        P_RESOURCE_TYPE => 'ASSIGN',
        P_RESOURCE_ID => ASG.ASSIGNMENT_ID,
        P_PERIOD_START => TO_DATE(:P_FROM_DATE, 'YYYY-MM-DD'),
        P_PERIOD_END => TO_DATE(:P_TO_DATE, 'YYYY-MM-DD') + 1
    )) SCH
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = ASG.PERSON_ID
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND ASG.ASSIGNMENT_TYPE IN ('E', 'C')
    AND ASG.PRIMARY_FLAG = 'Y'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    -- Public holiday only
    AND SCH.OBJECT_CATEGORY = 'PH'
    
    -- No timecard exists for this date
    AND NOT EXISTS (
        SELECT 1
        FROM HWM_EXT_TIMECARD_DETAIL_V TMD
        WHERE TMD.RESOURCE_ID = PAPF.PERSON_ID
        AND TMD.GRP_TYPE_NAME IN ('TimecardDay', 'Absences Entry')
        AND TMD.LAYER_CODE IN ('TIME_RPTD', 'ABSENCES')
        AND TRUNC(TMD.START_TIME) = TRUNC(SCH.START_DATE_TIME)
    )
    
    AND TRUNC(SCH.START_DATE_TIME) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
```

---

## 🔗 10. CROSS-MODULE INTEGRATION PATTERNS

### Pattern 10.1: Employee Master with Salary Components

**Problem:** Single query for employee details + compensation breakdown

**Solution:**

```sql
WITH ELEMENT_COMPONENTS AS (
    SELECT
        CSSC.PERSON_ID,
        SUBSTR(CSSC.COMPONENT_CODE, 5, 50) COMPONENT_NAME,
        CSSC.AMOUNT
    FROM
        CMP_SALARY_SIMPLE_COMPNTS CSSC,
        PER_ALL_PEOPLE_F PAP
    WHERE
        CSSC.PERSON_ID = PAP.PERSON_ID
        AND CSSC.COMPONENT_CODE NOT IN ('ORA_OVERALL_SALARY')
        AND TRUNC(SYSDATE) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
        AND TRUNC(SYSDATE) BETWEEN CSSC.SALARY_DATE_FROM AND CSSC.SALARY_DATE_TO
        
        -- Latest update
        AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
            SELECT MAX(TRUNC(LAST_UPDATE_DATE))
            FROM CMP_SALARY_SIMPLE_COMPNTS
            WHERE PERSON_ID = CSSC.PERSON_ID
        )
)
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    PAAF.ASSIGNMENT_NUMBER,
    
    -- Organization
    ORG.NAME DEPARTMENT,
    BU.BU_NAME BUSINESS_UNIT,
    LE.NAME LEGAL_ENTITY,
    
    -- Job details
    JOB.NAME JOB_TITLE,
    POS.NAME POSITION,
    GRADE.NAME GRADE,
    
    -- Dates
    TO_CHAR(PPOS.DATE_START, 'DD-MON-YYYY') HIRE_DATE,
    TO_CHAR(PPOS.ACTUAL_TERMINATION_DATE, 'DD-MON-YYYY') TERM_DATE,
    
    -- Salary components (pivot)
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'BASIC' THEN COMP.AMOUNT ELSE 0 END) BASIC_SALARY,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'HOUSING_ALLOWANCE' THEN COMP.AMOUNT ELSE 0 END) HOUSING_ALLOWANCE,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'TRANSPORT_ALLOWANCE' THEN COMP.AMOUNT ELSE 0 END) TRANSPORT_ALLOWANCE,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'OTHER_ALLOWANCE' THEN COMP.AMOUNT ELSE 0 END) OTHER_ALLOWANCE,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'OVERALL_SALARY' THEN COMP.AMOUNT ELSE 0 END) TOTAL_SALARY
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_M PAAF,
    PER_PERIODS_OF_SERVICE PPOS,
    PER_DEPARTMENTS ORG,
    FUN_ALL_BUSINESS_UNITS_V BU,
    PER_LEGAL_EMPLOYERS LE,
    PER_JOBS_F_VL JOB,
    HR_ALL_POSITIONS_F_VL POS,
    PER_GRADES_F_VL GRADE,
    ELEMENT_COMPONENTS COMP
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAPF.PERSON_ID = PPOS.PERSON_ID
    AND PAAF.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
    
    AND PAAF.ORGANIZATION_ID = ORG.ORGANIZATION_ID(+)
    AND PAAF.BUSINESS_UNIT_ID = BU.BU_ID
    AND PAAF.LEGAL_ENTITY_ID = LE.ORGANIZATION_ID
    AND PAAF.JOB_ID = JOB.JOB_ID(+)
    AND PAAF.POSITION_ID = POS.POSITION_ID(+)
    AND PAAF.GRADE_ID = GRADE.GRADE_ID(+)
    
    AND PAPF.PERSON_ID = COMP.PERSON_ID(+)
    
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.EFFECTIVE_LATEST_CHANGE = 'Y'
    AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ORG.EFFECTIVE_START_DATE(+) AND ORG.EFFECTIVE_END_DATE(+)
    AND TRUNC(SYSDATE) BETWEEN JOB.EFFECTIVE_START_DATE(+) AND JOB.EFFECTIVE_END_DATE(+)
    AND TRUNC(SYSDATE) BETWEEN POS.EFFECTIVE_START_DATE(+) AND POS.EFFECTIVE_END_DATE(+)
    AND TRUNC(SYSDATE) BETWEEN GRADE.EFFECTIVE_START_DATE(+) AND GRADE.EFFECTIVE_END_DATE(+)
    
GROUP BY
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    PAAF.ASSIGNMENT_NUMBER,
    ORG.NAME,
    BU.BU_NAME,
    LE.NAME,
    JOB.NAME,
    POS.NAME,
    GRADE.NAME,
    PPOS.DATE_START,
    PPOS.ACTUAL_TERMINATION_DATE
```

---

**END OF CROSS-MODULE PATTERNS - PART 1**

**Continue to Part 2 for more patterns...**

**Status:** Production-Ready  
**Last Updated:** 07-Jan-2026  
**Coverage:** 40 production queries analyzed
