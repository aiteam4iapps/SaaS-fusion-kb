# Benefits Report Templates

**Purpose:** Ready-to-use SQL skeletons for Benefits reporting.

---

## 1. Medical Enrollment List
*List all employees enrolled in Medical plans.*

```sql
/*
TITLE: Active Medical Enrollments
PURPOSE: Audit active medical plan participants
*/

WITH
-- 1. Enrollments
ENROLLMENTS AS (
    SELECT /*+ qb_name(E) MATERIALIZE */
           PEN.PERSON_ID, PL.NAME AS PLAN, OPT.NAME AS COVERAGE
    FROM   BEN_PRTT_ENRT_RSLT_F PEN
          ,BEN_PL_F PL
          ,BEN_OPT_F OPT
          ,BEN_PL_TYP_F PT
    WHERE  TRUNC(SYSDATE) BETWEEN PEN.EFFECTIVE_START_DATE AND PEN.EFFECTIVE_END_DATE
      AND  PEN.PRTT_ENRT_RSLT_STAT_CD IS NULL
      AND  PEN.PL_ID = PL.PL_ID
      AND  PL.PL_TYP_ID = PT.PL_TYP_ID
      AND  PT.NAME = 'Medical' -- Filter by Plan Type
      AND  PEN.OIPl_ID = OPT.OPT_ID(+) -- Simplification
)

-- 2. Final Select
SELECT P.PERSON_NUMBER, E.PLAN, E.COVERAGE
FROM   ENROLLMENTS E
      ,PER_ALL_PEOPLE_F P
WHERE  E.PERSON_ID = P.PERSON_ID
  AND  TRUNC(SYSDATE) BETWEEN P.EFFECTIVE_START_DATE AND P.EFFECTIVE_END_DATE
```
