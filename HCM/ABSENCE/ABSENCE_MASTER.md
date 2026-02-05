# HCM Absence Master Instructions: Leave & Absence Management

**Module:** HCM Absence Management  
**Tag:** `#HCM #ABSENCE #LEAVE #TIMEOFF`  
**Status:** Active  
**Last Updated:** 07-Jan-2026  
**Version:** 2.0 (Merged with update file)

---

## 1. 🚨 Critical Absence Constraints
*Violating these rules breaks the system.*

### 1.1 Date-Track Filtering (The "Golden Rule")
**Rule:** `AND TRUNC(SYSDATE) BETWEEN [TABLE].EFFECTIVE_START_DATE AND [TABLE].EFFECTIVE_END_DATE`  
**Why:** Absence Type definitions and configurations change over time. Without this filter, you get historical versions.  
**Scope:** Applied to all `_F` tables (ANC_ABSENCE_TYPES_F_TL, ANC_ABSENCE_REASONS_F_TL, etc.)

### 1.2 Approval Status Filtering
**Rule:** `AND ABSENCE_ENTRY.APPROVAL_STATUS_CD NOT IN ('DENIED', 'ORA_WITHDRAWN', 'ORA_AWAIT_AWAIT')`  
**Why:** Prevents inclusion of rejected or withdrawn leave requests.  
**Scope:** All queries against `ANC_PER_ABS_ENTRIES`

**Approved Status Values:**
- `'APPROVED'` - Fully approved leaves
- Exclude: `'DENIED'`, `'ORA_WITHDRAWN'`, `'ORA_AWAIT_AWAIT'`, `'PENDING'`

### 1.3 Absence Status Filtering
**Rule:** `AND ABSENCE_ENTRY.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'`  
**Why:** Withdrawn entries should not appear in standard reports.  
**Scope:** All queries against `ANC_PER_ABS_ENTRIES`

**Valid Absence Status Lookups:**
- Lookup Type: `'ANC_PER_ABS_ENT_STATUS'`
- Exclude: `'Withdrawn'`, `'Denied'`, `'Awaiting'` (meanings)

### 1.4 Absence Type Classification
**Rule:** Always join to `ANC_ABSENCE_TYPES_F_TL` with `LANGUAGE = 'US'`  
**Why:** Absence types are translated. Without language filter, you get duplicate rows.  
**Scope:** All absence type lookups

**Common Absence Types:**
- `'Annual Leave'` - Standard annual/vacation leave
- `'Annual Leave Staff'` - Staff-specific annual leave
- `'Sick Leave'` - Medical/illness leave
- `'Vacation Leave'` - Holiday leave

### 1.5 Accrual Balance Filtering
**Rule:** Always get MAX accrual period for current year  
**Pattern:**
```sql
AND APAE.ACCRUAL_PERIOD = (
    SELECT MAX(APA.ACCRUAL_PERIOD)
    FROM ANC_PER_ACCRUAL_ENTRIES APA
    WHERE APAE.PERSON_ID = APA.PERSON_ID
    AND APA.PLAN_ID = APAE.PLAN_ID
    AND TO_CHAR(APA.ACCRUAL_PERIOD, 'YYYY') <= TO_CHAR(SYSDATE, 'YYYY')
)
```
**Why:** Accrual entries are incremental. Latest period has cumulative balance.  
**Scope:** All balance queries against `ANC_PER_ACCRUAL_ENTRIES`

### 1.6 Assignment Context
**Rule:** Link absence entries to active primary assignments  
**Pattern:**
```sql
AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
AND PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
```
**Why:** Ensures absence is linked to current employment record.  
**Scope:** All queries joining `ANC_PER_ABS_ENTRIES` to `PER_ALL_ASSIGNMENTS_F`

### 1.7 Period of Service Context
**Rule:** Filter active employment periods  
**Pattern:**
```sql
AND TRUNC(SYSDATE) BETWEEN PPOS.DATE_START 
    AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
```
**Why:** Links absence to valid employment term.  
**Scope:** Queries involving employment history

### 1.8 Effective Date Parameter (NEW)
**Rule:** Always use parameter date for date-track filtering (not SYSDATE)  
**Pattern:**
```sql
-- Define parameter
TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY'))

-- Apply to all date-tracked tables
AND P.EFFECTIVE_DATE BETWEEN TABLE.EFFECTIVE_START_DATE AND TABLE.EFFECTIVE_END_DATE

-- For accrual periods
AND APAE.ACCRUAL_PERIOD <= P.EFFECTIVE_DATE

-- For transactions
AND APAE.START_DATE <= P.EFFECTIVE_DATE
```

**Why:** Enables "as of" date queries for accurate historical reporting  
**Scope:** All queries requiring point-in-time accuracy

**Benefits:**
- Historical queries: Run report as of any past date
- Consistency: All data reflects same point in time
- Audit support: Recreate exact report as it appeared
- Comparison: Run for different dates to compare changes

### 1.9 Case-Insensitive Filtering (NEW)
**Rule:** Apply UPPER() to text parameters for case-insensitive comparison  
**Pattern:**
```sql
-- In PARAMETERS CTE
UPPER(NVL(:P_PARAMETER, 'ALL'))

-- In WHERE clause
UPPER(field) = P.PARAMETER OR P.PARAMETER = 'ALL'
```

**Why:** User doesn't need to match exact case, improves usability  
**Scope:** All text-based parameter filters

**Example:**
```
User enters: "abc corporation llc"
Matches: "ABC CORPORATION LLC", "Abc Corporation LLC", "ABC Corporation Llc"
```

---

## 2. ⚡ Performance Optimization

### 2.1 Index Hints

| Object | Optimal Access Path | Hint Syntax |
|--------|---------------------|-------------|
| **ANC_PER_ABS_ENTRIES** | PERSON_ID | `/*+ INDEX(APAE ANC_PER_ABS_ENTRIES_N1) */` |
| **ANC_PER_ACCRUAL_ENTRIES** | PERSON_ID + PLAN_ID | `/*+ INDEX(APAE ANC_PER_ACCRUAL_ENTRIES_N1) */` |
| **PER_ALL_PEOPLE_F** | PERSON_ID | `/*+ INDEX(PAPF PER_PEOPLE_F_PK) */` |

### 2.2 CTE Naming Convention
**Rule:** All CTEs MUST have `/*+ qb_name(NAME) */` hint  
**Pattern:**
```sql
WITH PERIOD AS (
    /*+ qb_name(PERIOD) */
    SELECT ...
)
```
**Why:** Mandatory performance standard per system instructions.  
**Scope:** ALL CTE definitions

### 2.3 Join Order Optimization
**Recommended Order:**
1. Start with Person/Assignment base (smallest set after date filtering)
2. Join to Absence Entries (filtered by date range)
3. Join to Absence Types/Reasons (lookup tables)
4. Join to Accrual Balances (aggregated data)
5. Join to Organizational/Manager hierarchy (denormalized data)

---

## 3. 🗺️ Schema Map (Key Tables)

### 3.1 Core Absence Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **APAE** | `ANC_PER_ABS_ENTRIES` | Absence Entry Header (Leave requests) |
| **AATFT** | `ANC_ABSENCE_TYPES_F_TL` | Absence Type Master (Annual, Sick, etc.) |
| **APACE** | `ANC_PER_ACCRUAL_ENTRIES` | Accrual Balance History |
| **AAPV** | `ANC_ABSENCE_PLANS_VL` | Absence Plan Definitions |
| **AATRF** | `ANC_ABSENCE_TYPE_REASONS_F` | Absence Reason Link |
| **AARF** | `ANC_ABSENCE_REASONS_F_TL` | Absence Reason Master |

### 3.2 Integration Tables (HR Core)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAPF** | `PER_ALL_PEOPLE_F` | Person Header |
| **PPNF** | `PER_PERSON_NAMES_F` | Person Names |
| **PAAF** | `PER_ALL_ASSIGNMENTS_F` | Assignment Details (contains PERSON_TYPE_ID) |
| **PPTTL** | `PER_PERSON_TYPES_TL` | Person Type Translations |
| **PPOS** | `PER_PERIODS_OF_SERVICE` | Employment Terms |
| **PASF** | `PER_ASSIGNMENT_SUPERVISORS_F` | Manager Hierarchy |

### 3.3 Organizational Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **HAOU** | `HR_ALL_ORGANIZATION_UNITS` | Organization Unit Master |
| **HAOUF** | `HR_ALL_ORGANIZATION_UNITS_F` | Date-tracked Org Units |
| **HAUFT** | `HR_ORGANIZATION_UNITS_F_TL` | Org Unit Translations |
| **HOUCF** | `HR_ORG_UNIT_CLASSIFICATIONS_F` | Org Classifications (DEPARTMENT, etc.) |

### 3.4 Workflow/Approval Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **WF** | `FA_FUSION_SOAINFRA.WFTASK` | Workflow Task History |

---

## 4. 📋 Standard Filters (Copy-Paste Ready)

### 4.1 Employee Base Filter
```sql
AND PAPF.PERSON_ID = PPNF.PERSON_ID
AND PAPF.PERSON_ID = PAAF.PERSON_ID
AND PPNF.NAME_TYPE = 'GLOBAL'
AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
AND PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE) AND TRUNC(PAPF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) AND TRUNC(PPNF.EFFECTIVE_END_DATE)
AND TRUNC(SYSDATE) BETWEEN TRUNC(PAAF.EFFECTIVE_START_DATE) AND TRUNC(PAAF.EFFECTIVE_END_DATE)
```

### 4.2 Absence Entry Filter (Approved Only)
```sql
AND AATFT.LANGUAGE = 'US'
AND AATFT.ABSENCE_TYPE_ID = APAE.ABSENCE_TYPE_ID
AND APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
AND APAE.APPROVAL_STATUS_CD NOT IN ('DENIED', 'ORA_WITHDRAWN', 'ORA_AWAIT_AWAIT')
```

### 4.3 Date Range Filter (Parameters)
```sql
AND TRUNC(APAE.START_DATE) BETWEEN 
    TRUNC(CAST(NVL(:P_START_DATE, (SELECT MIN(START_DATE) FROM ANC_PER_ABS_ENTRIES)) AS DATE))
    AND TRUNC(CAST(NVL(:P_END_DATE, LAST_DAY(SYSDATE)) AS DATE))
```

### 4.4 Organization/Department Filter
```sql
AND HAOUF.ORGANIZATION_ID = HOUCF.ORGANIZATION_ID
AND HAOUF.ORGANIZATION_ID = HAUFT.ORGANIZATION_ID
AND HAOUF.EFFECTIVE_START_DATE BETWEEN HOUCF.EFFECTIVE_START_DATE AND HOUCF.EFFECTIVE_END_DATE
AND HAUFT.LANGUAGE = 'US'
AND HAUFT.EFFECTIVE_START_DATE = HAOUF.EFFECTIVE_START_DATE
AND HAUFT.EFFECTIVE_END_DATE = HAOUF.EFFECTIVE_END_DATE
AND HOUCF.CLASSIFICATION_CODE = 'DEPARTMENT'
AND SYSDATE BETWEEN HAUFT.EFFECTIVE_START_DATE AND HAUFT.EFFECTIVE_END_DATE
```

### 4.5 Workflow Approval Filter
```sql
AND WF.OUTCOME IN ('APPROVE')
AND WF.ASSIGNEES IS NOT NULL
AND WF.WORKFLOWPATTERN NOT IN ('AGGREGATION', 'FYI')
AND TO_CHAR(APAE.PER_ABSENCE_ENTRY_ID) = WF.IDENTIFICATIONKEY(+)
```

### 4.6 Multi-Parameter Filter (NEW)
```sql
-- Multi-parameter with 'ALL' support
AND (UPPER(field1) = P.PARAM1 OR P.PARAM1 = 'ALL')
AND (UPPER(field2) = P.PARAM2 OR P.PARAM2 = 'ALL')
AND (UPPER(field3) = P.PARAM3 OR P.PARAM3 = 'ALL')
```

### 4.7 Effective Date Filter (NEW)
```sql
-- Use parameter date instead of SYSDATE
AND P.EFFECTIVE_DATE BETWEEN TABLE.EFFECTIVE_START_DATE AND TABLE.EFFECTIVE_END_DATE

-- For accrual periods
AND APAE.ACCRUAL_PERIOD <= P.EFFECTIVE_DATE

-- For transactions
AND APAE.START_DATE <= P.EFFECTIVE_DATE
```

---

## 5. 🔐 Business Rules

### 5.1 Leave Balance Calculation
**Rule:** Always use END_BAL from latest accrual period  
**Formula:** Current Balance = `APAE.END_BAL` from MAX(ACCRUAL_PERIOD)  
**Projected Balance:** Not stored - must be calculated as:
```
Projected = Current Balance - Pending Approved Leave Days
```

### 5.2 Duration Calculation
**Rule:** Duration is stored in `ANC_PER_ABS_ENTRIES.DURATION`  
**Unit:** Days (decimal, e.g., 0.5 for half-day)  
**Conversion:** Already calculated by Oracle - DO NOT recalculate from dates

### 5.3 Absence Type vs Plan Relationship
**Rule:** 
- `ANC_ABSENCE_TYPES_F_TL.NAME` = Display name (e.g., "Annual Leave")
- `ANC_ABSENCE_PLANS_VL.NAME` = Plan name (e.g., "Annual Leave Plan")
- Join: `PLAN_ID` links entries to plans
- Join: `ABSENCE_TYPE_ID` links entries to types

### 5.4 Absence Reason Handling
**Rule:** Absence reasons are OPTIONAL  
**Pattern:**
```sql
LEFT JOIN to ANC_ABSENCE_TYPE_REASONS_F using ABSENCE_TYPE_REASON_ID
```
**Why:** Not all absence types require reasons

### 5.5 Manager/Supervisor Lookup
**Rule:** Use `PER_ASSIGNMENT_SUPERVISORS_F` for current manager  
**Pattern:**
```sql
AND PASF.PERSON_ID = [Employee.PERSON_ID]
AND PASF.MANAGER_ID = [Manager.PERSON_ID]
AND TRUNC(SYSDATE) BETWEEN TRUNC(PASF.EFFECTIVE_START_DATE) AND TRUNC(PASF.EFFECTIVE_END_DATE)
```

### 5.6 Historical Leave Comparison
**Rule:** To find "All Previous Leave Taken Records":
```sql
SELECT COUNT(*) or details
FROM ANC_PER_ABS_ENTRIES APAE_HIST
WHERE APAE_HIST.PERSON_ID = [Current.PERSON_ID]
AND APAE_HIST.ABSENCE_TYPE_ID = [Current.ABSENCE_TYPE_ID]
AND APAE_HIST.PER_ABSENCE_ENTRY_ID <> [Current.PER_ABSENCE_ENTRY_ID]
AND APAE_HIST.APPROVAL_STATUS_CD = 'APPROVED'
AND APAE_HIST.START_DATE < [Current.START_DATE]
```

### 5.7 Service Calculation (NEW)
**Rule:** Use MONTHS_BETWEEN() / 12 for accurate service year calculation  
**Formula:** `ROUND(MONTHS_BETWEEN(EFFECTIVE_DATE, HIRE_DATE) / 12, 2)`

**Implementation:**
```sql
ROUND(MONTHS_BETWEEN(P.EFFECTIVE_DATE, 
    NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START)) / 12, 2) AS SERVICE_IN_YEARS
```

**Why:** Accurate to day-level precision, handles leap years correctly  
**Scope:** When service duration is required in reports

**Considerations:**
- Use ORIGINAL_DATE_OF_HIRE if available, else DATE_START
- ROUND to 2 decimal places for readability
- Use Effective Date (not SYSDATE) for consistency

### 5.8 Full Time / Part Time Classification (NEW)
**Rule:** Use NORMAL_HOURS from assignment to classify employees  
**Pattern:**
```sql
CASE 
    WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
    WHEN NVL(PAAF.NORMAL_HOURS, 0) > 0 AND NVL(PAAF.NORMAL_HOURS, 0) < 40 THEN 'Part Time'
    ELSE 'Not Specified'
END AS FULL_TIME_PART_TIME
```

**Why:** Standardized classification for reporting  
**Scope:** When FT/PT status is required  
**Note:** Adjust threshold (40 hours) based on organizational policy

**Customization Examples:**
```sql
-- For 35-hour workweek
WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 35 THEN 'Full Time'

-- For specific categories
CASE 
    WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
    WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 20 AND < 40 THEN 'Part Time'
    WHEN NVL(PAAF.NORMAL_HOURS, 0) > 0 AND < 20 THEN 'Casual'
    ELSE 'Not Specified'
END
```

### 5.9 Accrual Year Breakdown (NEW)
**Rule:** Split accrual balance into PY (Previous Year) and CY (Current Year) components  
**Pattern:**
```sql
-- Previous Year Carry Forward
SUM(CASE 
    WHEN TO_CHAR(APAE.ACCRUAL_PERIOD, 'YYYY') < TO_CHAR(P.EFFECTIVE_DATE, 'YYYY')
    THEN NVL(APAE.END_BAL, 0)
    ELSE 0 
END) AS PY_CARRY_FORWARD

-- Current Year Accrued
SUM(CASE 
    WHEN TO_CHAR(APAE.ACCRUAL_PERIOD, 'YYYY') = TO_CHAR(P.EFFECTIVE_DATE, 'YYYY')
    THEN NVL(APAE.ACCRUAL_BALANCE, 0)
    ELSE 0 
END) AS CY_ACCRUED
```

**Why:** Required for leave balance reporting and compliance  
**Scope:** Leave balance reports requiring carryover tracking

**Key Points:**
- Use TO_CHAR(date, 'YYYY') for year comparison
- PY uses END_BAL (cumulative balance from prior year)
- CY uses ACCRUAL_BALANCE (accrued in current year)
- Both filter ACCRUAL_PERIOD <= EFFECTIVE_DATE

### 5.10 Unpaid Leave Tracking (NEW)
**Rule:** Track unpaid leave separately using absence type name pattern  
**Pattern:** `UPPER(AATFT.NAME) LIKE '%UNPAID%'`

**Implementation:**
```sql
-- Unpaid leave taken
SUM(CASE 
    WHEN APAE.APPROVAL_STATUS_CD = 'APPROVED'
    AND APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
    AND UPPER(AATFT.NAME) LIKE '%UNPAID%'
    THEN NVL(APAE.DURATION, 0)
END) AS UNPAID_LEAVE_DAYS
```

**Why:** Unpaid leave affects entitlement calculations differently  
**Scope:** Leave transaction queries requiring unpaid leave separation

**Alternative Patterns:**
```sql
-- By category
AND AATFT.ABSENCE_CATEGORY = 'UNPAID'

-- By type code
AND AATFT.ABSENCE_TYPE_CODE LIKE '%UNPAID%'

-- By plan type
AND AAPV.PLAN_TYPE = 'UNPAID_LEAVE'
```

### 5.11 DFF Attribute Mapping (NEW)
**Rule:** Create separate CTE for DFF attribute to business field mapping  
**Pattern:**
```sql
-- Step 1: Expose in EMP_ASSIGNMENT
,EMP_ASSIGNMENT AS (
    SELECT
        PAAF.PERSON_ID,
        PAAF.ATTRIBUTE1,
        PAAF.ATTRIBUTE2,
        PAAF.ATTRIBUTE3,
        PAAF.ATTRIBUTE4,
        PAAF.ATTRIBUTE5
        -- ... other columns
    FROM PER_ALL_ASSIGNMENTS_F PAAF
)

-- Step 2: Map in EMP_DFF
,EMP_DFF AS (
    /*+ qb_name(EMP_DFF) */
    SELECT
        EA.PERSON_ID,
        -- Map DFF attributes to business fields
        EA.ATTRIBUTE1 AS CONTRACT_TYPE,
        EA.ATTRIBUTE5 AS CLIENT_JOB_TITLE,
        EA.ATTRIBUTE3 AS PROJECT_NUMBER,
        EA.ATTRIBUTE4 AS SERVICE_LINE
    FROM EMP_ASSIGNMENT EA
)
```

**Why:** Isolates DFF logic for easy maintenance and updates  
**Scope:** When DFF fields are required in reports

**Discovery Query:**
```sql
SELECT 
    APPLICATION_COLUMN_NAME,
    END_USER_COLUMN_NAME
FROM FND_DESCR_FLEX_COLUMN_USAGES
WHERE APPLICATION_TABLE_NAME = 'PER_ALL_ASSIGNMENTS_F'
AND ENABLED_FLAG = 'Y'
```

### 5.12 Multi-Parameter Filtering (NEW)
**Rule:** Implement independent optional filters with 'ALL' bypass  
**Pattern:** `(UPPER(field) = P.PARAMETER OR P.PARAMETER = 'ALL')`

**Implementation:**
```sql
-- In PARAMETERS CTE: Default to 'ALL'
WITH PARAMETERS AS (
    SELECT
        UPPER(NVL(:P_LEGAL_EMPLOYER, 'ALL')) AS LEGAL_EMPLOYER,
        UPPER(NVL(:P_ABSENCE_PLAN, 'ALL')) AS ABSENCE_PLAN,
        UPPER(NVL(:P_JOB_TITLE, 'ALL')) AS JOB_TITLE
    FROM DUAL
)

-- In WHERE clause: Apply 'OR = ALL' pattern
WHERE
    (UPPER(EA.LEGAL_EMPLOYER_NAME) = P.LEGAL_EMPLOYER OR P.LEGAL_EMPLOYER = 'ALL')
AND (UPPER(PE.PLAN_NAME) = P.ABSENCE_PLAN OR P.ABSENCE_PLAN = 'ALL')
AND (UPPER(EA.JOB_TITLE) = P.JOB_TITLE OR P.JOB_TITLE = 'ALL')
```

**Why:** Allows flexible filtering without complex NULL handling  
**Scope:** Reports with multiple independent filter parameters

**Benefits:**
- Each filter works independently
- No NULL handling needed (defaulted to 'ALL')
- Case-insensitive matching
- Clear, readable syntax

### 5.13 Balance Calculation Pattern (NEW)
**Rule:** Display all balance components separately PLUS calculated total  
**Formula:** `PY + CY + Adj - Enc - Taken - Expired = Balance`

**Implementation:**
```sql
SELECT
    -- Individual Components (visible)
    NVL(AB.PY_CARRY_FORWARD, 0) AS "PY Leave Carried Forward (Days)",
    NVL(AB.CY_ACCRUED, 0) AS "CY Leave Accrued (Days)",
    NVL(AB.BALANCE_ADJUSTMENT, 0) AS "Annual leave balance adjustment",
    NVL(EN.ANNUAL_LEAVE_ENCASHMENT, 0) AS "Annual leave encashment",
    NVL(LT.LEAVE_TAKEN, 0) AS "Leave Taken",
    NVL(CD.CARRYOVER_EXPIRED, 0) AS "Carryover Expired (days)",
    
    -- Calculated Balance (formula)
    (
        NVL(AB.PY_CARRY_FORWARD, 0) 
        + NVL(AB.CY_ACCRUED, 0) 
        + NVL(AB.BALANCE_ADJUSTMENT, 0) 
        - NVL(EN.ANNUAL_LEAVE_ENCASHMENT, 0) 
        - NVL(LT.LEAVE_TAKEN, 0) 
        - NVL(CD.CARRYOVER_EXPIRED, 0)
    ) AS "Calc. Leave Balance"
FROM ...
```

**Why:** Transparency, audit trail, verification capability  
**Scope:** Any balance calculation query

**Components:**
- PY Carry Forward (from prior years)
- CY Accrued (current year)
- Adjustments (manual changes)
- Encashment (paid out)
- Leave Taken (used)
- Carryover Expired (lapsed)

**Validation Query:**
```sql
SELECT 
    PERSON_NUMBER,
    (PY + CY + ADJ - ENC - TAKEN - EXPIRED) AS MANUAL_CALC,
    CALCULATED_BALANCE AS QUERY_CALC,
    MANUAL_CALC - QUERY_CALC AS DIFFERENCE
FROM result_table
WHERE ABS(MANUAL_CALC - QUERY_CALC) > 0.01
```

---

## 6. 🎯 Report-Specific Rules

### 6.1 Leave History Report
**Purpose:** Show all approved leaves with historical comparison  
**Key Columns:**
- Start Date, End Date, Type of Leave, Duration
- Historical comparison indicator
- Previous leave records summary
- Remarks/Details

**Filters:**
- Approved status only
- Date range (parameter-driven)
- Employee filter (parameter-driven)

### 6.2 Leave Balance Report
**Purpose:** Show current leave balances and active absences  
**Key Columns:**
- Employee details
- Absence type, start/end dates, duration
- Current accrual balance
- Absence reason, submission date
- Approval and absence status

**Filters:**
- Active absences (currently ongoing or future)
- Current year accrual balance
- Approved or submitted status

### 6.3 Leave Record Form
**Purpose:** Auto-generated form for single leave transaction  
**Key Fields:**
- Employee details (auto-populated)
- Leave information from timesheet
- Timesheet entry reference number
- Leave balance (before and after)
- Manager approval fields
- HR remarks

**Unique Requirements:**
- Single row per leave transaction
- Include SYSDATE for record generation
- Employee Login ID for signature
- Manager name and details

### 6.4 Comprehensive Leave Balance Report (NEW)
**Purpose:** Complete balance report with all components  
**Key Columns:**
- All employee and organizational details
- Service in years calculation
- FT/PT classification
- Balance component breakdown (PY, CY, Adj, Enc, Taken, Expired)
- Calculated total balance

**Filters:**
- Effective Date (mandatory)
- Multiple optional filters (Legal Employer, Plan, Job, Type, Location)
- All filters case-insensitive with 'ALL' bypass

**Calculations:**
- Service in Years: `ROUND(MONTHS_BETWEEN(EFFECTIVE_DATE, HIRE_DATE) / 12, 2)`
- FT/PT: Based on NORMAL_HOURS >= 40
- Balance: `PY + CY + Adj - Enc - Taken - Expired`

**Special Handling:**
- DFF attribute mapping
- Optional tables (carryover, encashment)
- Unpaid leave tracking
- PY/CY year breakdown

---

## 7. ⚠️ Common Pitfalls

### 7.1 Duplicate Rows
**Problem:** Getting multiple rows per absence entry  
**Causes:**
- Missing date-track filter on `_F` tables
- Missing `LANGUAGE = 'US'` on translation tables
- Joining without proper period of service context

**Solution:** Apply all date-track and language filters

### 7.2 PERSON_TYPE_ID Column Location
**Problem:** Column not found error for PERSON_TYPE_ID  
**Cause:**
- `PERSON_TYPE_ID` is NOT in `PER_ALL_PEOPLE_F`
- `PERSON_TYPE_ID` is in `PER_ALL_ASSIGNMENTS_F`

**Solution:** 
Always join through `PER_ALL_ASSIGNMENTS_F` to access `PERSON_TYPE_ID`:
```sql
FROM PER_ALL_PEOPLE_F PAPF,
     PER_ALL_ASSIGNMENTS_F PAAF,
     PER_PERSON_TYPES_TL PPTTL
WHERE PAPF.PERSON_ID = PAAF.PERSON_ID
AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID(+)
```

### 7.3 Missing Balances
**Problem:** NULL or zero balances  
**Causes:**
- Not filtering for MAX(ACCRUAL_PERIOD)
- Wrong plan name or plan ID
- Not filtering for current year

**Solution:** Use MAX subquery pattern from Section 1.5

### 7.4 Workflow Data Issues
**Problem:** Missing approver names  
**Causes:**
- `FA_FUSION_SOAINFRA.WFTASK` is a cross-schema view
- May require special permissions
- Workflow data may not be available in all environments

**Solution:** Use outer join and handle NULLs gracefully

### 7.5 Organization Hierarchy
**Problem:** Missing department names  
**Causes:**
- Complex date-tracked joins across 3+ tables
- Missing classification code filter

**Solution:** Use pre-validated DEPARTMENTS CTE from repository

### 7.6 Plan Name Case Sensitivity
**Problem:** Leave balances not found due to case sensitivity  
**Causes:**
- Plan names may be stored with different casing
- Direct string comparison fails

**Solution:** Use `UPPER()` function for case-insensitive matching:
```sql
AND UPPER(AAPV.NAME) = 'ANNUAL LEAVE'
```

### 7.7 Terminated Employee Date Filtering
**Problem:** Incorrect date-track filtering for terminated employees  
**Causes:**
- Standard SYSDATE filter doesn't work for terminated employees
- Need to handle both active and terminated employees

**Solution:** Use `LEAST()` function with termination date:
```sql
AND LEAST(NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY')), TRUNC(SYSDATE))
    BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
```

### 7.8 Source Language vs Language
**Problem:** Duplicate rows when using `_F_TL` tables  
**Causes:**
- Missing `SOURCE_LANG` filter
- `LANGUAGE` filter alone is insufficient

**Solution:** Always use both filters for `_F_TL` tables:
```sql
AND AAPFTL.SOURCE_LANG = 'US'
AND AAPFTL.LANGUAGE = 'US'
```

### 7.9 Using SYSDATE Instead of Parameter Date (NEW)
**Problem:** Using SYSDATE for date-track filtering in historical queries  
**Cause:** Default pattern uses SYSDATE, but historical queries need parameter date

**Solution:**
```sql
-- WRONG: Using SYSDATE
AND SYSDATE BETWEEN TABLE.EFFECTIVE_START_DATE AND TABLE.EFFECTIVE_END_DATE

-- CORRECT: Using parameter date
AND P.EFFECTIVE_DATE BETWEEN TABLE.EFFECTIVE_START_DATE AND TABLE.EFFECTIVE_END_DATE
```

**Impact:** Historical queries return incorrect data, audit reports are inaccurate

### 7.10 Case-Sensitive Parameter Matching (NEW)
**Problem:** Parameter filters don't work due to case mismatch  
**Cause:** Direct string comparison without UPPER()

**Solution:**
```sql
-- WRONG: Case-sensitive
WHERE EA.LEGAL_EMPLOYER_NAME = P.LEGAL_EMPLOYER

-- CORRECT: Case-insensitive
WHERE UPPER(EA.LEGAL_EMPLOYER_NAME) = P.LEGAL_EMPLOYER
```

### 7.11 Missing NVL() in Balance Calculations (NEW)
**Problem:** Balance calculation returns NULL due to NULL arithmetic  
**Cause:** Any NULL component makes entire calculation NULL

**Solution:**
```sql
-- WRONG: NULL-prone
SELECT (PY + CY + ADJ - ENC - TAKEN - EXPIRED) AS BALANCE

-- CORRECT: NVL-protected
SELECT (
    NVL(PY, 0) + NVL(CY, 0) + NVL(ADJ, 0) 
    - NVL(ENC, 0) - NVL(TAKEN, 0) - NVL(EXPIRED, 0)
) AS BALANCE
```

### 7.12 Optional Table Handling (NEW)
**Rule:** Use outer joins and comments for optional tables  
**Pattern:**
```sql
-- ============================================================================
-- CARRYOVER DETAILS (Optional - comment out if table doesn't exist)
-- ============================================================================
,CARRYOVER_DETAILS AS (
    /*+ qb_name(CARRYOVER_DETAILS) */
    SELECT ...
)

-- In final SELECT: Use outer join and NVL
SELECT
    NVL(CD.CARRYOVER_EXPIRED, 0) AS "Carryover Expired (days)"
FROM
    EMP_BASE EB,
    CARRYOVER_DETAILS CD
WHERE
    EB.PERSON_ID = CD.PERSON_ID(+)
```

**Why:** Query works in environments with or without optional tables  
**Scope:** Carryover, encashment, or other optional absence tables

---

## 8. 📊 Standard Columns (Always Include)

### 8.1 Employee Identification
- `PERSON_NUMBER` - Employee number
- `DISPLAY_NAME` / `FULL_NAME` - Employee name
- `EMPLOYEE_TYPE` - Person type

### 8.2 Organizational Context
- `DEPARTMENT` - Department name
- `BUSINESS_UNIT` - Business unit name
- `JOB` - Job title

### 8.3 Absence Details
- `ABSENCE_TYPE` - Leave type name
- `START_DATE` - Leave start date (formatted)
- `END_DATE` - Leave end date (formatted)
- `DURATION` - Number of days

### 8.4 Status Fields
- `APPROVAL_STATUS` - Approval status (meaning)
- `ABSENCE_STATUS` - Absence status (meaning)
- `SUBMITTED_DATE` - Date submitted
- `CONFIRMED_DATE` - Date approved/confirmed

### 8.5 Audit Columns (Optional but Recommended)
- `CREATION_DATE` - Record creation date
- `LAST_UPDATE_DATE` - Last modified date
- `CREATED_BY` - Created by user
- `LAST_UPDATED_BY` - Last updated by user

---

## 9. 🔧 Advanced Patterns

### 9.1 Workflow Approval Integration
**Purpose:** Link absence entries to workflow approval history  
**Table:** `FA_FUSION_SOAINFRA.WFTASK`

**Pattern:**
```sql
,WORKFLOW_APPROVAL AS (
    SELECT
        WF.IDENTIFICATIONKEY,
        WF.ASSIGNEESDISPLAYNAME APPROVER_NAME,
        WF.FROMUSERDISPLAYNAME REQUESTOR_NAME,
        WF.OUTCOME
    FROM
        FA_FUSION_SOAINFRA.WFTASK WF
    WHERE
        WF.OUTCOME IN ('APPROVE')
    AND WF.ASSIGNEES IS NOT NULL
    AND WF.WORKFLOWPATTERN NOT IN ('AGGREGATION', 'FYI')
)
```

**Join Pattern:**
```sql
AND TO_CHAR(APAE.PER_ABSENCE_ENTRY_ID) = WF.IDENTIFICATIONKEY(+)
```

**Notes:**
- Cross-schema access required (FA_FUSION_SOAINFRA)
- May not be available in all environments
- Always use outer join
- IDENTIFICATIONKEY is character-based, convert PER_ABSENCE_ENTRY_ID to CHAR

### 9.2 Payroll Integration (Salary Advance Recovery)
**Purpose:** Link salary advance recovery to absence entries  
**Tables:** `PAY_ELEMENT_ENTRIES_F`, `PAY_ELEMENT_ENTRY_VALUES_F`, `PAY_INPUT_VALUES_F`, `PAY_ELEMENT_TYPES_F`

**Pattern:**
```sql
,SALARY_ADVANCE AS (
    SELECT
        PEEF.PERSON_ID,
        PEEV.SCREEN_ENTRY_VALUE ADVANCE_SALARY
    FROM
        PAY_ELEMENT_ENTRIES_F PEEF,
        PAY_ELEMENT_ENTRY_VALUES_F PEEV,
        PAY_INPUT_VALUES_F PIVF,
        PAY_ELEMENT_TYPES_F PETF,
        PER_ALL_PEOPLE_F PAPF
    WHERE
        PEEF.ELEMENT_ENTRY_ID = PEEV.ELEMENT_ENTRY_ID
    AND PIVF.ELEMENT_TYPE_ID = PETF.ELEMENT_TYPE_ID
    AND PIVF.INPUT_VALUE_ID = PEEV.INPUT_VALUE_ID
    AND PIVF.ELEMENT_TYPE_ID = PEEF.ELEMENT_TYPE_ID
    AND PIVF.BASE_NAME IN ('AMOUNT', 'PAY VALUE')
    AND PETF.BASE_ELEMENT_NAME = 'SALARY ADVANCE RECOVERY RETRO'
    AND PEEF.PERSON_ID = PAPF.PERSON_ID
)
```

**Join Pattern:**
```sql
LEFT JOIN SALARY_ADVANCE SA ON PAAF.PERSON_ID = SA.PERSON_ID
```

### 9.3 Specific Absence Type Filtering
**Rule:** Different absence types may require different handling  

**Annual Leave Staff Pattern:**
```sql
AND ((ABS_TYPE.NAME = 'Annual Leave Staff'
      OR ABS_TYPE.NAME <> 'Annual Leave Staff')
    AND TRUNC(SYSDATE) BETWEEN ABS_ENTR.START_DATE AND ABS_ENTR.END_DATE)
```

**Multiple Type Filter:**
```sql
AND AATFT.NAME IN ('Annual Leave', 'Annual Leave Staff', 'Sick Leave')
```

**Case-Insensitive Filter:**
```sql
AND UPPER(AAPV.NAME) = 'ANNUAL LEAVE'
```

### 9.4 Current Year Accrual Balance Filter
**Purpose:** Get accrual balance for specific year only  

**Pattern:**
```sql
AND APAE.ACCRUAL_PERIOD BETWEEN 
    TO_DATE('01/01/' || TO_CHAR(TRUNC(SYSDATE), 'YYYY'), 'DD/MM/YYYY') 
    AND TO_DATE('31/12/' || TO_CHAR(TRUNC(SYSDATE), 'YYYY'), 'DD/MM/YYYY')
```

**Why:** Filters accrual periods to current calendar year only

### 9.5 Status Decoding via HR_LOOKUPS
**Purpose:** Convert status codes to user-friendly meanings  

**Approval Status Pattern:**
```sql
SELECT HL.MEANING
FROM HR_LOOKUPS HL
WHERE HL.LOOKUP_CODE = ABS_ENTR.APPROVAL_STATUS_CD
AND HL.LOOKUP_TYPE = 'ANC_PER_ABS_ENT_APROVAL_STATUS'
```

**Absence Status Pattern:**
```sql
SELECT HL.MEANING
FROM HR_LOOKUPS HL
WHERE HL.LOOKUP_CODE = ABS_ENTR.ABSENCE_STATUS_CD
AND HL.LOOKUP_TYPE = 'ANC_PER_ABS_ENT_STATUS'
```

**Filter by Meaning:**
```sql
AND (SELECT HL.MEANING
     FROM HR_LOOKUPS HL
     WHERE HL.LOOKUP_CODE = ABS_ENTR.ABSENCE_STATUS_CD
     AND HL.LOOKUP_TYPE = 'ANC_PER_ABS_ENT_STATUS') 
    NOT IN ('Withdrawn', 'Denied', 'Awaiting')
```

### 9.6 Complex Absence Reason Lookup
**Purpose:** Get absence reason name through type relationship  

**Pattern:**
```sql
,ABSENCE_REASONS AS (
    SELECT
        AARF.NAME,
        AARF.ABSENCE_REASON_ID,
        AAT.ABSENCE_TYPE_REASON_ID
    FROM
        ANC_ABSENCE_REASONS_F AAR,
        ANC_ABSENCE_REASONS_F_TL AARF,
        ANC_ABSENCE_TYPE_REASONS_F AAT
    WHERE
        AAR.ABSENCE_REASON_ID = AARF.ABSENCE_REASON_ID
    AND AAR.ABSENCE_REASON_ID = AAT.ABSENCE_REASON_ID
    AND AARF.LANGUAGE = 'US'
    AND SYSDATE BETWEEN AAR.EFFECTIVE_START_DATE AND AAR.EFFECTIVE_END_DATE
    AND SYSDATE BETWEEN AARF.EFFECTIVE_START_DATE AND AARF.EFFECTIVE_END_DATE
    AND SYSDATE BETWEEN AAT.EFFECTIVE_START_DATE AND AAT.EFFECTIVE_END_DATE
)
```

**Join Pattern:**
```sql
AND APAE.ABSENCE_TYPE_REASON_ID = REA.ABSENCE_TYPE_REASON_ID(+)
```

### 9.7 Service Duration Calculation (NEW)
**Purpose:** Calculate accurate service years for entitlement  
**Pattern:**
```sql
ROUND(MONTHS_BETWEEN(EFFECTIVE_DATE, 
    NVL(ORIGINAL_DATE_OF_HIRE, DATE_START)) / 12, 2) AS SERVICE_IN_YEARS
```

### 9.8 Year-Based Accrual Breakdown (NEW)
**Purpose:** Separate PY and CY accruals  
**Pattern:**
```sql
-- Previous Year
SUM(CASE 
    WHEN TO_CHAR(ACCRUAL_PERIOD, 'YYYY') < TO_CHAR(EFFECTIVE_DATE, 'YYYY')
    THEN NVL(END_BAL, 0)
    ELSE 0 
END) AS PY_CARRY_FORWARD

-- Current Year
SUM(CASE 
    WHEN TO_CHAR(ACCRUAL_PERIOD, 'YYYY') = TO_CHAR(EFFECTIVE_DATE, 'YYYY')
    THEN NVL(ACCRUAL_BALANCE, 0)
    ELSE 0 
END) AS CY_ACCRUED
```

### 9.9 FT/PT Classification Logic (NEW)
**Purpose:** Standardized employee time classification  
**Pattern:**
```sql
CASE 
    WHEN NVL(NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
    WHEN NVL(NORMAL_HOURS, 0) > 0 AND NVL(NORMAL_HOURS, 0) < 40 THEN 'Part Time'
    ELSE 'Not Specified'
END AS FULL_TIME_PART_TIME
```

---

## 10. 🔄 Integration Points

### 10.1 Payroll Integration
**Link:** Absence entries feed into payroll for leave deductions  
**Key Fields:** `PERSON_ID`, `ABSENCE_TYPE_ID`, `START_DATE`, `END_DATE`, `DURATION`

### 10.2 Time and Labor Integration
**Link:** Absence entries may originate from timesheet  
**Key Fields:** Timesheet entry reference (if available)

### 10.3 Workflow Integration
**Link:** Approval workflow tracks in `FA_FUSION_SOAINFRA.WFTASK`  
**Key Fields:** `IDENTIFICATIONKEY` = `PER_ABSENCE_ENTRY_ID`

### 10.4 Salary Advance Recovery Integration
**Link:** Leave may impact salary advance recovery in payroll  
**Tables:** `PAY_ELEMENT_ENTRIES_F`, `PAY_ELEMENT_ENTRY_VALUES_F`  
**Key Fields:** `PERSON_ID`, Element type: 'SALARY ADVANCE RECOVERY RETRO'

---

## 11. ✅ Self-Validation Checklist

Before finalizing any Absence Management query, verify:

**Core Constraints:**
- [ ] Date-track filter applied to all `_F` tables
- [ ] `LANGUAGE = 'US'` applied to all `_TL` tables
- [ ] Approval status filter applied (exclude DENIED, WITHDRAWN)
- [ ] Absence status filter applied (exclude Withdrawn)
- [ ] MAX accrual period logic for balances
- [ ] Active assignment filters applied
- [ ] Oracle Traditional Join Syntax used (no ANSI joins)
- [ ] All CTEs have `/*+ qb_name(NAME) */` hints
- [ ] Date formatting uses `INITCAP(TO_CHAR(..., 'DD-fmMON-YYYY'))`
- [ ] Parameters handle NULL with NVL or default values
- [ ] All joins use outer join (+) where appropriate

**NEW Pattern Checks:**
- [ ] Effective Date parameter used (not SYSDATE) for date-track filtering
- [ ] All text parameters use UPPER() for case-insensitive comparison
- [ ] Service calculation uses MONTHS_BETWEEN() / 12 pattern
- [ ] FT/PT classification based on NORMAL_HOURS (threshold documented)
- [ ] Accrual balance split by year (PY vs CY) if required
- [ ] Unpaid leave identified separately if required
- [ ] Multi-parameter filters use 'OR = ALL' pattern
- [ ] Balance calculation displays all components + total
- [ ] All components use NVL() to prevent NULL arithmetic
- [ ] Optional tables handled with outer joins and comments
- [ ] DFF attributes mapped in separate CTE with discovery query documented

---

## 📊 PATTERN PRIORITY

**Critical Patterns** (Must Use):
1. Effective Date filtering (not SYSDATE)
2. Date-track filtering on all `_F` tables
3. LANGUAGE = 'US' on all `_TL` tables
4. Active assignment filters
5. NVL() in calculations

**High Priority Patterns** (Strongly Recommended):
1. Case-insensitive parameter filtering
2. Multi-parameter 'ALL' bypass
3. Service calculation standard formula
4. Balance component breakdown

**Medium Priority Patterns** (Use When Applicable):
1. FT/PT classification
2. PY/CY accrual breakdown
3. Unpaid leave tracking
4. DFF attribute mapping
5. Optional table handling

---

## Summary

This ABSENCE_MASTER document contains:
- Critical constraints for absence/leave queries
- Approval and status filtering rules
- Performance optimization patterns
- Schema map and table relationships
- Standard filters (copy-paste ready)
- Business rules for calculations
- Report-specific requirements
- Common pitfalls and solutions
- NEW patterns from Employee Annual Leave Balance Report
- Self-validation checklist

**Usage:** Review this document BEFORE generating any absence/leave SQL. Apply all constraints and patterns.

**Update Frequency:** When new absence types, plans, or business rules are added.

---

**END OF ABSENCE_MASTER.md**

**Status:** Merged and Complete  
**Last Merged:** 07-Jan-2026  
**Source Files:** ABSENCE_MASTER.md + ABSENCE_MASTER_UPDATE_31-12-25.md  
**Version:** 2.0
