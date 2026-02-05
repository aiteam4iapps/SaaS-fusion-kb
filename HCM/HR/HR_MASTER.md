# One HR Master Instructions: Core Human Resources

**Module:** Core HR  
**Tag:** `#HCM #HR #CoreHR`  
**Status:** Active  
**Last Updated:** 07-Jan-2026  
**Version:** 2.2 (Merged with ALL critical fixes)

---

## 1. 🚨 Critical HR Constraints
*Violating these rules breaks the system.*

1.  **Date-Track Filtering (The "Golden Rule"):**
    *   **Rule:** `AND TRUNC(SYSDATE) BETWEEN [TABLE].EFFECTIVE_START_DATE AND [TABLE].EFFECTIVE_END_DATE`
    *   **Why:** Without this, you get duplicate rows for every historical change (Promotions, Salary Changes).
    *   **Scope:** Applied to all `_F` (DateTrack) and `_M` (DateTracked with Updates) tables.

2.  **Assignment Status:**
    *   **Rule:** `AND PAAM.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'` (unless reporting on Terminations).
    *   **Why:** Excludes 'Redundant' or 'Inactive' assignment rows.

3.  **Primary Assignment Flag:**
    *   **Rule:** `AND PAAM.PRIMARY_FLAG = 'Y'`
    *   **Why:** Using secondary assignments can duplicate headcount numbers.

4.  **Legislative Data Group (LDG):**
    *   **Rule:** `AND LEGISLATION_CODE = 'US'` (or relevant code).

5.  **PERSON_TYPE_ID Join Path (CRITICAL - User Reported 3 Times):** **(NEW)**
    *   **Rule:** PERSON_TYPE_ID is in `PER_ALL_ASSIGNMENTS_F`, NOT in `PER_ALL_PEOPLE_F`
    *   **Join Path:** PAPF → PAAF → PPTTL (MANDATORY)
    *   **Why:** Direct join from PAPF to PPTTL using PERSON_TYPE_ID will cause "column does not exist" error
    *   **Required Filters:** PRIMARY_FLAG='Y', ASSIGNMENT_TYPE='E', date-track, LANGUAGE='US'
    *   **See:** Section 7.6 for complete implementation details

6.  **PER_DEPARTMENTS Join (HIGH PRIORITY):** **(NEW)**
    *   **Rule:** Join using `ORGANIZATION_ID`, NOT `DEPARTMENT_ID`
    *   **Pattern:** `PAAF.ORGANIZATION_ID = PD.ORGANIZATION_ID(+)`
    *   **Why:** PER_DEPARTMENTS table does NOT have a DEPARTMENT_ID column
    *   **See:** Section 7.7 for complete implementation details

7.  **Effective Date Parameter (The "Historical Rule"):** **(NEW)**
    *   **Rule:** `AND :P_EFFECTIVE_DATE BETWEEN [TABLE].EFFECTIVE_START_DATE AND [TABLE].EFFECTIVE_END_DATE`
    *   **Why:** SYSDATE always returns current data, breaking historical/"as of" queries.
    *   **Impact:** Critical for audit compliance, historical reporting, point-in-time analysis.
    *   **Scope:** ALL date-tracked tables (`_F`, `_TL` tables).

**Pattern:**
```sql
-- Define parameter first
WITH PARAMETERS AS (
    SELECT TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE
    FROM DUAL
)

-- Apply consistently across ALL date-tracked tables
WHERE P.EFFECTIVE_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
  AND P.EFFECTIVE_DATE BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
  AND P.EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
```

**When to Use:**
- Historical reports (e.g., "Show me employees as of 31-DEC-2023")
- Audit queries requiring specific date accuracy
- Compliance reports for past periods
- Year-end snapshots

**When to Use SYSDATE:**
- Real-time dashboards requiring current data
- Operational reports always showing "now"
- Queries explicitly scoped to current state only

---

## 2. ⚡ Performance Optimization

| Object | Optimal Access Path | Hint Syntax |
|--------|---------------------|-------------|
| **Person** | PERSON_ID | `/*+ INDEX(PAPF PER_PEOPLE_F_PK) */` |
| **Assignment (_F)** | ASSIGNMENT_ID | `/*+ INDEX(PAAF PER_ALL_ASSIGNMENTS_F_PK) */` |
| **Assignment (_M)** | ASSIGNMENT_ID | `/*+ INDEX(PAAM PER_ALL_ASSIGNMENTS_M_PK) */` |
| **Period of Service** | PERSON_ID | `/*+ INDEX(PPOS PER_PERIODS_OF_SERVICE_N1) */` |

---

## 2.1 🔥 Managed Tables (_M) vs Date-Tracked (_F)

**Critical Decision Point:** When to use `_M` vs `_F` tables

### Use `PER_ALL_ASSIGNMENTS_M` When:
- You only need the **latest/current** assignment record
- Report is for **current snapshot** (not historical)
- Performance is critical (single row per person)

**Pattern:**
```sql
FROM PER_ALL_ASSIGNMENTS_M PAAM
WHERE PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
AND PAAM.PRIMARY_FLAG = 'Y'
AND PAAM.ASSIGNMENT_TYPE = 'E'
```

### Use `PER_ALL_ASSIGNMENTS_F` When:
- You need **full date-track history**
- Report covers **historical changes** (promotions, transfers)
- Need to query **specific date range**

**Pattern:**
```sql
FROM PER_ALL_ASSIGNMENTS_F PAAF
WHERE PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
AND [DATE] BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
```

**Performance Impact:** `_M` tables are **significantly faster** for current data queries.

---

## 3. 🗺️ Schema Map (Key Tables)

###  3.1 Core Person Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAPF** | `PER_ALL_PEOPLE_F` | Person Header (Name, Hire Date) |
| **PPNF** | `PER_PERSON_NAMES_F` | Names (First, Last, Display, Title) |
| **PS** | `PER_PERSONS` | Person Core (DOB, Country of Birth) |
| **PPLF** | `PER_PEOPLE_LEGISLATIVE_F` | Legislative Data (Gender, Marital Status, SSN) |
| **PPTV** | `PER_PERSON_TYPES_VL` | Person Types (Employee, Contingent Worker) |
| **PPTTL** | `PER_PERSON_TYPES_TL` | Person Type Translations |
| **PPTU** | `PER_PERSON_TYPE_USAGES_M` | Person Type Usage History |

### 3.2 Assignment Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAAF** | `PER_ALL_ASSIGNMENTS_F` | Assignment (Full Date-Track History) |
| **PAAM** | `PER_ALL_ASSIGNMENTS_M` | Assignment (Managed - Latest Changes Only) |
| **PASF** | `PER_ASSIGNMENT_SUPERVISORS_F` | Manager/Supervisor Hierarchy |
| **PASTT** | `PER_ASSIGNMENT_STATUS_TYPES_TL` | Assignment Status Translations |

### 3.3 Identification & Documents

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PNI** | `PER_NATIONAL_IDENTIFIERS` | National IDs (Emirates ID, SSN, Tax IDs) |
| **PNIV** | `PER_NATIONAL_IDENTIFIERS_V` | National Identifiers View |
| **PP** | `PER_PASSPORTS` | Passport Details |
| **PC** | `PER_CITIZENSHIPS` | Citizenship/Nationality |

### 3.4 Employment & Service

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PPOS** | `PER_PERIODS_OF_SERVICE` | Employment Terms (Hire, Termination) |
| **PAC** | `PER_ACTION_OCCURRENCES` | Action Occurrences (Transfer, Termination) |
| **ACTN** | `PER_ACTIONS_VL` | Actions Master (Leaving, Promotion) |
| **PART** | `PER_ACTION_REASONS_TL` | Action Reasons (Resignation, etc.) |
| **PAR** | `PER_ACTION_REASONS_B` | Action Reasons Base |

### 3.5 Contact Information

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PEA** | `PER_EMAIL_ADDRESSES` | Email Addresses |
| **PR** | `PER_RELIGIONS` | Religion Information |

### 3.6 Organization & Job

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PD** | `PER_DEPARTMENTS` | Department Details |
| **PJFV** | `PER_JOBS_F_VL` | Job Definitions (View with Translations) |
| **PG** | `PER_GRADES` | Grade Definitions |
| **PGFT** | `PER_GRADES_F_TL` | Grade Translations |
| **HAPFT** | `HR_ALL_POSITIONS_F_TL` | Position Translations |
| **PL** | `PER_LOCATION_DETAILS_F_VL` | Location Details View |
| **PPG** | `PER_PEOPLE_GROUPS` | People Groups (Payroll Grouping) |

### 3.7 Lookups & Reference

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **HL** | `HCM_LOOKUPS` | HCM Lookup Values |
| **PVL** | `FND_TERRITORIES_VL` | Country/Territory Lookup |

---

## 4. 📋 Legislative Data Patterns

### 4.1 Gender Decode
```sql
DECODE(PPLF.SEX, 'M', 'Male', 'F', 'Female', PPLF.SEX) GENDER
```

### 4.2 Marital Status Decode
```sql
DECODE(PPLF.MARITAL_STATUS, 
    'M', 'Married', 
    'S', 'Single', 
    'W', 'Widowed', 
    'D', 'Divorced', 
    PPLF.MARITAL_STATUS
) MARITAL_STATUS
```

### 4.3 Nationality Lookup Pattern
```sql
SELECT H.MEANING
FROM PER_CITIZENSHIPS PC,
     HCM_LOOKUPS H
WHERE PAPF.PERSON_ID = PC.PERSON_ID
AND H.LOOKUP_CODE = PC.LEGISLATION_CODE
AND H.LOOKUP_TYPE = 'NATIONALITY'
```

### 4.4 Emirates ID Formatting (UAE Specific)
```sql
CASE WHEN PNI.NATIONAL_IDENTIFIER_NUMBER IS NOT NULL THEN 
    SUBSTR(PNI.NATIONAL_IDENTIFIER_NUMBER, 1, 3) || '-' || 
    SUBSTR(PNI.NATIONAL_IDENTIFIER_NUMBER, 4, 4) || '-' ||
    SUBSTR(PNI.NATIONAL_IDENTIFIER_NUMBER, 8, 7) || '-' ||
    SUBSTR(PNI.NATIONAL_IDENTIFIER_NUMBER, 15, 1)
ELSE NULL 
END EMIRATES_ID_FORMATTED
```

**Format:** 784-1234-1234567-1

### 4.5 Religion Lookup Pattern
```sql
SELECT HL.MEANING
FROM PER_RELIGIONS PR,
     HCM_LOOKUPS HL
WHERE HL.LOOKUP_TYPE = 'PER_RELIGION'
AND PR.RELIGION = HL.LOOKUP_CODE
AND PAPF.PERSON_ID = PR.PERSON_ID
```

---

## 5. 🔍 Common Lookup Types

| Lookup Type | Purpose | Table | Sample Values |
|-------------|---------|-------|---------------|
| `NATIONALITY` | Nationality/Citizenship | HCM_LOOKUPS | ARE, USA, IND, PAK |
| `PER_RELIGION` | Religion | HCM_LOOKUPS | MUSLIM, CHRISTIAN, HINDU |
| `EMPLOYEE_CATG` | Employee Category | HR_LOOKUPS | STAFF, MANAGER, EXECUTIVE |
| `TITLE` | Name Title | HR_LOOKUPS | MR., MRS., MS., MISS |
| `PER_MARITAL_STATUS` | Marital Status | HR_LOOKUPS | M, S, W, D |

---

## 5.5 Service in Years Calculation **(NEW)**

**Formula:**
```sql
ROUND(MONTHS_BETWEEN(P.EFFECTIVE_DATE, NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START)) / 12, 2) AS SERVICE_IN_YEARS
```

**Key Points:**
- Use `ORIGINAL_DATE_OF_HIRE` if available, fallback to `DATE_START`
- Use `EFFECTIVE_DATE` parameter (not SYSDATE) for historical accuracy
- `MONTHS_BETWEEN` provides precise calculation
- Round to 2 decimals for readability
- Result accurate to day-level precision

**Source Table:** `PER_PERIODS_OF_SERVICE`

**Date Filter:**
```sql
AND P.EFFECTIVE_DATE BETWEEN PPOS.DATE_START 
    AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
```

**Usage Example:**
```sql
SELECT
    PERSON_NUMBER,
    FULL_NAME,
    TO_CHAR(HIRE_DATE, 'DD-MM-YYYY') AS HIRE_DATE,
    ROUND(MONTHS_BETWEEN(TRUNC(SYSDATE), HIRE_DATE) / 12, 2) AS SERVICE_YEARS,
    CASE 
        WHEN ROUND(MONTHS_BETWEEN(TRUNC(SYSDATE), HIRE_DATE) / 12, 2) >= 10 THEN 'Senior'
        WHEN ROUND(MONTHS_BETWEEN(TRUNC(SYSDATE), HIRE_DATE) / 12, 2) >= 5 THEN 'Mid-Level'
        ELSE 'Junior'
    END AS SENIORITY_BAND
FROM HR_WORKER_MASTER;
```

---

## 6. 🔗 Standard Joins (Copy-Paste Ready)

### 6.0 Person with Person Type (CRITICAL - MUST USE)
**Purpose:** Get person type (Employee, Contingent Worker, etc.)

**IMPORTANT:** Person Type MUST be retrieved via Assignment table

```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PERSON_NAMES_F PPNF,
     PER_ALL_ASSIGNMENTS_F PAAF,
     PER_PERSON_TYPES_TL PPTTL
WHERE PAPF.PERSON_ID = PPNF.PERSON_ID
AND PAPF.PERSON_ID = PAAF.PERSON_ID
AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- Via PAAF, NOT PAPF
AND PPNF.NAME_TYPE = 'GLOBAL'
AND PPTTL.LANGUAGE = 'US'
AND PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
```

### 6.1 Person with Legislative Data
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PERSON_NAMES_F PPNF,
     PER_PEOPLE_LEGISLATIVE_F PPLF
WHERE PAPF.PERSON_ID = PPNF.PERSON_ID
AND PAPF.PERSON_ID = PPLF.PERSON_ID
AND PPNF.NAME_TYPE = 'GLOBAL'
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE) AND TRUNC(PAPF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) AND TRUNC(PPNF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PPLF.EFFECTIVE_START_DATE) AND TRUNC(PPLF.EFFECTIVE_END_DATE)
```

### 6.2 Person with Citizenship
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_CITIZENSHIPS PC,
     HCM_LOOKUPS HL
WHERE PAPF.PERSON_ID = PC.PERSON_ID(+)
AND PC.LEGISLATION_CODE = HL.LOOKUP_CODE(+)
AND HL.LOOKUP_TYPE(+) = 'NATIONALITY'
```

### 6.3 Person with National Identifier
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_NATIONAL_IDENTIFIERS PNI
WHERE PAPF.PERSON_ID = PNI.PERSON_ID(+)
AND PNI.NATIONAL_IDENTIFIER_TYPE(+) = 'NATIONAL_IDENTIFIER'
```

### 6.4 Person with Passport
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PASSPORTS PP
WHERE PAPF.PERSON_ID = PP.PERSON_ID(+)
AND PP.PASSPORT_TYPE(+) = 'PASSPORT'
```

### 6.5 Assignment with Manager
```sql
FROM PER_ALL_ASSIGNMENTS_F PAAF,
     PER_ASSIGNMENT_SUPERVISORS_F PASF,
     PER_PERSON_NAMES_F PPNF_MGR
WHERE PAAF.PERSON_ID = PASF.PERSON_ID(+)
AND PASF.MANAGER_ID = PPNF_MGR.PERSON_ID(+)
AND PPNF_MGR.NAME_TYPE(+) = 'GLOBAL'
AND TRUNC(SYSDATE) BETWEEN TRUNC(PASF.EFFECTIVE_START_DATE(+)) AND TRUNC(PASF.EFFECTIVE_END_DATE(+))
AND TRUNC(SYSDATE) BETWEEN TRUNC(PPNF_MGR.EFFECTIVE_START_DATE(+)) AND TRUNC(PPNF_MGR.EFFECTIVE_END_DATE(+))
```

### 6.6 Assignment with Termination Actions
```sql
FROM PER_ALL_ASSIGNMENTS_M PAAM,
     PER_ACTION_OCCURRENCES PAC,
     PER_ACTIONS_VL ACTN,
     PER_ACTION_REASONS_TL PART
WHERE PAC.ACTION_OCCURRENCE_ID = PAAM.ACTION_OCCURRENCE_ID(+)
AND ACTN.ACTION_ID = PAC.ACTION_ID(+)
AND PAAM.REASON_CODE = PART.ACTION_REASON_CODE(+)
AND PART.LANGUAGE(+) = 'US'
```

---

## 7. ⚠️ Common Pitfalls

### 7.1 Using Wrong Assignment Table
**Problem:** Query too slow or returns duplicate rows  
**Cause:** Using `_F` when `_M` would be sufficient

**Solution:**
- Use `_M` for current data reports
- Use `_F` only when history needed

### 7.2 Missing EFFECTIVE_LATEST_CHANGE Flag
**Problem:** Multiple rows per person from `_M` table  
**Cause:** Not filtering for latest change

**Solution:**
```sql
AND PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
```

### 7.3 Legislative Data Not Found
**Problem:** Gender, Marital Status returning NULL  
**Cause:** Not joining to `PER_PEOPLE_LEGISLATIVE_F`

**Solution:**
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PEOPLE_LEGISLATIVE_F PPLF
WHERE PAPF.PERSON_ID = PPLF.PERSON_ID
AND TRUNC(SYSDATE) BETWEEN PPLF.EFFECTIVE_START_DATE AND PPLF.EFFECTIVE_END_DATE
```

### 7.4 Nationality Shows Code Instead of Meaning
**Problem:** Nationality column shows 'ARE', 'IND' instead of 'United Arab Emirates', 'India'

**Solution:** Join to HCM_LOOKUPS to get meaning
```sql
SELECT HL.MEANING
FROM PER_CITIZENSHIPS PC,
     HCM_LOOKUPS HL
WHERE PC.LEGISLATION_CODE = HL.LOOKUP_CODE
AND HL.LOOKUP_TYPE = 'NATIONALITY'
```

### 7.5 Multiple National Identifiers
**Problem:** Duplicate rows because person has multiple IDs (Emirates ID + Passport)

**Solution:** Filter by specific identifier type
```sql
AND PNI.NATIONAL_IDENTIFIER_TYPE = 'NATIONAL_IDENTIFIER'  -- Emirates ID only
-- OR
AND PNI.NATIONAL_IDENTIFIER_TYPE = 'SSN'  -- Social Security Number only
```

### 7.6 PERSON_TYPE_ID Location (CRITICAL - REPORTED 3 TIMES)

**🚨 CRITICAL FIX - HIGH PRIORITY**

**Problem:** Using `PAPF.PERSON_TYPE_ID` causes "column does not exist" error

**Root Cause:** `PERSON_TYPE_ID` column does **NOT** exist in `PER_ALL_PEOPLE_F` table

**Table Structure:**
- **PER_ALL_PEOPLE_F**: Does NOT contain `PERSON_TYPE_ID`
- **PER_ALL_ASSIGNMENTS_F**: DOES contain `PERSON_TYPE_ID`
- **Join Path**: PAPF → PAAF → PPTTL (MANDATORY)

**❌ WRONG PATTERN (DO NOT USE):**
```sql
-- ❌ INCORRECT - This will cause error
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PERSON_TYPES_TL PPTTL
WHERE PAPF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- ERROR: Column does not exist
```

**✅ CORRECT SOLUTION:**
```sql
-- ✅ CORRECT - Person Type via Assignment Table
FROM PER_ALL_PEOPLE_F PAPF,
     PER_ALL_ASSIGNMENTS_F PAAF,
     PER_PERSON_TYPES_TL PPTTL
WHERE PAPF.PERSON_ID = PAAF.PERSON_ID
AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- Correct: Use PAAF, not PAPF
AND PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
AND PPTTL.LANGUAGE = 'US'
```

**MANDATORY FILTERS when retrieving Person Type:**
1. `PAAF.PRIMARY_FLAG = 'Y'`
2. `PAAF.ASSIGNMENT_TYPE = 'E'` (for employees)
3. `TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE`
4. `PPTTL.LANGUAGE = 'US'`

**CTE Pattern (Early Retrieval):**
```sql
EMP_BASE AS (
    SELECT
        PAPF.PERSON_ID,
        PAPF.PERSON_NUMBER,
        PPNF.FULL_NAME,
        PPTTL.USER_PERSON_TYPE AS PERSON_TYPE  -- Via PAAF join
    FROM
        PER_ALL_PEOPLE_F PAPF,
        PER_PERSON_NAMES_F PPNF,
        PER_ALL_ASSIGNMENTS_F PAAF,  -- REQUIRED for person type
        PER_PERSON_TYPES_TL PPTTL
    WHERE
        PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- Correct join path
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PPTTL.LANGUAGE = 'US'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
)
```

**Validation Checklist:**
- [ ] Person type NOT joined directly from PER_ALL_PEOPLE_F
- [ ] PER_ALL_ASSIGNMENTS_F included in join path
- [ ] PRIMARY_FLAG = 'Y' filter present
- [ ] ASSIGNMENT_TYPE = 'E' filter present
- [ ] Date-track filter on assignment present
- [ ] LANGUAGE = 'US' filter on types table present

**NOTE:** This issue has been reported 3 times. Always verify the join path before deployment.

### 7.7 PER_DEPARTMENTS Join (HIGH PRIORITY - WRONG COLUMN) **(NEW)**

**Problem:** Query fails with "invalid identifier DEPARTMENT_ID"

**Root Cause:** `PER_DEPARTMENTS` table does NOT have a `DEPARTMENT_ID` column

**Table Structure:**
- **PER_DEPARTMENTS**: Uses `ORGANIZATION_ID` as primary key (NOT `DEPARTMENT_ID`)
- **PER_ALL_ASSIGNMENTS_F**: Contains `ORGANIZATION_ID` for department link
- **Join Column**: `ORGANIZATION_ID` (not `DEPARTMENT_ID`)

**❌ WRONG PATTERN:**
```sql
-- ❌ INCORRECT - DEPARTMENT_ID does NOT exist in PER_DEPARTMENTS
FROM PER_ALL_ASSIGNMENTS_F PAAF,
     PER_DEPARTMENTS PD
WHERE PAAF.DEPARTMENT_ID = PD.DEPARTMENT_ID(+)
```

**✅ CORRECT SOLUTION:**
```sql
-- ✅ CORRECT - Join using ORGANIZATION_ID
FROM PER_ALL_ASSIGNMENTS_F PAAF,
     PER_DEPARTMENTS PD
WHERE PAAF.ORGANIZATION_ID = PD.ORGANIZATION_ID(+)
```

**Complete Example:**
```sql
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.FULL_NAME,
    PD.NAME AS DEPARTMENT_NAME
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_DEPARTMENTS PD
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
AND PAPF.PERSON_ID = PAAF.PERSON_ID
AND PAAF.ORGANIZATION_ID = PD.ORGANIZATION_ID(+)  -- Correct join
AND PPNF.NAME_TYPE = 'GLOBAL'
AND PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
```

**Why Both Department AND Organization Unit Use Same Column:**

`PER_DEPARTMENTS` and `HR_ALL_ORGANIZATION_UNITS` both represent organizational structures:
- **PER_DEPARTMENTS**: Specific department information
- **HR_ALL_ORGANIZATION_UNITS**: General organization unit (can be dept, business unit, etc.)

Both use `ORGANIZATION_ID` as their primary key and can join to `PAAF.ORGANIZATION_ID`.

**Validation:**
- [ ] Department join uses `PD.ORGANIZATION_ID` (NOT `PD.DEPARTMENT_ID`)
- [ ] Join to `PAAF.ORGANIZATION_ID` (assignment table)
- [ ] Outer join `(+)` used if department is optional

### 7.8 Handling Optional Tables **(NEW)**

**Problem:** Query fails when table doesn't exist in all environments  
**Cause:** Hardcoded table joins to environment-specific tables

**Solution:** Use outer joins and provide documentation

**Pattern:**
```sql
-- Define optional CTE
OPTIONAL_DATA AS (
    SELECT
        PERSON_ID,
        OPTIONAL_FIELD
    FROM OPTIONAL_TABLE  -- May not exist in all environments
    WHERE conditions
)

-- In final SELECT, use outer join
FROM
    REQUIRED_TABLE RT,
    OPTIONAL_DATA OD
WHERE
    RT.PERSON_ID = OD.PERSON_ID(+)  -- Outer join allows NULL when table missing or empty

-- Use NVL in SELECT to handle NULL
SELECT
    RT.PERSON_NUMBER,
    NVL(OD.OPTIONAL_FIELD, 'Not Available') AS OPTIONAL_FIELD
FROM ...
```

**Deployment Documentation:**
```sql
/*
 * OPTIONAL TABLES - Environment-Specific
 * =====================================
 *
 * The following CTEs query tables that may not exist in all environments:
 * 
 * 1. EXTENDED_INFO_CTE - Queries CUSTOM_EMPLOYEE_INFO table
 *    - If table doesn't exist, comment out lines 45-60
 *    - Fields will show as NULL in output
 *
 * 2. PROJECT_ASSIGNMENTS_CTE - Queries PA_PROJECT_ASSIGNMENTS
 *    - If table doesn't exist, comment out lines 75-90
 *    - Project fields will show as 'Not Available'
 */
```

---

## 8. 📊 Standard Filters

### 8.1 Active Employees (Managed Table)
```sql
AND PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
AND PAAM.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
AND PAAM.PRIMARY_FLAG = 'Y'
AND PAAM.ASSIGNMENT_TYPE = 'E'
```

### 8.2 Current Employees with Termination Date Handling (UPDATED)

**Old Pattern:**
```sql
AND TRUNC(SYSDATE) BETWEEN PPOS.DATE_START 
    AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('4712-12-31', 'YYYY-MM-DD'))
```

**New Pattern (with Effective Date):**
```sql
AND P.EFFECTIVE_DATE BETWEEN PPOS.DATE_START 
    AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
```

**Key Changes:**
1. Use `P.EFFECTIVE_DATE` instead of `SYSDATE`
2. Consistent date format: `'DD/MM/YYYY'`
3. End of time date: `31/12/4712`

**Why This Matters:**
- Enables historical queries ("Show terminated employees as of 31-DEC-2023")
- Consistent with date-track filtering pattern
- Handles active employees (ACTUAL_TERMINATION_DATE is NULL)

### 8.3 Legislative Data Current Snapshot
```sql
AND TRUNC(SYSDATE) BETWEEN PPLF.EFFECTIVE_START_DATE AND PPLF.EFFECTIVE_END_DATE
```

### 8.4 Case-Insensitive Parameter Filtering with 'ALL' Default **(NEW)**

**Problem:** Users struggle with exact case matching ("DUBAI" vs "Dubai" vs "dubai")

**Solution:**
```sql
-- Step 1: In PARAMETERS CTE
WITH PARAMETERS AS (
    SELECT
        UPPER(NVL(:P_LEGAL_EMPLOYER, 'ALL')) AS LEGAL_EMPLOYER,
        UPPER(NVL(:P_DEPARTMENT, 'ALL')) AS DEPARTMENT,
        UPPER(NVL(:P_LOCATION, 'ALL')) AS LOCATION
    FROM DUAL
)

-- Step 2: In WHERE clause
AND (UPPER(EA.LEGAL_EMPLOYER_NAME) = P.LEGAL_EMPLOYER OR P.LEGAL_EMPLOYER = 'ALL')
AND (UPPER(EA.DEPARTMENT_NAME) = P.DEPARTMENT OR P.DEPARTMENT = 'ALL')
AND (UPPER(EA.LOCATION_NAME) = P.LOCATION OR P.LOCATION = 'ALL')
```

**Benefits:**
- Users can enter "DUBAI", "Dubai", or "dubai" - all work
- 'ALL' bypasses filter without complex NULL handling
- Simplified logic, no DECODE/CASE needed
- Self-documenting code
- Consistent pattern across all parameters

### 8.5 Multi-Parameter Filtering Pattern **(NEW)**

**Complete Parameter Handling Pattern:**

```sql
-- Step 1: Define ALL parameters in single CTE
WITH PARAMETERS AS (
    /*+ qb_name(PARAMETERS) */
    SELECT
        -- Mandatory parameters
        TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        
        -- Optional parameters with UPPER and 'ALL' default
        UPPER(NVL(:P_LEGAL_EMPLOYER, 'ALL')) AS LEGAL_EMPLOYER,
        UPPER(NVL(:P_DEPARTMENT, 'ALL')) AS DEPARTMENT,
        UPPER(NVL(:P_JOB_TITLE, 'ALL')) AS JOB_TITLE,
        UPPER(NVL(:P_EMPLOYEE_TYPE, 'ALL')) AS EMPLOYEE_TYPE,
        UPPER(NVL(:P_LOCATION, 'ALL')) AS LOCATION,
        UPPER(NVL(:P_GRADE, 'ALL')) AS GRADE
    FROM DUAL
)

-- Step 2: Join PARAMETERS to all CTEs
,EMP_BASE AS (
    SELECT ...
    FROM ..., PARAMETERS P
    WHERE P.EFFECTIVE_DATE BETWEEN ...
)

-- Step 3: Apply filters in WHERE clause
WHERE
    -- Legal Employer filter
    (UPPER(EA.LEGAL_EMPLOYER_NAME) = P.LEGAL_EMPLOYER OR P.LEGAL_EMPLOYER = 'ALL')
    -- Department filter
AND (UPPER(EA.DEPARTMENT_NAME) = P.DEPARTMENT OR P.DEPARTMENT = 'ALL')
    -- Job Title filter
AND (UPPER(EA.JOB_TITLE) = P.JOB_TITLE OR P.JOB_TITLE = 'ALL')
    -- Employee Type filter
AND (UPPER(EB.PERSON_TYPE) = P.EMPLOYEE_TYPE OR P.EMPLOYEE_TYPE = 'ALL')
    -- Location filter
AND (UPPER(EA.LOCATION_NAME) = P.LOCATION OR P.LOCATION = 'ALL')
    -- Grade filter
AND (UPPER(EA.GRADE_NAME) = P.GRADE OR P.GRADE = 'ALL')
```

**Benefits:**
- All parameters defined in one place
- Consistent case-insensitive matching
- Simple bypass logic with 'ALL'
- No complex NULL handling
- Easy to add new parameters

---

## 10. 🚪 Leaving Actions & Reasons

### 10.1 Leaving Action Pattern

**Use Case:** Get termination action (Voluntary Resignation, Retirement, etc.)

```sql
(SELECT ACTN.ACTION_NAME
 FROM PER_ALL_ASSIGNMENTS_M ASG1,
      PER_ACTION_OCCURRENCES PAC,
      PER_ACTIONS_VL ACTN
 WHERE PAC.ACTION_OCCURRENCE_ID = ASG1.ACTION_OCCURRENCE_ID
 AND ACTN.ACTION_ID = PAC.ACTION_ID
 AND ASG1.ASSIGNMENT_ID = PAAM.ASSIGNMENT_ID
 AND ASG1.ASSIGNMENT_TYPE = 'E'
 AND ASG1.PRIMARY_FLAG = 'Y'
 AND ASG1.EFFECTIVE_LATEST_CHANGE = 'Y'
 AND TRUNC(PPOS.ACTUAL_TERMINATION_DATE + 1) BETWEEN ASG1.EFFECTIVE_START_DATE 
                                                  AND ASG1.EFFECTIVE_END_DATE
 AND ROWNUM = 1
) LEAVING_ACTION
```

### 10.2 Leaving Reason Pattern

**Use Case:** Get termination reason

```sql
(SELECT PART.ACTION_REASON
 FROM PER_ALL_ASSIGNMENTS_M ASG1,
      PER_ACTION_REASONS_TL PART,
      PER_ACTION_REASONS_B PAR
 WHERE ASG1.ASSIGNMENT_ID = PAAM.ASSIGNMENT_ID
 AND PART.ACTION_REASON_ID = PAR.ACTION_REASON_ID
 AND ASG1.REASON_CODE = PAR.ACTION_REASON_CODE
 AND ASG1.ASSIGNMENT_TYPE = 'E'
 AND ASG1.PRIMARY_FLAG = 'Y'
 AND ASG1.EFFECTIVE_LATEST_CHANGE = 'Y'
 AND PART.LANGUAGE = 'US'
 AND TRUNC(PPOS.ACTUAL_TERMINATION_DATE + 1) BETWEEN ASG1.EFFECTIVE_START_DATE 
                                                  AND ASG1.EFFECTIVE_END_DATE
 AND TRUNC(PPOS.ACTUAL_TERMINATION_DATE + 1) BETWEEN PAR.START_DATE AND PAR.END_DATE
 AND ROWNUM = 1
) LEAVING_REASON
```

---

## 11. 💼 Worker Category & Type

### 11.1 Worker Category Pattern

```sql
(SELECT MEANING 
 FROM HR_LOOKUPS 
 WHERE LOOKUP_TYPE = 'EMPLOYEE_CATG' 
 AND LOOKUP_CODE = PAAM.EMPLOYEE_CATEGORY 
 AND ROWNUM = 1
) WORKER_CATEGORY
```

### 11.2 Payroll Time Type Pattern

```sql
PAAM.ASS_ATTRIBUTE1 AS PAYROLL_TIME_TYPE
```

### 11.3 Full Time / Part Time Classification **(NEW)**

**Pattern:**
```sql
CASE 
    WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
    WHEN NVL(PAAF.NORMAL_HOURS, 0) > 0 AND NVL(PAAF.NORMAL_HOURS, 0) < 40 THEN 'Part Time'
    ELSE 'Not Specified'
END AS FULL_TIME_PART_TIME
```

**Source Field:** `PER_ALL_ASSIGNMENTS_F.NORMAL_HOURS`

**Configuration Note:** The 40-hour threshold is customizable based on:
- Country legislation (some use 37.5 or 35 hours)
- Organization policy
- Industry standards

**Enhanced Version with Frequency Check:**
```sql
CASE 
    WHEN PAAF.FREQUENCY = 'W' AND NVL(PAAF.NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
    WHEN PAAF.FREQUENCY = 'W' AND NVL(PAAF.NORMAL_HOURS, 0) > 0 AND NVL(PAAF.NORMAL_HOURS, 0) < 40 THEN 'Part Time'
    WHEN PAAF.FREQUENCY = 'M' AND NVL(PAAF.NORMAL_HOURS, 0) >= 160 THEN 'Full Time'  -- 40 hours * 4 weeks
    WHEN PAAF.FREQUENCY = 'M' AND NVL(PAAF.NORMAL_HOURS, 0) > 0 AND NVL(PAAF.NORMAL_HOURS, 0) < 160 THEN 'Part Time'
    ELSE 'Not Specified'
END AS FULL_TIME_PART_TIME
```

**Frequency Values:**
- `'W'` - Weekly
- `'M'` - Monthly
- `'Y'` - Yearly

---

## 12. 🆔 Additional Identification Patterns

### 12.1 National Identifier

```sql
(SELECT PNI.NATIONAL_IDENTIFIER_NUMBER
 FROM PER_NATIONAL_IDENTIFIERS PNI,
      PER_NAT_IDENTIFIER_TYPES PNIT
 WHERE PAPF.PERSON_ID = PNI.PERSON_ID
 AND PNI.NATIONAL_IDENTIFIER_TYPE_ID = PNIT.NATIONAL_IDENTIFIER_TYPE_ID
 AND UPPER(PNIT.LEGISLATION_CODE) = 'US'
 AND UPPER(PNIT.NATIONAL_IDENTIFIER_TYPE) = 'SSN'
 AND ROWNUM = 1
) NATIONAL_ID
```

### 12.2 Email Address

```sql
FROM PER_EMAIL_ADDRESSES PEA
WHERE PAPF.PERSON_ID = PEA.PERSON_ID
AND PEA.EMAIL_TYPE = 'W1'  -- Work email
AND TRUNC(SYSDATE) BETWEEN PEA.DATE_FROM 
    AND NVL(PEA.DATE_TO, TO_DATE('4712-12-31', 'YYYY-MM-DD'))
```

---

## 13. 🏢 Organization Classification

```sql
FROM HR_ORG_UNIT_CLASSIFICATIONS_F HOUCF,
     HR_ALL_ORGANIZATION_UNITS_F HAOUF,
     HR_ORGANIZATION_UNITS_F_TL HAUFT
WHERE HAOUF.ORGANIZATION_ID = HOUCF.ORGANIZATION_ID
AND HAOUF.ORGANIZATION_ID = HAUFT.ORGANIZATION_ID
AND HAOUF.EFFECTIVE_START_DATE BETWEEN HOUCF.EFFECTIVE_START_DATE 
                                   AND HOUCF.EFFECTIVE_END_DATE
AND HAUFT.LANGUAGE = 'US'
AND HOUCF.CLASSIFICATION_CODE = 'DEPARTMENT'
AND TRUNC(SYSDATE) BETWEEN HAUFT.EFFECTIVE_START_DATE AND HAUFT.EFFECTIVE_END_DATE
```

---

## 14. 🔍 DFF (Descriptive Flexfield) Attributes **(NEW)**

### 14.1 DFF Discovery Query

**Purpose:** Identify which ATTRIBUTE columns map to which business fields

**Discovery Query:**
```sql
SELECT 
    DFC.APPLICATION_COLUMN_NAME,      -- Physical column (ATTRIBUTE1, ATTRIBUTE2, etc.)
    DFC.END_USER_COLUMN_NAME,         -- Business name (Contract Type, Client Job Title, etc.)
    DFC.COLUMN_SEQ_NUM,               -- Display sequence
    DFC.DESCRIPTIVE_FLEXFIELD_NAME,   -- Flexfield name
    DFC.ENABLED_FLAG                  -- Whether enabled
FROM FND_DESCR_FLEX_COLUMN_USAGES DFC
WHERE DFC.APPLICATION_TABLE_NAME = 'PER_ALL_ASSIGNMENTS_F'
AND DFC.ENABLED_FLAG = 'Y'
AND DFC.DESCRIPTIVE_FLEXFIELD_NAME = 'Assignment Developer DF'  -- Common DFF name
ORDER BY DFC.COLUMN_SEQ_NUM;
```

**Sample Output:**
| APPLICATION_COLUMN_NAME | END_USER_COLUMN_NAME | COLUMN_SEQ_NUM |
|-------------------------|----------------------|----------------|
| ATTRIBUTE1              | Contract Type        | 1              |
| ATTRIBUTE2              | Employee Grade       | 2              |
| ATTRIBUTE3              | Project Number       | 3              |
| ATTRIBUTE4              | Service Line         | 4              |
| ATTRIBUTE5              | Client Job Title     | 5              |

### 14.2 DFF Usage Pattern

**After running discovery query, create mapping CTE:**
```sql
EMP_DFF AS (
    SELECT
        PAAF.PERSON_ID,
        PAAF.ASSIGNMENT_ID,
        -- Map based on discovery query results
        PAAF.ATTRIBUTE1 AS CONTRACT_TYPE,        -- Discovered mapping
        PAAF.ATTRIBUTE2 AS EMPLOYEE_GRADE_DFF,   -- Discovered mapping
        PAAF.ATTRIBUTE3 AS PROJECT_NUMBER,       -- Discovered mapping
        PAAF.ATTRIBUTE4 AS SERVICE_LINE,         -- Discovered mapping
        PAAF.ATTRIBUTE5 AS CLIENT_JOB_TITLE      -- Discovered mapping
    FROM PER_ALL_ASSIGNMENTS_F PAAF, PARAMETERS P
    WHERE PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND P.EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
)
```

### 14.3 DFF Best Practices

1. **Always run discovery query first** - Don't guess attribute mappings
2. **Document mappings in comments** - Future developers will thank you
3. **Handle NULL values** - DFF fields are often optional
4. **Use meaningful aliases** - `CONTRACT_TYPE` not `ATTR1`
5. **Date-track filter** - DFF attributes can change over time

### 14.4 Common DFF Contexts

**For PER_ALL_ASSIGNMENTS_F:**
- Assignment Developer DF
- Assignment DFF
- ASG_DF (varies by implementation)

**For PER_ALL_PEOPLE_F:**
- Person Developer DF
- Person DFF
- PER_PEOPLE_DFF

**Discovery Query for All Contexts:**
```sql
SELECT DISTINCT
    DFC.DESCRIPTIVE_FLEXFIELD_NAME,
    DFC.APPLICATION_TABLE_NAME,
    COUNT(*) AS ATTRIBUTE_COUNT
FROM FND_DESCR_FLEX_COLUMN_USAGES DFC
WHERE DFC.ENABLED_FLAG = 'Y'
AND DFC.APPLICATION_TABLE_NAME IN ('PER_ALL_ASSIGNMENTS_F', 'PER_ALL_PEOPLE_F')
GROUP BY DFC.DESCRIPTIVE_FLEXFIELD_NAME, DFC.APPLICATION_TABLE_NAME
ORDER BY DFC.APPLICATION_TABLE_NAME, DFC.DESCRIPTIVE_FLEXFIELD_NAME;
```

---

## 15. 🔴 CRITICAL FIELD MAPPINGS **(NEW)**

**Purpose:** Production-validated field locations and join patterns  
**Authority:** These are NOT assumptions - they are from working production queries  
**Priority:** CRITICAL - Must Follow

### 15.1 Personal Information Fields

**CRITICAL:** Many personal fields are NOT in PER_ALL_PEOPLE_F

| Field | ❌ WRONG Table | ✅ CORRECT Table | Join Pattern |
|-------|---------------|------------------|--------------|
| **SEX (Gender)** | `PER_ALL_PEOPLE_F.SEX` | `PER_PEOPLE_LEGISLATIVE_F.SEX` | Direct via PERSON_ID |
| **DATE_OF_BIRTH** | `PER_ALL_PEOPLE_F.DATE_OF_BIRTH` | `PER_PERSONS.DATE_OF_BIRTH` | Direct via PERSON_ID (NOT date-tracked) |
| **MARITAL_STATUS** | `PER_ALL_PEOPLE_F.MARITAL_STATUS` | `PER_PEOPLE_LEGISLATIVE_F.MARITAL_STATUS` | Direct via PERSON_ID |

**CORRECT SQL Pattern:**
```sql
SELECT
    PPLF.SEX AS GENDER,
    PP.DATE_OF_BIRTH,
    PPLF.MARITAL_STATUS
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PEOPLE_LEGISLATIVE_F PPLF,
    PER_PERSONS PP
WHERE
    PAPF.PERSON_ID = PPLF.PERSON_ID
AND PAPF.PERSON_ID = PP.PERSON_ID
AND :P_EFFECTIVE_DATE BETWEEN PPLF.EFFECTIVE_START_DATE AND PPLF.EFFECTIVE_END_DATE
-- Note: PER_PERSONS is NOT date-tracked
```

### 15.2 Religion Lookup Pattern

**CRITICAL:** Religion requires subquery, not direct join

| Field | ❌ WRONG Approach | ✅ CORRECT Approach |
|-------|------------------|---------------------|
| **RELIGION** | `PER_ALL_PEOPLE_F.RELIGION_ID = PER_RELIGIONS.RELIGION_ID` | Subquery via PERSON_ID + Lookup |

**CORRECT SQL Pattern (SUBQUERY):**
```sql
(SELECT FLV.MEANING
 FROM PER_RELIGIONS PR, FND_LOOKUP_VALUES FLV
 WHERE PR.RELIGION = FLV.LOOKUP_CODE
   AND FLV.LOOKUP_TYPE = 'PER_RELIGION'
   AND FLV.LANGUAGE = 'US'
   AND PR.PERSON_ID = PAPF.PERSON_ID
   AND ROWNUM = 1
) AS RELIGION_NAME
```

**Key Points:**
- ❌ **NOT** joined via `PAPF.RELIGION_ID` (column doesn't exist or isn't reliable)
- ✅ Join via `PR.PERSON_ID = PAPF.PERSON_ID`
- ✅ Use `FND_LOOKUP_VALUES` to get the meaning
- ✅ Lookup type = `'PER_RELIGION'`
- ✅ Implemented as **SUBQUERY**, not in FROM clause

### 15.3 National Identifier (Dual Join Pattern)

**CRITICAL:** National Identifier requires BOTH join conditions

| Field | ❌ WRONG Approach | ✅ CORRECT Approach |
|-------|------------------|---------------------|
| **EMIRATES_ID / NATIONAL_ID** | Only `PRIMARY_NID_ID` join | **BOTH** `PRIMARY_NID_ID` + `PERSON_ID` |

**CORRECT SQL Pattern:**
```sql
SELECT
    PNI.NATIONAL_IDENTIFIER_NUMBER AS EMIRATES_ID
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_NATIONAL_IDENTIFIERS PNI
WHERE
    PAPF.PRIMARY_NID_ID = PNI.NATIONAL_IDENTIFIER_ID(+)
AND PNI.PERSON_ID(+) = PAPF.PERSON_ID  -- CRITICAL: Both joins required
```

**Key Points:**
- ✅ Use **BOTH** join conditions (not just one)
- ✅ `PRIMARY_NID_ID` links to `NATIONAL_IDENTIFIER_ID`
- ✅ `PERSON_ID` links to `PERSON_ID`

### 15.4 Nationality & Country of Birth

**CRITICAL:** Use PER_CITIZENSHIPS, not PER_NATIONALITIES_TL

| Field | ❌ WRONG Table | ✅ CORRECT Table |
|-------|---------------|------------------|
| **NATIONALITY** | `PER_NATIONALITIES_TL` | `PER_CITIZENSHIPS` + `FND_COMMON_LOOKUPS` |
| **COUNTRY_OF_BIRTH** | `PER_NATIONALITIES_TL` | `PER_CITIZENSHIPS` + `FND_TERRITORIES_VL` |

**CORRECT SQL Pattern (SUBQUERIES):**

**Nationality:**
```sql
(SELECT LISTAGG(LKP.MEANING,', ') WITHIN GROUP (ORDER BY LKP.MEANING)
 FROM PER_CITIZENSHIPS PC, FND_COMMON_LOOKUPS LKP
 WHERE PC.PERSON_ID = PAPF.PERSON_ID
   AND PC.CITIZENSHIP_STATUS = 'A'
   AND LKP.LOOKUP_CODE = PC.LEGISLATION_CODE
   AND LKP.LOOKUP_TYPE = 'NATIONALITY'
) AS NATIONALITY
```

**Country of Birth:**
```sql
(SELECT LISTAGG(FTV.TERRITORY_SHORT_NAME,', ') WITHIN GROUP (ORDER BY FTV.TERRITORY_SHORT_NAME)
 FROM PER_CITIZENSHIPS PC, FND_TERRITORIES_VL FTV
 WHERE PC.PERSON_ID = PAPF.PERSON_ID
   AND PC.CITIZENSHIP_STATUS = 'A'
   AND PC.LEGISLATION_CODE = FTV.TERRITORY_CODE
) AS COUNTRY_OF_BIRTH
```

**Key Points:**
- ❌ `PER_NATIONALITIES_TL` table does NOT exist or is not the correct approach
- ✅ Use `PER_CITIZENSHIPS` for both fields
- ✅ Use `LISTAGG` to handle multiple citizenships
- ✅ Filter by `CITIZENSHIP_STATUS = 'A'` (Active)

### 15.5 Summary - Table Join Reference

**Tables with PERSON_ID Join:**

| Table | Date-Tracked? | Key Fields | Notes |
|-------|---------------|------------|-------|
| `PER_ALL_PEOPLE_F` | ✅ Yes | Base person record | Primary table |
| `PER_PEOPLE_LEGISLATIVE_F` | ✅ Yes | SEX, MARITAL_STATUS | Legislative fields |
| `PER_PERSONS` | ❌ No | DATE_OF_BIRTH | **NOT date-tracked** |
| `PER_CITIZENSHIPS` | ❌ No | NATIONALITY, COUNTRY | Via subquery |
| `PER_RELIGIONS` | ❌ No | RELIGION | Via subquery with lookup |
| `PER_NATIONAL_IDENTIFIERS` | ❌ No | NATIONAL_ID | Dual join (PRIMARY_NID_ID + PERSON_ID) |

### 15.6 Master Validation Checklist

Before generating ANY SQL query involving personal information:

- [ ] SEX from `PER_PEOPLE_LEGISLATIVE_F.SEX` (NOT PAPF)
- [ ] DATE_OF_BIRTH from `PER_PERSONS.DATE_OF_BIRTH` (NOT PAPF)
- [ ] MARITAL_STATUS from `PER_PEOPLE_LEGISLATIVE_F.MARITAL_STATUS` (NOT PAPF)
- [ ] RELIGION via subquery from `PER_RELIGIONS` + `FND_LOOKUP_VALUES`
- [ ] NATIONALITY via subquery from `PER_CITIZENSHIPS` + `FND_COMMON_LOOKUPS`
- [ ] COUNTRY_OF_BIRTH via subquery from `PER_CITIZENSHIPS` + `FND_TERRITORIES_VL`
- [ ] NATIONAL_ID with BOTH `PRIMARY_NID_ID` and `PERSON_ID` joins
- [ ] PERSON_TYPE via `PER_ALL_ASSIGNMENTS_F` (NOT from PAPF)
- [ ] DEPARTMENT via `ORGANIZATION_ID` (NOT DEPARTMENT_ID)
- [ ] `PER_PERSONS` has NO date-track filtering

### 15.7 Common Mistakes Summary

**Mistake 1: Assuming PAPF has all personal fields**
```sql
-- ❌ WRONG
SELECT PAPF.SEX, PAPF.DATE_OF_BIRTH, PAPF.MARITAL_STATUS

-- ✅ CORRECT
SELECT PPLF.SEX, PP.DATE_OF_BIRTH, PPLF.MARITAL_STATUS
```

**Mistake 2: Single join for National Identifier**
```sql
-- ❌ WRONG
AND PAPF.PRIMARY_NID_ID = PNI.NATIONAL_IDENTIFIER_ID(+)

-- ✅ CORRECT
AND PAPF.PRIMARY_NID_ID = PNI.NATIONAL_IDENTIFIER_ID(+)
AND PNI.PERSON_ID(+) = PAPF.PERSON_ID
```

**Mistake 3: Using non-existent tables**
```sql
-- ❌ WRONG - Table doesn't exist or is wrong approach
PER_NATIONALITIES_TL

-- ✅ CORRECT
PER_CITIZENSHIPS + FND_COMMON_LOOKUPS
```

---

**Last Updated:** 07-Jan-2026  
**Status:** Production-Ready  
**Module:** Core HR  
**Version:** 2.2 (Merged with Department & Critical Mappings fixes)  
**Source Files:** HR_MASTER.md + HR_MASTER_UPDATE_02-01-26.md + HR_MASTER_PERSON_TYPE_FIX_05-01-26.md + HR_DEPARTMENTS_TABLE_FIX_05-01-26.md + HR_CRITICAL_TABLE_MAPPINGS_05-01-26.md
