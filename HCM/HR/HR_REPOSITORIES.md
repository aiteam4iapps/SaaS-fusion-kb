# HR Repository Patterns

**Purpose:** Standardized CTEs for extracting Core HR data  
**Critical Rule:** All `_F` tables MUST have date filters  
**Last Updated:** 07-Jan-2026  
**Version:** 2.0 (Merged with update file)

---

## 📋 Repository Index

| CTE Name | Purpose | Key Features |
|----------|---------|--------------|
| **PARAMETERS (Enhanced)** | Parameter handling with Effective Date | Case-insensitive, 'ALL' support |
| **HR_WORKER_MASTER** | Active people with names and emails | Current snapshot |
| **HR_WORKER_MASTER (Enhanced)** | With service calculation | Service years, Effective Date filtering |
| **HR_ASG_MASTER** | Current assignment details | Job, Dept, Location |
| **HR_ASG_MASTER (Enhanced)** | With FT/PT classification | Full Time/Part Time status |
| **HR_ORG_MASTER** | Organization lookup | Department names |
| **HR_ORG_MASTER (Enhanced)** | Complete organizational context | Legal employer, BU, Location, Grade |
| **EMP_DFF** | DFF attribute mapping | Business field mapping |

---

## 1. PARAMETERS CTE - Enhanced with Effective Date **(NEW)**

**Purpose:** Parameter handling with automatic case normalization  
**Usage:** Use when parameters need case-insensitive comparison

```sql
WITH PARAMETERS AS (
    /*+ qb_name(PARAMETERS) */
    SELECT
        TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        UPPER(NVL(:P_LEGAL_EMPLOYER, 'ALL')) AS LEGAL_EMPLOYER,
        UPPER(NVL(:P_DEPARTMENT, 'ALL')) AS DEPARTMENT,
        UPPER(NVL(:P_JOB_TITLE, 'ALL')) AS JOB_TITLE,
        UPPER(NVL(:P_EMPLOYEE_TYPE, 'ALL')) AS EMPLOYEE_TYPE,
        UPPER(NVL(:P_LOCATION, 'ALL')) AS LOCATION
    FROM DUAL
)
```

**Key Features:**
- `UPPER()` function on all text parameters for case-insensitive comparison
- `NVL()` with 'ALL' default for optional parameters
- `TRUNC(TO_DATE())` for date parameter with explicit format
- All parameters accessible throughout query via cross join

**Benefits:**
- User doesn't need to match exact case
- Consistent handling of NULL parameters
- Single source of truth for parameter values

**Usage in WHERE Clause:**
```sql
-- Old way (case-sensitive, complex NULL handling)
AND (:P_LEGAL_EMPLOYER IS NULL OR EA.LEGAL_EMPLOYER_NAME = :P_LEGAL_EMPLOYER)

-- New way (case-insensitive, simple)
AND (UPPER(EA.LEGAL_EMPLOYER_NAME) = P.LEGAL_EMPLOYER OR P.LEGAL_EMPLOYER = 'ALL')
```

---

## 2. HR_WORKER_MASTER (Standard)
*Retrieves active people with names and emails.*

```sql
HR_WORKER_MASTER AS (
    SELECT /*+ qb_name(HR_WORKER) MATERIALIZE PARALLEL(2) */
           PAPF.PERSON_ID
          ,PAPF.PERSON_NUMBER
          ,PNAME.FULL_NAME
          ,PEMAIL.EMAIL_ADDRESS
          ,PPOS.ORIGINAL_DATE_OF_HIRE
    FROM   PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F PNAME
          ,PER_EMAIL_ADDRESSES PEMAIL
          ,PER_PERIODS_OF_SERVICE PPOS
    WHERE  TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
      AND  TRUNC(SYSDATE) BETWEEN PNAME.EFFECTIVE_START_DATE AND PNAME.EFFECTIVE_END_DATE
      AND  PNAME.NAME_TYPE = 'GLOBAL'
      AND  PAPF.PERSON_ID = PNAME.PERSON_ID
      AND  PAPF.PERSON_ID = PEMAIL.PERSON_ID(+) -- Email is optional
      AND  PEMAIL.EMAIL_TYPE(+) = 'W1'
      AND  PAPF.PERSON_ID = PPOS.PERSON_ID
      AND  PPOS.DATE_START = (SELECT MAX(DATE_START) FROM PER_PERIODS_OF_SERVICE WHERE PERSON_ID = PAPF.PERSON_ID)
)
```

---

## 3. HR_WORKER_MASTER - Enhanced with Service Calculation **(NEW)**

**What's New:** Service calculation using Effective Date, not SYSDATE

```sql
HR_WORKER_MASTER AS (
    /*+ qb_name(HR_WORKER) MATERIALIZE */
    SELECT
        PAPF.PERSON_ID,
        PAPF.PERSON_NUMBER,
        PPNF.FULL_NAME,
        PPNF.DISPLAY_NAME,
        PPTTL.USER_PERSON_TYPE AS PERSON_TYPE,
        PPOS.PERIOD_OF_SERVICE_ID,
        TO_CHAR(NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START), 'DD-MM-YYYY') AS HIRE_DATE,
        -- NEW: Service in Years calculation
        ROUND(MONTHS_BETWEEN(P.EFFECTIVE_DATE, NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START)) / 12, 2) AS SERVICE_IN_YEARS,
        -- NEW: Store raw hire date for calculations
        NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START) AS HIRE_DATE_RAW,
        PPOS.ACTUAL_TERMINATION_DATE
    FROM
        PER_ALL_PEOPLE_F PAPF,
        PER_PERSON_NAMES_F PPNF,
        PER_ALL_ASSIGNMENTS_F PAAF,
        PER_PERSON_TYPES_TL PPTTL,
        PER_PERIODS_OF_SERVICE PPOS,
        PARAMETERS P
    WHERE
        PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID(+)
    AND PAPF.PERSON_ID = PPOS.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PPTTL.LANGUAGE(+) = 'US'
    AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    -- CRITICAL: Use P.EFFECTIVE_DATE instead of SYSDATE
    AND P.EFFECTIVE_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PPOS.DATE_START 
        AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
)
```

**Key Improvements:**
1. **Service Calculation:** Accurate to 2 decimal places
2. **Effective Date Filtering:** Enables historical queries
3. **Raw Date Storage:** For further calculations
4. **Consistent Date Handling:** Uses parameter across all tables

**Business Value:**
- Enables "as of" reporting (e.g., "Show me employees as of 31-DEC-2023")
- Accurate service calculations for any point in time
- Audit compliance for historical data

---

## 4. HR_ASG_MASTER (Standard)
*Retrieves current active primary assignment details (Job, Dept, Loc).*

```sql
HR_ASG_MASTER AS (
    SELECT /*+ qb_name(HR_ASG) MATERIALIZE */
           PAAM.ASSIGNMENT_ID
          ,PAAM.PERSON_ID
          ,PAAM.JOB_ID
          ,PAAM.ORGANIZATION_ID
          ,PAAM.LOCATION_ID
          ,PAAM.ASSIGNMENT_STATUS_TYPE
          ,PAAM.ASSIGNMENT_NUMBER
    FROM   PER_ALL_ASSIGNMENTS_M PAAM
    WHERE  TRUNC(SYSDATE) BETWEEN PAAM.EFFECTIVE_START_DATE AND PAAM.EFFECTIVE_END_DATE
      AND  PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
      AND  PAAM.ASSIGNMENT_TYPE IN ('E', 'C') -- Employee, Contingent
      AND  PAAM.PRIMARY_FLAG = 'Y'
      AND  PAAM.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
)
```

---

## 5. HR_ASG_MASTER - Enhanced with FT/PT Classification **(NEW)**

**What's New:** Full Time / Part Time classification based on NORMAL_HOURS

```sql
HR_ASG_MASTER AS (
    /*+ qb_name(HR_ASG) MATERIALIZE */
    SELECT
        PAAF.PERSON_ID,
        PAAF.ASSIGNMENT_ID,
        PAAF.ASSIGNMENT_NUMBER,
        PAAF.ORGANIZATION_ID,
        PAAF.BUSINESS_UNIT_ID,
        PAAF.LOCATION_ID,
        PAAF.GRADE_ID,
        PAAF.ASSIGNMENT_CATEGORY,
        PAAF.POSITION_ID,
        PAAF.JOB_ID,
        PAAF.LEGAL_ENTITY_ID,
        PAAF.NORMAL_HOURS,
        PAAF.FREQUENCY,
        -- Job and Position
        PJFV.NAME AS JOB_TITLE,
        HAPL.NAME AS POSITION_TITLE,
        -- Organization
        PD.NAME AS DEPARTMENT_NAME,
        HAOULE.NAME AS LEGAL_EMPLOYER_NAME,
        HAOUBU.NAME AS BUSINESS_UNIT_NAME,
        HLOCVL.LOCATION_NAME,
        -- Grade
        PGFV.NAME AS GRADE_NAME,
        -- Worker Type
        PAAF.ASSIGNMENT_CATEGORY AS WORKER_TYPE,
        -- NEW: Full Time / Part Time Classification
        CASE 
            WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
            WHEN NVL(PAAF.NORMAL_HOURS, 0) > 0 AND NVL(PAAF.NORMAL_HOURS, 0) < 40 THEN 'Part Time'
            ELSE 'Not Specified'
        END AS FULL_TIME_PART_TIME,
        -- DFF Attributes
        PAAF.ATTRIBUTE1,
        PAAF.ATTRIBUTE2,
        PAAF.ATTRIBUTE3,
        PAAF.ATTRIBUTE4,
        PAAF.ATTRIBUTE5
    FROM
        PER_ALL_ASSIGNMENTS_F PAAF,
        PER_JOBS_F_VL PJFV,
        HR_ALL_POSITIONS_F_TL HAPL,
        PER_DEPARTMENTS PD,
        HR_ALL_ORGANIZATION_UNITS HAOULE,
        HR_ALL_ORGANIZATION_UNITS HAOUBU,
        HR_LOCATIONS_ALL_F_VL HLOCVL,
        PER_GRADES_F_VL PGFV,
        PARAMETERS P
    WHERE
        PAAF.JOB_ID = PJFV.JOB_ID(+)
    AND PAAF.POSITION_ID = HAPL.POSITION_ID(+)
    AND PAAF.ORGANIZATION_ID = PD.ORGANIZATION_ID(+)
    AND PAAF.LEGAL_ENTITY_ID = HAOULE.ORGANIZATION_ID(+)
    AND PAAF.BUSINESS_UNIT_ID = HAOUBU.ORGANIZATION_ID(+)
    AND PAAF.LOCATION_ID = HLOCVL.LOCATION_ID(+)
    AND PAAF.GRADE_ID = PGFV.GRADE_ID(+)
    AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND HAPL.LANGUAGE(+) = 'US'
    AND PGFV.LANGUAGE(+) = 'US'
    -- Use Effective Date, not SYSDATE
    AND P.EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PJFV.EFFECTIVE_START_DATE(+) AND PJFV.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN HAPL.EFFECTIVE_START_DATE(+) AND HAPL.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN PD.EFFECTIVE_START_DATE(+) AND PD.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN HLOCVL.EFFECTIVE_START_DATE(+) AND HLOCVL.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN PGFV.EFFECTIVE_START_DATE(+) AND PGFV.EFFECTIVE_END_DATE(+)
)
```

**Configuration Note:** The 40-hour threshold is customizable. Some organizations use 37.5 or 35 hours.

**Key Features:**
- **FT/PT Classification**: Based on NORMAL_HOURS
- **Comprehensive Org Data**: Legal employer, business unit, location, department
- **DFF Attributes**: Exposed for further processing
- **Effective Date Filtering**: Enables historical queries

---

## 6. HR_ORG_MASTER (Standard)
*Standard lookup for Job and Org names.*

```sql
HR_ORG_MASTER AS (
    SELECT /*+ qb_name(HR_ORG) MATERIALIZE */
           HAOU.ORGANIZATION_ID
          ,HAOU.NAME AS DEPT_NAME
    FROM   HR_ALL_ORGANIZATION_UNITS_F HAOU
    WHERE  TRUNC(SYSDATE) BETWEEN HAOU.EFFECTIVE_START_DATE AND HAOU.EFFECTIVE_END_DATE
)
```

---

## 7. HR_ORG_MASTER - Enhanced with Full Organizational Context **(NEW)**

**What's New:** Complete organizational hierarchy in single CTE

```sql
HR_ORG_MASTER AS (
    /*+ qb_name(HR_ORG) MATERIALIZE */
    SELECT
        PD.ORGANIZATION_ID AS DEPT_ORG_ID,
        PD.NAME AS DEPARTMENT_NAME,
        HAOULE.ORGANIZATION_ID AS LEGAL_ENTITY_ID,
        HAOULE.NAME AS LEGAL_EMPLOYER_NAME,
        HAOUBU.ORGANIZATION_ID AS BUSINESS_UNIT_ID,
        HAOUBU.NAME AS BUSINESS_UNIT_NAME,
        HLOCVL.LOCATION_ID,
        HLOCVL.LOCATION_NAME,
        PGFV.GRADE_ID,
        PGFV.NAME AS GRADE_NAME
    FROM
        PER_DEPARTMENTS PD,
        HR_ALL_ORGANIZATION_UNITS HAOULE,
        HR_ALL_ORGANIZATION_UNITS HAOUBU,
        HR_LOCATIONS_ALL_F_VL HLOCVL,
        PER_GRADES_F_VL PGFV,
        PARAMETERS P
    WHERE
        PGFV.LANGUAGE(+) = 'US'
    -- Date-track filtering
    AND P.EFFECTIVE_DATE BETWEEN PD.EFFECTIVE_START_DATE(+) AND PD.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN HLOCVL.EFFECTIVE_START_DATE(+) AND HLOCVL.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN PGFV.EFFECTIVE_START_DATE(+) AND PGFV.EFFECTIVE_END_DATE(+)
)
```

---

## 8. EMP_DFF - DFF Attribute Mapping **(NEW)**

**Purpose:** Standardized DFF attribute extraction pattern

```sql
EMP_DFF AS (
    /*+ qb_name(EMP_DFF) */
    SELECT
        EA.PERSON_ID,
        EA.ASSIGNMENT_ID,
        -- Map DFF attributes to business fields
        -- TODO: Update these mappings based on FND_DESCR_FLEX_COLUMN_USAGES query results
        EA.ATTRIBUTE1 AS CONTRACT_TYPE,
        EA.ATTRIBUTE5 AS CLIENT_JOB_TITLE,
        EA.ATTRIBUTE3 AS PROJECT_NUMBER,
        EA.ATTRIBUTE4 AS SERVICE_LINE,
        -- Add more DFF attributes as needed
        EA.ATTRIBUTE2 AS CUSTOM_FIELD_2
    FROM
        EMP_ASSIGNMENT EA
)
```

**Discovery Query (Run First):**
```sql
SELECT 
    DFC.APPLICATION_COLUMN_NAME,      -- e.g., ATTRIBUTE1, ATTRIBUTE2
    DFC.END_USER_COLUMN_NAME,         -- e.g., Contract Type, Client Job Title
    DFC.COLUMN_SEQ_NUM,
    DFC.ENABLED_FLAG
FROM FND_DESCR_FLEX_COLUMN_USAGES DFC
WHERE DFC.APPLICATION_TABLE_NAME = 'PER_ALL_ASSIGNMENTS_F'
AND DFC.ENABLED_FLAG = 'Y'
ORDER BY DFC.COLUMN_SEQ_NUM;
```

**Usage:** After running discovery query, update the DFF CTE with actual attribute mappings.

**Best Practice:** Document the mapping in comments for future maintenance.

---

## 🎯 CRITICAL PATTERN: EFFECTIVE DATE vs SYSDATE

### ❌ NEVER DO THIS:
```sql
WHERE TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
```

### ✅ ALWAYS DO THIS (For Historical Queries):
```sql
WHERE P.EFFECTIVE_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
```

**Why This Matters:**
- SYSDATE returns current data, breaking historical queries
- Effective Date parameter enables "as of" reporting
- Critical for audit compliance and historical analysis

**Example Impact:**
```sql
-- Query 1: Using SYSDATE (WRONG for historical queries)
-- Question: "Show me employees as of 31-DEC-2023"
-- Result: Returns current employees (as of today), not 31-DEC-2023

-- Query 2: Using EFFECTIVE_DATE (CORRECT)
-- Question: "Show me employees as of 31-DEC-2023"
-- Result: Returns employees exactly as they were on 31-DEC-2023
```

---

## 🔗 USAGE EXAMPLES

### Example 1: Historical Headcount Report
```sql
WITH PARAMETERS AS (
    SELECT TRUNC(TO_DATE('31-DEC-2023', 'DD-MON-YYYY')) AS EFFECTIVE_DATE
    FROM DUAL
)
,HR_WORKER_MASTER AS (
    -- Use enhanced pattern with service calculation
    ...
)
SELECT
    COUNT(*) AS HEADCOUNT,
    AVG(SERVICE_IN_YEARS) AS AVG_SERVICE
FROM HR_WORKER_MASTER;
```

### Example 2: Employee List with Filters
```sql
WITH PARAMETERS AS (
    SELECT
        TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        UPPER(NVL(:P_DEPARTMENT, 'ALL')) AS DEPARTMENT
    FROM DUAL
)
,HR_WORKER_MASTER AS (
    -- Enhanced pattern
    ...
)
,HR_ASG_MASTER AS (
    -- Enhanced pattern with FT/PT
    ...
)
SELECT
    HW.PERSON_NUMBER,
    HW.FULL_NAME,
    HA.DEPARTMENT_NAME,
    HA.FULL_TIME_PART_TIME,
    HW.SERVICE_IN_YEARS
FROM HR_WORKER_MASTER HW, HR_ASG_MASTER HA
WHERE HW.PERSON_ID = HA.PERSON_ID
AND (UPPER(HA.DEPARTMENT_NAME) = P.DEPARTMENT OR P.DEPARTMENT = 'ALL');
```

---

## ✅ Validation Checklist

Before using any CTE from this repository:

- [ ] CTE has `/*+ qb_name(NAME) */` hint
- [ ] All joins use Oracle Traditional Syntax
- [ ] Date-track filters applied to `_F` tables
- [ ] `LANGUAGE = 'US'` applied to `_TL` tables
- [ ] Active assignment filters applied
- [ ] PARAMETERS CTE defined when using Effective Date
- [ ] Text parameters use UPPER() for case-insensitive comparison
- [ ] Optional tables use outer joins

---

## 📝 Notes

1. **Choose the right pattern** - Standard for current data, Enhanced for historical queries
2. **ALWAYS copy complete CTEs** - do not write fresh joins
3. **Document DFF mappings** - run discovery query first
4. **Use PARAMETERS CTE** - for all new queries with filters
5. **Test with historical dates** - verify Effective Date filtering works

---

**END OF HR_REPOSITORIES.md**

**Status:** Merged and Complete  
**Last Merged:** 07-Jan-2026  
**Source Files:** HR_REPOSITORIES.md + HR_REPOSITORIES_UPDATE_02-01-26.md  
**Version:** 2.0
