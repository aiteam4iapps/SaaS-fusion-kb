# Time & Labor Master Instructions

**Module:** Time & Labor (HWM)  
**Tag:** `#HCM #TL #HWM #Timesheet`  
**Status:** Production-Ready  
**Last Updated:** 18-Dec-2025

---

## 1. 🚨 Critical Time & Labor Constraints

*Violating these rules breaks timesheet calculations.*

### 1.1 Version Handling
**Rule:** Always use the LATEST version for time record groups

```sql
AND AUSG.USAGES_SOURCE_VERSION = (
    SELECT MAX(A1.USAGES_SOURCE_VERSION) 
    FROM HWM_TM_REP_ATRB_USAGES A1 
    WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
)
```

**Why:** Timesheets can be edited multiple times; only the latest version is current.

### 1.2 Date-Track Filtering
**Rule:** Always filter Time & Labor tables by `EFFECTIVE_START_DATE` and `EFFECTIVE_END_DATE`

```sql
AND TRUNC(TMD.START_TIME) BETWEEN P1.EFFECTIVE_START_DATE AND P1.EFFECTIVE_END_DATE
```

**Why:** Time records span multiple effective dates; must align with person/assignment context.

### 1.3 Status Filtering
**Rule:** Filter by `STATUS` to exclude drafts and rejected timesheets

```sql
AND TMH.STATUS IN ('Approved', 'Submitted')
```

**Status Values:**
- `'Approved'` - Approved by manager
- `'Submitted'` - Submitted, awaiting approval
- `'Saved'` - Draft (not submitted)

### 1.4 Absence Integration
**Rule:** When timesheet has absence types, cross-check with `ANC_PER_ABS_ENTRIES`

```sql
AND ((ABSE.ABSENCE_STATUS_CD = 'SUBMITTED' AND ABSE.APPROVAL_STATUS_CD = 'APPROVED') OR
     (ABSE.ABSENCE_STATUS_CD = 'ORA_WITHDRAWN' AND ABSE.APPROVAL_STATUS_CD = 'ORA_AWAIT_AWAIT') OR
     (ABSE.ABSENCE_STATUS_CD = 'SUBMITTED' AND ABSE.APPROVAL_STATUS_CD = 'AWAITING'))
```

**Why:** Timesheet absence entries must align with official absence records.

### 1.5 Project Attribute Handling
**Rule:** Use `ATTRIBUTE_CATEGORY` and `ATTRIBUTE_NUMBER1/2` for project/task linkage

```sql
AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
AND ATR.ATTRIBUTE_NUMBER1 = PJP.PROJECT_ID
AND ATR.ATTRIBUTE_NUMBER2 = PJT.TASK_ID
```

**Why:** Time attributes are stored generically; category determines the entity type.

---

## 2. 🗺️ Schema Map

### 2.1 Time Record Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **TMH** | `HWM_TM_REC_SUMM` | Timesheet Header (Group Summary) |
| **TMD** | `HWM_TM_REP_HIERARCHIES_VL` | Timesheet Detail (Line Items) |
| **AUSG** | `HWM_TM_REP_ATRB_USAGES` | Attribute Usages (Project, Task, Expenditure Type linkage) |
| **ATR** | `HWM_TM_REP_ATRBS` | Attribute Definitions |
| **TRT** | `HWM_TM_REC_TYPES_VL` | Time Record Types |

### 2.2 Project Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PJP** | `PJF_PROJECTS_ALL_VL` | Projects |
| **PJT** | `PJF_TASKS_V` | Project Tasks |
| **PET** | `PJF_EXP_TYPES_TL` | Expenditure Types |
| **PPP** | `PJF_PROJECT_PARTIES` | Project Team Members |
| **PPR** | `PJF_PROJ_ROLE_TYPES_TL` | Project Roles |

### 2.3 Absence Tables (Integration)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **ABSE** | `ANC_PER_ABS_ENTRIES` | Absence Entries |
| **ABST** | `ANC_ABSENCE_TYPES_F_TL` | Absence Types |
| **ABV** | `ANC_ABSENCE_TYPES_VL` | Absence Types View |

### 2.4 Person & Assignment Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAPF** | `PER_ALL_PEOPLE_F` | Person Master |
| **PPNF** | `PER_PERSON_NAMES_F` | Person Names |
| **PAAM** / **ASG** | `PER_ALL_ASSIGNMENTS_M` | Assignments (Managed) |
| **PAAF** | `PER_ALL_ASSIGNMENTS_F` | Assignments (Date-Tracked) |
| **PASF** | `PER_ASSIGNMENT_SUPERVISORS_F` | Line Managers |

---

## 3. 📋 Attribute Patterns

### 3.1 Project Scalar Subquery

**Pattern:**
```sql
(SELECT PJP.SEGMENT1
 FROM HWM_TM_REP_ATRB_USAGES AUSG,
      HWM_TM_REP_ATRBS ATR,
      PJF_PROJECTS_ALL_VL PJP
 WHERE TMD.TM_REC_ID = AUSG.USAGES_SOURCE_ID
 AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
 AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
 AND ATR.ATTRIBUTE_NUMBER1 = PJP.PROJECT_ID
 AND AUSG.USAGES_SOURCE_VERSION = (
     SELECT MAX(A1.USAGES_SOURCE_VERSION)
     FROM HWM_TM_REP_ATRB_USAGES A1
     WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
 )
 AND ROWNUM = 1
) PROJECT_NUMBER
```

### 3.2 Task Scalar Subquery

**Pattern:**
```sql
(SELECT PJT.TASK_NUMBER
 FROM HWM_TM_REP_ATRB_USAGES AUSG,
      HWM_TM_REP_ATRBS ATR,
      PJF_TASKS_V PJT
 WHERE TMD.TM_REC_ID = AUSG.USAGES_SOURCE_ID
 AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
 AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
 AND ATR.ATTRIBUTE_NUMBER2 = PJT.TASK_ID
 AND AUSG.USAGES_SOURCE_VERSION = (
     SELECT MAX(A1.USAGES_SOURCE_VERSION)
     FROM HWM_TM_REP_ATRB_USAGES A1
     WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
 )
 AND ROWNUM = 1
) TASK_NUMBER
```

### 3.3 Expenditure Type Scalar Subquery

**Pattern:**
```sql
NVL(
  (SELECT D.EXPENDITURE_TYPE_NAME
   FROM HWM_TM_REP_ATRB_USAGES B,
        HWM_TM_REP_ATRBS C,
        PJF_EXP_TYPES_TL D
   WHERE TMD.TM_REC_ID = B.USAGES_SOURCE_ID
   AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
   AND C.ATTRIBUTE_CATEGORY = TO_CHAR(D.EXPENDITURE_TYPE_ID)
   AND D.LANGUAGE = 'US'
   AND B.USAGES_SOURCE_VERSION = (
       SELECT MAX(A1.USAGES_SOURCE_VERSION)
       FROM HWM_TM_REP_ATRB_USAGES A1
       WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
   )
   AND ROWNUM = 1
  ),
  (SELECT D.NAME
   FROM HWM_TM_REP_ATRB_USAGES B,
        HWM_TM_REP_ATRBS C,
        ANC_ABSENCE_TYPES_VL D
   WHERE TMD.TM_REC_ID = B.USAGES_SOURCE_ID
   AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
   AND C.ATTRIBUTE_CATEGORY = TO_CHAR(D.ABSENCE_TYPE_ID)
   AND D.LANGUAGE = 'US'
   AND B.USAGES_SOURCE_VERSION = (
       SELECT MAX(A1.USAGES_SOURCE_VERSION)
       FROM HWM_TM_REP_ATRB_USAGES A1
       WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
   )
   AND ROWNUM = 1
  )
) EXPENDITURE_TYPE
```

**Note:** This pattern handles BOTH project expenditure types AND absence types.

### 3.4 Stat Holiday Pattern

**Use Case:** Identify public holidays from time records

**Pattern:**
```sql
(SELECT UPPER(MAX(C.ATTRIBUTE_CATEGORY))
 FROM HWM_TM_REP_ATRB_USAGES B,
      HWM_TM_REP_ATRBS C
 WHERE TMD.TM_REC_ID = B.USAGES_SOURCE_ID
 AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
 AND UPPER(C.ATTRIBUTE_CATEGORY) LIKE 'STAT%HOLIDAY%'
 AND B.USAGES_SOURCE_VERSION = (
     SELECT MAX(A1.USAGES_SOURCE_VERSION)
     FROM HWM_TM_REP_ATRB_USAGES A1
     WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
 )
) STAT_HOLIDAY
```

### 3.5 Leave Project Reference Pattern

**Use Case:** Get reference from leave attributes

**Pattern:**
```sql
(SELECT C.ATTRIBUTE_CHAR1
 FROM HWM_TM_REP_ATRB_USAGES B,
      HWM_TM_REP_ATRBS C
 WHERE TMD.TM_REC_ID = B.USAGES_SOURCE_ID
 AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
 AND C.ATTRIBUTE_CATEGORY LIKE 'ORA_ANC_%'
 AND B.USAGES_SOURCE_VERSION = (
     SELECT MAX(A1.USAGES_SOURCE_VERSION)
     FROM HWM_TM_REP_ATRB_USAGES A1
     WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
 )
 AND ROWNUM = 1
) LEAVE_PROJECT_REFERENCE
```

---

## 4. 🔗 Standard Joins (Copy-Paste Ready)

### 4.1 Timesheet Header to Detail Join

```sql
FROM HWM_TM_REC_SUMM TMH,
     HWM_TM_REP_HIERARCHIES_VL TMD
WHERE TMH.TM_REC_GRP_ID = TMD.TM_REC_GRP_ID
AND TMH.STATUS IN ('Approved', 'Submitted')
```

### 4.2 Timesheet to Project Join (via Attributes)

```sql
FROM HWM_TM_REP_HIERARCHIES_VL TMD,
     HWM_TM_REP_ATRB_USAGES AUSG,
     HWM_TM_REP_ATRBS ATR,
     PJF_PROJECTS_ALL_VL PJP
WHERE TMD.TM_REC_ID = AUSG.USAGES_SOURCE_ID
AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
AND ATR.ATTRIBUTE_NUMBER1 = PJP.PROJECT_ID
AND AUSG.USAGES_SOURCE_VERSION = (
    SELECT MAX(A1.USAGES_SOURCE_VERSION)
    FROM HWM_TM_REP_ATRB_USAGES A1
    WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
)
```

### 4.3 Timesheet to Task Join (via Attributes)

```sql
FROM HWM_TM_REP_HIERARCHIES_VL TMD,
     HWM_TM_REP_ATRB_USAGES AUSG,
     HWM_TM_REP_ATRBS ATR,
     PJF_TASKS_V PJT
WHERE TMD.TM_REC_ID = AUSG.USAGES_SOURCE_ID
AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
AND ATR.ATTRIBUTE_NUMBER2 = PJT.TASK_ID
AND AUSG.USAGES_SOURCE_VERSION = (
    SELECT MAX(A1.USAGES_SOURCE_VERSION)
    FROM HWM_TM_REP_ATRB_USAGES A1
    WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
)
```

### 4.4 Timesheet to Line Manager Join

**Using Assignment Supervisor:**
```sql
FROM HWM_TM_REP_HIERARCHIES_VL TMD,
     HWM_TM_REC_SUMM TMH,
     PER_ALL_PEOPLE_F PAPF,
     PER_ALL_ASSIGNMENTS_M ASG,
     PER_ASSIGNMENT_SUPERVISORS_F PASF,
     PER_ALL_ASSIGNMENTS_M MGASG,
     PER_PERSON_NAMES_F MGNAME
WHERE TMH.TM_REC_GRP_ID = TMD.TM_REC_GRP_ID
AND TMD.PERSON_ID = PAPF.PERSON_ID
AND PAPF.PERSON_ID = ASG.PERSON_ID
AND ASG.ASSIGNMENT_ID = PASF.ASSIGNMENT_ID
AND PASF.MANAGER_ASSIGNMENT_ID = MGASG.ASSIGNMENT_ID
AND MGASG.PERSON_ID = MGNAME.PERSON_ID
AND PASF.MANAGER_TYPE = 'LINE_MANAGER'
AND ASG.PRIMARY_FLAG = 'Y'
AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
AND MGNAME.NAME_TYPE = 'GLOBAL'
AND TRUNC(TMD.START_TIME) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
AND TRUNC(TMD.START_TIME) BETWEEN PASF.EFFECTIVE_START_DATE AND PASF.EFFECTIVE_END_DATE
AND TRUNC(TMD.START_TIME) BETWEEN MGNAME.EFFECTIVE_START_DATE AND MGNAME.EFFECTIVE_END_DATE
```

**Using Project Manager (Fallback):**
```sql
FROM HWM_TM_REP_ATRB_USAGES AUSG,
     HWM_TM_REP_ATRBS ATR,
     PJF_TASKS_V PJT,
     PER_PERSON_NAMES_F P1
WHERE TMD.TM_REC_ID = AUSG.USAGES_SOURCE_ID
AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
AND ATR.ATTRIBUTE_NUMBER2 = PJT.TASK_ID
AND PJT.TASK_MANAGER_PERSON_ID = P1.PERSON_ID
AND P1.NAME_TYPE = 'GLOBAL'
AND TRUNC(TMD.START_TIME) BETWEEN P1.EFFECTIVE_START_DATE AND P1.EFFECTIVE_END_DATE
```

### 4.5 Timesheet to Absence Join (Cross-Check)

```sql
FROM HWM_TM_REP_HIERARCHIES_VL TMD,
     ANC_PER_ABS_ENTRIES ABSE,
     ANC_ABSENCE_TYPES_F_TL ABST
WHERE ABSE.PERSON_ID = TMD.PERSON_ID
AND ABSE.ABSENCE_TYPE_ID = ABST.ABSENCE_TYPE_ID
AND ABST.LANGUAGE = 'US'
AND TRUNC(TMD.START_TIME) BETWEEN TRUNC(ABSE.START_DATE) AND TRUNC(ABSE.END_DATE)
AND TRUNC(TMD.START_TIME) BETWEEN TRUNC(ABST.EFFECTIVE_START_DATE) AND TRUNC(ABST.EFFECTIVE_END_DATE)
AND ((ABSE.ABSENCE_STATUS_CD = 'SUBMITTED' AND ABSE.APPROVAL_STATUS_CD = 'APPROVED') OR
     (ABSE.ABSENCE_STATUS_CD = 'ORA_WITHDRAWN' AND ABSE.APPROVAL_STATUS_CD = 'ORA_AWAIT_AWAIT') OR
     (ABSE.ABSENCE_STATUS_CD = 'SUBMITTED' AND ABSE.APPROVAL_STATUS_CD = 'AWAITING') OR
     (ABSE.ABSENCE_STATUS_CD = 'SAVED'))
AND UPPER(ABST.NAME) = UPPER(TMD.EXPENDITURE_TYPE)  -- Match by name
```

---

## 5. 📊 Standard Filters

### 5.1 Date Range Filtering

**Timesheet Group Level:**
```sql
AND TMH.START_TIME >= :P_START_DATE
AND TMH.STOP_TIME <= :P_END_DATE
```

**Timesheet Detail Level:**
```sql
AND TMD.START_TIME >= TO_DATE(:P_START_DATE, 'YYYY-MM-DD')
AND TMD.STOP_TIME <= TO_DATE(:P_END_DATE, 'YYYY-MM-DD')
```

### 5.2 Status Filtering

**Approved Only:**
```sql
AND TMH.STATUS = 'Approved'
```

**Submitted or Approved:**
```sql
AND TMH.STATUS IN ('Approved', 'Submitted')
```

### 5.3 Project Filtering

**By Project Number:**
```sql
AND PJP.SEGMENT1 = :P_PROJECT_NUMBER
```

**By Project Name:**
```sql
AND UPPER(PJP.NAME) LIKE UPPER('%' || :P_PROJECT_NAME || '%')
```

### 5.4 Hours Calculation

**Total Hours (Recorded + Absence):**
```sql
NVL(TMH.RECORDED_HOURS, 0) + NVL(TMH.ABSENCE_HOURS, 0) TOTAL_HOURS
```

---

## 6. ⚠️ Common Pitfalls

### 6.1 Using Old Versions
**Problem:** Getting incorrect project/task/expenditure type  
**Cause:** Not filtering for latest `USAGES_SOURCE_VERSION`

**Solution:**
```sql
AND AUSG.USAGES_SOURCE_VERSION = (
    SELECT MAX(A1.USAGES_SOURCE_VERSION)
    FROM HWM_TM_REP_ATRB_USAGES A1
    WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
)
```

### 6.2 Missing Date Context
**Problem:** Cartesian products, wrong person/manager names  
**Cause:** Not filtering date-tracked tables with `START_TIME`

**Solution:**
```sql
AND TRUNC(TMD.START_TIME) BETWEEN P1.EFFECTIVE_START_DATE AND P1.EFFECTIVE_END_DATE
```

### 6.3 Assuming Single Approver
**Problem:** NULLs for approver when multiple approvers exist  
**Cause:** Not using `ROWNUM = 1`

**Solution:**
```sql
AND ROWNUM = 1  -- Take first approver
```

### 6.4 Mixing Expenditure Types and Absence Types
**Problem:** Getting only one type  
**Cause:** Not using `NVL` fallback pattern

**Solution:** Use the combined pattern (see Section 3.3)

---

## 7. 💡 Calculation Patterns

### 7.1 Line Status Derivation

**Complex logic for combining timesheet status and absence status:**

```sql
CASE
    WHEN PROJECT IS NOT NULL THEN NVL(LINE_STATUS1, STATUS)
    WHEN ABS_COUNT > 0 THEN (
        SELECT CASE
            WHEN ABSENCE_STATUS_CD = 'SUBMITTED' AND APPROVAL_STATUS_CD = 'APPROVED' THEN 'Approved'
            WHEN ABSENCE_STATUS_CD = 'ORA_WITHDRAWN' AND APPROVAL_STATUS_CD = 'ORA_AWAIT_AWAIT' THEN 'Approved'
            WHEN ABSENCE_STATUS_CD = 'SUBMITTED' AND APPROVAL_STATUS_CD = 'AWAITING' THEN 'Submitted'
            WHEN ABSENCE_STATUS_CD = 'SAVED' THEN 'Saved'
        END
        FROM ANC_PER_ABS_ENTRIES ABSE
        WHERE ABSE.PERSON_ID = X.PERSON_ID
        AND TRUNC(X.SEQ_DATE) BETWEEN TRUNC(ABSE.START_DATE) AND TRUNC(ABSE.END_DATE)
        AND ROWNUM = 1
    )
END LINE_STATUS
```

### 7.2 Approval Date Logic

**Only show approval date when status is Approved:**
```sql
CASE WHEN TMH.STATUS = 'Approved' THEN TMH.LAST_UPDATE_DATE END APPROVAL_DATE
```

---

## 8. 📅 Parameters

| Parameter | Format | Description | Example |
|-----------|--------|-------------|---------|
| `:P_START_DATE` | Date | Start date | TO_DATE('01-12-2024','DD-MM-YYYY') |
| `:P_END_DATE` | Date | End date | TO_DATE('31-12-2024','DD-MM-YYYY') |
| `:P_EMP_NO` | String | Employee number | '12345' |
| `:P_PROJECT_NUMBER` | String | Project number | 'PRJ001' |
| `:P_STATUS` | String | Timesheet status | 'Approved' |
| `:P_DEPT` | String | Department name | 'Finance' |

---

**Last Updated:** 13-Jan-2026  
**Status:** Production-Ready  
**Source:** Employee Timesheet Report (980 lines analyzed) + OTL Production Queries (10 files)

---

## 9. 🚀 Advanced OTL Patterns (07-Jan-2026)

### 9.1 HWM_TM_REP_ATRB_USAGES Latest Version Pattern

**Problem:** Get latest attribute usage version for timecard

**Solution:**

```sql
SELECT
    TMD.TM_REC_ID,
    
    -- Project (latest version)
    (SELECT PJP.SEGMENT1
     FROM
         HWM_TM_REP_ATRB_USAGES AUSG,
         HWM_TM_REP_ATRBS ATR,
         PJF_PROJECTS_ALL_VL PJP
     WHERE
         TMD.TM_REC_ID = AUSG.USAGES_SOURCE_ID
         AND AUSG.TM_REP_ATRB_ID = ATR.TM_REP_ATRB_ID
         AND ATR.ATTRIBUTE_CATEGORY = 'Projects'
         AND ATR.ATTRIBUTE_NUMBER1 = PJP.PROJECT_ID
         
         -- CRITICAL: Get latest usage version
         AND AUSG.USAGES_SOURCE_VERSION = (
             SELECT MAX(A1.USAGES_SOURCE_VERSION)
             FROM HWM_TM_REP_ATRB_USAGES A1
             WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
         )
         AND ROWNUM = 1
    ) PROJECT_NUMBER
FROM HWM_EXT_TIMECARD_DETAIL_V TMD
```

**Why Critical:**
- Timecard attributes can be updated/versioned
- Must use `MAX(USAGES_SOURCE_VERSION)` to get latest
- Without this, may get old/deleted attribute values

**Attribute Categories:**
- `'Projects'` - Project attributes (ATTRIBUTE_NUMBER1 = PROJECT_ID, ATTRIBUTE_NUMBER2 = TASK_ID)
- `TO_CHAR(EXPENDITURE_TYPE_ID)` - Expenditure type
- `TO_CHAR(ABSENCE_TYPE_ID)` - Absence type
- `'ORA_CUSTOM'` - Custom attributes
- `'STAT HOLIDAY'` - Stat holiday attribute

### 9.2 Custom Attribute Detection (Leave Project Reference)

**Problem:** Detect if timecard is for leave project vs regular project

**Solution:**

```sql
-- Leave project reference
NVL(
    -- Check for custom attribute indicating leave/fringe
    (SELECT DECODE(C.ATTRIBUTE_VARCHAR1, '1', 'Fringe', C.ATTRIBUTE_VARCHAR1)
     FROM
         HWM_TM_REP_ATRB_USAGES B,
         HWM_TM_REP_ATRBS C
     WHERE
         TMD.TM_REC_ID = B.USAGES_SOURCE_ID
         AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
         AND C.ATTRIBUTE_CATEGORY = 'ORA_CUSTOM'
         AND C.ATTRIBUTE_VARCHAR1 IN ('1', 'O003 | Regular Time', 'O009 | Regular Time')
         AND B.USAGES_SOURCE_VERSION = (
             SELECT MAX(A1.USAGES_SOURCE_VERSION)
             FROM HWM_TM_REP_ATRB_USAGES A1
             WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
         )
    ),
    -- Otherwise, show project | task reference
    (SELECT PJP.SEGMENT1 || ' | ' || PJT.TASK_NUMBER
     FROM
         HWM_TM_REP_ATRB_USAGES B,
         HWM_TM_REP_ATRBS C,
         PJF_PROJECTS_ALL_VL PJP,
         PJF_TASKS_V PJT
     WHERE
         TMD.TM_REC_ID = B.USAGES_SOURCE_ID
         AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
         AND C.ATTRIBUTE_CATEGORY = 'ORA_CUSTOM'
         AND C.ATTRIBUTE_VARCHAR1 NOT IN ('1', 'O003 | Regular Time')
         AND C.ATTRIBUTE_VARCHAR1 = TO_CHAR(PJT.TASK_ID)
         AND PJT.PROJECT_ID = PJP.PROJECT_ID
         AND B.USAGES_SOURCE_VERSION = (
             SELECT MAX(A1.USAGES_SOURCE_VERSION)
             FROM HWM_TM_REP_ATRB_USAGES A1
             WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
         )
    )
) LEAVE_PROJECT_REFERENCE
```

**Purpose:** Distinguish between regular time (non-project, fringe), leave projects (absence tracking via projects), and actual project work

### 9.3 Payroll Time Type from Timecard

**Problem:** Get payroll time type assigned to timecard

**Solution:**

```sql
-- Payroll time type
(SELECT A.PAY_PAYROLL_TIME_TYPE
 FROM HWM_TM_REP_M_PTT_ATRBS_V A
 WHERE A.USAGES_SOURCE_ID = TMD.TM_REC_ID
 AND A.USAGES_SOURCE_VERSION = (
     SELECT MAX(A1.USAGES_SOURCE_VERSION)
     FROM HWM_TM_REP_ATRB_USAGES A1
     WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
 )
) PAYROLL_TIME_TYPE
```

**Table:** `HWM_TM_REP_M_PTT_ATRBS_V`  
**Purpose:** View that joins timecard attributes to payroll time types

### 9.4 Stat Holiday Detection

**Solution:**

```sql
-- Stat holiday detection
(SELECT UPPER(MAX(C.ATTRIBUTE_CATEGORY))
 FROM
     HWM_TM_REP_ATRB_USAGES B,
     HWM_TM_REP_ATRBS C
 WHERE
     TMD.TM_REC_ID = B.USAGES_SOURCE_ID
     AND B.TM_REP_ATRB_ID = C.TM_REP_ATRB_ID
     AND UPPER(C.ATTRIBUTE_CATEGORY) LIKE 'STAT%HOLIDAY%'
     AND B.USAGES_SOURCE_VERSION = (
         SELECT MAX(A1.USAGES_SOURCE_VERSION)
         FROM HWM_TM_REP_ATRB_USAGES A1
         WHERE A1.USAGES_SOURCE_ID = TMD.TM_REC_ID
     )
) STAT_HOLIDAY
```

### 9.5 Project-Based Approval Hierarchy

**Problem:** Determine approver based on project assignment (task manager → project manager → line manager)

**Approval Hierarchy:**
```
1. Task Manager (if project task assigned)
   ↓ (if not found)
2. Project Manager (if project assigned)
   ↓ (if not found or not project time)
3. Line Manager (default)
```

**Solution:** See TL_OTL_COMPREHENSIVE_GUIDE for complete implementation

### 9.6 Project Status Integration

**Problem:** Get project costing status for timecard line

**Solution:**

```sql
-- Project status (from HWM_TM_A_APP_STATUS_PJC_V)
(SELECT DISTINCT INITCAP(PJCS.STATUS_VALUE)
 FROM HWM_TM_A_APP_STATUS_PJC_V PJCS
 WHERE PJCS.TM_BLDG_BLK_ID = TMD.TM_REC_ID
 AND PJCS.TM_BLDG_BLK_VERSION = TMD.TM_REC_VERSION
) LINE_STATUS_PROJECT
```

**Tables:**
- `HWM_TM_A_APP_STATUS_PJC_V` - Timecard-to-project costing approval status
- Links timecard to project costing approval workflow

### 9.7 Critical OTL Tables

#### HWM_TM_REP_ATRB_USAGES (Timecard Attribute Usages)

**Purpose:** Link timecard records to attributes (projects, tasks, expenditure types)

**Critical Columns:**
- `USAGES_SOURCE_ID` - TM_REC_ID (timecard line)
- `USAGES_SOURCE_VERSION` - Version number (CRITICAL: use MAX)
- `TM_REP_ATRB_ID` - Links to HWM_TM_REP_ATRBS

**Why Versioning Matters:**
- Timecards can be edited
- Each edit creates new version
- Old versions retained
- **MUST** use MAX(USAGES_SOURCE_VERSION)

#### HWM_TM_REP_ATRBS (Timecard Attributes)

**Purpose:** Define timecard attributes

**Critical Columns:**
- `TM_REP_ATRB_ID` - Primary key
- `ATTRIBUTE_CATEGORY` - Category/type
- `ATTRIBUTE_NUMBER1` - First numeric attribute (e.g., PROJECT_ID)
- `ATTRIBUTE_NUMBER2` - Second numeric attribute (e.g., TASK_ID)
- `ATTRIBUTE_VARCHAR1` - First character attribute

**Common Categories:**
- `'Projects'` - Project/task attributes
- `TO_CHAR(EXPENDITURE_TYPE_ID)` - Expenditure type
- `TO_CHAR(ABSENCE_TYPE_ID)` - Absence type
- `'ORA_CUSTOM'` - Custom attributes
- `'STAT HOLIDAY'` - Stat holiday

#### HWM_TM_REP_M_PTT_ATRBS_V (Payroll Time Type View)

**Purpose:** View linking timecard to payroll time types

**Columns:**
- `USAGES_SOURCE_ID` - TM_REC_ID
- `USAGES_SOURCE_VERSION` - Version
- `PAY_PAYROLL_TIME_TYPE` - Payroll time type name

#### HWM_TM_A_APP_STATUS_PJC_V (Project Costing Approval Status)

**Purpose:** Timecard-to-project costing approval status

**Columns:**
- `TM_BLDG_BLK_ID` - TM_REC_ID or TM_REC_GRP_ID
- `TM_BLDG_BLK_VERSION` - Version
- `STATUS_VALUE` - Status (e.g., 'Approved', 'Rejected')

---

## 10. 📚 Additional Resources

### OTL Knowledge Base Reference

For comprehensive Oracle Time & Labor (OTL) attendance and shift management patterns, refer to:
- **TL_OTL_COMPREHENSIVE_GUIDE** - Complete OTL implementation guide (50+ patterns)
- **TL_OTL_QUERY_TEMPLATES** - 8 ready-to-use OTL query templates
- **TL_OTL_KNOWLEDGE_SUMMARY** - Quick start guide and troubleshooting

**Note:** The OTL files focus on attendance tracking, shift management, and time clock operations, while TL_MASTER focuses on timesheet processing and project time tracking.

