# Benefits Repository Patterns

**Module:** Benefits  
**Tag:** `#HCM #BEN #REPOSITORIES`  
**Purpose:** Standardized CTEs for extracting Benefits data  
**Last Updated:** 13-Jan-2026  
**Version:** 2.0 (Merged with update file)

---

## 📋 Repository Index

| CTE Name | Purpose | Source Tables | Use Case |
|----------|---------|---------------|----------|
| **PARAMETERS** | Parameter handling with case-insensitive filtering | Parameters | All reports with filters |
| **BEN_ENROLL_MASTER** | Active benefit enrollments | BEN_PRTT_ENRT_RSLT_F, BEN_PL_F | All enrollment queries |
| **BEN_ENROLL_MASTER (Enhanced)** | With effective date filtering | BEN_PRTT_ENRT_RSLT_F, BEN_PL_F | Historical enrollment queries |
| **BEN_PLAN_TYPES** | Plan type master | BEN_PL_TYP_F | Plan classification |
| **BEN_OPTIONS** | Benefit options | BEN_OPT_F | Coverage options |

---

## 1. PARAMETERS CTE (Enhanced with Case-Insensitive Filtering)

**Purpose:** Parameter handling with automatic case normalization  
**Usage:** Use when parameters need case-insensitive comparison

```sql
WITH PARAMETERS AS (
    /*+ qb_name(PARAMETERS) */
    SELECT
        TRUNC(TO_DATE(:P_EFFECTIVE_DATE, 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        UPPER(NVL(:P_PLAN_TYPE, 'ALL')) AS PLAN_TYPE,
        UPPER(NVL(:P_PLAN_NAME, 'ALL')) AS PLAN_NAME,
        UPPER(NVL(:P_OPTION_NAME, 'ALL')) AS OPTION_NAME
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

## 2. BEN_ENROLL_MASTER (Standard - Current Enrollments)

**Purpose:** Retrieves currently active benefit enrollments  
**Usage:** For current enrollment status queries

```sql
,BEN_ENROLL_MASTER AS (
    /*+ qb_name(BEN_ENR) MATERIALIZE */
    SELECT
        PEN.PERSON_ID,
        PEN.PL_ID,
        PEN.OIPL_ID,
        PEN.PRTT_ENRT_RSLT_ID,
        PL.NAME AS PLAN_NAME,
        OPT.NAME AS OPTION_NAME
    FROM
        BEN_PRTT_ENRT_RSLT_F PEN,
        BEN_PL_F PL,
        BEN_OIPL_F OIPL,
        BEN_OPT_F OPT
    WHERE
        TRUNC(SYSDATE) BETWEEN PEN.EFFECTIVE_START_DATE AND PEN.EFFECTIVE_END_DATE
    AND PEN.PRTT_ENRT_RSLT_STAT_CD IS NULL -- Active enrollment
    AND PEN.ENRT_CVG_THRU_DT = TO_DATE('4712-12-31', 'YYYY-MM-DD') -- Through end of time
    AND PEN.PL_ID = PL.PL_ID
    AND TRUNC(SYSDATE) BETWEEN PL.EFFECTIVE_START_DATE AND PL.EFFECTIVE_END_DATE
    AND PEN.OIPL_ID = OIPL.OIPL_ID(+)
    AND OIPL.OPT_ID = OPT.OPT_ID(+)
)
```

**Key Filters:**
- `PRTT_ENRT_RSLT_STAT_CD IS NULL` - Active enrollments only (CRITICAL)
- `ENRT_CVG_THRU_DT = '4712-12-31'` - Coverage through end of time
- Date-tracked on SYSDATE

---

## 3. BEN_ENROLL_MASTER (Enhanced - Historical Enrollments)

**Purpose:** Active benefit enrollments with effective date filtering  
**Usage:** For "as of" date enrollment queries and historical reporting

```sql
,BEN_ENROLL_MASTER AS (
    /*+ qb_name(BEN_ENR) MATERIALIZE */
    SELECT
        PEN.PERSON_ID,
        PEN.PL_ID,
        PEN.OIPL_ID,
        PEN.PRTT_ENRT_RSLT_ID,
        PL.NAME AS PLAN_NAME,
        OPT.NAME AS OPTION_NAME,
        TO_CHAR(PEN.ENRT_CVG_STRT_DT, 'DD-MM-YYYY') AS COVERAGE_START_DATE,
        TO_CHAR(PEN.ENRT_CVG_THRU_DT, 'DD-MM-YYYY') AS COVERAGE_END_DATE,
        PEN.ENRT_CVG_STRT_DT AS COVERAGE_START_RAW,
        PEN.ENRT_CVG_THRU_DT AS COVERAGE_END_RAW
    FROM
        BEN_PRTT_ENRT_RSLT_F PEN,
        BEN_PL_F PL,
        BEN_OIPL_F OIPL,
        BEN_OPT_F OPT,
        PARAMETERS P
    WHERE
        PEN.PL_ID = PL.PL_ID
    AND PEN.OIPL_ID = OIPL.OIPL_ID(+)
    AND OIPL.OPT_ID = OPT.OPT_ID(+)
    -- Active enrollment status (CRITICAL - DO NOT CHANGE)
    AND PEN.PRTT_ENRT_RSLT_STAT_CD IS NULL
    -- Coverage active as of Effective Date
    AND P.EFFECTIVE_DATE BETWEEN PEN.ENRT_CVG_STRT_DT 
        AND NVL(PEN.ENRT_CVG_THRU_DT, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
    -- Date-track filtering using Effective Date (NOT SYSDATE)
    AND P.EFFECTIVE_DATE BETWEEN PEN.EFFECTIVE_START_DATE AND PEN.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN PL.EFFECTIVE_START_DATE AND PL.EFFECTIVE_END_DATE
    AND P.EFFECTIVE_DATE BETWEEN OIPL.EFFECTIVE_START_DATE(+) AND OIPL.EFFECTIVE_END_DATE(+)
    AND P.EFFECTIVE_DATE BETWEEN OPT.EFFECTIVE_START_DATE(+) AND OPT.EFFECTIVE_END_DATE(+)
)
```

**Key Features:**
- **Effective Date filtering**: Uses parameter date instead of SYSDATE
- **Dual date formats**: Both formatted (DD-MM-YYYY) and raw date for different uses
- **Coverage period check**: Validates enrollment was active on effective date
- **Critical constraint preserved**: `PRTT_ENRT_RSLT_STAT_CD IS NULL`

**Benefits:**
- Query enrollments "as of" any past date
- Audit compliance for historical coverage verification
- Year-end enrollment snapshots
- Consistent with HR/Absence patterns

---

## 4. BEN_PLAN_TYPES CTE

**Purpose:** Plan type master with translations  
**Usage:** For plan type classification and filtering

```sql
,BEN_PLAN_TYPES AS (
    /*+ qb_name(BEN_PLN_TYP) */
    SELECT
        PT.PL_TYP_ID,
        PT.NAME AS PLAN_TYPE_NAME
    FROM
        BEN_PL_TYP_F PT,
        PARAMETERS P
    WHERE
        P.EFFECTIVE_DATE BETWEEN PT.EFFECTIVE_START_DATE AND PT.EFFECTIVE_END_DATE
)
```

**Common Plan Types:**
- `'Medical'` - Medical/Health insurance
- `'Dental'` - Dental insurance
- `'Vision'` - Vision insurance
- `'Life'` - Life insurance
- `'Disability'` - Short-term/Long-term disability

---

## 5. BEN_OPTIONS CTE

**Purpose:** Benefit coverage options  
**Usage:** For coverage level classification

```sql
,BEN_OPTIONS AS (
    /*+ qb_name(BEN_OPT) */
    SELECT
        OPT.OPT_ID,
        OPT.NAME AS OPTION_NAME
    FROM
        BEN_OPT_F OPT,
        PARAMETERS P
    WHERE
        P.EFFECTIVE_DATE BETWEEN OPT.EFFECTIVE_START_DATE AND OPT.EFFECTIVE_END_DATE
)
```

**Common Options:**
- `'Employee Only'` - Individual coverage
- `'Employee + Spouse'` - Employee and spouse
- `'Employee + Children'` - Employee and children
- `'Family'` - Full family coverage

---

## 6. MULTI-PARAMETER FILTERING PATTERN

**Purpose:** Implement multiple optional filters with 'ALL' support  
**Usage:** When report needs multiple independent filters

```sql
WHERE
    EB.PERSON_ID = BEM.PERSON_ID
-- ... other joins ...

-- Parameter Filters with 'ALL' support
AND (UPPER(PT.NAME) = P.PLAN_TYPE OR P.PLAN_TYPE = 'ALL')
AND (UPPER(PL.NAME) = P.PLAN_NAME OR P.PLAN_NAME = 'ALL')
AND (UPPER(OPT.NAME) = P.OPTION_NAME OR P.OPTION_NAME = 'ALL')

ORDER BY 
    TO_NUMBER(EB.PERSON_NUMBER),
    PL.NAME
```

**Key Features:**
- **Case-Insensitive**: UPPER() on both sides of comparison
- **'ALL' Bypass**: `OR PARAMETER = 'ALL'` allows filter bypass
- **Independent Filters**: Each filter works independently
- **No NULL Issues**: Parameters defaulted to 'ALL' in PARAMETERS CTE

**Pattern Template:**
```sql
AND (UPPER(field_name) = P.PARAMETER_NAME OR P.PARAMETER_NAME = 'ALL')
```

---

## 7. OPTIONAL CUSTOM BENEFITS HANDLING

**Purpose:** Handle client-specific benefits tables gracefully  
**Usage:** When custom benefit programs or flex benefits are in use

```sql
-- ============================================================================
-- CUSTOM BENEFITS (Optional - comment out if table doesn't exist)
-- ============================================================================
,BEN_CUSTOM_COVERAGE AS (
    /*+ qb_name(BEN_CUSTOM) */
    SELECT
        PERSON_ID,
        CUSTOM_COVERAGE_AMOUNT,
        CUSTOM_COVERAGE_TYPE
    FROM CLIENT_CUSTOM_BENEFITS
    WHERE ACTIVE_FLAG = 'Y'
)

-- In final SELECT: Use outer join and NVL
SELECT
    BEM.PERSON_NUMBER,
    BEM.PLAN_NAME,
    NVL(BCC.CUSTOM_COVERAGE_AMOUNT, 0) AS CUSTOM_COVERAGE
FROM
    BEN_ENROLL_MASTER BEM,
    BEN_CUSTOM_COVERAGE BCC
WHERE
    BEM.PERSON_ID = BCC.PERSON_ID(+)
```

**Why:** Query works in environments with or without custom benefits tables  
**Scope:** Flex benefits, client-specific benefit programs

**If Table Doesn't Exist:**
```sql
-- Comment out the CTE
/*
,BEN_CUSTOM_COVERAGE AS (
    ...
)
*/

-- Set to 0 or NULL in final SELECT
SELECT
    0 AS CUSTOM_COVERAGE  -- Table doesn't exist
FROM ...
```

---

## 🎯 USAGE PATTERNS

### Pattern 1: Current Active Enrollments
```sql
WITH BEN_ENROLL_MASTER AS (...)
SELECT
    PAPF.PERSON_NUMBER,
    PPNF.DISPLAY_NAME,
    BEM.PLAN_NAME,
    BEM.OPTION_NAME
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_PERSON_NAMES_F PPNF,
    BEN_ENROLL_MASTER BEM
WHERE
    PAPF.PERSON_ID = PPNF.PERSON_ID
AND PAPF.PERSON_ID = BEM.PERSON_ID
AND PPNF.NAME_TYPE = 'GLOBAL'
AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
```

### Pattern 2: Historical Enrollment Query
```sql
WITH PARAMETERS AS (
    SELECT 
        TRUNC(TO_DATE('01-JAN-2023', 'DD-MON-YYYY')) AS EFFECTIVE_DATE,
        'ALL' AS PLAN_TYPE
    FROM DUAL
)
,BEN_ENROLL_MASTER AS (
    -- Enhanced pattern with Effective Date
    ...
)
SELECT
    PERSON_NUMBER,
    FULL_NAME,
    PLAN_NAME,
    OPTION_NAME,
    COVERAGE_START_DATE
FROM BEN_ENROLL_MASTER
WHERE PLAN_TYPE = 'Medical'
ORDER BY PERSON_NUMBER;

-- Result: Shows enrollments exactly as they were on 01-JAN-2023
```

### Pattern 3: Current Enrollments with Case-Insensitive Filter
```sql
WITH PARAMETERS AS (
    SELECT 
        TRUNC(SYSDATE) AS EFFECTIVE_DATE,
        UPPER(NVL(:P_PLAN_NAME, 'ALL')) AS PLAN_NAME
    FROM DUAL
)
,BEN_ENROLL_MASTER AS (
    -- Enhanced pattern
    ...
)
SELECT
    COUNT(*) AS ENROLLMENT_COUNT,
    PLAN_NAME
FROM BEN_ENROLL_MASTER, PARAMETERS P
WHERE (UPPER(PLAN_NAME) = P.PLAN_NAME OR P.PLAN_NAME = 'ALL')
GROUP BY PLAN_NAME;

-- User can enter :P_PLAN_NAME as 'medical plan' or 'Medical Plan' or 'MEDICAL PLAN'
```

---

## ⚠️ BENEFITS-SPECIFIC CRITICAL CONSTRAINTS

### DO NOT CHANGE These Patterns:

1. **Enrollment Status Filter (CRITICAL):**
   ```sql
   AND PEN.PRTT_ENRT_RSLT_STAT_CD IS NULL
   ```
   **Why:** Benefits history contains voided and backed-out enrollments. This filter MUST be present for active enrollments.

2. **Coverage Period Validation (REQUIRED):**
   ```sql
   AND P.EFFECTIVE_DATE BETWEEN PEN.ENRT_CVG_STRT_DT 
       AND NVL(PEN.ENRT_CVG_THRU_DT, TO_DATE('31/12/4712', 'DD/MM/YYYY'))
   ```
   **Why:** Ensures enrollment was actually active on the effective date.

3. **Life Event Context (RECOMMENDED):**
   ```sql
   -- Join to BEN_PER_IN_LER for enrollment reasons
   AND PEN.PER_IN_LER_ID = PIL.PER_IN_LER_ID(+)
   ```
   **Why:** Provides context for why enrollment changed (Marriage, Birth, Open Enrollment).

**The new patterns COMPLEMENT these critical constraints, they do not replace them.**

---

## ✅ Validation Checklist

Before using any CTE from this repository:

**Core Checks:**
- [ ] CTE has `/*+ qb_name(NAME) */` hint ✓
- [ ] All joins use Oracle Traditional Syntax ✓
- [ ] Date-track filters applied to `_F` tables ✓
- [ ] `PRTT_ENRT_RSLT_STAT_CD IS NULL` applied (CRITICAL) ✓
- [ ] Coverage period validated ✓
- [ ] Outer joins (+) used where appropriate ✓

**Enhanced Pattern Checks:**
- [ ] Effective Date parameter used (not SYSDATE) for historical queries ✓
- [ ] All text parameters use UPPER() for case-insensitive comparison ✓
- [ ] Multi-parameter filters use 'OR = ALL' pattern ✓
- [ ] Optional tables handled with outer joins and comments ✓

---

## 📝 Notes

1. **DO NOT modify critical constraints** without understanding the benefits data model
2. **ALWAYS copy complete CTEs** - do not write fresh joins
3. **Use Enhanced CTEs** when historical queries or flexible filtering is needed
4. **Test with known enrollment data** before production use
5. **Document custom benefits tables** - use comments to indicate optional tables

---

**END OF BEN_REPOSITORIES.md**

**Status:** Merged and Complete  
**Last Merged:** 13-Jan-2026  
**Source Files:** BEN_REPOSITORIES.md + BEN_REPOSITORIES_UPDATE_02-01-26.md  
**Version:** 2.0
