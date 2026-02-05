# HCM Absence Repositories: Pre-Validated CTEs

**Module:** HCM Absence Management  
**Purpose:** Ready-to-use CTE components for absence/leave queries  
**Tag:** `#HCM #ABSENCE #REPOSITORIES #CTEs`  
**Last Updated:** 07-Jan-2026  
**Version:** 2.0 (Merged with update file)

---

## 📋 Repository Index

| CTE Name | Purpose | Source Tables | Use Case |
|----------|---------|---------------|----------|
| **PARAMETERS (Enhanced)** | Parameter handling with case-insensitive filtering | Parameters | All reports with filters |
| **PERIOD** | Date range & employee filter | Parameters | All reports |
| **EMP_MASTER** | Employee base details | PER_ALL_PEOPLE_F, PER_PERSON_NAMES_F | All employee queries |
| **EMP_BASE (Enhanced)** | Employee base with service calculation | PER_ALL_PEOPLE_F, PPOS | Reports requiring service years |
| **EMP_ASSIGNMENT** | Assignment & org details | PER_ALL_ASSIGNMENTS_F, departments | All queries |
| **EMP_ASSIGNMENT (Enhanced FT/PT)** | Assignment with Full Time/Part Time classification | PER_ALL_ASSIGNMENTS_F | Reports with FT/PT status |
| **EMP_DFF** | DFF attribute mapping | EMP_ASSIGNMENT | Reports with DFF fields |
| **DEPARTMENTS** | Organization/Department hierarchy | HR_ALL_ORGANIZATION_UNITS_F | Org structure queries |
| **LEAVE_TRANSACTIONS** | Absence entries (approved) | ANC_PER_ABS_ENTRIES | Leave history reports |
| **LEAVE_TRANSACTIONS (Enhanced)** | With unpaid leave tracking | ANC_PER_ABS_ENTRIES, AATFT | Reports tracking unpaid leave |
| **ABSENCE_TYPES** | Leave type master | ANC_ABSENCE_TYPES_F_TL | Type classification |
| **ANNUAL_LEAVE_BALANCE** | Annual leave balance | ANC_PER_ACCRUAL_ENTRIES | Balance reports |
| **ACCRUAL_BALANCE (Enhanced)** | With PY/CY year breakdown | ANC_PER_ACCRUAL_ENTRIES | Comprehensive balance |
| **LEAVE_BALANCES** | All leave plan balances | ANC_PER_ACCRUAL_ENTRIES | Multi-plan balance |
| **SUPERVISOR** | Manager hierarchy | PER_ASSIGNMENT_SUPERVISORS_F | Manager approval queries |
| **WORKFLOW_APPROVAL** | Approval workflow history | FA_FUSION_SOAINFRA.WFTASK | Approval tracking |
| **ABSENCE_REASONS** | Absence reason lookup | ANC_ABSENCE_REASONS_F_TL | Reason classification |
| **LEAVE_HISTORY** | Historical leave summary | ANC_PER_ABS_ENTRIES | Historical comparison |
| **WORKFLOW_APPROVAL_DETAIL** | Detailed workflow with names | FA_FUSION_SOAINFRA.WFTASK | Enhanced approval tracking |
| **SALARY_ADVANCE_RECOVERY** | Salary advance from payroll | PAY_ELEMENT_ENTRIES_F | Payroll integration |
| **LEAVE_DETAILS_ENHANCED** | Enhanced leave with workflow | ANC_PER_ABS_ENTRIES, WFTASK | Comprehensive leave details |
| **ANNUAL_LEAVE_BALANCE_ADVANCED** | Case-insensitive balance | ANC_PER_ACCRUAL_ENTRIES | Balance with UPPER matching |
| **CURRENT_ABSENCE_ENTRIES** | Current/ongoing absences | ANC_PER_ABS_ENTRIES | Current absence activity |
| **TERMINATED_EMP_FILTER** | Employee with termination handling | PER_ALL_ASSIGNMENTS_F, PPOS | Terminated employee queries |
| **ACCRUAL_BALANCE_CURRENT_YEAR** | Current year balance only | ANC_PER_ACCRUAL_ENTRIES | Year-specific balance |
| **PLAN_ENROLLMENT** | Absence plan enrollment | ANC_PER_ENROLLMENTS | Plan-based queries |
| **CARRYOVER_DETAILS** | Carryover and expiry | ANC_PER_CARRYOVER | Balance with carryover |
| **ENCASHMENT_DETAILS** | Leave encashment | ANC_PER_ENCASHMENTS | Encashment tracking |

---

## 1. PARAMETERS CTE (Enhanced with Case-Insensitive Filtering)

**Purpose:** Parameter handling with automatic case normalization  
**Usage:** Use when parameters need case-insensitive comparison

```sql
WITH PARAMETERS AS (
    /*+ qb_name(PARAMETERS) */
    SELECT
        TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        UPPER(NVL(:P_LEGAL_EMPLOYER, 'ALL')) AS LEGAL_EMPLOYER,
        UPPER(NVL(:P_ABSENCE_PLAN, 'ALL')) AS ABSENCE_PLAN,
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

---

## 2. PERIOD CTE
**Purpose:** Parameter-driven date range and employee filter  
**Usage:** Copy at the start of every query

```sql
WITH PERIOD AS (
    /*+ qb_name(PERIOD) */
    SELECT
        TRUNC(CAST(NVL(:P_START_DATE, ADD_MONTHS(TRUNC(SYSDATE), -12)) AS DATE)) AS START_DATE,
        TRUNC(CAST(NVL(:P_END_DATE, LAST_DAY(SYSDATE)) AS DATE)) AS END_DATE,
        :P_EMP_NO AS EMPLOYEE_NUMBER,
        :P_EMP_NAME AS EMPLOYEE_NAME
    FROM DUAL
)
```

**Parameters:**
- `:P_START_DATE` - Start date (defaults to 12 months ago)
- `:P_END_DATE` - End date (defaults to end of current month)
- `:P_EMP_NO` - Employee number (optional, use 'ALL' for all employees)
- `:P_EMP_NAME` - Employee name (optional, use 'ALL' for all employees)

---

## 3. DEPARTMENTS CTE
**Purpose:** Organization/Department hierarchy with proper classification  
**Usage:** Standard department lookup for all queries

```sql
,DEPARTMENTS AS (
    /*+ qb_name(DEPARTMENTS) */
    SELECT
        HAUFT.ORGANIZATION_ID,
        HAUFT.NAME DEPARTMENT
    FROM
        HR_ORG_UNIT_CLASSIFICATIONS_F HOUCF,
        HR_ALL_ORGANIZATION_UNITS_F HAOUF,
        HR_ORGANIZATION_UNITS_F_TL HAUFT
    WHERE
        HAOUF.ORGANIZATION_ID = HOUCF.ORGANIZATION_ID
    AND HAOUF.ORGANIZATION_ID = HAUFT.ORGANIZATION_ID
    AND HAOUF.EFFECTIVE_START_DATE BETWEEN HOUCF.EFFECTIVE_START_DATE AND HOUCF.EFFECTIVE_END_DATE
    AND HAUFT.LANGUAGE = 'US'
    AND HAUFT.EFFECTIVE_START_DATE = HAOUF.EFFECTIVE_START_DATE
    AND HAUFT.EFFECTIVE_END_DATE = HAOUF.EFFECTIVE_END_DATE
    AND HOUCF.CLASSIFICATION_CODE = 'DEPARTMENT'
    AND SYSDATE BETWEEN HAUFT.EFFECTIVE_START_DATE AND HAUFT.EFFECTIVE_END_DATE
)
```

**Key Filters:**
- `CLASSIFICATION_CODE = 'DEPARTMENT'` - Only department-level orgs
- `LANGUAGE = 'US'` - English translation
- Date-tracked on SYSDATE

---

## 4. EMP_MASTER CTE
**Purpose:** Employee base details (person and names)  
**Usage:** Foundation for all employee queries

```sql
,EMP_MASTER AS (
    /*+ qb_name(EMP_MASTER) */
    SELECT
        PAPF.PERSON_ID,
        PAPF.PERSON_NUMBER,
        PPNF.DISPLAY_NAME,
        PPNF.FULL_NAME,
        PPTTL.USER_PERSON_TYPE EMPLOYEE_TYPE
    FROM
        PER_ALL_PEOPLE_F PAPF,
        PER_PERSON_NAMES_F PPNF,
        PER_ALL_ASSIGNMENTS_F PAAF,
        PER_PERSON_TYPES_TL PPTTL
    WHERE
        PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF.PERSON_ID
    AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID(+)
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND PPTTL.LANGUAGE(+) = 'US'
    AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PAPF.EFFECTIVE_START_DATE) AND TRUNC(PAPF.EFFECTIVE_END_DATE)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) AND TRUNC(PPNF.EFFECTIVE_END_DATE)
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PAAF.EFFECTIVE_START_DATE) AND TRUNC(PAAF.EFFECTIVE_END_DATE)
)
```

**Key Filters:**
- `NAME_TYPE = 'GLOBAL'` - Standard display name
- Date-tracked on SYSDATE
- Outer join to person type (optional)

---

## 5. EMP_BASE WITH SERVICE CALCULATION (Enhanced)

**Purpose:** Employee base with service years calculation  
**Usage:** When service duration is required in reports

```sql
,EMP_BASE AS (
    /*+ qb_name(EMP_BASE) */
    SELECT
        PAPF.PERSON_ID,
        PAPF.PERSON_NUMBER,
        PPNF.FULL_NAME,
        PPNF.DISPLAY_NAME,
        PPTTL.USER_PERSON_TYPE AS PERSON_TYPE,
        PPOS.PERIOD_OF_SERVICE_ID,
        TO_CHAR(NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START), 'DD-MM-YYYY') AS HIRE_DATE,
        NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START) AS HIRE_DATE_RAW,
        PPOS.DATE_START,
        PPOS.ACTUAL_TERMINATION_DATE,
        -- Calculate Service in Years as of Effective Date
        ROUND(MONTHS_BETWEEN(P.EFFECTIVE_DATE, NVL(PPOS.ORIGINAL_DATE_OF_HIRE, PPOS.DATE_START)) / 12, 2) AS SERVICE_IN_YEARS
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
    -- Date-track filtering using P.EFFECTIVE_DATE (NOT SYSDATE)
    AND P.EFFECTIVE_DATE BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PPOS.DATE_START 
        AND NVL(PPOS.ACTUAL_TERMINATION_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
)
```

**Key Features:**
- **Service calculation**: `ROUND(MONTHS_BETWEEN(...) / 12, 2)` gives years of service
- **Dual date formats**: Both formatted (DD-MM-YYYY) and raw date for different uses
- **Effective Date filtering**: Uses parameter date instead of SYSDATE
- **Termination handling**: NVL with far future date for active employees

**Service Calculation Formula:**
```sql
ROUND(MONTHS_BETWEEN(EFFECTIVE_DATE, HIRE_DATE) / 12, 2)
```

---

## 6. EMP_ASSIGNMENT CTE
**Purpose:** Assignment details with job and department  
**Usage:** For organizational context in reports

```sql
,EMP_ASSIGNMENT AS (
    /*+ qb_name(EMP_ASSIGNMENT) */
    SELECT
        PAAF.PERSON_ID,
        PAAF.ASSIGNMENT_ID,
        PAAF.ASSIGNMENT_NUMBER,
        PAAF.ORGANIZATION_ID,
        PAAF.BUSINESS_UNIT_ID,
        PAAF.PERIOD_OF_SERVICE_ID,
        PJFV.NAME AS JOB_NAME,
        PD.NAME AS DEPARTMENT_NAME,
        HAOU.NAME AS ORG_NAME
    FROM
        PER_ALL_ASSIGNMENTS_F PAAF,
        PER_JOBS_F_VL PJFV,
        PER_DEPARTMENTS PD,
        HR_ALL_ORGANIZATION_UNITS HAOU
    WHERE
        PAAF.JOB_ID = PJFV.JOB_ID(+)
    AND PAAF.ORGANIZATION_ID = PD.ORGANIZATION_ID(+)
    AND PAAF.ORGANIZATION_ID = HAOU.ORGANIZATION_ID(+)
    AND PAAF.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND PAAF.PRIMARY_FLAG = 'Y'
    AND PAAF.ASSIGNMENT_TYPE = 'E'
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PAAF.EFFECTIVE_START_DATE) AND TRUNC(PAAF.EFFECTIVE_END_DATE)
)
```

**Key Filters:**
- `ASSIGNMENT_STATUS_TYPE = 'ACTIVE'` - Active assignments only
- `PRIMARY_FLAG = 'Y'` - Primary assignment only
- `ASSIGNMENT_TYPE = 'E'` - Employee assignments (not contingent worker)
- Date-tracked on SYSDATE

---

## 7. EMP_ASSIGNMENT WITH FULL TIME/PART TIME CLASSIFICATION (Enhanced)

**Purpose:** Assignment details with employee classification  
**Usage:** When FT/PT status is required

```sql
,EMP_ASSIGNMENT AS (
    /*+ qb_name(EMP_ASSIGNMENT) */
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
        -- Full Time / Part Time determination
        CASE 
            WHEN NVL(PAAF.NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
            WHEN NVL(PAAF.NORMAL_HOURS, 0) > 0 AND NVL(PAAF.NORMAL_HOURS, 0) < 40 THEN 'Part Time'
            ELSE 'Not Specified'
        END AS FULL_TIME_PART_TIME,
        -- DFF Attributes (for reference)
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
    AND P.EFFECTIVE_DATE BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PJFV.EFFECTIVE_START_DATE(+) AND PJFV.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN HAPL.EFFECTIVE_START_DATE(+) AND HAPL.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN PD.EFFECTIVE_START_DATE(+) AND PD.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN HLOCVL.EFFECTIVE_START_DATE(+) AND HLOCVL.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN PGFV.EFFECTIVE_START_DATE(+) AND PGFV.EFFECTIVE_END_DATE(+)
)
```

**Key Features:**
- **FT/PT Classification**: Based on NORMAL_HOURS (>= 40 = Full Time, < 40 = Part Time)
- **Comprehensive Org Data**: Legal employer, business unit, location, department
- **DFF Attributes**: Exposed for further processing
- **Multiple Org Units**: Separate aliases for different organization types

**FT/PT Logic:**
```sql
CASE 
    WHEN NVL(NORMAL_HOURS, 0) >= 40 THEN 'Full Time'
    WHEN NVL(NORMAL_HOURS, 0) > 0 AND NVL(NORMAL_HOURS, 0) < 40 THEN 'Part Time'
    ELSE 'Not Specified'
END
```

---

## 8. DFF ATTRIBUTE HANDLING CTE (New Pattern)

**Purpose:** Extract and map Descriptive Flexfield attributes  
**Usage:** When DFF fields need to be mapped to business fields

```sql
,EMP_DFF AS (
    /*+ qb_name(EMP_DFF) */
    SELECT
        EA.PERSON_ID,
        EA.ASSIGNMENT_ID,
        -- Map DFF attributes to business fields
        -- Update these mappings based on FND_DESCR_FLEX_COLUMN_USAGES query
        EA.ATTRIBUTE1 AS CONTRACT_TYPE,
        EA.ATTRIBUTE5 AS CLIENT_JOB_TITLE,
        EA.ATTRIBUTE3 AS PROJECT_NUMBER,
        EA.ATTRIBUTE4 AS SERVICE_LINE
    FROM
        EMP_ASSIGNMENT EA
)
```

**Key Features:**
- **Separate CTE**: Isolates DFF logic for easy maintenance
- **Business Field Mapping**: Maps technical attributes to business names
- **Documentation**: Comments indicate where to find correct mappings

**Discovery Query for DFF Mapping:**
```sql
SELECT 
    DFC.APPLICATION_COLUMN_NAME,
    DFC.END_USER_COLUMN_NAME,
    DFC.COLUMN_SEQ_NUM
FROM FND_DESCR_FLEX_COLUMN_USAGES DFC
WHERE DFC.APPLICATION_TABLE_NAME = 'PER_ALL_ASSIGNMENTS_F'
AND DFC.ENABLED_FLAG = 'Y'
ORDER BY DFC.COLUMN_SEQ_NUM
```

---

## 9. SUPERVISOR CTE
**Purpose:** Manager/Supervisor hierarchy with job details  
**Usage:** For manager approval queries and reporting structure

```sql
,SUPERVISOR AS (
    /*+ qb_name(SUPERVISOR) */
    SELECT
        PASF.PERSON_ID,
        PASF.MANAGER_ID,
        PPN.DISPLAY_NAME SUPERVISOR_NAME,
        PJF.NAME SUPERVISOR_JOB
    FROM
        PER_ASSIGNMENT_SUPERVISORS_F PASF,
        PER_PERSON_NAMES_F PPN,
        PER_ALL_ASSIGNMENTS_F PAA,
        PER_JOBS_F_TL PJF
    WHERE
        PASF.MANAGER_ID = PPN.PERSON_ID
    AND PPN.PERSON_ID = PAA.PERSON_ID
    AND PAA.JOB_ID = PJF.JOB_ID
    AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(PASF.EFFECTIVE_START_DATE, SYSDATE)) AND TRUNC(NVL(PASF.EFFECTIVE_END_DATE, SYSDATE))
    AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(PPN.EFFECTIVE_START_DATE, SYSDATE)) AND TRUNC(NVL(PPN.EFFECTIVE_END_DATE, SYSDATE))
    AND TRUNC(SYSDATE) BETWEEN TRUNC(NVL(PAA.EFFECTIVE_START_DATE, SYSDATE)) AND TRUNC(NVL(PAA.EFFECTIVE_END_DATE, SYSDATE))
    AND PPN.NAME_TYPE = 'GLOBAL'
    AND PAA.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND PAA.PRIMARY_FLAG = 'Y'
    AND PAA.ASSIGNMENT_TYPE = 'E'
    AND PJF.LANGUAGE = 'US'
)
```

**Key Filters:**
- Links supervisor through MANAGER_ID
- Gets supervisor's job title
- Date-tracked on SYSDATE
- Active managers only

---

## 10. ANNUAL_LEAVE_BALANCE CTE
**Purpose:** Annual leave balance (latest accrual period)  
**Usage:** For annual leave balance queries

```sql
,ANNUAL_LEAVE_BALANCE AS (
    /*+ qb_name(ANNUAL_LEAVE_BALANCE) */
    SELECT
        APAE.END_BAL ANU_BAL,
        APAE.PERSON_ID,
        APAE.PLAN_ID
    FROM
        ANC_PER_ACCRUAL_ENTRIES APAE,
        ANC_ABSENCE_PLANS_VL AAPV
    WHERE
        APAE.PLAN_ID = AAPV.ABSENCE_PLAN_ID(+)
    AND UPPER(AAPV.NAME) = 'ANNUAL LEAVE'
    AND APAE.ACCRUAL_PERIOD = (
        SELECT MAX(APA.ACCRUAL_PERIOD)
        FROM ANC_PER_ACCRUAL_ENTRIES APA
        WHERE APAE.PERSON_ID = APA.PERSON_ID
        AND APA.PLAN_ID = APAE.PLAN_ID
        AND TO_CHAR(APA.ACCRUAL_PERIOD, 'YYYY') <= TO_CHAR(SYSDATE, 'YYYY')
    )
)
```

**Key Logic:**
- MAX(ACCRUAL_PERIOD) for current year
- Filter by plan name 'ANNUAL LEAVE'
- END_BAL is the current balance

---

## 11. ACCRUAL_BALANCE WITH YEAR BREAKDOWN (Enhanced)

**Purpose:** Accrual balance with Previous Year vs Current Year breakdown  
**Usage:** When PY carryover and CY accrued need to be separated

```sql
,ACCRUAL_BALANCE AS (
    /*+ qb_name(ACCRUAL_BALANCE) */
    SELECT
        APAE.PERSON_ID,
        APAE.PLAN_ID,
        APAE.PRD_OF_SVC_ID,
        -- Previous Year Carry Forward (balance from prior years)
        SUM(CASE 
            WHEN TO_CHAR(APAE.ACCRUAL_PERIOD, 'YYYY') < TO_CHAR(P.EFFECTIVE_DATE, 'YYYY')
            THEN NVL(APAE.END_BAL, 0)
            ELSE 0 
        END) AS PY_CARRY_FORWARD,
        -- Current Year Accrued (accrued in current year)
        SUM(CASE 
            WHEN TO_CHAR(APAE.ACCRUAL_PERIOD, 'YYYY') = TO_CHAR(P.EFFECTIVE_DATE, 'YYYY')
            THEN NVL(APAE.ACCRUAL_BALANCE, 0)
            ELSE 0 
        END) AS CY_ACCRUED,
        -- Adjustments (sum of manual adjustments)
        SUM(NVL(APAE.ADJUSTMENT, 0)) AS BALANCE_ADJUSTMENT,
        -- Entitlement Override (latest value)
        MAX(APAE.ENTITLEMENT_OVERRIDE) AS ENTITLEMENT_OVERRIDE,
        -- Annual Entitlement (accrual rate per annum)
        MAX(APAE.ACCRUAL_RATE) AS ANNUAL_ENTITLEMENT
    FROM
        ANC_PER_ACCRUAL_ENTRIES APAE,
        PARAMETERS P
    WHERE
        APAE.ACCRUAL_PERIOD <= P.EFFECTIVE_DATE
    GROUP BY 
        APAE.PERSON_ID, 
        APAE.PLAN_ID, 
        APAE.PRD_OF_SVC_ID,
        P.EFFECTIVE_DATE
)
```

**Key Features:**
- **Year Comparison**: `TO_CHAR(ACCRUAL_PERIOD, 'YYYY')` vs `TO_CHAR(EFFECTIVE_DATE, 'YYYY')`
- **PY Logic**: Sum of END_BAL from years prior to effective year
- **CY Logic**: Sum of ACCRUAL_BALANCE from current year only
- **Adjustments**: Captures manual balance changes

**Balance Component Breakdown:**
```
PY Carry Forward = Sum of END_BAL where year < current year
CY Accrued       = Sum of ACCRUAL_BALANCE where year = current year
```

---

## 12. LEAVE_BALANCES CTE (Generic - All Plans)
**Purpose:** Current leave balances for all absence plans  
**Usage:** For multi-plan balance reports

```sql
,LEAVE_BALANCES AS (
    /*+ qb_name(LEAVE_BALANCES) */
    SELECT
        APAE.PERSON_ID,
        APAE.PLAN_ID,
        AAPFTL.NAME PLAN_NAME,
        SUM(APAE.END_BAL) ACCRUAL_BALANCE,
        PPOS.PERIOD_OF_SERVICE_ID
    FROM
        ANC_PER_ACCRUAL_ENTRIES APAE,
        ANC_ABSENCE_PLANS_F_TL AAPFTL,
        PER_PERIODS_OF_SERVICE PPOS
    WHERE
        APAE.PLAN_ID = AAPFTL.ABSENCE_PLAN_ID
    AND APAE.PRD_OF_SVC_ID = PPOS.PERIOD_OF_SERVICE_ID
    AND AAPFTL.SOURCE_LANG = 'US'
    AND AAPFTL.LANGUAGE = 'US'
    AND TRUNC(SYSDATE) BETWEEN AAPFTL.EFFECTIVE_START_DATE AND AAPFTL.EFFECTIVE_END_DATE
    AND APAE.ACCRUAL_PERIOD = (
        SELECT MAX(ACC.ACCRUAL_PERIOD)
        FROM ANC_PER_ACCRUAL_ENTRIES ACC
        WHERE ACC.PERSON_ID = APAE.PERSON_ID
        AND APAE.PLAN_ID = ACC.PLAN_ID
        AND APAE.PRD_OF_SVC_ID = ACC.PRD_OF_SVC_ID
        AND ACC.ACCRUAL_PERIOD BETWEEN 
            TO_DATE('01/01/' || TO_CHAR(TRUNC(SYSDATE), 'YYYY'), 'DD/MM/YYYY') 
            AND TO_DATE('31/12/' || TO_CHAR(TRUNC(SYSDATE), 'YYYY'), 'DD/MM/YYYY')
    )
    GROUP BY APAE.PERSON_ID, APAE.PLAN_ID, AAPFTL.NAME, PPOS.PERIOD_OF_SERVICE_ID
)
```

**Key Logic:**
- SUM of all balances for each plan
- Current year accrual period
- Grouped by person and plan
- Links to period of service

---

## 13. LEAVE_TRANSACTIONS CTE (Approved Leaves)
**Purpose:** Absence entries with approval status (approved leaves only)  
**Usage:** For leave history and detail reports

```sql
,LEAVE_TRANSACTIONS AS (
    /*+ qb_name(LEAVE_TRANSACTIONS) */
    SELECT DISTINCT
        APAE.PERSON_ID,
        APAE.PER_ABSENCE_ENTRY_ID,
        APAE.ABSENCE_TYPE_ID,
        AATFT.NAME LEAVE_TYPE,
        INITCAP(TO_CHAR(APAE.START_DATE, 'DD-fmMON-YYYY', 'NLS_DATE_LANGUAGE = AMERICAN')) AS START_DATE_DISPLAY,
        INITCAP(TO_CHAR(APAE.END_DATE, 'DD-fmMON-YYYY', 'NLS_DATE_LANGUAGE = AMERICAN')) AS END_DATE_DISPLAY,
        APAE.START_DATE,
        APAE.END_DATE,
        APAE.DURATION,
        INITCAP(TO_CHAR(APAE.SUBMITTED_DATE, 'DD-fmMON-YYYY', 'NLS_DATE_LANGUAGE = AMERICAN')) AS SUBMITTED_DATE,
        TO_CHAR(APAE.CREATION_DATE, 'DD-MM-YYYY') AS CREATION_DATE,
        TO_CHAR(APAE.LAST_UPDATE_DATE, 'DD-MM-YYYY') AS LAST_UPDATE_DATE,
        APAE.ABSENCE_TYPE_REASON_ID,
        APAE.APPROVAL_STATUS_CD,
        APAE.ABSENCE_STATUS_CD
    FROM
        ANC_PER_ABS_ENTRIES APAE,
        ANC_ABSENCE_TYPES_F_TL AATFT,
        PERIOD P
    WHERE
        AATFT.LANGUAGE = 'US'
    AND AATFT.ABSENCE_TYPE_ID = APAE.ABSENCE_TYPE_ID
    AND APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
    AND APAE.APPROVAL_STATUS_CD NOT IN ('DENIED', 'ORA_WITHDRAWN', 'ORA_AWAIT_AWAIT')
    AND TRUNC(APAE.START_DATE) BETWEEN P.START_DATE AND P.END_DATE
)
```

**Key Filters:**
- Approved leaves only (excludes denied/withdrawn)
- Date range from PERIOD CTE
- Formatted dates for display
- DISTINCT to avoid workflow duplicates

---

## 14. LEAVE_TRANSACTIONS WITH UNPAID IDENTIFICATION (Enhanced)

**Purpose:** Leave transactions with separate unpaid leave tracking  
**Usage:** When unpaid leave needs to be reported separately

```sql
,LEAVE_TRANSACTIONS AS (
    /*+ qb_name(LEAVE_TRANSACTIONS) */
    SELECT
        APAE.PERSON_ID,
        APAE.PLAN_ID,
        -- Leave Applied (all non-withdrawn leaves)
        SUM(CASE 
            WHEN APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
            AND APAE.START_DATE <= P.EFFECTIVE_DATE
            THEN NVL(APAE.DURATION, 0)
            ELSE 0 
        END) AS LEAVE_APPLIED,
        -- Leave Taken (approved leaves only)
        SUM(CASE 
            WHEN APAE.APPROVAL_STATUS_CD IN ('APPROVED')
            AND APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
            AND APAE.START_DATE <= P.EFFECTIVE_DATE
            THEN NVL(APAE.DURATION, 0)
            ELSE 0 
        END) AS LEAVE_TAKEN,
        -- Unpaid Leave Days (identify by absence type name containing 'UNPAID')
        SUM(CASE 
            WHEN APAE.APPROVAL_STATUS_CD IN ('APPROVED')
            AND APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
            AND APAE.START_DATE <= P.EFFECTIVE_DATE
            AND UPPER(AATFT.NAME) LIKE '%UNPAID%'
            THEN NVL(APAE.DURATION, 0)
            ELSE 0 
        END) AS UNPAID_LEAVE_DAYS
    FROM
        ANC_PER_ABS_ENTRIES APAE,
        ANC_ABSENCE_TYPES_F_TL AATFT,
        PARAMETERS P
    WHERE
        APAE.ABSENCE_TYPE_ID = AATFT.ABSENCE_TYPE_ID
    AND AATFT.LANGUAGE = 'US'
    AND P.EFFECTIVE_DATE BETWEEN AATFT.EFFECTIVE_START_DATE AND AATFT.EFFECTIVE_END_DATE
    GROUP BY 
        APAE.PERSON_ID, 
        APAE.PLAN_ID,
        P.EFFECTIVE_DATE
)
```

**Key Features:**
- **Three Metrics**: Applied, Taken (approved), and Unpaid separately
- **Unpaid Identification**: `UPPER(NAME) LIKE '%UNPAID%'` for flexibility
- **Date Cutoff**: `START_DATE <= EFFECTIVE_DATE` for as-of-date accuracy
- **Status Filtering**: Proper approval and absence status handling

**Unpaid Leave Pattern:**
```sql
AND UPPER(AATFT.NAME) LIKE '%UNPAID%'
```

---

## 15. ABSENCE_TYPES CTE
**Purpose:** Absence type master with translations  
**Usage:** For type classification and filtering

```sql
,ABSENCE_TYPES AS (
    /*+ qb_name(ABSENCE_TYPES) */
    SELECT
        AATFT.ABSENCE_TYPE_ID,
        AATFT.NAME ABSENCE_TYPE_NAME,
        AATFT.DESCRIPTION
    FROM
        ANC_ABSENCE_TYPES_F_TL AATFT
    WHERE
        AATFT.LANGUAGE = 'US'
    AND SYSDATE BETWEEN AATFT.EFFECTIVE_START_DATE AND AATFT.EFFECTIVE_END_DATE
)
```

**Key Filters:**
- `LANGUAGE = 'US'` - English translation
- Date-tracked on SYSDATE

---

## 16. ABSENCE_REASONS CTE
**Purpose:** Absence reason lookup with type relationship  
**Usage:** For reason classification in detail reports

```sql
,ABSENCE_REASONS AS (
    /*+ qb_name(ABSENCE_REASONS) */
    SELECT
        AARF.NAME REASON_NAME,
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

**Key Filters:**
- Links reason to absence type through ABSENCE_TYPE_REASON_ID
- `LANGUAGE = 'US'`
- Date-tracked on SYSDATE

---

## 17. WORKFLOW_APPROVAL CTE
**Purpose:** Workflow approval history from WFTASK  
**Usage:** For approver name and approval tracking

```sql
,WORKFLOW_APPROVAL AS (
    /*+ qb_name(WORKFLOW_APPROVAL) */
    SELECT
        WF.IDENTIFICATIONKEY,
        WF.ASSIGNEESDISPLAYNAME APPROVER_NAME,
        WF.FROMUSERDISPLAYNAME REQUESTOR_NAME,
        WF.OUTCOME,
        WF.ASSIGNMENTDATE,
        WF.APPROVEDDATE
    FROM
        FA_FUSION_SOAINFRA.WFTASK WF
    WHERE
        WF.OUTCOME IN ('APPROVE')
    AND WF.ASSIGNEES IS NOT NULL
    AND WF.WORKFLOWPATTERN NOT IN ('AGGREGATION', 'FYI')
)
```

**Key Filters:**
- `OUTCOME = 'APPROVE'` - Approved tasks only
- Excludes aggregation and FYI workflows
- IDENTIFICATIONKEY links to PER_ABSENCE_ENTRY_ID

**Note:** This table requires cross-schema access to FA_FUSION_SOAINFRA. May not be available in all environments.

---

## 18. LEAVE_HISTORY CTE (Historical Comparison)
**Purpose:** Historical leave summary for comparison  
**Usage:** For "All Previous Leave Taken Records" column

```sql
,LEAVE_HISTORY AS (
    /*+ qb_name(LEAVE_HISTORY) */
    SELECT
        APAE.PERSON_ID,
        APAE.ABSENCE_TYPE_ID,
        COUNT(*) PREVIOUS_COUNT,
        SUM(APAE.DURATION) TOTAL_DAYS_TAKEN,
        MAX(APAE.END_DATE) LAST_LEAVE_DATE,
        LISTAGG(
            INITCAP(TO_CHAR(APAE.START_DATE, 'DD-MON-YY')) || ' (' || APAE.DURATION || ' days)',
            ', '
        ) WITHIN GROUP (ORDER BY APAE.START_DATE DESC) AS PREVIOUS_DETAILS
    FROM
        ANC_PER_ABS_ENTRIES APAE
    WHERE
        APAE.APPROVAL_STATUS_CD = 'APPROVED'
    AND APAE.ABSENCE_STATUS_CD <> 'ORA_WITHDRAWN'
    GROUP BY APAE.PERSON_ID, APAE.ABSENCE_TYPE_ID
)
```

**Key Logic:**
- COUNT of previous approved leaves by type
- SUM of total days taken
- LISTAGG for comma-separated history
- Approved leaves only

---

## 19. PLAN_ENROLLMENT CTE

**Purpose:** Absence plan enrollment  
**Usage:** Plan-based queries

```sql
,PLAN_ENROLLMENT AS (
    /*+ qb_name(PLAN_ENROLLMENT) */
    SELECT
        APE.PERSON_ID,
        APE.PLAN_ID,
        APE.PRD_OF_SVC_ID,
        AAPVL.NAME AS PLAN_NAME,
        TO_CHAR(APE.START_DATE, 'DD-MM-YYYY') AS ENROLLMENT_START_DATE
    FROM
        ANC_PER_ENROLLMENTS APE,
        ANC_ABSENCE_PLANS_VL AAPVL,
        PARAMETERS P
    WHERE
        APE.PLAN_ID = AAPVL.ABSENCE_PLAN_ID
    AND UPPER(AAPVL.NAME) LIKE '%ANNUAL%'
    AND P.EFFECTIVE_DATE BETWEEN APE.START_DATE 
        AND NVL(APE.END_DATE, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
)
```

---

## 20. CARRYOVER_DETAILS CTE

**Purpose:** Carryover and expiry tracking  
**Usage:** Balance reports with carryover

```sql
,CARRYOVER_DETAILS AS (
    /*+ qb_name(CARRYOVER_DETAILS) */
    SELECT
        APC.PERSON_ID,
        APC.PLAN_ID,
        APC.PRD_OF_SVC_ID,
        -- Expired carryover
        SUM(CASE 
            WHEN APC.EXPIRY_DATE < P.EFFECTIVE_DATE 
            THEN NVL(APC.CARRYOVER_BALANCE, 0)
            ELSE 0 
        END) AS CARRYOVER_EXPIRED,
        MAX(APC.EXPIRY_DATE) AS CARRYOVER_EXPIRY_DATE
    FROM
        ANC_PER_CARRYOVER APC,
        PARAMETERS P
    WHERE
        NVL(APC.CARRYOVER_BALANCE, 0) > 0
    GROUP BY 
        APC.PERSON_ID, 
        APC.PLAN_ID, 
        APC.PRD_OF_SVC_ID,
        P.EFFECTIVE_DATE
)
```

---

## 21. ENCASHMENT_DETAILS CTE

**Purpose:** Leave encashment tracking  
**Usage:** Encashment reports

```sql
,ENCASHMENT_DETAILS AS (
    /*+ qb_name(ENCASHMENT_DETAILS) */
    SELECT
        APE.PERSON_ID,
        APE.PLAN_ID,
        SUM(NVL(APE.ENCASHMENT_AMOUNT, 0)) AS ANNUAL_LEAVE_ENCASHMENT
    FROM
        ANC_PER_ENCASHMENTS APE,
        PARAMETERS P
    WHERE
        APE.ENCASHMENT_DATE <= P.EFFECTIVE_DATE
    GROUP BY 
        APE.PERSON_ID, 
        APE.PLAN_ID
)
```

---

## 🎯 Usage Patterns

### Pattern 1: Simple Leave History Query
```sql
WITH PERIOD AS (...),
     EMP_MASTER AS (...),
     LEAVE_TRANSACTIONS AS (...)
SELECT
    EM.PERSON_NUMBER,
    EM.DISPLAY_NAME,
    LT.LEAVE_TYPE,
    LT.START_DATE_DISPLAY,
    LT.END_DATE_DISPLAY,
    LT.DURATION
FROM
    EMP_MASTER EM,
    LEAVE_TRANSACTIONS LT
WHERE
    EM.PERSON_ID = LT.PERSON_ID
```

### Pattern 2: Comprehensive Balance Report
```sql
WITH PARAMETERS AS (...),
     EMP_BASE AS (...),
     EMP_ASSIGNMENT AS (...),
     ACCRUAL_BALANCE AS (...),
     LEAVE_TRANSACTIONS AS (...)
SELECT
    EB.PERSON_NUMBER,
    EB.FULL_NAME,
    AB.PY_CARRY_FORWARD,
    AB.CY_ACCRUED,
    LT.LEAVE_TAKEN,
    (AB.PY_CARRY_FORWARD + AB.CY_ACCRUED - LT.LEAVE_TAKEN) AS BALANCE
FROM EMP_BASE EB
    JOIN EMP_ASSIGNMENT EA ON EB.PERSON_ID = EA.PERSON_ID
    LEFT JOIN ACCRUAL_BALANCE AB ON EB.PERSON_ID = AB.PERSON_ID
    LEFT JOIN LEAVE_TRANSACTIONS LT ON EB.PERSON_ID = LT.PERSON_ID
```

---

## ✅ Validation Checklist

Before using any CTE from this repository:

- [ ] CTE has `/*+ qb_name(NAME) */` hint ✓
- [ ] All joins use Oracle Traditional Syntax ✓
- [ ] Date-track filters applied to `_F` tables ✓
- [ ] `LANGUAGE = 'US'` applied to `_TL` tables ✓
- [ ] Status filters applied (approved, not withdrawn) ✓
- [ ] Outer joins (+) used where appropriate ✓
- [ ] PARAMETERS CTE uses UPPER() for case-insensitive comparison ✓
- [ ] Date filtering uses P.EFFECTIVE_DATE (not SYSDATE) where required ✓
- [ ] All components use NVL() to prevent NULL arithmetic ✓

---

## 📝 Notes

1. **DO NOT modify these CTEs** without understanding the constraints from ABSENCE_MASTER.md
2. **ALWAYS copy complete CTEs** - do not write fresh joins
3. **Test workflow CTEs** in your environment - FA_FUSION_SOAINFRA may require special access
4. **Use Enhanced CTEs** when additional features (service calculation, FT/PT, unpaid tracking) are needed
5. **Document DFF Mappings** - run discovery query and update EMP_DFF CTE accordingly

---

**END OF ABSENCE_REPOSITORIES.md**

**Status:** Merged and Complete  
**Last Merged:** 07-Jan-2026  
**Source Files:** ABSENCE_REPOSITORIES.md + ABSENCE_REPOSITORIES_UPDATE_31-12-25.md  
**Version:** 2.0
