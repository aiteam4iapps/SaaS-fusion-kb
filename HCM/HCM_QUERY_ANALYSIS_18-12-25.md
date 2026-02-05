# HCM Query Analysis - Comprehensive Pattern Extraction

**Date:** 18-12-25  
**Source:** 13 Production HCM SQL Queries  
**Purpose:** Extract patterns, tables, and best practices for Knowledge Base update

---

## 📊 Query Analysis Summary

| Query File | Focus Area | Lines | Key Tables | Complexity |
|------------|------------|-------|------------|------------|
| Employee Master Details Report | HR Core + Compensation | 319 | 25+ tables | High |
| New Joiner Report | HR Core + Cost Allocation | 98 | 16 tables | Medium |
| Payroll Compensation Query | Compensation + Elements | 127 | 12 tables | Medium |
| Payslip Report | Payroll + Banking | 402 | 30+ tables | Very High |
| Payroll Details Report (Hardcoded) | Payroll Elements | 444 | 28 tables | Very High |
| Payroll Detail Report (Dynamic) | Payroll + Classifications | 279 | 15 tables | High |
| CTC Reconciliation | Payroll + Element Values | 686 | 35+ tables | Very High |
| Accrual Detail Report | Leave Accruals + Gratuity | 758 | 40+ tables | Very High |
| Employee Timesheet Report | Time & Labor + Projects | 980 | 45+ tables | Extreme |
| Employee Details Report | HR Core + Extended | 466 | 30+ tables | Very High |
| End of Service Report | Termination + EOS | 504 | 35+ tables | Very High |
| Missing Timesheet Report | Time & Labor | 124 | 20 tables | Medium |
| Missing In & Out Report | Time Cards + Shifts | 493 | 25+ tables | Very High |

**Total Analysis:** 5,880 lines of production SQL  
**Unique Tables Identified:** 80+ tables  
**New Patterns Discovered:** 25+ patterns  

---

## 🗺️ New Tables Discovered (Not in Current KB)

### Category 1: HR Core Extensions

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `PER_ALL_ASSIGNMENTS_M` | PAAM | Assignment Managed Table (latest changes) | Yes (_M) |
| `PER_PEOPLE_LEGISLATIVE_F` | PPLF | Legislative data (SSN, Gender, Marital Status) | Yes |
| `PER_CITIZENSHIPS` | PC | Citizenship/Nationality information | No |
| `PER_PASSPORTS` | PP | Passport details | No |
| `PER_NATIONAL_IDENTIFIERS` | PNI | Emirates ID, SSN, Tax IDs | No |
| `PER_RELIGIONS` | PR | Religion information | No |
| `PER_PEOPLE_GROUPS` | PPG | People Group (payroll grouping) | No |
| `PER_PERSONS` | PS | Person core table (DOB, country of birth) | No |
| `PER_LOCATION_DETAILS_F_VL` | PL | Location details (view with translations) | Yes |
| `PER_GRADES_F_TL` | PGFT | Grade translations | Yes |
| `HR_ALL_POSITIONS_F_TL` | HAPFT | Position translations | Yes |
| `PER_PERSON_TYPE_USAGES_M` | PPTU | Person type usage history | Yes (_M) |
| `PER_ASSIGNMENT_STATUS_TYPES_TL` | PASTT | Assignment status translations | No |
| `FND_TERRITORIES_VL` | PVL | Country/Territory lookup | No |
| `PER_ACTION_OCCURRENCES` | PAC | Action occurrence (termination, transfer) | No |
| `PER_ACTIONS_VL` | ACTN | Actions master (leaving, promotion) | No |
| `PER_ACTION_REASONS_TL` | PART | Action reasons (resignation, termination) | No |
| `PER_ACTION_REASONS_B` | PAR | Action reasons base | No |

### Category 2: Payroll Core

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `PAY_ELEMENT_TYPES_F` | PETF | Element types (salary, allowances, deductions) | Yes |
| `PAY_ELEMENT_TYPES_TL` | PETT | Element type translations | No |
| `PAY_ELEMENT_TYPES_VL` | PETV | Element types view (with translations) | No |
| `PAY_INPUT_VALUES_F` | PIVF | Input values for elements | Yes |
| `PAY_INPUT_VALUES_TL` | PIVTL | Input value translations | No |
| `PAY_INPUT_VALUES_VL` | PIVV | Input values view | No |
| `PAY_ELEMENT_ENTRIES_F` | PEEF | Element entry header | Yes |
| `PAY_ELEMENT_ENTRIES_VL` | PEEV | Element entries view | Yes |
| `PAY_ELEMENT_ENTRY_VALUES_F` | PEEVF | Element entry values | Yes |
| `PAY_RUN_RESULTS` | PRR | Payroll run results | No |
| `PAY_RUN_RESULT_VALUES` | PRRV | Payroll result values | No |
| `PAY_PAYROLL_REL_ACTIONS` | PPRA | Payroll relationship actions | No |
| `PAY_PAYROLL_ACTIONS` | PPA | Payroll actions (runs) | No |
| `PAY_PAY_RELATIONSHIPS_DN` | PPRD | Payroll relationships denormalized | No |
| `PAY_TIME_PERIODS` | PTP | Time periods (payroll calendar) | No |
| `PAY_ALL_PAYROLLS_F` | PAP | Payroll definitions | Yes |
| `PAY_ELE_CLASSIFICATIONS` | PEC | Element classifications | No |
| `PAY_ELE_CLASSIFICATIONS_TL` | PECT | Classification translations | No |
| `PAY_CONSOLIDATION_SETS` | PCS | Consolidation sets | No |
| `PAY_REQUESTS` | PRQ | Payroll requests | No |
| `PAY_FLOW_INSTANCES` | PFI | Payroll flow instances | No |
| `PAY_CARD_PAYSLIPS_V` | PCPV | Payslip card view | No |
| `PAY_REL_GROUPS_DN` | PRG | Payroll relationship groups | No |
| `PAY_ASSIGNED_PAYROLLS_DN` | PAPD | Assigned payrolls denormalized | No |

### Category 3: Banking & Payment Methods

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `PAY_PERSONAL_PAYMENT_METHODS_F` | PPPMF | Personal payment methods | Yes |
| `PAY_BANK_ACCOUNTS` | PBA | Bank account details | No |
| `PAY_ORG_PAY_METHODS_VL` | POPM | Organization payment methods | Yes |
| `PAY_PAYMENT_TYPES_VL` | PPT | Payment types (bank transfer, check) | No |
| `PAY_PAYROLL_ASSIGNMENTS` | PPA | Payroll assignments | No |

### Category 4: Compensation Management

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `CMP_SALARY_SIMPLE_COMPNTS` | CSSC | Salary simple components | Yes (DATE_FROM/TO) |
| `CMP_ASG_SALARY_RATE_COMPTS_V` | CASR | Assignment salary rate components | Yes |
| `CMP_PLANS_VL` | CPVL | Compensation plans | No |
| `CMP_COMPONENTS_VL` | CCVL | Compensation components | No |
| `CMP_ATTRIBUTE_ELEMENTS` | CAE | Attribute elements | No |
| `CMP_PLAN_ATTRIBUTES` | CPA | Plan attributes | No |

### Category 5: Cost Accounting

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `PAY_COST_ALLOCATIONS_F` | CCPCA | Cost allocations | Yes |
| `PAY_COST_ALLOC_ACCOUNTS` | CCPCAA | Cost allocation accounts | No |
| `FUN_ALL_BUSINESS_UNITS_V` | FABU | Business units (Financials) | No |
| `HR_LEGAL_ENTITIES` | HLE | Legal entities | Yes |
| `PER_LEGAL_EMPLOYERS` | PLE | Legal employers | Yes |

### Category 6: Time and Labor

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `HWM_TM_REC_GRP_DETS` | TMD | Time record group details | No |
| `HWM_TM_REC_GRP_HDRS` | TMH | Time record group headers | No |
| `HWM_TM_REC_GRP_TYPES_TL` | TMGT | Time record group types | No |
| `HWM_TM_REP_ATRB_USAGES` | AUSG | Time reporting attribute usages | No |
| `HWM_TM_REP_ATRBS` | ATR | Time reporting attributes | No |
| `HWM_TM_SHIFT_DETS` | SHIFT | Shift details | No |
| `HWM_TM_SHIFT_HDRS` | SHIFTH | Shift headers | No |

### Category 7: Project Costing

| Table Name | Alias | Purpose | Date-Tracked |
|------------|-------|---------|--------------|
| `PJF_PROJECTS_ALL_VL` | PJP | Project definitions | No |
| `PJF_TASKS_V` | PJT | Project tasks | No |
| `PJF_EXP_TYPES_TL` | PJFEXP | Expenditure types | No |

---

## 🔑 Critical Pattern Discoveries

### Pattern 1: Managed Table (_M) Usage

**Discovery:** Queries use `PER_ALL_ASSIGNMENTS_M` instead of `PER_ALL_ASSIGNMENTS_F`

**Key Flags:**
```sql
AND PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'  -- Latest change only
AND PAAM.PRIMARY_FLAG = 'Y'             -- Primary assignment
AND PAAM.ASSIGNMENT_TYPE = 'E'          -- Employee (not Contingent/Pending)
```

**When to Use `_M` vs `_F`:**
- Use `_M` when you only need the latest effective record
- Use `_F` when you need full date-track history
- `_M` tables have `EFFECTIVE_LATEST_CHANGE` flag

### Pattern 2: Legislative Data Patterns

**Gender Decode:**
```sql
DECODE(PPLF.SEX, 'M', 'Male', 'F', 'Female') GENDER
```

**Marital Status Decode:**
```sql
DECODE(PPLF.MARITAL_STATUS, 'M', 'Married', 'S', 'Single', 'W', 'Widowed', 'D', 'Divorced')
```

**Nationality Lookup:**
```sql
SELECT H.MEANING
FROM PER_CITIZENSHIPS PC,
     HCM_LOOKUPS H
WHERE PAPF.PERSON_ID = PC.PERSON_ID
AND H.LOOKUP_CODE = PC.LEGISLATION_CODE
AND H.LOOKUP_TYPE = 'NATIONALITY'
```

### Pattern 3: Element Entry Pattern (Payroll Elements)

**Standard Pattern for Getting Element Values:**
```sql
SELECT SUM(PEEV.SCREEN_ENTRY_VALUE)
FROM PAY_ELEMENT_TYPES_VL PETF,
     PAY_INPUT_VALUES_VL PIVF,
     PAY_ELEMENT_ENTRIES_F PEEF,
     PAY_ELEMENT_ENTRY_VALUES_F PEEVF
WHERE PETF.ELEMENT_TYPE_ID = PIVF.ELEMENT_TYPE_ID
AND PETF.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
AND PEEF.ELEMENT_ENTRY_ID = PEEVF.ELEMENT_ENTRY_ID
AND PIVF.INPUT_VALUE_ID = PEEVF.INPUT_VALUE_ID
AND PETF.REPORTING_NAME = 'Basic Salary'  -- Element name
AND PIVF.NAME = 'Amount'                   -- Input value name
AND [DATE] BETWEEN PETF.EFFECTIVE_START_DATE AND PETF.EFFECTIVE_END_DATE
AND [DATE] BETWEEN PIVF.EFFECTIVE_START_DATE AND PIVF.EFFECTIVE_END_DATE
AND [DATE] BETWEEN PEEF.EFFECTIVE_START_DATE AND PEEF.EFFECTIVE_END_DATE
AND [DATE] BETWEEN PEEVF.EFFECTIVE_START_DATE AND PEEVF.EFFECTIVE_END_DATE
AND PEEF.PERSON_ID = [PERSON_ID]
```

**Key Points:**
- Use `REPORTING_NAME` or `BASE_ELEMENT_NAME` for element identification
- Use `PIVF.NAME` or `PIVF.BASE_NAME` for input value
- Date filtering on ALL 4 tables
- Common input value names: 'Amount', 'Pay Value', 'Basic Salary'

### Pattern 4: Payroll Run Results Pattern

**Standard Pattern for Getting Payroll Results:**
```sql
SELECT SUM(TO_NUMBER(PRRV.RESULT_VALUE))
FROM PAY_RUN_RESULT_VALUES PRRV,
     PAY_RUN_RESULTS PRR,
     PAY_PAYROLL_REL_ACTIONS PPRA,
     PAY_PAYROLL_ACTIONS PPA,
     PAY_TIME_PERIODS PTP,
     PAY_ELEMENT_TYPES_F PETF,
     PAY_INPUT_VALUES_F PIVF
WHERE PRRV.RUN_RESULT_ID = PRR.RUN_RESULT_ID
AND PRR.PAYROLL_REL_ACTION_ID = PPRA.PAYROLL_REL_ACTION_ID
AND PPRA.PAYROLL_ACTION_ID = PPA.PAYROLL_ACTION_ID
AND PPA.ACTION_TYPE IN ('Q', 'R')      -- QuickPay or Regular
AND PPA.ACTION_STATUS = 'C'            -- Complete
AND PPA.EARN_TIME_PERIOD_ID = PTP.TIME_PERIOD_ID
AND PETF.ELEMENT_TYPE_ID = PRR.ELEMENT_TYPE_ID
AND PIVF.INPUT_VALUE_ID = PRRV.INPUT_VALUE_ID
AND PPRA.RETRO_COMPONENT_ID IS NULL    -- Exclude retro
```

**Key Filters:**
- `ACTION_TYPE IN ('Q', 'R')` - QuickPay or Regular payroll
- `ACTION_STATUS = 'C'` - Complete status only
- `RETRO_COMPONENT_ID IS NULL` - Exclude retro adjustments

### Pattern 5: Compensation Component Pattern

**Getting Compensation Components:**
```sql
SELECT CSSC.COMPONENT_CODE,
       CSSC.AMOUNT,
       SUBSTR(CSSC.COMPONENT_CODE, 5, 50) COMPONENT_CODE1  -- Remove 'ORA_' prefix
FROM CMP_SALARY_SIMPLE_COMPNTS CSSC
WHERE CSSC.PERSON_ID = [PERSON_ID]
AND TRUNC(SYSDATE) BETWEEN TRUNC(CSSC.SALARY_DATE_FROM) AND TRUNC(CSSC.SALARY_DATE_TO)
AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
    SELECT MAX(TRUNC(LAST_UPDATE_DATE))
    FROM CMP_SALARY_SIMPLE_COMPNTS
    WHERE PERSON_ID = CSSC.PERSON_ID
)
```

**Component Code Pattern:**
- Format: `ORA_BASIC`, `ORA_HOUSING_ALLOWANCE`, `ORA_TRANSPORT_ALLOWANCE`
- Use `SUBSTR(COMPONENT_CODE, 5, 50)` to remove 'ORA_' prefix
- Filter by latest `LAST_UPDATE_DATE`

### Pattern 6: Payroll Name Lookup Pattern

**Standard Payroll Assignment Pattern:**
```sql
SELECT PAP.PAYROLL_NAME
FROM PER_ALL_PEOPLE_F PAPF,
     PAY_PAY_RELATIONSHIPS_DN PPE,
     PAY_REL_GROUPS_DN PRG,
     PAY_ASSIGNED_PAYROLLS_DN PAPD,
     PAY_ALL_PAYROLLS_F PAP
WHERE PAPF.PERSON_ID = PPE.PERSON_ID
AND PPE.PAYROLL_RELATIONSHIP_ID = PRG.PAYROLL_RELATIONSHIP_ID
AND PRG.RELATIONSHIP_GROUP_ID = PAPD.PAYROLL_TERM_ID
AND PAPD.PAYROLL_ID = PAP.PAYROLL_ID
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE) AND TRUNC(PAPF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAP.EFFECTIVE_START_DATE) AND PAP.EFFECTIVE_END_DATE)
```

### Pattern 7: Element Classification Pattern

**Grouping by Classification:**
```sql
FROM PAY_ELEMENT_TYPES_F PETF,
     PAY_ELE_CLASSIFICATIONS PEC,
     PAY_ELE_CLASSIFICATIONS_TL PECT
WHERE PETF.CLASSIFICATION_ID = PEC.CLASSIFICATION_ID
AND PEC.CLASSIFICATION_ID = PECT.CLASSIFICATION_ID
AND PECT.LANGUAGE = 'US'
AND PEC.BASE_CLASSIFICATION_NAME IN (
    'Standard Earnings',
    'Voluntary Deductions',
    'Social Insurance Deductions',
    'Involuntary Deductions'
)
```

**Common Classifications:**
- `Standard Earnings` - All earning elements
- `Voluntary Deductions` - Voluntary deductions
- `Social Insurance Deductions` - Social security, etc.
- `Involuntary Deductions` - Court orders, etc.
- `Supplemental Earnings` - Bonuses, commissions

### Pattern 8: Bank Account Pattern

**Bank Details Lookup:**
```sql
SELECT PBA.BANK_NAME,
       PBA.BANK_ACCOUNT_NAME,
       PBA.BANK_ACCOUNT_NUM,
       PBA.IBAN_NUMBER,
       PBA.CURRENCY_CODE,
       PBA.BANK_BRANCH_NAME
FROM PAY_PAYROLL_ASSIGNMENTS PPA,
     PAY_PERSONAL_PAYMENT_METHODS_F PPPMF,
     PAY_BANK_ACCOUNTS PBA
WHERE PPA.PAYROLL_RELATIONSHIP_ID = PPPMF.PAYROLL_RELATIONSHIP_ID
AND PPPMF.BANK_ACCOUNT_ID = PBA.BANK_ACCOUNT_ID
AND [DATE] BETWEEN PPPMF.EFFECTIVE_START_DATE AND PPPMF.EFFECTIVE_END_DATE
```

### Pattern 9: Cost Center / Cost Allocation Pattern

**Getting Cost Center Code:**
```sql
FROM PAY_COST_ALLOCATIONS_F CCPCA,
     PAY_COST_ALLOC_ACCOUNTS CCPCAA
WHERE CCPCAA.COST_ALLOCATION_RECORD_ID = CCPCA.COST_ALLOCATION_RECORD_ID
AND CCPCA.SOURCE_TYPE = 'ORG'
AND CCPCA.SOURCE_ID = [ORGANIZATION_ID]
AND CCPCAA.SOURCE_SUB_TYPE = 'COST'
AND [DATE] BETWEEN CCPCA.EFFECTIVE_START_DATE AND CCPCA.EFFECTIVE_END_DATE
```

**Segment Pattern:**
- `CCPCAA.SEGMENT2` typically contains cost center code

### Pattern 10: Time & Labor Attribute Pattern

**Getting Project/Task from Timesheet:**
```sql
SELECT PJP.SEGMENT1 PROJECT_NUMBER,
       PJP.NAME PROJECT_NAME,
       PJT.TASK_NUMBER,
       PJT.TASK_NAME
FROM HWM_TM_REP_ATRB_USAGES AUSG,
     HWM_TM_REP_ATRBS ATR,
     PJF_PROJECTS_ALL_VL PJP,
     PJF_TASKS_V PJT
WHERE [TM_REC_ID] = AUSG.USAGES_SOURCE_ID
AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
AND ATR.ATTRIBUTE_NUMBER1 = PJP.PROJECT_ID
AND ATR.ATTRIBUTE_NUMBER2 = PJT.TASK_ID(+)
AND AUSG.USAGES_SOURCE_VERSION = (
    SELECT MAX(A1.USAGES_SOURCE_VERSION)
    FROM HWM_TM_REP_ATRB_USAGES A1
    WHERE A1.USAGES_SOURCE_ID = [TM_REC_ID]
)
```

---

## 📝 Common CTE Patterns Found

### CTE 1: ELEMENT (Compensation Components)

```sql
WITH ELEMENT AS (
    SELECT
        CSSC.COMPONENT_CODE,
        CSSC.AMOUNT,
        CSSC.PERSON_ID,
        SUBSTR(CSSC.COMPONENT_CODE, 5, 50) COMPONENT_CODE1
    FROM CMP_SALARY_SIMPLE_COMPNTS CSSC,
         PER_ALL_PEOPLE_F PAP
    WHERE PAP.PERSON_ID = CSSC.PERSON_ID(+)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PAP.EFFECTIVE_START_DATE) AND TRUNC(PAP.EFFECTIVE_END_DATE)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(CSSC.SALARY_DATE_FROM) AND TRUNC(CSSC.SALARY_DATE_TO)
    AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
        SELECT MAX(TRUNC(LAST_UPDATE_DATE))
        FROM CMP_SALARY_SIMPLE_COMPNTS
        WHERE PERSON_ID = CSSC.PERSON_ID
    )
)
```

### CTE 2: PAYROLL_NAME

```sql
,PAYROLL_NAME AS (
    SELECT 
        PAPF.PERSON_NUMBER,
        PAP.PAYROLL_NAME,
        PAPF.PERSON_ID
    FROM PER_ALL_PEOPLE_F PAPF,
         PAY_PAY_RELATIONSHIPS_DN PPE,
         PAY_REL_GROUPS_DN PRG,
         PAY_ASSIGNED_PAYROLLS_DN PAPD,
         PAY_ALL_PAYROLLS_F PAP
    WHERE PAPF.PERSON_ID = PPE.PERSON_ID(+)
    AND PPE.PAYROLL_RELATIONSHIP_ID = PRG.PAYROLL_RELATIONSHIP_ID
    AND PRG.RELATIONSHIP_GROUP_ID = PAPD.PAYROLL_TERM_ID
    AND PAPD.PAYROLL_ID = PAP.PAYROLL_ID
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE) AND TRUNC(PAPF.EFFECTIVE_END_DATE)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PAP.EFFECTIVE_START_DATE) AND TRUNC(PAP.EFFECTIVE_END_DATE)
)
```

### CTE 3: BANK_DETAILS

```sql
,BANK_DETAILS AS (
    SELECT 
        PBA.BANK_ACCOUNT_ID,
        PBA.BANK_NAME,
        PBA.BANK_ACCOUNT_NAME,
        PBA.BANK_ACCOUNT_NUM BANK_ACCOUNT_NUMBER,
        PBA.CURRENCY_CODE,
        PBA.IBAN_NUMBER IBAN,
        PBA.BANK_BRANCH_NAME BRANCH_NAME,
        PPA.PERSON_ID,
        PPT.PAYMENT_TYPE_NAME PAY_NAME
    FROM PAY_PAYROLL_ASSIGNMENTS PPA,
         PAY_PERSONAL_PAYMENT_METHODS_F PPPMF,
         PAY_BANK_ACCOUNTS PBA,
         PAY_ORG_PAY_METHODS_VL POPM,
         PAY_PAYMENT_TYPES_VL PPT
    WHERE PPA.PAYROLL_RELATIONSHIP_ID = PPPMF.PAYROLL_RELATIONSHIP_ID(+)
    AND PPPMF.BANK_ACCOUNT_ID = PBA.BANK_ACCOUNT_ID(+)
    AND PPPMF.ORG_PAYMENT_METHOD_ID = POPM.ORG_PAYMENT_METHOD_ID(+)
    AND POPM.PAYMENT_TYPE_ID = PPT.PAYMENT_TYPE_ID(+)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PPPMF.EFFECTIVE_START_DATE) AND TRUNC(PPPMF.EFFECTIVE_END_DATE)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(POPM.EFFECTIVE_START_DATE) AND TRUNC(POPM.EFFECTIVE_END_DATE)
)
```

---

## ⚠️ Critical Observations

### 1. **PERSON_TYPE_ID Location Confirmed**
All queries correctly use `PAAF.PERSON_TYPE_ID` or `PAAM.PERSON_TYPE_ID`, NOT `PAPF.PERSON_TYPE_ID`.

### 2. **Managed Tables (_M) Benefits**
- Faster performance (single row per person at current date)
- Use `EFFECTIVE_LATEST_CHANGE = 'Y'` flag
- Common in reports where history not needed

### 3. **Element Entry vs Run Results**
- **Element Entries**: Current assignments/setup
- **Run Results**: Actual payroll calculations
- Use Element Entries for "what should be paid"
- Use Run Results for "what was paid"

### 4. **Date Filtering Complexity**
Many queries use `LEAST()` function for termination date handling:
```sql
LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('4712-12-31', 'YYYY-MM-DD')), [PERIOD_DATE])
```

### 5. **Multiple Language Filters**
Always include:
- `LANGUAGE = 'US'` for `_TL` tables
- `SOURCE_LANG = 'US'` for some tables
- `USERENV('LANG')` for dynamic language

---

## 📚 Recommended Knowledge Base Updates

### High Priority
1. ✅ Create PAY_MASTER.md (if doesn't exist) or enhance existing
2. ✅ Create PAY_REPOSITORIES.md with element/payroll CTEs
3. ✅ Update HR_REPOSITORIES.md with legislative, passport, citizenship CTEs
4. ✅ Create COMPENSATION module (CMP_MASTER, CMP_REPOSITORIES)
5. ✅ Create TIME_LABOR module (TL_MASTER, TL_REPOSITORIES)

### Medium Priority
6. ✅ Update HR_MASTER.md with managed table patterns
7. ✅ Add bank/payment patterns to PAY_REPOSITORIES
8. ✅ Document element entry vs run results patterns
9. ✅ Add cost allocation patterns

### Low Priority
10. Create project costing module (if needed)
11. Add specialized templates for each report type
12. Document termination/EOS patterns

---

**Status:** Analysis Complete ✅  
**Next Step:** Update Knowledge Base files with discovered patterns

---

**END OF ANALYSIS**

