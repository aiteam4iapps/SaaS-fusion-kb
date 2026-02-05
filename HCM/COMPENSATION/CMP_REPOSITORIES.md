# Compensation Repositories

**Module:** Compensation Management  
**Tag:** `#HCM #CMP #Repositories`  
**Status:** Production-Ready  
**Last Updated:** 13-Jan-2026  
**Version:** 2.0 (Merged with update file)

---

## Critical Rules

1. **NEVER** write fresh compensation joins from scratch
2. **ALWAYS** copy these CTEs as-is
3. **ALWAYS** include `/*+ qb_name(NAME) MATERIALIZE */` hints
4. **ALWAYS** filter by effective date for element entries
5. **ALWAYS** use `PROCESSING_TYPE = 'R'` for recurring compensation

---

## 1. Basic Salary CTEs

### 1.1 CMP_BASIC_SALARY

**Purpose:** Get current basic salary (monthly)

**When to Use:** For salary listings, compensation reports

```sql
CMP_BASIC_SAL AS (
    SELECT /*+ qb_name(CMP_BASIC) MATERIALIZE */
           PEEF.PERSON_ID
          ,ROUND(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) / 12, 2) MONTHLY_BASIC
          ,TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) ANNUAL_BASIC
    FROM   PAY_ELEMENT_TYPES_VL PETV,
           PAY_ELEMENT_ENTRIES_F PEEF,
           PAY_ELEMENT_ENTRY_VALUES_F PEEV,
           PAY_INPUT_VALUES_VL PIVL
    WHERE  PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
      AND  PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
      AND  PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
      AND  PETV.BASE_ELEMENT_NAME = 'Basic'
      AND  UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
      AND  :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEV.EFFECTIVE_END_DATE)
)
```

---

## 2. Gross Salary CTEs

### 2.1 CMP_GROSS_SALARY

**Purpose:** Get total gross salary (all recurring earning elements)

**When to Use:** For total compensation reports, CTC calculations

```sql
CMP_GROSS_SAL AS (
    SELECT /*+ qb_name(CMP_GROSS) MATERIALIZE */
           PEEF.PERSON_ID
          ,SUM(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE)) GROSS_AMOUNT
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
      AND  :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEV.EFFECTIVE_END_DATE)
    GROUP BY PEEF.PERSON_ID
)
```

---

## 3. Hardcoded Element CTEs

### 3.1 CMP_ALLOWANCES_HARD

**Purpose:** Get specific allowances by hardcoded element names

**When to Use:** When element names are standardized and known

```sql
CMP_ALLOW_HARD AS (
    SELECT /*+ qb_name(CMP_ALLOW_H) MATERIALIZE */
           PEEF.PERSON_ID
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Basic' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) / 12 END) BASIC
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Housing Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) HOUSING
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Transport Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) TRANSPORT
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Food Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) FOOD
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Mobile Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) MOBILE
          ,SUM(CASE WHEN PETV.BASE_ELEMENT_NAME = 'Other Allowance' 
                    THEN TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) END) OTHER_ALLOWANCE
    FROM   PAY_ELEMENT_TYPES_VL PETV,
           PAY_ELEMENT_ENTRIES_F PEEF,
           PAY_ELEMENT_ENTRY_VALUES_F PEEV,
           PAY_INPUT_VALUES_VL PIVL
    WHERE  PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
      AND  PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
      AND  PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
      AND  UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
      AND  :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEV.EFFECTIVE_END_DATE)
    GROUP BY PEEF.PERSON_ID
)
```

---

## 4. Dynamic Element CTEs

### 4.1 CMP_ALL_ELEMENTS

**Purpose:** Get all earning elements without hardcoding names

**When to Use:** When element names vary or are not known in advance

```sql
CMP_ALL_ELEM AS (
    SELECT /*+ qb_name(CMP_ALL_EL) MATERIALIZE */
           PEEF.PERSON_ID
          ,PETV.ELEMENT_NAME
          ,TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) AMOUNT
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
      AND  :P_DATE BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  :P_DATE BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) 
                       AND TRUNC(PEEV.EFFECTIVE_END_DATE)
)
```

---

## 5. Employee Master CTEs

### 5.1 CMP_EMPLOYEE_MASTER

**Purpose:** Get employee master with assignment details

**When to Use:** For employee compensation listings

```sql
CMP_EMP_MASTER AS (
    SELECT /*+ qb_name(CMP_EMP) MATERIALIZE */
           PAPF.PERSON_ID
          ,PAPF.PERSON_NUMBER
          ,PPNF.FULL_NAME
          ,TO_CHAR(PAPF.START_DATE, 'DD-MON-YYYY') HIRE_DATE
          ,PAAM.ASSIGNMENT_ID
          ,PAAM.ASSIGNMENT_NUMBER
          ,PAAM.ASSIGNMENT_STATUS_TYPE
          ,PLE.NAME LEGAL_ENTITY
          ,BU.BU_NAME BUSINESS_UNIT
          ,HDORG.NAME DEPARTMENT
          ,PJFT.NAME JOB_NAME
          ,PGFT.NAME GRADE_NAME
          ,PPFT.NAME POSITION_NAME
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F PPNF
          ,PER_ALL_ASSIGNMENTS_M PAAM
          ,PER_LEGAL_ENTITIES PLE
          ,FUN_ALL_BUSINESS_UNITS_V BU
          ,HR_ORGANIZATION_UNITS_F_TL HDORG
          ,PER_JOBS_F PJF
          ,PER_JOBS_F_TL PJFT
          ,PER_GRADES_F PGF
          ,PER_GRADES_F_TL PGFT
          ,PER_POSITIONS_F PPF
          ,PER_POSITIONS_F_TL PPFT
    WHERE  PAPF.PERSON_ID = PPNF.PERSON_ID
      AND  PAPF.PERSON_ID = PAAM.PERSON_ID
      AND  PAAM.LEGAL_ENTITY_ID = PLE.ORGANIZATION_ID
      AND  PAAM.BUSINESS_UNIT_ID = BU.BU_ID(+)
      AND  PAAM.ORGANIZATION_ID = HDORG.ORGANIZATION_ID
      AND  PAAM.JOB_ID = PJF.JOB_ID(+)
      AND  PJF.JOB_ID = PJFT.JOB_ID(+)
      AND  PAAM.GRADE_ID = PGF.GRADE_ID(+)
      AND  PGF.GRADE_ID = PGFT.GRADE_ID(+)
      AND  PAAM.POSITION_ID = PPF.POSITION_ID(+)
      AND  PPF.POSITION_ID = PPFT.POSITION_ID(+)
      AND  TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
      AND  PPNF.NAME_TYPE = 'GLOBAL'
      AND  TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
      AND  PAAM.PRIMARY_FLAG = 'Y'
      AND  PAAM.ASSIGNMENT_TYPE = 'E'
      AND  PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
      AND  HDORG.LANGUAGE = 'US'
      AND  TRUNC(SYSDATE) BETWEEN HDORG.EFFECTIVE_START_DATE AND HDORG.EFFECTIVE_END_DATE
      AND  PJFT.LANGUAGE(+) = 'US'
      AND  TRUNC(SYSDATE) BETWEEN PJF.EFFECTIVE_START_DATE(+) AND PJF.EFFECTIVE_END_DATE(+)
      AND  TRUNC(SYSDATE) BETWEEN PJFT.EFFECTIVE_START_DATE(+) AND PJFT.EFFECTIVE_END_DATE(+)
      AND  PGFT.LANGUAGE(+) = 'US'
      AND  TRUNC(SYSDATE) BETWEEN PGF.EFFECTIVE_START_DATE(+) AND PGF.EFFECTIVE_END_DATE(+)
      AND  TRUNC(SYSDATE) BETWEEN PGFT.EFFECTIVE_START_DATE(+) AND PGFT.EFFECTIVE_END_DATE(+)
      AND  PPFT.LANGUAGE(+) = 'US'
      AND  TRUNC(SYSDATE) BETWEEN PPF.EFFECTIVE_START_DATE(+) AND PPF.EFFECTIVE_END_DATE(+)
      AND  TRUNC(SYSDATE) BETWEEN PPFT.EFFECTIVE_START_DATE(+) AND PPFT.EFFECTIVE_END_DATE(+)
)
```

---

## 6. Terminated Employee CTEs

### 6.1 CMP_TERM_EMPLOYEE

**Purpose:** Get compensation for terminated employees

**When to Use:** For end-of-service reports, exit compensation

```sql
CMP_TERM_EMP AS (
    SELECT /*+ qb_name(CMP_TERM) MATERIALIZE */
           PAPF.PERSON_ID
          ,PAPF.PERSON_NUMBER
          ,PPNF.FULL_NAME
          ,TO_CHAR(PAPF.START_DATE, 'DD-MON-YYYY') HIRE_DATE
          ,TO_CHAR(POPS.ACTUAL_TERMINATION_DATE, 'DD-MON-YYYY') TERMINATION_DATE
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F PPNF
          ,PER_PERIODS_OF_SERVICE POPS
    WHERE  PAPF.PERSON_ID = PPNF.PERSON_ID
      AND  PAPF.PERSON_ID = POPS.PERSON_ID
      AND  POPS.ACTUAL_TERMINATION_DATE IS NOT NULL
      AND  POPS.ACTUAL_TERMINATION_DATE BETWEEN :P_START_DATE AND :P_END_DATE
      AND  PPNF.NAME_TYPE = 'GLOBAL'
      AND  TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
      AND  TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
)
```

### 6.2 CMP_TERM_COMP

**Purpose:** Get compensation for terminated employees as of termination date

**When to Use:** For final settlement, exit calculations

```sql
CMP_TERM_COMP AS (
    SELECT /*+ qb_name(CMP_TERM_C) MATERIALIZE */
           PEEF.PERSON_ID
          ,SUM(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE)) GROSS_AT_TERMINATION
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERIODS_OF_SERVICE POPS
          ,PAY_ELEMENT_TYPES_VL PETV
          ,PAY_ELEMENT_ENTRIES_F PEEF
          ,PAY_ELEMENT_ENTRY_VALUES_F PEEV
          ,PAY_INPUT_VALUES_VL PIVL
          ,PAY_ELE_CLASSIFICATIONS_TL PECT
    WHERE  PAPF.PERSON_ID = POPS.PERSON_ID
      AND  PAPF.PERSON_ID = PEEF.PERSON_ID
      AND  PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
      AND  PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
      AND  PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
      AND  PETV.CLASSIFICATION_ID = PECT.CLASSIFICATION_ID
      AND  PETV.PROCESSING_TYPE = 'R'
      AND  UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
      AND  PECT.LANGUAGE = 'US'
      AND  UPPER(PECT.CLASSIFICATION_NAME) LIKE '%EARNING%'
      AND  POPS.ACTUAL_TERMINATION_DATE IS NOT NULL
      AND  LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TO_DATE('4712-12-31', 'YYYY-MM-DD')), 
                 TO_DATE(:P_DATE, 'YYYY-MM-DD'))
           BETWEEN TRUNC(PEEF.EFFECTIVE_START_DATE) AND TRUNC(PEEF.EFFECTIVE_END_DATE)
      AND  LEAST(NVL(POPS.ACTUAL_TERMINATION_DATE, TO_DATE('4712-12-31', 'YYYY-MM-DD')), 
                 TO_DATE(:P_DATE, 'YYYY-MM-DD'))
           BETWEEN TRUNC(PEEV.EFFECTIVE_START_DATE) AND TRUNC(PEEV.EFFECTIVE_END_DATE)
    GROUP BY PEEF.PERSON_ID
)
```

---

## 7. Compensation History CTEs

### 7.1 CMP_SAL_HISTORY

**Purpose:** Get salary change history for a person

**When to Use:** For salary progression reports, compensation analysis

```sql
CMP_SAL_HIST AS (
    SELECT /*+ qb_name(CMP_HIST) MATERIALIZE */
           PEEF.PERSON_ID
          ,PEEF.EFFECTIVE_START_DATE
          ,PEEF.EFFECTIVE_END_DATE
          ,TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) SALARY_AMOUNT
          ,LAG(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE)) 
               OVER (PARTITION BY PEEF.PERSON_ID ORDER BY PEEF.EFFECTIVE_START_DATE) PREV_SALARY
          ,TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE) - 
           LAG(TO_NUMBER(PEEV.SCREEN_ENTRY_VALUE)) 
               OVER (PARTITION BY PEEF.PERSON_ID ORDER BY PEEF.EFFECTIVE_START_DATE) SALARY_CHANGE
    FROM   PAY_ELEMENT_TYPES_VL PETV,
           PAY_ELEMENT_ENTRIES_F PEEF,
           PAY_ELEMENT_ENTRY_VALUES_F PEEV,
           PAY_INPUT_VALUES_VL PIVL
    WHERE  PETV.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
      AND  PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
      AND  PEEV.INPUT_VALUE_ID = PIVL.INPUT_VALUE_ID
      AND  PETV.BASE_ELEMENT_NAME = 'Basic'
      AND  UPPER(TRIM(PIVL.NAME)) = 'AMOUNT'
      AND  PEEF.PERSON_ID = :P_PERSON_ID
)
```

---

## 8. Cost Center CTE (Client-Specific)

### 8.1 CMP_COST_CENTER

**Purpose:** Map department to cost center

**When to Use:** For cost center reporting (requires client-specific mapping)

```sql
CMP_COST_CTR AS (
    SELECT /*+ qb_name(CMP_CC) MATERIALIZE */
           PAAM.PERSON_ID
          ,HDORG.NAME DEPARTMENT
          ,DECODE(HDORG.NAME,
                  'Business Support', '502',
                  'CEO Off', '510',
                  'Human Resources', '512',
                  'Finance', '501',
                  'IT', '508',
                  'Marketing', '506',
                  'Production', '505',
                  'Purchase', '516',
                  'Quality', '513',
                  'Sales H&O', '504',
                  'Sales Retail', '503',
                  'Supply Chain', '509',
                  'Operations', '511',
                  'Unknown') COST_CENTER
    FROM   PER_ALL_ASSIGNMENTS_M PAAM
          ,HR_ORGANIZATION_UNITS_F_TL HDORG
    WHERE  PAAM.ORGANIZATION_ID = HDORG.ORGANIZATION_ID
      AND  PAAM.PRIMARY_FLAG = 'Y'
      AND  PAAM.ASSIGNMENT_TYPE = 'E'
      AND  PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
      AND  HDORG.LANGUAGE = 'US'
      AND  TRUNC(SYSDATE) BETWEEN HDORG.EFFECTIVE_START_DATE AND HDORG.EFFECTIVE_END_DATE
)
```

**Note:** The DECODE mapping is client-specific and should be adjusted per implementation.

---

## 9. Compensation Analytics CTEs

### 9.1 CMP_SALARY_BAND

**Purpose:** Classify employees by salary band

**When to Use:** For salary analysis, compensation benchmarking

```sql
CMP_SAL_BAND AS (
    SELECT /*+ qb_name(CMP_BAND) MATERIALIZE */
           BS.PERSON_ID
          ,BS.MONTHLY_BASIC
          ,CASE
               WHEN BS.MONTHLY_BASIC < 5000 THEN 'Band 1 (< 5K)'
               WHEN BS.MONTHLY_BASIC BETWEEN 5000 AND 10000 THEN 'Band 2 (5K-10K)'
               WHEN BS.MONTHLY_BASIC BETWEEN 10000 AND 20000 THEN 'Band 3 (10K-20K)'
               ELSE 'Band 4 (> 20K)'
           END SALARY_BAND
    FROM   CMP_BASIC_SAL BS
)
```

### 9.2 CMP_DEPT_AVG

**Purpose:** Calculate average salary by department

**When to Use:** For departmental compensation analysis

```sql
CMP_DEPT_AVG AS (
    SELECT /*+ qb_name(CMP_D_AVG) MATERIALIZE */
           PAAM.ORGANIZATION_ID
          ,HDORG.NAME DEPARTMENT
          ,COUNT(*) EMP_COUNT
          ,ROUND(AVG(BS.MONTHLY_BASIC), 2) AVG_BASIC_SALARY
          ,ROUND(AVG(GS.GROSS_AMOUNT), 2) AVG_GROSS_SALARY
    FROM   PER_ALL_ASSIGNMENTS_M PAAM
          ,HR_ORGANIZATION_UNITS_F_TL HDORG
          ,CMP_BASIC_SAL BS
          ,CMP_GROSS_SAL GS
    WHERE  PAAM.ORGANIZATION_ID = HDORG.ORGANIZATION_ID
      AND  PAAM.PERSON_ID = BS.PERSON_ID
      AND  PAAM.PERSON_ID = GS.PERSON_ID
      AND  PAAM.PRIMARY_FLAG = 'Y'
      AND  PAAM.ASSIGNMENT_TYPE = 'E'
      AND  PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
      AND  HDORG.LANGUAGE = 'US'
      AND  TRUNC(SYSDATE) BETWEEN HDORG.EFFECTIVE_START_DATE AND HDORG.EFFECTIVE_END_DATE
    GROUP BY PAAM.ORGANIZATION_ID, HDORG.NAME
)
```

---

## 10. Enhanced Pattern CTEs (02-Jan-2026 Update)

### 10.1 PARAMETERS CTE (With Effective Date Filtering)

**Purpose:** Parameter handling with effective date support  
**Usage:** For historical compensation queries

```sql
WITH PARAMETERS AS (
    /*+ qb_name(PARAMETERS) */
    SELECT
        TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        UPPER(NVL(:P_SALARY_BASIS, 'ALL')) AS SALARY_BASIS,
        UPPER(NVL(:P_GRADE, 'ALL')) AS GRADE,
        UPPER(NVL(:P_PAY_FREQUENCY, 'ALL')) AS PAY_FREQUENCY
    FROM DUAL
)
```

**Key Features:**
- `EFFECTIVE_DATE` for point-in-time queries
- `UPPER()` on all text parameters for case-insensitive comparison
- `NVL()` with 'ALL' default for optional parameters

**Benefits:**
- Query salaries "as of" any past date
- Case-insensitive filtering
- Flexible parameter handling

---

### 10.2 CMP_SALARY_HISTORY (Enhanced with Effective Date)

**Purpose:** Get salary history with effective date filtering  
**Usage:** For "as of" date salary queries

```sql
,CMP_SALARY_HISTORY AS (
    /*+ qb_name(CMP_SAL_HIST) MATERIALIZE */
    SELECT
        CSAL.PERSON_ID,
        CSAL.SALARY_AMOUNT,
        CSAL.SALARY_BASIS_ID,
        CSB.NAME AS SALARY_BASIS_NAME,
        TO_CHAR(CSAL.DATE_FROM, 'DD-MM-YYYY') AS EFFECTIVE_FROM,
        TO_CHAR(CSAL.DATE_TO, 'DD-MM-YYYY') AS EFFECTIVE_TO
    FROM
        CMP_SALARY CSAL,
        CMP_SALARY_BASIS CSB,
        PARAMETERS P
    WHERE
        CSAL.SALARY_BASIS_ID = CSB.SALARY_BASIS_ID(+)
    -- Salary active as of Effective Date
    AND P.EFFECTIVE_DATE BETWEEN CSAL.DATE_FROM 
        AND NVL(CSAL.DATE_TO, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
)
```

**Key Features:**
- Uses parameter date instead of SYSDATE
- Dual date formats (formatted and raw)
- Salary basis lookup

**Benefits:**
- Salary progression analysis
- Historical compensation snapshots
- Audit compliance

---

### 10.3 EMP_SERVICE (Service-Based Analysis)

**Purpose:** Calculate service in years for compensation planning  
**Usage:** When service duration affects compensation

```sql
,EMP_SERVICE AS (
    /*+ qb_name(EMP_SERVICE) MATERIALIZE */
    SELECT
        PAPF.PERSON_ID,
        ROUND(MONTHS_BETWEEN(P.EFFECTIVE_DATE, 
              NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START)) / 12, 2) AS SERVICE_IN_YEARS
    FROM
        PER_ALL_PEOPLE_F PAPF,
        PER_PERIODS_OF_SERVICE PPOS,
        PARAMETERS P
    WHERE
        PAPF.PERSON_ID = PPOS.PERSON_ID
    AND P.EFFECTIVE_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PPOS.DATE_START 
        AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
)
```

**Service Calculation Formula:**
```sql
ROUND(MONTHS_BETWEEN(EFFECTIVE_DATE, HIRE_DATE) / 12, 2)
```

**Benefits:**
- Service-based compensation analysis
- Salary progression tracking
- Experience band classification

---

### 10.4 CMP_EXP_BAND (Experience Band Classification)

**Purpose:** Classify employees by experience level for compensation analysis  
**Usage:** For salary benchmarking and planning

```sql
,CMP_EXP_BAND AS (
    /*+ qb_name(CMP_EXP) MATERIALIZE */
    SELECT
        ES.PERSON_ID,
        ES.SERVICE_IN_YEARS,
        CS.SALARY_AMOUNT,
        CASE 
            WHEN ES.SERVICE_IN_YEARS < 2 THEN 'Entry Level'
            WHEN ES.SERVICE_IN_YEARS BETWEEN 2 AND 5 THEN 'Mid Level'
            WHEN ES.SERVICE_IN_YEARS BETWEEN 5 AND 10 THEN 'Senior Level'
            ELSE 'Expert Level'
        END AS EXPERIENCE_BAND,
        -- Salary per year of service
        ROUND(CS.SALARY_AMOUNT / GREATEST(ES.SERVICE_IN_YEARS, 1), 2) AS SALARY_PER_SERVICE_YEAR
    FROM
        EMP_SERVICE ES,
        CMP_SALARY_HISTORY CS
    WHERE
        ES.PERSON_ID = CS.PERSON_ID
)
```

**Benefits:**
- Compensation planning by experience level
- Salary per service year analysis
- Benchmarking support

---

### 10.5 MULTI-PARAMETER FILTERING PATTERN

**Purpose:** Implement multiple optional filters with 'ALL' support  
**Usage:** When report needs multiple independent filters

```sql
WHERE
    EB.PERSON_ID = CS.PERSON_ID
-- ... other joins ...

-- Parameter Filters with 'ALL' support
AND (UPPER(CSB.NAME) = P.SALARY_BASIS OR P.SALARY_BASIS = 'ALL')
AND (UPPER(PG.NAME) = P.GRADE OR P.GRADE = 'ALL')
AND (UPPER(CSB.PAY_FREQUENCY) = P.PAY_FREQUENCY OR P.PAY_FREQUENCY = 'ALL')

ORDER BY 
    TO_NUMBER(EB.PERSON_NUMBER)
```

**Key Features:**
- **Case-Insensitive**: UPPER() on both sides
- **'ALL' Bypass**: `OR PARAMETER = 'ALL'`
- **Independent Filters**: Each works independently

**Pattern Template:**
```sql
AND (UPPER(field_name) = P.PARAMETER_NAME OR P.PARAMETER_NAME = 'ALL')
```

---

## 🎯 USAGE PATTERNS

### Pattern 1: Historical Salary Query
```sql
WITH PARAMETERS AS (
    SELECT 
        TRUNC(TO_DATE('01-JAN-2023', 'DD-MON-YYYY')) AS EFFECTIVE_DATE
    FROM DUAL
)
,CMP_SALARY_HISTORY AS (...)
SELECT
    PERSON_NUMBER,
    FULL_NAME,
    SALARY_AMOUNT,
    SALARY_BASIS_NAME,
    EFFECTIVE_FROM
FROM CMP_SALARY_HISTORY
WHERE SALARY_AMOUNT > 50000
ORDER BY SALARY_AMOUNT DESC;

-- Result: Shows salaries exactly as they were on 01-JAN-2023
```

### Pattern 2: Service-Based Compensation Analysis
```sql
SELECT
    EXPERIENCE_BAND,
    COUNT(*) AS EMPLOYEE_COUNT,
    AVG(SALARY_AMOUNT) AS AVG_SALARY,
    MIN(SALARY_AMOUNT) AS MIN_SALARY,
    MAX(SALARY_AMOUNT) AS MAX_SALARY,
    AVG(SALARY_PER_SERVICE_YEAR) AS AVG_SALARY_PER_YEAR
FROM CMP_EXP_BAND
GROUP BY EXPERIENCE_BAND
ORDER BY AVG_SALARY;
```

---

**Last Updated:** 13-Jan-2026  
**Status:** Production-Ready  
**Version:** 2.0 (Merged with update file)  
**Source:** 2 Production Compensation Queries + Cross-Module Knowledge Integration

