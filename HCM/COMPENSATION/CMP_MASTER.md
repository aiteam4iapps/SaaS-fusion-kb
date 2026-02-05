# Compensation Master Instructions

**Module:** Compensation Management  
**Tag:** `#HCM #CMP #Compensation`  
**Status:** Production-Ready  
**Last Updated:** 13-Jan-2026  
**Version:** 2.0 (Merged with advanced patterns)

---

## 1. 🚨 Critical Compensation Constraints

*Violating these rules breaks compensation calculations.*

### 1.1 Element Entry Date Filtering
**Rule:** Always filter element entries by effective date for active compensation

```sql
AND :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
```

**Why:** Element entries are date-tracked; without date filtering, you get historical/future values.

### 1.2 Termination Date Handling
**Rule:** For terminated employees, use the lesser of termination date or period end date

```sql
LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TRUNC(:P_DATE)), TRUNC(:P_DATE))
```

**Why:** Element entries may exist beyond termination date; must cap at termination.

### 1.3 Processing Type Filter
**Rule:** Filter by `PROCESSING_TYPE = 'R'` for recurring elements

```sql
AND PETF.PROCESSING_TYPE = 'R'  -- Recurring only
```

**Processing Types:**
- `'R'` - Recurring (ongoing salary, allowances)
- `'N'` - Nonrecurring (bonuses, one-time payments)

**Why:** Compensation reports typically show recurring compensation, not one-time payments.

### 1.4 Classification Filter
**Rule:** Use classification to separate earnings from deductions

```sql
AND PEC.BASE_CLASSIFICATION_NAME IN ('Standard Earnings')
```

**Why:** Without classification filtering, totals include deductions and information elements.

### 1.5 Input Value Name
**Rule:** Use `NAME = 'Amount'` for element entries (not `'Pay Value'`)

```sql
AND UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
```

**Note:** Element Entries use `'Amount'`; Run Results use `'Pay Value'`.

---

## 2. 🗺️ Schema Map

### 2.1 Element Entry Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PEEF** | `PAY_ELEMENT_ENTRIES_F` | Element Entries (Date-Tracked) |
| **PEEV** | `PAY_ELEMENT_ENTRY_VALUES_F` | Entry Values (Date-Tracked) |
| **PETV** / **PETF** | `PAY_ELEMENT_TYPES_VL` / `PAY_ELEMENT_TYPES_F` | Element Type Definitions |
| **PIVL** / **PIVF** | `PAY_INPUT_VALUES_VL` / `PAY_INPUT_VALUES_F` | Input Value Definitions |
| **PEC** | `PAY_ELE_CLASSIFICATIONS` | Element Classifications |
| **PECT** | `PAY_ELE_CLASSIFICATIONS_TL` | Element Classification Translations |

### 2.2 Person & Assignment Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAPF** | `PER_ALL_PEOPLE_F` | Person Master |
| **PPNF** | `PER_PERSON_NAMES_F` | Person Names |
| **PAAM** | `PER_ALL_ASSIGNMENTS_M` | Assignments (Managed) |
| **PAAF** | `PER_ALL_ASSIGNMENTS_F` | Assignments (Date-Tracked) |
| **POPS** | `PER_PERIODS_OF_SERVICE` | Employment History |

### 2.3 Organization Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **HDORG** / **HAOUF** | `HR_ORGANIZATION_UNITS_F_TL` / `HR_ALL_ORGANIZATION_UNITS_F` | Organization Units |
| **PJF** | `PER_JOBS_F` | Jobs |
| **PGF** | `PER_GRADES_F` | Grades |
| **PPF** | `PER_POSITIONS_F` | Positions |
| **PLE** | `PER_LEGAL_ENTITIES` | Legal Entities |
| **BU** | `FUN_ALL_BUSINESS_UNITS_V` | Business Units |

---

## 3. 📋 Element Entry Patterns

### 3.1 Basic Salary Scalar Subquery

**Use Case:** Get current basic salary for an employee

**Pattern:**
```sql
(SELECT ROUND(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) / 12, 2)
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
 AND :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
 AND :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
 AND ROWNUM = 1
) BASIC_SALARY
```

**Note:** Dividing by 12 converts annual salary to monthly.

### 3.2 Gross Salary Scalar Subquery

**Use Case:** Get total gross salary (all earning elements)

**Pattern:**
```sql
(SELECT SUM(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE))
 FROM PAY_ELEMENT_TYPES_VL PETV,
      PAY_ELEMENT_ENTRIES_F PEEF,
      PAY_ELEMENT_ENTRY_VALUES_F PEEV,
      PAY_INPUT_VALUES_VL PIVL,
      PAY_ELE_CLASSIFICATIONS_TL PECT
 WHERE PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
 AND PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
 AND PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
 AND PETV.CLASSIFICATION_ID = PECT.CLASSIFICATION_ID
 AND PETV.PROCESSING_TYPE = 'R'
 AND UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
 AND PECT.LANGUAGE = 'US'
 AND UPPER(PECT.CLASSIFICATION_NAME) LIKE '%EARNING%'
 AND PEEF.PERSON_ID = PAPF.PERSON_ID
 AND :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
 AND :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
) GROSS_SALARY
```

### 3.3 Hardcoded Element Pattern (CTE)

**Use Case:** Get specific elements by name

**Pattern:**
```sql
,COMP_ELEMENTS AS (
    SELECT /*+ qb_name(COMP_EL) MATERIALIZE */
           PEEF.PERSON_ID
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Basic' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) BASIC
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Housing Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) HOUSING
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Transport Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) TRANSPORT
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Food Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) FOOD
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Mobile Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) MOBILE
    FROM   PAY_ELEMENT_TYPES_VL PETV,
           PAY_ELEMENT_ENTRIES_F PEEF,
           PAY_ELEMENT_ENTRY_VALUES_F PEEV,
           PAY_INPUT_VALUES_VL PIVL
    WHERE  PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
      AND  PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
      AND  PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
      AND  UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
      AND  :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
    GROUP BY PEEF.PERSON_ID
)
```

### 3.4 Dynamic Element Pattern (CTE)

**Use Case:** Get all elements without hardcoding names

**Pattern:**
```sql
,COMP_ALL_ELEMENTS AS (
    SELECT /*+ qb_name(COMP_ALL) MATERIALIZE */
           PEEF.PERSON_ID
          ,PETV.ELEMENT_NAME
          ,SUM(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE)) AMOUNT
    FROM   PAY_ELEMENT_TYPES_VL PETV,
           PAY_ELEMENT_ENTRIES_F PEEF,
           PAY_ELEMENT_ENTRY_VALUES_F PEEV,
           PAY_INPUT_VALUES_VL PIVL,
           PAY_ELE_CLASSIFICATIONS_TL PECT
    WHERE  PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
      AND  PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
      AND  PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
      AND  PETV.CLASSIFICATION_ID = PECT.CLASSIFICATION_ID
      AND  PETV.PROCESSING_TYPE = 'R'
      AND  UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
      AND  PECT.LANGUAGE = 'US'
      AND  UPPER(PECT.CLASSIFICATION_NAME) LIKE '%EARNING%'
      AND  :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
    GROUP BY PEEF.PERSON_ID, PETV.ELEMENT_NAME
)
```

---

## 4. 🔗 Standard Joins (Copy-Paste Ready)

### 4.1 Element Entry Full Chain

**Person → Element Entry → Entry Value → Element Type → Input Value:**
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PAY_ELEMENT_ENTRIES_F PEEF,
     PAY_ELEMENT_ENTRY_VALUES_F PEEV,
     PAY_ELEMENT_TYPES_VL PETV,
     PAY_INPUT_VALUES_VL PIVL,
     PAY_ELE_CLASSIFICATIONS_TL PECT
WHERE PAPF.PERSON_ID = PEEF.PERSON_ID
AND PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
AND PEEF.ELEMENT_TYPE_ID = PETV.ELEMENT_TYPE_ID
AND PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
AND PETV.ELEMENT_TYPE_ID = PIVL.ELEMENT_TYPE_ID
AND PETV.CLASSIFICATION_ID = PECT.CLASSIFICATION_ID
AND PECT.LANGUAGE = 'US'
AND :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
```

### 4.2 Assignment to Job Join

**Assignment → Job:**
```sql
FROM PER_ALL_ASSIGNMENTS_M PAAM,
     PER_JOBS_F PJF,
     PER_JOBS_F_TL PJFT
WHERE PAAM.JOB_ID = PJF.JOB_ID
AND PJF.JOB_ID = PJFT.JOB_ID
AND PJFT.LANGUAGE = 'US'
AND PAAM.PRIMARY_FLAG = 'Y'
AND PAAM.ASSIGNMENT_TYPE = 'E'
AND PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
AND TRUNC(SYSDATE) BETWEEN PJF.EFFECTIVE_START_DATE AND PJF.EFFECTIVE_END_DATE
AND TRUNC(SYSDATE) BETWEEN PJFT.EFFECTIVE_START_DATE AND PJFT.EFFECTIVE_END_DATE
```

### 4.3 Assignment to Grade Join

**Assignment → Grade:**
```sql
FROM PER_ALL_ASSIGNMENTS_M PAAM,
     PER_GRADES_F PGF,
     PER_GRADES_F_TL PGFT
WHERE PAAM.GRADE_ID = PGF.GRADE_ID
AND PGF.GRADE_ID = PGFT.GRADE_ID
AND PGFT.LANGUAGE = 'US'
AND TRUNC(SYSDATE) BETWEEN PGF.EFFECTIVE_START_DATE AND PGF.EFFECTIVE_END_DATE
AND TRUNC(SYSDATE) BETWEEN PGFT.EFFECTIVE_START_DATE AND PGFT.EFFECTIVE_END_DATE
```

### 4.4 Assignment to Position Join

**Assignment → Position:**
```sql
FROM PER_ALL_ASSIGNMENTS_M PAAM,
     PER_POSITIONS_F PPF,
     PER_POSITIONS_F_TL PPFT
WHERE PAAM.POSITION_ID = PPF.POSITION_ID
AND PPF.POSITION_ID = PPFT.POSITION_ID
AND PPFT.LANGUAGE = 'US'
AND TRUNC(SYSDATE) BETWEEN PPF.EFFECTIVE_START_DATE AND PPF.EFFECTIVE_END_DATE
AND TRUNC(SYSDATE) BETWEEN PPFT.EFFECTIVE_START_DATE AND PPFT.EFFECTIVE_END_DATE
```

---

## 5. 📊 Standard Filters

### 5.1 Active Employees Only

```sql
AND PAAM.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
AND PAAM.PRIMARY_FLAG = 'Y'
AND PAAM.ASSIGNMENT_TYPE = 'E'
AND PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
```

### 5.2 Recurring Elements Only

```sql
AND PETV.PROCESSING_TYPE = 'R'
```

### 5.3 Earnings Only

```sql
AND PECT.LANGUAGE = 'US'
AND UPPER(PECT.CLASSIFICATION_NAME) LIKE '%EARNING%'
```

### 5.4 Specific Element by Name

**By BASE_ELEMENT_NAME:**
```sql
AND PETV.BASE_ELEMENT_NAME = 'Basic'
```

**By ELEMENT_NAME (translated):**
```sql
AND PETV.ELEMENT_NAME = 'Basic Salary'
```

### 5.5 Effective Date Filtering

**For Active Employees:**
```sql
AND :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
```

**For Terminated Employees:**
```sql
AND LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TRUNC(:P_DATE)), TRUNC(:P_DATE))
    BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TRUNC(:P_DATE)), TRUNC(:P_DATE))
    BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
```

---

## 6. ⚠️ Common Pitfalls

### 6.1 Not Filtering by Effective Date
**Problem:** Getting historical or future compensation values  
**Cause:** Missing date filters on element entries

**Solution:**
```sql
AND :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
AND :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
```

### 6.2 Mixing Annual and Monthly Salaries
**Problem:** Basic salary is annual, but other allowances are monthly  
**Cause:** Not dividing basic salary by 12

**Solution:**
```sql
ROUND(BASIC_ANNUAL / 12, 2) BASIC_MONTHLY
```

### 6.3 Using 'Pay Value' Instead of 'Amount'
**Problem:** No results from element entries  
**Cause:** Element entries use `'Amount'`, not `'Pay Value'`

**Solution:**
```sql
AND UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'  -- For element entries
```

### 6.4 Including Nonrecurring Elements
**Problem:** Bonuses, one-time payments skew totals  
**Cause:** Not filtering by `PROCESSING_TYPE`

**Solution:**
```sql
AND PETV.PROCESSING_TYPE = 'R'  -- Recurring only
```

### 6.5 Missing Classification Filter
**Problem:** Totals include deductions and information elements  
**Cause:** Not filtering by classification

**Solution:**
```sql
AND UPPER(PECT.CLASSIFICATION_NAME) LIKE '%EARNING%'
```

### 6.6 Not Handling Terminated Employees
**Problem:** NULL compensation for terminated employees  
**Cause:** Not capping date at termination date

**Solution:**
```sql
LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TRUNC(:P_DATE)), TRUNC(:P_DATE))
```

---

## 7. 💡 Calculation Patterns

### 7.1 Monthly from Annual

```sql
ROUND(ANNUAL_AMOUNT / 12, 2) MONTHLY_AMOUNT
```

### 7.2 Annual from Monthly

```sql
(MONTHLY_AMOUNT * 12) ANNUAL_AMOUNT
```

### 7.3 Gross Salary (All Allowances)

```sql
(NVL(BASIC, 0) + 
 NVL(HOUSING, 0) + 
 NVL(TRANSPORT, 0) +
 NVL(FOOD, 0) +
 NVL(MOBILE, 0) +
 NVL(OTHER, 0)) GROSS_SALARY
```

### 7.4 Total Compensation (with Benefits)

```sql
(GROSS_SALARY + 
 NVL(AIR_TICKET_PROVISION, 0) +
 NVL(GRATUITY_PROVISION, 0) +
 NVL(MEDICAL_INSURANCE, 0)) TOTAL_COMPENSATION
```

---

## 8. 📅 Parameters

| Parameter | Format | Description | Example |
|-----------|--------|-------------|---------|
| `:P_DATE` | Date | Effective date | TRUNC(SYSDATE) |
| `:P_PERIOD` | String | Period (DD-MM-YYYY) | '31-12-2024' |
| `:P_EMP_NO` | String | Employee number | '12345' |
| `:P_DEPT` | String | Department name | 'Finance' |
| `:P_ELEMENT_NAME` | String | Element name | 'Basic' |

---

## 9. 🔍 Advanced Patterns

### 9.1 Cost Center Decode (Client-Specific)

**Hardcoded mapping of department to cost center:**
```sql
DECODE(DEPARTMENT_NAME,
    'Business Support', '502',
    'CEO Off', '510',
    'Human Resources', '512',
    'Finance', '501',
    'IT', '508',
    'Marketing', '506',
    'Production', '505',
    ...) COST_CENTER
```

### 9.2 Salary Band Analysis

**Grouping by salary ranges:**
```sql
CASE
    WHEN BASIC_SALARY < 5000 THEN 'Band 1 (< 5K)'
    WHEN BASIC_SALARY BETWEEN 5000 AND 10000 THEN 'Band 2 (5K-10K)'
    WHEN BASIC_SALARY BETWEEN 10000 AND 20000 THEN 'Band 3 (10K-20K)'
    ELSE 'Band 4 (> 20K)'
END SALARY_BAND
```

---

## 10. 🚀 Advanced Compensation Patterns (07-Jan-2026)

### 10.1 CMP_SALARY_SIMPLE_COMPNTS with Latest Update

**Problem:** Get current salary components with latest update

**Pattern:**
```sql
WITH ELEMENT_COMPONENTS AS (
    SELECT
        CSSC.PERSON_ID,
        CSSC.COMPONENT_CODE,
        SUBSTR(CSSC.COMPONENT_CODE, 5, 50) COMPONENT_NAME,  -- Remove 'ORA_' prefix
        CSSC.AMOUNT,
        CSSC.SALARY_ID,
        CSSC.LAST_UPDATE_DATE
    FROM
        CMP_SALARY_SIMPLE_COMPNTS CSSC,
        PER_ALL_PEOPLE_F PAP
    WHERE
        CSSC.PERSON_ID = PAP.PERSON_ID
        AND CSSC.COMPONENT_CODE NOT IN ('ORA_OVERALL_SALARY')  -- Exclude total
        
        -- Current salary period
        AND TRUNC(SYSDATE) BETWEEN CSSC.SALARY_DATE_FROM AND CSSC.SALARY_DATE_TO
        
        -- Latest update ONLY
        AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
            SELECT MAX(TRUNC(LAST_UPDATE_DATE))
            FROM CMP_SALARY_SIMPLE_COMPNTS
            WHERE PERSON_ID = CSSC.PERSON_ID
        )
        
        AND TRUNC(SYSDATE) BETWEEN PAP.EFFECTIVE_START_DATE AND PAP.EFFECTIVE_END_DATE
)
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    
    -- Pivot components
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'BASIC' THEN COMP.AMOUNT ELSE 0 END) BASIC_SALARY,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'HOUSING_ALLOWANCE' THEN COMP.AMOUNT ELSE 0 END) HOUSING_ALLOWANCE,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'TRANSPORT_ALLOWANCE' THEN COMP.AMOUNT ELSE 0 END) TRANSPORT_ALLOWANCE,
    MAX(CASE WHEN COMP.COMPONENT_NAME = 'MOBILE_ALLOWANCE' THEN COMP.AMOUNT ELSE 0 END) MOBILE_ALLOWANCE
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    ELEMENT_COMPONENTS COMP
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = COMP.PERSON_ID(+)
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
GROUP BY
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME
```

**Critical Points:**
- **ALWAYS filter by `MAX(TRUNC(LAST_UPDATE_DATE))`** - Components can be updated
- **ALWAYS filter by date range** - `SALARY_DATE_FROM` to `SALARY_DATE_TO`
- **Remove 'ORA_' prefix** - Use `SUBSTR(COMPONENT_CODE, 5, 50)`
- **Exclude total** - `NOT IN ('ORA_OVERALL_SALARY')`

### 10.2 Child Allowance Calculation (UAE Nationals)

**Problem:** Calculate child allowance for UAE nationals (AED 600 per eligible child)

**Pattern:**
```sql
SELECT
    PAPF.PERSON_ID,
    PAPF.PERSON_NUMBER,
    
    -- Child count (eligible for allowance)
    (SELECT COUNT(PCRF.CONT_ATTRIBUTE3)
     FROM
         PER_CONTACT_RELSHIPS_F PCRF,
         PER_CITIZENSHIPS PEC
     WHERE
         PCRF.PERSON_ID = PAPF.PERSON_ID
         AND PEC.PERSON_ID = PAPF.PERSON_ID
         AND PCRF.CONTACT_TYPE = 'C'  -- Child
         AND PCRF.CONT_ATTRIBUTE3 = 'Y'  -- Allowance eligible
         AND PEC.LEGISLATION_CODE = 'AE'  -- UAE nationals only
         AND TRUNC(SYSDATE) BETWEEN PCRF.EFFECTIVE_START_DATE AND PCRF.EFFECTIVE_END_DATE
    ) ELIGIBLE_CHILDREN_COUNT,
    
    -- Child allowance amount
    (ELIGIBLE_CHILDREN_COUNT * 600) CHILD_ALLOWANCE_AMOUNT
    
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_CITIZENSHIPS PEC
WHERE
    PAPF.PERSON_ID = PEC.PERSON_ID
    AND PEC.LEGISLATION_CODE = 'AE'
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
```

**Business Rules:**
- **AED 600 per child** (fixed amount)
- **UAE nationals only** (LEGISLATION_CODE = 'AE')
- **Eligible flag required** (CONT_ATTRIBUTE3 = 'Y')
- **Contact type = 'C'** (Child)

### 10.3 Airfare Allowance by Dependents (Age-Based)

**Problem:** Calculate airfare allowance based on dependent ages and UDT rates

**UDT Tables:**
- `AIRFARE_ALLOWANCE_ADULT` - Adult rates by destination
- `AIRFARE_ALLOWANCE_CHILD` - Child rates by destination  
- `AIRFARE_ALLOWANCE_INFANT` - Infant rates by destination

**Age Breakdowns:**
- **Infant:** < 2 years
- **Child:** 2-11 years
- **Adult:** > 11 years
- **Spouse:** Any age (adult rate)

**Pattern:**
```sql
WITH DEPENDENT_COUNTS AS (
    SELECT
        PAPF.PERSON_ID,
        -- Infant (< 2 years)
        SUM(CASE 
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, PP.DATE_OF_BIRTH) / 12) < 2 
            THEN 1 ELSE 0 
        END) INFANT_COUNT,
        -- Child (2-11 years)
        SUM(CASE 
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, PP.DATE_OF_BIRTH) / 12) BETWEEN 2 AND 11 
            THEN 1 ELSE 0 
        END) CHILD_COUNT,
        -- Adult dependent (> 11 years)
        SUM(CASE 
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, PP.DATE_OF_BIRTH) / 12) > 11 
            THEN 1 ELSE 0 
        END) ADULT_DEPENDENT_COUNT,
        -- Spouse
        SUM(CASE WHEN PCRF.CONTACT_TYPE = 'S' THEN 1 ELSE 0 END) SPOUSE_COUNT
    FROM
        PER_ALL_PEOPLE_F PAPF,
        PER_CONTACT_RELSHIPS_F PCRF,
        PER_PERSONS PP
    WHERE
        PAPF.PERSON_ID = PCRF.PERSON_ID
        AND PCRF.CONTACT_PERSON_ID = PP.PERSON_ID
        AND PCRF.CONTACT_TYPE IN ('C', 'IN_D', 'IN_S', 'S')
        AND PCRF.CONT_ATTRIBUTE1 = 'Y'  -- Airfare eligible
        AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
        AND TRUNC(SYSDATE) BETWEEN PCRF.EFFECTIVE_START_DATE AND PCRF.EFFECTIVE_END_DATE
    GROUP BY PAPF.PERSON_ID
)
SELECT ...
```

### 10.4 CTC Reconciliation Formula

**Problem:** Calculate total cost-to-company including all components

**CTC Components:**
1. **Direct Cash Compensation:**  Net Salary (Earnings - Deductions)
2. **Provisions (Accruals):** Airfare + Leave Accrual + Gratuity Liability
3. **Total CTC:** NET SALARY + TOTAL PROVISIONS

**Formula:**
```sql
(NET_SALARY +
 NVL(PERSON_AIR_TICKET_PROV, 0) +
 NVL(SPOUSE_AIR_TICKET_PROV, 0) +
 NVL(CHILD_AIR_TICKET_PROV, 0) +
 NVL(GRATUITY_LIABILITY, 0) +
 NVL(ANNUAL_LEAVE_ACCRUAL, 0)) TOTAL_COST_TO_COMPANY
```

### 10.5 End of Service (EOS) Compensation

**EOS Components:**
1. **Leave Encashment** = (Basic + Housing) / 30 × Leave Balance Days
2. **Gratuity** = Total gratuity balance (from payroll or calculation)
3. **Airfare** = Self + Spouse + Children (from UDT rates)
4. **Total EOS** = Sum of all components

**Pattern:**
```sql
SELECT
    -- Calculate EOS totals
    ((BASIC_SALARY + HOUSING_ALLOWANCE) / 30) ONE_DAY_SALARY,
    (((BASIC_SALARY + HOUSING_ALLOWANCE) / 30) * LEAVE_BALANCE_DAYS) LEAVE_ENCASHMENT,
    GRATUITY_BALANCE,
    
    -- Total EOS payment
    ((((BASIC_SALARY + HOUSING_ALLOWANCE) / 30) * LEAVE_BALANCE_DAYS) +
     GRATUITY_BALANCE +
     AIR_FARE_SELF +
     AIR_FARE_SPOUSE +
     AIR_FARE_CHILD +
     AIR_FARE_INFANT +
     AIR_FARE_ADULT_DEPENDENT) TOTAL_EOS_PAYMENT
FROM ...
WHERE
    PAAF.ASSIGNMENT_STATUS_TYPE = 'INACTIVE'  -- Terminated only
```

---

## 11. 🔑 Key Compensation Tables

### 11.1 CMP_SALARY_SIMPLE_COMPNTS (Simple Compensation)

**Purpose:** Store salary components (base, allowances)

**Critical Columns:**
- `PERSON_ID` - Employee
- `COMPONENT_CODE` - Component type (e.g., 'ORA_BASIC', 'ORA_HOUSING_ALLOWANCE')
- `AMOUNT` - Component amount
- `SALARY_DATE_FROM` / `SALARY_DATE_TO` - Effective period
- `LAST_UPDATE_DATE` - Update timestamp (CRITICAL for latest)

**Key Pattern:**
```sql
WHERE TRUNC(LAST_UPDATE_DATE) = (
    SELECT MAX(TRUNC(LAST_UPDATE_DATE))
    FROM CMP_SALARY_SIMPLE_COMPNTS
    WHERE PERSON_ID = CSSC.PERSON_ID
)
```

### 11.2 CMP_ASG_SALARY_RATE_COMPTS_V (Rate Components View)

**Purpose:** Assignment-level salary rate components

**Columns:**
- `PERSON_ID`, `RATE_NAME`, `RATE_AMOUNT`, `DATE_FROM` / `DATE_TO`

### 11.3 CMP_ATTRIBUTE_ELEMENTS (Compensation Plan Link)

**Purpose:** Link pay elements to compensation plans

**Critical Columns:**
- `ELEMENT_TYPE_ID` - Pay element
- `PLAN_ATTRIBUTE_ID` - Links to CMP_PLAN_ATTRIBUTES
- `COMP_TYPE` - 'ICD' for Individual Compensation

### 11.4 FF_USER_* Tables (UDTs for Compensation)

**Common UDTs:**
- `AIRFARE_ALLOWANCE_ADULT` - Adult airfare rates
- `AIRFARE_ALLOWANCE_CHILD` - Child airfare rates
- `AIRFARE_ALLOWANCE_INFANT` - Infant airfare rates
- `EPG_ANNUAL_BALANCE` - Leave entitlement by grade

**Structure:**
- **Rows:** Grades or destinations
- **Columns:** Classes (Economy/Business) or entitlement values
- **Values:** Rates or days

---

**Last Updated:** 13-Jan-2026  
**Status:** Production-Ready  
**Version:** 2.0 (Merged with advanced patterns)  
**Source:** 6 Production Compensation Queries (Employee Master Details, CTC Reconciliation, EOS, Salary Components, Airfare Allowance, Child Allowance)

