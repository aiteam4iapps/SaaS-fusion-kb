# HCM Module Instructions

**Domain:** Oracle Fusion Human Capital Management
**Location:** `FUSION_SAAS/HCM/`

---

## 1. 📂 Module Navigation (Routes)

| Sub-Module | Instruction File | Repository File | Template File |
|------------|------------------|-----------------|---------------|
| **Core HR** | [HR_MASTER](HR/HR_MASTER.md) | [HR_REPOS](HR/HR_REPOSITORIES.md) | [HR_TMPL](HR/HR_TEMPLATES.md) |
| **Payroll** | [PAY_MASTER](PAY/PAY_MASTER.md) | [PAY_REPOS](PAY/PAY_REPOSITORIES.md) | [PAY_TMPL](PAY/PAY_TEMPLATES.md) |
| **Benefits** | [BEN_MASTER](BEN/BEN_MASTER.md) | [BEN_REPOS](BEN/BEN_REPOSITORIES.md) | [BEN_TMPL](BEN/BEN_TEMPLATES.md) |
| **Absence** | [ABSENCE_MASTER](ABSENCE/ABSENCE_MASTER.md) | [ABSENCE_REPOS](ABSENCE/ABSENCE_REPOSITORIES.md) | [ABSENCE_TMPL](ABSENCE/ABSENCE_TEMPLATES.md) |
| **Time & Labor** | [TL_MASTER](TIME_LABOR/TL_MASTER.md) | [TL_REPOS](TIME_LABOR/TL_REPOSITORIES.md) | [TL_TMPL](TIME_LABOR/TL_TEMPLATES.md) |
| **Compensation** | [CMP_MASTER](COMPENSATION/CMP_MASTER.md) | [CMP_REPOS](COMPENSATION/CMP_REPOSITORIES.md) | [CMP_TMPL](COMPENSATION/CMP_TEMPLATES.md) |

---

## 2. 🔗 Shared Integration Rules (Cross-Module)

### A. Date-Effective Records (The #1 Rule)
*   **Concept:** HCM tables track history. A person has multiple rows (one per change).
*   **Rule:** ALWAYS filter `TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE` (for current snapshots).
*   **Tables:** `PER_ALL_PEOPLE_F`, `PER_ALL_ASSIGNMENTS_M`, `PAY_ELEMENT_ENTRIES_F` (Any table ending in `_F` or `_M`).

### B. Enterprise Structures
*   **Business Unit:** `ORG_ID` (HR) vs `BU_ID` (Finance). Be careful with naming.
*   **Legal Entity:** `LEGAL_ENTITY_ID`.
*   **Legislative Data Group (LDG):** Crucial for Payroll partitioning.

### C. Security
*   **Assignment-Based Security:** Most data is secured at the Assignment level, not just Person level.

### D. Critical Table Mappings (Common Mistakes)
*   **DATE_OF_BIRTH:** Located in `PER_PERSONS`, **NOT** `PER_ALL_PEOPLE_F`
*   **SEX (Gender):** Located in `PER_PEOPLE_LEGISLATIVE_F`, **NOT** `PER_ALL_PEOPLE_F`
*   **MARITAL_STATUS:** Located in `PER_PEOPLE_LEGISLATIVE_F`, **NOT** `PER_ALL_PEOPLE_F`
*   **PERSON_TYPE_ID:** Located in `PER_ALL_ASSIGNMENTS_F`, **NOT** `PER_ALL_PEOPLE_F`
*   **EMAIL_ADDRESS:** Located in `PER_EMAIL_ADDRESSES`, **NOT** `PER_ALL_PEOPLE_F`
*   **NATIONALITY (Primary):** Filter using `PC.CITIZENSHIP_STATUS = 'A'`, **NOT** `PC.PRIMARY_FLAG = 'Y'` (column doesn't exist)
*   **PROBATION_PERIOD:** Stored in `PER_ALL_ASSIGNMENTS_F` (DFF attributes), **NOT** in `PER_PERIODS_OF_SERVICE` as standard columns
*   **JOB TITLE:** Use `PER_JOBS_F_VL.NAME` (broader classification)
*   **DESIGNATION (Position):** Use `HR_ALL_POSITIONS_F_TL.NAME` (specific role/title)

**Correct Pattern:**
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PERSONS PS,                      -- For DATE_OF_BIRTH (NOT date-tracked)
     PER_PEOPLE_LEGISLATIVE_F PPLF,       -- For SEX, MARITAL_STATUS (date-tracked)
     PER_ALL_ASSIGNMENTS_F PAAF,          -- For PERSON_TYPE_ID
     PER_EMAIL_ADDRESSES PEA,             -- For EMAIL_ADDRESS (date-tracked)
     PER_JOBS_F_VL JOB,                   -- For JOB_TITLE
     HR_ALL_POSITIONS_F_TL POS            -- For DESIGNATION (Position)
WHERE PAPF.PERSON_ID = PS.PERSON_ID
  AND PAPF.PERSON_ID = PPLF.PERSON_ID
  AND PAPF.PERSON_ID = PAAF.PERSON_ID
  AND PAPF.PERSON_ID = PEA.PERSON_ID(+)
  -- Assignment to Job and Position
  AND PAAF.JOB_ID = JOB.JOB_ID(+)
  AND PAAF.POSITION_ID = POS.POSITION_ID(+)
  AND POS.LANGUAGE(+) = 'US'
  -- Note: PER_PERSONS is NOT date-tracked, no EFFECTIVE_START/END_DATE
  AND :P_DATE BETWEEN PPLF.EFFECTIVE_START_DATE AND PPLF.EFFECTIVE_END_DATE
  AND :P_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
  AND :P_DATE BETWEEN JOB.EFFECTIVE_START_DATE(+) AND JOB.EFFECTIVE_END_DATE(+)
  AND :P_DATE BETWEEN POS.EFFECTIVE_START_DATE(+) AND POS.EFFECTIVE_END_DATE(+)
  -- Email filters
  AND PEA.EMAIL_TYPE(+) = 'W1'  -- Work email
  AND :P_DATE BETWEEN PEA.DATE_FROM(+) AND NVL(PEA.DATE_TO(+), TO_DATE('4712-12-31', 'YYYY-MM-DD'))
```

**Key Distinctions:**
- **JOB (Job Title)**: Broader classification (e.g., "Manager", "Developer")
- **DESIGNATION (Position)**: Specific role/title (e.g., "Senior Project Manager", "Lead Frontend Developer")

**Reference:** 
- HCM/HR/HR_MASTER.md Sections 12.2 and 15.1 for complete field mappings
- HCM/HR/HR_REPOSITORIES.md Section 4 (HR_ASG_MASTER) for Job/Position pattern

---

## 3. 📝 SQL Coding Standards

### A. Query Termination
*   **Rule:** SQL queries should **NOT** end with a semicolon (;)
*   **Reason:** Compatibility with Oracle BI Publisher and OTBI reporting tools
*   **Example:**
    ```sql
    SELECT * FROM PER_ALL_PEOPLE_F
    WHERE PERSON_ID = 123
    ORDER BY PERSON_NUMBER
    -- NO semicolon here
    ```

### B. Join Syntax (Oracle Old-Style Joins REQUIRED)
*   **Rule:** ALWAYS use Oracle old-style joins (comma-separated tables with WHERE clause)
*   **Never Use:** ANSI JOIN syntax (INNER JOIN, LEFT JOIN, RIGHT JOIN)
*   **Reason:** Standard practice for Oracle Fusion HCM queries, better compatibility
*   **Examples:**
    
    **Inner Join (Required table):**
    ```sql
    FROM TABLE1 T1, TABLE2 T2
    WHERE T1.ID = T2.ID
    ```
    
    **Outer Join (Optional table):**
    ```sql
    FROM TABLE1 T1, TABLE2 T2
    WHERE T1.ID = T2.ID(+)  -- (+) on optional side
    ```
    
    **Multiple Joins:**
    ```sql
    FROM PERSON_BASE PB,
         EMPLOYMENT_INFO EI,
         ASSIGNMENT_BASE AB,
         COMPENSATION COMP
    WHERE PB.PERSON_ID = EI.PERSON_ID          -- Inner join
      AND PB.PERSON_ID = AB.PERSON_ID(+)       -- Left join (AB optional)
      AND PB.PERSON_ID = COMP.PERSON_ID(+)     -- Left join (COMP optional)
    ```

### C. CTE Optimization
*   **Rule:** Use `/*+ qb_name(NAME) MATERIALIZE */` hints for all CTEs
*   **Reason:** Improves performance by caching intermediate results

### D. Date Formatting
*   **Standard Format:** `DD-MON-YYYY` for date outputs
*   **Example:** `TO_CHAR(DATE_COLUMN, 'DD-MON-YYYY')`
*   **ISO 8601:** Use `YYYY-MM-DDTHH24:MI:SS.000+00:00` when ISO format required

### E. NULL Handling
*   **Numeric Fields:** Use `NVL(column, 0)` for numeric calculations
*   **Text Fields:** Use outer joins `(+)` for optional relationships
*   **Rounding:** Always `ROUND(amount, 2)` for monetary values

### F. Performance Best Practices
*   Use `_M` tables (e.g., `PER_ALL_ASSIGNMENTS_M`) for current snapshot queries
*   Filter with `EFFECTIVE_LATEST_CHANGE = 'Y'` when using `_M` tables
*   Apply `PRIMARY_FLAG = 'Y'` for primary assignments
*   Use `CAST(column AS NUMBER DEFAULT 9999999999 ON CONVERSION ERROR)` for safe sorting

### G. Duplicate Prevention
*   **Rule:** Use subqueries with `ROWNUM = 1` for one-to-many relationships
*   **Common Causes:** Payroll assignments, email addresses, national identifiers
*   **Pattern:**
    ```sql
    -- BAD: Direct join can cause duplicates
    FROM PER_ALL_PEOPLE_F PAPF,
         PAY_ALL_PAYROLLS_F PAP
    WHERE PAPF.PERSON_ID = PAP.PERSON_ID(+)  -- Person can have multiple payrolls!
    
    -- GOOD: Subquery with ROWNUM = 1
    SELECT
        PAPF.PERSON_ID,
        (SELECT PAP.PAYROLL_NAME
         FROM PAY_ALL_PAYROLLS_F PAP
         WHERE PAP.PERSON_ID = PAPF.PERSON_ID
         AND ROWNUM = 1
        ) AS PAYROLL
    FROM PER_ALL_PEOPLE_F PAPF
    ```

---

## 4. 📋 Quick Reference - Common Field Locations

| Field Name | Correct Table | Key Points |
|------------|---------------|------------|
| **PERSON_ID** | PER_ALL_PEOPLE_F | Primary key for person |
| **PERSON_NUMBER** | PER_ALL_PEOPLE_F | Unique employee identifier |
| **PERSON_TYPE_ID** | PER_ALL_ASSIGNMENTS_F | ❌ NOT in PER_ALL_PEOPLE_F |
| **DATE_OF_BIRTH** | PER_PERSONS | ❌ NOT in PER_ALL_PEOPLE_F, NOT date-tracked |
| **SEX (Gender)** | PER_PEOPLE_LEGISLATIVE_F | ❌ NOT in PER_ALL_PEOPLE_F |
| **MARITAL_STATUS** | PER_PEOPLE_LEGISLATIVE_F | ❌ NOT in PER_ALL_PEOPLE_F |
| **EMAIL_ADDRESS** | PER_EMAIL_ADDRESSES | Filter: EMAIL_TYPE='W1' for work email |
| **FULL_NAME** | PER_PERSON_NAMES_F | Filter: NAME_TYPE='GLOBAL' |
| **ASSIGNMENT_STATUS** | PER_ASSIGNMENT_STATUS_TYPES_TL | Via ASSIGNMENT_STATUS_TYPE_ID |
| **DEPARTMENT** | PER_DEPARTMENTS | Join on ORGANIZATION_ID |
| **JOB (Job Title)** | PER_JOBS_F_VL | .NAME column, Date-tracked |
| **DESIGNATION (Position)** | HR_ALL_POSITIONS_F_TL | .NAME column, Date-tracked, LANGUAGE='US' |
| **GRADE** | PER_GRADES_F_VL | Date-tracked |
| **LOCATION** | PER_LOCATION_DETAILS_F_VL | Date-tracked |
| **PAYROLL_NAME** | PAY_ALL_PAYROLLS_F | Via relationship tables |
| **NATIONALITY** | PER_CITIZENSHIPS | Use subquery with FND_TERRITORIES_VL, filter: CITIZENSHIP_STATUS='A' |
| **EMIRATES_ID** | PER_NATIONAL_IDENTIFIERS | Join on PRIMARY_NID_ID or PERSON_ID |
| **RELIGION** | PER_RELIGIONS | Use subquery with FND_LOOKUP_VALUES |
| **HIRE_DATE** | PER_PERIODS_OF_SERVICE | DATE_START column |
| **TERMINATION_DATE** | PER_PERIODS_OF_SERVICE | ACTUAL_TERMINATION_DATE |
| **PROBATION_PERIOD** | PER_ALL_ASSIGNMENTS_F (DFF) | ❌ NOT standard columns - use DFF attributes |

---

## 5. ⚠️ Common Errors to Avoid

| ❌ WRONG | ✅ CORRECT | Why |
|---------|-----------|-----|
| `SELECT * FROM ...;` | `SELECT * FROM ...` | No semicolon for BI Publisher/OTBI |
| `INNER JOIN TABLE2 ON ...` | `FROM TABLE1, TABLE2 WHERE ...` | Use Oracle old-style joins |
| Direct join to payroll tables | Use subquery with `ROWNUM = 1` | Prevents duplicate rows |
| `PAPF.DATE_OF_BIRTH` | `PS.DATE_OF_BIRTH` | Wrong table |
| `PAPF.EMAIL_ADDRESS` | `PEA.EMAIL_ADDRESS` | Wrong table |
| `PAPF.PERSON_TYPE_ID` | `PAAF.PERSON_TYPE_ID` | Wrong table |
| `JOB.DESCRIPTION` for designation | `POS.NAME` (HR_ALL_POSITIONS_F_TL) | Use Position, not Job description |
| `PC.PRIMARY_FLAG = 'Y'` | `PC.CITIZENSHIP_STATUS = 'A'` | PRIMARY_FLAG column doesn't exist |
| `PPOS.PROBATION_PERIOD` | Use DFF in `PER_ALL_ASSIGNMENTS_F` | Columns don't exist in standard table |
| `TRUNC(SYSDATE)` everywhere | `:P_EFFECTIVE_DATE` | Historical accuracy |
| Missing `MATERIALIZE` | `/*+ MATERIALIZE */` | Performance |
| `TO_CHAR(date, 'MM/DD/YYYY')` | `TO_CHAR(date, 'DD-MON-YYYY')` | Standard format |

---

**Last Updated:** 13-Jan-2026  
**Version:** 2.0  
**Status:** Production Standards Active
