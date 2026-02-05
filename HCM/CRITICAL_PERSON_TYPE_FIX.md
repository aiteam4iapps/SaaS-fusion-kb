# ⚠️ CRITICAL: Oracle HCM Person Type Column Location

**Date Created:** 02-01-2026  
**Priority:** CRITICAL  
**Category:** Data Model Error Prevention

---

## ❌ COMMON MISTAKE (DO NOT USE)

```sql
-- WRONG: PERSON_TYPE_ID does NOT exist in PER_ALL_PEOPLE_F table
FROM PER_ALL_PEOPLE_F PAPF,
     PER_PERSON_TYPES_TL PPTTL
WHERE PAPF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- ❌ THIS COLUMN DOES NOT EXIST
```

**Error:** `PAPF.PERSON_TYPE_ID` - Column does not exist in `PER_ALL_PEOPLE_F`

---

## ✅ CORRECT IMPLEMENTATION

### Table Structure Facts:
- **PER_ALL_PEOPLE_F**: Does **NOT** have `PERSON_TYPE_ID` column
- **PER_ALL_ASSIGNMENTS_F**: **DOES** have `PERSON_TYPE_ID` column
- **Person Type MUST be retrieved through assignment table**

### Correct Pattern:
```sql
-- CORRECT: Get Person Type via PER_ALL_ASSIGNMENTS_F
SELECT
    PAPF.PERSON_ID,
    PAPF.PERSON_NUMBER,
    PPTTL.USER_PERSON_TYPE AS PERSON_TYPE
FROM
    PER_ALL_PEOPLE_F PAPF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_PERSON_TYPES_TL PPTTL
WHERE
    PAPF.PERSON_ID = PAAF.PERSON_ID
AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- ✅ CORRECT
AND PAAF.PRIMARY_FLAG = 'Y'
AND PAAF.ASSIGNMENT_TYPE = 'E'
AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
AND PPTTL.LANGUAGE = 'US'
```

---

## 📋 IMPLEMENTATION IN CTEs

### Early CTE (Before Assignment CTE):
```sql
EMP_BASE AS (
    /*+ qb_name(EMP_BASE) MATERIALIZE */
    SELECT
        PAPF.PERSON_ID,
        PAPF.PERSON_NUMBER,
        PPNF.FULL_NAME AS EMPLOYEE_NAME,
        PPTTL.USER_PERSON_TYPE AS PERSON_TYPE
    FROM
        PER_ALL_PEOPLE_F PAPF,
        PER_PERSON_NAMES_F PPNF,
        PER_ALL_ASSIGNMENTS_F PAAF_TYPE,  -- Additional alias for person type
        PER_PERSON_TYPES_TL PPTTL
    WHERE
        PAPF.PERSON_ID = PPNF.PERSON_ID
    AND PAPF.PERSON_ID = PAAF_TYPE.PERSON_ID
    AND PAAF_TYPE.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID  -- Via assignment
    AND PAAF_TYPE.PRIMARY_FLAG = 'Y'
    AND PAAF_TYPE.ASSIGNMENT_TYPE = 'E'
    AND PPTTL.LANGUAGE = 'US'
    AND TRUNC(SYSDATE) BETWEEN PAAF_TYPE.EFFECTIVE_START_DATE AND PAAF_TYPE.EFFECTIVE_END_DATE
)
```

### Later CTE (After Assignment CTE):
```sql
-- If assignment already retrieved in earlier CTE:
EMP_ASSIGNMENT AS (
    SELECT
        PAAF.PERSON_ID,
        PPTTL.USER_PERSON_TYPE AS PERSON_TYPE
    FROM
        PER_ALL_ASSIGNMENTS_F PAAF,
        PER_PERSON_TYPES_TL PPTTL
    WHERE
        PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID
    AND PPTTL.LANGUAGE = 'US'
)
```

---

## 🔍 JOIN PATH

```
Person → Assignment → Person Type
  ↓          ↓            ↓
PAPF    →  PAAF   →   PPTTL
         (contains
        PERSON_TYPE_ID)
```

---

## ⚡ KEY POINTS TO REMEMBER

1. **NEVER** try to join `PERSON_TYPE_ID` directly from `PER_ALL_PEOPLE_F`
2. **ALWAYS** use `PER_ALL_ASSIGNMENTS_F` as intermediary
3. **FILTER** assignment to primary and employee type
4. **DATE-TRACK** the assignment table properly
5. **LANGUAGE** filter on `PER_PERSON_TYPES_TL` (LANGUAGE = 'US')

---

## 📚 AFFECTED QUERIES

This pattern applies to:
- Employee reports requiring person type
- Any query joining PER_ALL_PEOPLE_F to PER_PERSON_TYPES_TL
- HR Master queries
- Absence reports with person type
- Payroll reports with person type

---

## 🚨 VALIDATION QUERY

Test if person type join is correct:
```sql
-- This should return data:
SELECT 
    PAPF.PERSON_NUMBER,
    PPTTL.USER_PERSON_TYPE
FROM 
    PER_ALL_PEOPLE_F PAPF,
    PER_ALL_ASSIGNMENTS_F PAAF,
    PER_PERSON_TYPES_TL PPTTL
WHERE 
    PAPF.PERSON_ID = PAAF.PERSON_ID
AND PAAF.PERSON_TYPE_ID = PPTTL.PERSON_TYPE_ID
AND PAAF.PRIMARY_FLAG = 'Y'
AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE AND PAPF.EFFECTIVE_END_DATE
AND TRUNC(SYSDATE) BETWEEN PAAF.EFFECTIVE_START_DATE AND PAAF.EFFECTIVE_END_DATE
AND PPTTL.LANGUAGE = 'US'
AND ROWNUM = 1;
```

---

**IMPORTANT:** This issue has been reported multiple times. Always verify person type joins use the assignment table.

**Last Updated:** 02-01-2026  
**Reported:** 3 times by user  
**Status:** CRITICAL - Must follow for all future queries
