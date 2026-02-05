# Oracle Recruiting Cloud (ORC) - Complete Table Reference

**Purpose:** Quick reference for all ORC tables, columns, and relationships  
**Date:** 07-Jan-2026  
**Status:** Production-Ready

---

## 📋 TABLE OF CONTENTS

1. [Core IRC Tables](#core-irc-tables)
2. [Flexfield Tables](#flexfield-tables)
3. [Workflow Tables](#workflow-tables)
4. [Assignment & Compensation Tables](#assignment--compensation-tables)
5. [User-Defined Tables (UDT)](#user-defined-tables-udt)
6. [Supporting Tables](#supporting-tables)
7. [Table Relationship Diagram](#table-relationship-diagram)
8. [Column Data Types & Constraints](#column-data-types--constraints)

---

## 1. CORE IRC TABLES

### IRC_REQUISITIONS_VL (Requisitions)

**Purpose:** Job openings/vacancies to be filled

| Column | Type | Description | Example | Constraints |
|--------|------|-------------|---------|-------------|
| `REQUISITION_ID` | NUMBER | Primary key | 300000001234567 | NOT NULL, UNIQUE |
| `REQUISITION_NUMBER` | VARCHAR2 | User-visible number | '1234' | NOT NULL, UNIQUE |
| `REQUISITION_TITLE` | VARCHAR2 | Job title | 'Software Engineer' | |
| `JOB_ID` | NUMBER | Links to PER_JOBS_F | 300000001234567 | FK |
| `JOB_FAMILY_ID` | NUMBER | Job family | 300000001234567 | FK |
| `DEPARTMENT_ID` | NUMBER | Hiring department | 300000001234567 | FK |
| `LOCATION_ID` | NUMBER | Primary work location | 300000001234567 | FK |
| `GEOGRAPHY_NODE_ID` | NUMBER | Geographic hierarchy | 300000001234567 | FK |
| `BUSINESS_UNIT_ID` | NUMBER | Business unit | 100 | FK |
| `LEGAL_EMPLOYER_ID` | NUMBER | Legal entity | 200 | FK |
| `HIRING_MANAGER_ID` | NUMBER | Hiring manager person ID | 300000001234567 | FK |
| `RECRUITER_ID` | NUMBER | Assigned recruiter | 300000001234567 | FK |
| `OPEN_DATE` | DATE | Date opened | 01-JAN-2024 | NOT NULL |
| `CLOSE_DATE` | DATE | Date closed | 31-JAN-2024 | |
| `WORKER_TYPE_CODE` | VARCHAR2(30) | Worker type | 'E', 'C' | E=Employee, C=Contingent |
| `RECRUITING_TYPE_CODE` | VARCHAR2(30) | Recruiting type | | |
| `JUSTIFICATION_CODE` | VARCHAR2(30) | Justification code | 'REPLACEMENT' | Lookup |
| `ATTRIBUTE_CHAR1-30` | VARCHAR2 | Flexfields | | Custom |
| `ATTRIBUTE_NUMBER1-15` | NUMBER | Numeric flexfields | | Custom |
| `ATTRIBUTE_DATE1-15` | DATE | Date flexfields | | Custom |

**Key Indexes:**
- Primary Key: `REQUISITION_ID`
- Unique: `REQUISITION_NUMBER`
- Foreign Keys: `JOB_ID`, `DEPARTMENT_ID`, `HIRING_MANAGER_ID`, `RECRUITER_ID`

**Common Queries:**
```sql
-- Active requisitions
WHERE REQ.CLOSE_DATE IS NULL

-- By hiring manager
WHERE REQ.HIRING_MANAGER_ID = :MANAGER_ID

-- By business unit
WHERE REQ.BUSINESS_UNIT_ID = :BU_ID
```

---

### IRC_CANDIDATES (Candidates)

**Purpose:** People who have applied or been sourced

| Column | Type | Description | Example | Constraints |
|--------|------|-------------|---------|-------------|
| `CANDIDATE_ID` | NUMBER | Primary key (NOT person_id) | 300000001234567 | NOT NULL, UNIQUE |
| `PERSON_ID` | NUMBER | Links to PER_ALL_PEOPLE_F | 300000001234567 | NOT NULL, FK |
| `CANDIDATE_NUMBER` | VARCHAR2 | User-visible number | '6367788' | NOT NULL, UNIQUE |
| `CAND_EMAIL_ID` | NUMBER | Preferred email ID | 300000001234567 | FK to PER_EMAIL_ADDRESSES |
| `CAND_PHONE_ID` | NUMBER | Preferred phone ID | 300000001234567 | FK to PER_PHONES |
| `CAND_ADDRESS_ID` | NUMBER | Preferred address ID | 300000001234567 | FK to PER_PERSON_ADDRESSES_V |
| `SOURCE_TRACKING_ID` | NUMBER | How sourced | 300000001234567 | FK |
| `CREATION_DATE` | DATE | When created | 01-JAN-2024 | NOT NULL |

**Key Patterns:**
```sql
-- Get candidate with preferred contact
SELECT
    CAND.CANDIDATE_NUMBER,
    EMAIL.EMAIL_ADDRESS,
    PHONE.PHONE_NUMBER
FROM
    IRC_CANDIDATES CAND,
    PER_EMAIL_ADDRESSES EMAIL,
    PER_PHONES PHONE
WHERE
    CAND.CAND_EMAIL_ID = EMAIL.EMAIL_ADDRESS_ID(+)
    AND CAND.CAND_PHONE_ID = PHONE.PHONE_ID(+);
```

---

### IRC_SUBMISSIONS (Applications)

**Purpose:** Candidate applications to requisitions

| Column | Type | Description | Example | Constraints |
|--------|------|-------------|---------|-------------|
| `SUBMISSION_ID` | NUMBER | Primary key | 300000001234567 | NOT NULL, UNIQUE |
| `REQUISITION_ID` | NUMBER | Which job | 300000001234567 | NOT NULL, FK |
| `PERSON_ID` | NUMBER | Which candidate | 300000001234567 | NOT NULL, FK |
| `CURRENT_PHASE_ID` | NUMBER | Current phase | 300000001234567 | FK |
| `CURRENT_STATE_ID` | NUMBER | Current state | 300000001234567 | FK |
| `SUBMISSION_DATE` | DATE | When applied | 01-JAN-2024 | NOT NULL |
| `CONFIRMED_FLAG` | VARCHAR2(1) | Confirmed | 'Y', 'N' | |
| `INTERNAL_FLAG` | VARCHAR2(1) | Internal candidate | 'Y', 'N' | |
| `SYSTEM_PERSON_TYPE` | VARCHAR2(30) | Person type when applying | 'EMP', 'EX_EMP', 'ORA_CANDIDATE' | |
| `OBJECT_STATUS` | VARCHAR2(30) | Submission status | | |
| `ACTIVE_FLAG` | VARCHAR2(1) | Is active | 'Y', 'N' | **CRITICAL FILTER** |
| `ADDED_BY_CONTEXT_CODE` | VARCHAR2(30) | How added | | |
| `CREATED_BY` | VARCHAR2(64) | Who created | | |

**CRITICAL Filter:**
```sql
AND SUB.ACTIVE_FLAG = 'Y'  -- ALWAYS USE THIS
```

**Key Patterns:**
```sql
-- Complete lifecycle
FROM
    IRC_REQUISITIONS_VL REQ,
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    IRC_PHASES_VL PHASE,
    IRC_STATES_VL STATE
WHERE
    REQ.REQUISITION_ID = SUB.REQUISITION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND SUB.CURRENT_PHASE_ID = PHASE.PHASE_ID
    AND SUB.CURRENT_STATE_ID = STATE.STATE_ID
    AND SUB.ACTIVE_FLAG = 'Y';
```

---

### IRC_OFFERS (Offers)

**Purpose:** Job offers extended to candidates

| Column | Type | Description | Example | Constraints |
|--------|------|-------------|---------|-------------|
| `OFFER_ID` | NUMBER | Primary key | 300000001234567 | NOT NULL, UNIQUE |
| `OFFER_NUMBER` | VARCHAR2 | User-visible number | 'OFR-2024-001' | UNIQUE |
| `ASSIGNMENT_OFFER_ID` | NUMBER | Offer assignment ID | 300000001234567 | **FK to PER_ALL_ASSIGNMENTS_M** |
| `SUBMISSION_ID` | NUMBER | Which submission | 300000001234567 | FK |
| `PERSON_ID` | NUMBER | Candidate | 300000001234567 | NOT NULL, FK |
| `OFFER_NAME` | VARCHAR2 | Offer title | | |
| `RECRUITER_ID` | NUMBER | Recruiter | 300000001234567 | FK |
| `HIRING_MANAGER_ID` | NUMBER | Hiring manager | 300000001234567 | FK |
| `CURRENT_PHASE_ID` | NUMBER | Current phase | 300000001234567 | FK |
| `CURRENT_STATE_ID` | NUMBER | Current state | 300000001234567 | FK |
| `DRAFTED_DATE` | DATE | Date drafted | 01-JAN-2024 | |
| `APPROVED_DATE` | DATE | Date approved | 02-JAN-2024 | |
| `EXTENDED_DATE` | DATE | Date sent to candidate | 03-JAN-2024 | |
| `ACCEPTED_DATE` | DATE | Date candidate accepted | 05-JAN-2024 | |
| `WITHDRAWN_REJECTED_DATE` | DATE | Date withdrawn/rejected | | |
| `ACCEPTED_ON_BEHALF` | VARCHAR2(1) | Accepted on behalf | 'Y', 'N' | |
| `MOVE_TO_HR_STATUS` | VARCHAR2(30) | Hire process status | 'SUCCESS', 'ERROR' | |
| `MOVE_TO_HR_DATE` | DATE | Date moved to HR | 10-JAN-2024 | |
| `OFFER_MOVE_STATUS` | VARCHAR2(30) | Move status | | |
| `OFFER_LETTER_CUSTOMIZED_FLAG` | VARCHAR2(1) | Is customized | 'Y', 'N' | |
| `ATTRIBUTE_CHAR1-30` | VARCHAR2 | Flexfields | | Custom |
| `ATTRIBUTE_NUMBER1-15` | NUMBER | Numeric flexfields | | Salary components |

**CRITICAL Pattern:**
```sql
FROM
    IRC_OFFERS OFFER,
    PER_ALL_ASSIGNMENTS_M ASG
WHERE
    OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'  -- MUST USE THIS
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
```

---

## 2. FLEXFIELD TABLES

### IRC_JA_EXTRA_INFO (Submission Flexfields)

**Purpose:** Store additional submission information (DFF)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `SUBMISSION_ID` | NUMBER | Links to submission | 300000001234567 |
| `PEI_INFORMATION_CATEGORY` | VARCHAR2(30) | Category/context | 'LOGISTICS', 'Medical_Health' |
| `PEI_INFORMATION1-30` | VARCHAR2 | Character fields | |
| `PEI_INFORMATION_NUMBER1-15` | NUMBER | Numeric fields | |
| `PEI_INFORMATION_DATE1-15` | DATE | Date fields | |

**Common Categories:**

| Category | Purpose | Key Fields |
|----------|---------|------------|
| `LOGISTICS` | Logistics details | PEI_INFORMATION15 (owner) |
| `XX_LOGISTICS` | Extended logistics | PEI_INFORMATION_DATE3 (completion) |
| `Medical_Health` | Medical screening | PEI_INFORMATION8 (result), PEI_INFORMATION_DATE3 (date) |
| `Screening` | Background screening | PEI_INFORMATION20 (owner), PEI_INFORMATION_DATE15 (date) |
| `Craft` | Trade/craft info | PEI_INFORMATION_DATE2 (mobilisation date) |
| `Candidate Local Name` | Arabic name | PEI_INFORMATION1/2/3 (first/middle/last), PEI_INFORMATION4 (title) |

**Pattern:**
```sql
SELECT
    SUB.SUBMISSION_ID,
    (SELECT PEI_INFORMATION15
     FROM IRC_JA_EXTRA_INFO
     WHERE SUBMISSION_ID = SUB.SUBMISSION_ID
     AND PEI_INFORMATION_CATEGORY = 'LOGISTICS') LOGISTICS_OWNER
FROM IRC_SUBMISSIONS SUB;
```

---

### PER_PEOPLE_EXTRA_INFO (Person Flexfields)

**Purpose:** Store additional person information (DFF)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `PERSON_EXTRA_INFO_ID` | NUMBER | Primary key | 300000001234567 |
| `PERSON_ID` | NUMBER | Links to person | 300000001234567 |
| `INFORMATION_TYPE` | VARCHAR2(60) | Category | 'Candidate Current Salary' |
| `PEI_INFORMATION1-30` | VARCHAR2 | Character fields | |
| `PEI_INFORMATION_NUMBER1-15` | NUMBER | Numeric fields | |
| `PEI_INFORMATION_DATE1-15` | DATE | Date fields | |

**Common Information Types:**

| Information Type | Purpose | Key Fields |
|-----------------|---------|------------|
| `Candidate Local Name` | Arabic name | PEI_INFORMATION1/2/3 (name parts), PEI_INFORMATION4 (title) |
| `Candidate Compensation Details` | Airfare details | PEI_INFORMATION1 (class), PEI_INFORMATION2 (destination), PEI_INFORMATION_NUMBER1/2/3 (adult/child/infant counts) |
| `Candidate Other Compensation` | Other allowances | PEI_INFORMATION1 (medical), PEI_INFORMATION2 (ticket) |
| `Candidate Current Salary` | Current salary | PEI_INFORMATION_NUMBER1/2/3 (monthly/ticket/education) |
| `Candidate Personal Details` | Personal info | PEI_INFORMATION1 (nationality), PEI_INFORMATION2 (marital status) |
| `Candidate qualification` | Qualifications | PEI_INFORMATION1-5 (qualification/experience/source/location/job title) |

**Pattern:**
```sql
WITH CANDIDATE_EXTRA AS (
    SELECT
        PERSON_ID,
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Current Salary'
            THEN PEI_INFORMATION_NUMBER1 END) MONTHLY_ALLOWANCE
    FROM PER_PEOPLE_EXTRA_INFO
    GROUP BY PERSON_ID
)
```

---

## 3. WORKFLOW TABLES

### IRC_PHASES_VL (Workflow Phases)

**Purpose:** High-level workflow stages

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `PHASE_ID` | NUMBER | Primary key | 300000001234567 |
| `PHASE_CODE` | VARCHAR2(30) | System code | 'ORA_INTERVIEW' |
| `NAME` | VARCHAR2(240) | Phase name | 'Interview' |

**Common Phases:**
- Application Review
- Interview
- Selection
- Offer
- Pre-Employment
- Hire

---

### IRC_STATES_VL (Workflow States)

**Purpose:** Detailed workflow states within phases

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `STATE_ID` | NUMBER | Primary key | 300000001234567 |
| `STATE_CODE` | VARCHAR2(30) | System code | 'ORA_TO_BE_REVIEWED' |
| `NAME` | VARCHAR2(240) | State name | 'To be Reviewed' |
| `PHASE_ID` | NUMBER | Which phase | 300000001234567 |

**Common States (Submissions):**
- `To be Reviewed`
- `Shared with Hiring Manager`
- `Rejected by Employer`
- `Withdrawn by Candidate`
- `Selected for Offer - Experienced`
- `Selected for Offer - Fresher`

**Common States (Offers):**
- `Draft` - Offer created
- `Pending Approval` - Awaiting approval
- `Approved` - Ready to extend
- `Extended` - Sent to candidate
- `Accepted` - Candidate accepted
- `Processed` - Employee joined
- `Pending Manual Processing` - Awaiting manual hire
- `Error During Processing` - Hire error

**Business Mapping:**
```sql
CASE
    WHEN NAME = 'Extended' THEN 'Offer Sent to Candidate'
    WHEN NAME = 'Accepted' THEN 'Offer Accepted by Candidate'
    WHEN NAME = 'Processed' THEN 'Employee Joined'
    ELSE NAME
END
```

---

## 4. ASSIGNMENT & COMPENSATION TABLES

### PER_ALL_ASSIGNMENTS_M (Assignments - including Offers)

**Purpose:** ALL assignment types including offer assignments

| Column | Type | Description | Example | Notes |
|--------|------|-------------|---------|-------|
| `ASSIGNMENT_ID` | NUMBER | Primary key | 300000001234567 | NOT NULL |
| `PERSON_ID` | NUMBER | Person | 300000001234567 | NOT NULL, FK |
| `ASSIGNMENT_NUMBER` | VARCHAR2 | User-visible number | 'E1234567' | |
| `ASSIGNMENT_TYPE` | VARCHAR2(1) | Type | **'O'**, 'E', 'C', 'P' | **CRITICAL: 'O' = Offer** |
| `ASSIGNMENT_STATUS_TYPE` | VARCHAR2(30) | Status | 'ACTIVE', 'INACTIVE', 'SUSPENDED' | |
| `PRIMARY_ASSIGNMENT_FLAG` | VARCHAR2(1) | Is primary | 'Y', 'N' | |
| `EFFECTIVE_START_DATE` | DATE | Effective from | 01-JAN-2024 | Date-tracked |
| `EFFECTIVE_END_DATE` | DATE | Effective to | 31-DEC-4712 | Date-tracked |
| `EFFECTIVE_LATEST_CHANGE` | VARCHAR2(1) | Latest at date | 'Y', 'N' | **CRITICAL FILTER** |
| `JOB_ID` | NUMBER | Job | 300000001234567 | FK |
| `GRADE_ID` | NUMBER | Grade | 300000001234567 | FK |
| `ORGANIZATION_ID` | NUMBER | Department | 300000001234567 | FK |
| `BUSINESS_UNIT_ID` | NUMBER | Business unit | 100 | FK |
| `LEGAL_ENTITY_ID` | NUMBER | Legal entity | 200 | FK |
| `LOCATION_ID` | NUMBER | Work location | 300000001234567 | FK |
| `PERIOD_OF_SERVICE_ID` | NUMBER | Service period | 300000001234567 | FK (NULL for offers) |
| `PROJECTED_START_DATE` | DATE | Expected start | 15-JAN-2024 | For offers |
| `ASS_ATTRIBUTE1-30` | VARCHAR2 | Flexfields | | Custom |
| `ASS_ATTRIBUTE_NUMBER1-15` | NUMBER | Numeric flexfields | | Custom |

**CRITICAL Filters:**
```sql
-- For Offers
WHERE
    ASG.ASSIGNMENT_TYPE = 'O'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE

-- For Employees
WHERE
    ASG.ASSIGNMENT_TYPE IN ('E', 'C')
    AND ASG.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND ASG.PRIMARY_ASSIGNMENT_FLAG = 'Y'
```

---

### CMP_SALARY (Offer Salary)

**Purpose:** Salary details for offer assignments

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `SALARY_ID` | NUMBER | Primary key | 300000001234567 |
| `ASSIGNMENT_ID` | NUMBER | Offer assignment | 300000001234567 |
| `SALARY_BASIS_ID` | NUMBER | Salary basis | 300000001234567 |
| `SALARY_AMOUNT` | NUMBER | Salary amount | 5000.00 |
| `ANNUAL_SALARY` | NUMBER | Annual salary | 60000.00 |
| `ANNUAL_FT_SALARY` | NUMBER | Annual full-time | 60000.00 |
| `RATE_MIN_AMOUNT` | NUMBER | Range minimum | 4000.00 |
| `RATE_MID_AMOUNT` | NUMBER | Range midpoint | 6000.00 |
| `RATE_MAX_AMOUNT` | NUMBER | Range maximum | 8000.00 |
| `COMPA_RATIO` | NUMBER | Compensation ratio | 0.83 |
| `RANGE_POSITION` | NUMBER | Position in range | 50.00 |
| `QUARTILE` | NUMBER | Quartile | 2 |
| `QUINTILE` | NUMBER | Quintile | 3 |
| `CURRENCY_CODE` | VARCHAR2(15) | Currency | 'AED', 'USD' |
| `DATE_FROM` | DATE | Effective from | 01-JAN-2024 |
| `DATE_TO` | DATE | Effective to | 31-DEC-4712 |
| `MULTIPLE_COMPONENTS` | VARCHAR2(1) | Has multiple | 'Y', 'N' |
| `WORK_AT_HOME` | VARCHAR2(1) | Work from home | 'Y', 'N' |
| `ASSIG_GRADE_LADDER_ID` | NUMBER | Grade ladder | 300000001234567 |
| `GEOGRAPHY_TYPE_ID` | NUMBER | Comp zone type | 300000001234567 |
| `GEOGRAPHY_ID` | NUMBER | Comp zone | 300000001234567 |

**Pattern:**
```sql
FROM
    IRC_OFFERS OFFER,
    CMP_SALARY CSA
WHERE
    OFFER.ASSIGNMENT_OFFER_ID = CSA.ASSIGNMENT_ID
    AND CSA.DATE_FROM <= TRUNC(SYSDATE)
    AND CSA.DATE_TO >= TRUNC(SYSDATE);
```

---

### CMP_SALARY_SIMPLE_COMPNTS (Salary Components)

**Purpose:** Break down salary into components

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `COMPONENT_CODE` | VARCHAR2(150) | Component code | 'ORA_BASIC_SALARY', 'ORA_ALLOWANCE' |
| `AMOUNT` | NUMBER | Component amount | 3000.00 |
| `SALARY_ID` | NUMBER | Links to CMP_SALARY | 300000001234567 |
| `ASSIGNMENT_ID` | NUMBER | Assignment | 300000001234567 |
| `PERSON_ID` | NUMBER | Person | 300000001234567 |
| `SALARY_DATE_FROM` | DATE | Effective from | 01-JAN-2024 |
| `SALARY_DATE_TO` | DATE | Effective to | 31-DEC-4712 |
| `LAST_UPDATE_DATE` | DATE | Last updated | 05-JAN-2024 |

**CRITICAL Pattern (Latest Only):**
```sql
WHERE
    TRUNC(CSSC.LAST_UPDATE_DATE) = (
        SELECT MAX(TRUNC(LAST_UPDATE_DATE))
        FROM CMP_SALARY_SIMPLE_COMPNTS
        WHERE PERSON_ID = CSSC.PERSON_ID
    )
    AND TRUNC(SYSDATE) BETWEEN CSSC.SALARY_DATE_FROM AND CSSC.SALARY_DATE_TO
```

**Component Types (via FND_LOOKUP_VALUES):**
```sql
-- Get component type
SELECT
    CSSC.COMPONENT_CODE,
    FLV.MEANING COMPONENT_TYPE
FROM
    CMP_SALARY_SIMPLE_COMPNTS CSSC,
    FND_LOOKUP_VALUES FLV
WHERE
    CSSC.COMPONENT_CODE = FLV.LOOKUP_CODE
    AND FLV.LOOKUP_TYPE = 'ORA_CMP_SIMPLE_SALARY_COMPS'
    AND FLV.LANGUAGE = 'US';
```

**Common Meanings:**
- `'Basic salary'` - Base salary
- `'Allowance'` - Various allowances
- `'Gross Salary'` - Total gross

---

## 5. USER-DEFINED TABLES (UDT)

### FF_USER_TABLES_VL (UDT Definitions)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `USER_TABLE_ID` | NUMBER | Primary key | 300000001234567 |
| `BASE_USER_TABLE_NAME` | VARCHAR2(80) | Table name | 'AIRFARE_ALLOWANCE_ADULT' |

**Common UDT Tables:**
- `AIRFARE_ALLOWANCE_ADULT`
- `AIRFARE_ALLOWANCE_CHILD`
- `AIRFARE_ALLOWANCE_INFANT`
- `MOCA_EDUCATIONAL_ALLOWANCE`
- `MOCA_MEDICAL_INSURANCE`

---

### FF_USER_COLUMNS_VL (UDT Columns)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `USER_COLUMN_ID` | NUMBER | Primary key | 300000001234567 |
| `USER_TABLE_ID` | NUMBER | Which table | 300000001234567 |
| `BASE_USER_COLUMN_NAME` | VARCHAR2(80) | Column name | 'ECONOMY', 'BUSINESS', 'FIRST' |

**Common Columns:**
- Airfare: `ECONOMY`, `BUSINESS`, `FIRST` (class)
- Education: `MOCA`, `PMO`, `UGMO`, etc. (entity codes)

---

### FF_USER_ROWS_VL (UDT Rows)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `USER_ROW_ID` | NUMBER | Primary key | 300000001234567 |
| `USER_TABLE_ID` | NUMBER | Which table | 300000001234567 |
| `ROW_NAME` | VARCHAR2(240) | Row name | 'DUBAI', 'LONDON', 'GRADE_10' |

**Common Rows:**
- Airfare: `DUBAI`, `LONDON`, `NEW YORK`, etc. (destinations)
- Education: `GRADE_10`, `GRADE_11`, etc. (grade names)

---

### FF_USER_COLUMN_INSTANCES_F (UDT Values)

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `USER_COLUMN_ID` | NUMBER | Which column | 300000001234567 |
| `USER_ROW_ID` | NUMBER | Which row | 300000001234567 |
| `VALUE` | NUMBER | The value | 2500.00 |
| `EFFECTIVE_START_DATE` | DATE | Effective from | 01-JAN-2024 |
| `EFFECTIVE_END_DATE` | DATE | Effective to | 31-DEC-4712 |

**4-Table Join Pattern:**
```sql
SELECT
    FUTV.BASE_USER_TABLE_NAME TABLE_NAME,
    FUCV.BASE_USER_COLUMN_NAME COLUMN_NAME,
    FURV.ROW_NAME ROW_NAME,
    FUCIF.VALUE VALUE
FROM
    FF_USER_TABLES_VL FUTV,
    FF_USER_COLUMNS_VL FUCV,
    FF_USER_ROWS_VL FURV,
    FF_USER_COLUMN_INSTANCES_F FUCIF
WHERE
    FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
    AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
    AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
    AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
    AND FUTV.BASE_USER_TABLE_NAME = :TABLE_NAME
    AND FUCV.BASE_USER_COLUMN_NAME = :COLUMN_NAME
    AND FURV.ROW_NAME = :ROW_NAME
    AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE;
```

---

## 6. SUPPORTING TABLES

### IRC_SOURCE_TRACKING (Recruitment Sources)

| Column | Type | Description |
|--------|------|-------------|
| `SOURCE_TRACKING_ID` | NUMBER | Primary key |
| `SUBMISSION_ID` | NUMBER | Which submission |
| `CANDIDATE_NUMBER` | VARCHAR2 | Candidate number |
| `RECRUITER_ID` | NUMBER | Recruiter |
| `DIMENSION_ID` | NUMBER | Source dimension |
| `SOURCE_LEVEL` | VARCHAR2(30) | Source level |

---

### IRC_DIMENSION_DEF_B (Source Dimensions)

| Column | Type | Description |
|--------|------|-------------|
| `DIMENSION_ID` | NUMBER | Primary key |
| `SOURCE_URL_VALUE` | VARCHAR2 | Source name/URL |
| `SOURCE_MEDIUM` | VARCHAR2(30) | Medium code |

**Pattern:**
```sql
FROM
    IRC_SOURCE_TRACKING ST,
    IRC_DIMENSION_DEF_B DIM,
    FND_LOOKUP_VALUES_VL FLV
WHERE
    ST.DIMENSION_ID = DIM.DIMENSION_ID
    AND DIM.SOURCE_MEDIUM = FLV.LOOKUP_CODE
    AND FLV.LOOKUP_TYPE = 'ORA_IRC_SOURCE_TRACKING_MEDIUM';
```

---

### IRC_GEO_HIER_NODES (Geography Hierarchy)

| Column | Type | Description |
|--------|------|-------------|
| `GEOGRAPHY_NODE_ID` | NUMBER | Primary key |
| `GEOGRAPHY_ID` | NUMBER | Geography |

**Links to HZ_GEOGRAPHIES:**
```sql
FROM
    IRC_REQUISITIONS_VL REQ,
    IRC_GEO_HIER_NODES IGEO,
    HZ_GEOGRAPHIES HGEO
WHERE
    REQ.GEOGRAPHY_NODE_ID = IGEO.GEOGRAPHY_NODE_ID
    AND IGEO.GEOGRAPHY_ID = HGEO.GEOGRAPHY_ID;
```

---

## 7. TABLE RELATIONSHIP DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                    RECRUITING LIFECYCLE                          │
└─────────────────────────────────────────────────────────────────┘

IRC_REQUISITIONS_VL (Job Opening)
    │
    │ REQUISITION_ID
    ↓
IRC_SUBMISSIONS (Application)
    │
    │ PERSON_ID              │ SUBMISSION_ID
    ↓                        ↓
IRC_CANDIDATES          IRC_JA_EXTRA_INFO (Submission Flexfields)
    │                       - LOGISTICS
    │ PERSON_ID             - Medical_Health
    ↓                       - Screening
PER_ALL_PEOPLE_F           - Craft
    │
    │ PERSON_ID
    ↓
PER_PEOPLE_EXTRA_INFO (Person Flexfields)
    - Candidate Current Salary
    - Candidate Compensation Details
    - Candidate Personal Details
    - Candidate qualification

IRC_SUBMISSIONS
    │
    │ SUBMISSION_ID
    ↓
IRC_OFFERS (Offer)
    │
    │ ASSIGNMENT_OFFER_ID
    ↓
PER_ALL_ASSIGNMENTS_M (Type='O')
    │
    │ ASSIGNMENT_ID          │ PERSON_ID
    ↓                        ↓
CMP_SALARY              PER_PERIODS_OF_SERVICE
    │                       (Hire Confirmation)
    │ SALARY_ID
    ↓
CMP_SALARY_SIMPLE_COMPNTS
    (Component Breakdown)


┌─────────────────────────────────────────────────────────────────┐
│                    WORKFLOW TRACKING                             │
└─────────────────────────────────────────────────────────────────┘

IRC_SUBMISSIONS / IRC_OFFERS
    │
    │ CURRENT_PHASE_ID      │ CURRENT_STATE_ID
    ↓                       ↓
IRC_PHASES_VL           IRC_STATES_VL
    (High-level)            (Detailed)


┌─────────────────────────────────────────────────────────────────┐
│                    SOURCE TRACKING                               │
└─────────────────────────────────────────────────────────────────┘

IRC_SUBMISSIONS
    │
    │ SUBMISSION_ID
    ↓
IRC_SOURCE_TRACKING
    │
    │ DIMENSION_ID
    ↓
IRC_DIMENSION_DEF_B
    │
    │ SOURCE_MEDIUM
    ↓
FND_LOOKUP_VALUES_VL
    (Source Medium Names)


┌─────────────────────────────────────────────────────────────────┐
│                    UDT ALLOWANCE RATES                           │
└─────────────────────────────────────────────────────────────────┘

FF_USER_TABLES_VL (e.g., AIRFARE_ALLOWANCE_ADULT)
    │
    │ USER_TABLE_ID
    ├───────────────────────────┬─────────────────────────┐
    ↓                           ↓                         ↓
FF_USER_COLUMNS_VL    FF_USER_ROWS_VL        FF_USER_COLUMN_INSTANCES_F
    (e.g., BUSINESS)      (e.g., DUBAI)           (VALUE: 2500.00)
    │                     │                       │
    │ USER_COLUMN_ID      │ USER_ROW_ID          │ VALUE
    └─────────────────────┴─────────────────────→ 
```

---

## 8. COLUMN DATA TYPES & CONSTRAINTS

### Key ID Columns (NUMBER Type)

| Column | Range | Notes |
|--------|-------|-------|
| `REQUISITION_ID` | 15 digits | 300000001234567 |
| `SUBMISSION_ID` | 15 digits | 300000001234567 |
| `OFFER_ID` | 15 digits | 300000001234567 |
| `PERSON_ID` | 15 digits | 300000001234567 |
| `ASSIGNMENT_ID` | 15 digits | 300000001234567 |

### Key Code Columns (VARCHAR2 Type)

| Column | Length | Values |
|--------|--------|--------|
| `ASSIGNMENT_TYPE` | 1 | 'O', 'E', 'C', 'P', 'N' |
| `ACTIVE_FLAG` | 1 | 'Y', 'N' |
| `EFFECTIVE_LATEST_CHANGE` | 1 | 'Y', 'N' |
| `INTERNAL_FLAG` | 1 | 'Y', 'N' |
| `WORKER_TYPE_CODE` | 30 | 'E', 'C' |
| `NAME_TYPE` | 30 | 'GLOBAL', 'AE' |
| `LANGUAGE` | 4 | 'US', 'AR' |

### Date Columns (DATE Type)

| Column | Nullable | Default |
|--------|----------|---------|
| `EFFECTIVE_START_DATE` | No | |
| `EFFECTIVE_END_DATE` | No | 31-DEC-4712 |
| `SUBMISSION_DATE` | No | |
| `OPEN_DATE` | No | |
| `CLOSE_DATE` | Yes | NULL (if still open) |
| `EXTENDED_DATE` | Yes | NULL (if not extended) |
| `ACCEPTED_DATE` | Yes | NULL (if not accepted) |

---

## 🎯 QUICK REFERENCE CARD

### Most Common Joins (Copy-Paste)

**Requisition → Submission:**
```sql
WHERE REQ.REQUISITION_ID = SUB.REQUISITION_ID AND SUB.ACTIVE_FLAG = 'Y'
```

**Submission → Candidate:**
```sql
WHERE SUB.PERSON_ID = CAND.PERSON_ID
```

**Submission → Offer:**
```sql
WHERE SUB.SUBMISSION_ID = OFFER.SUBMISSION_ID
```

**Offer → Assignment (CRITICAL):**
```sql
WHERE OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
AND ASG.ASSIGNMENT_TYPE = 'O'
AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
```

**Offer → Salary:**
```sql
WHERE ASG.ASSIGNMENT_ID = CSA.ASSIGNMENT_ID
AND CSA.DATE_FROM <= SYSDATE AND CSA.DATE_TO >= SYSDATE
```

**Candidate → Person Name:**
```sql
WHERE CAND.PERSON_ID = PPNF.PERSON_ID
AND PPNF.NAME_TYPE = 'GLOBAL'
AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
```

---

### Most Common Filters (Copy-Paste)

**Active Submissions:**
```sql
AND SUB.ACTIVE_FLAG = 'Y'
```

**Offer Assignments:**
```sql
AND ASG.ASSIGNMENT_TYPE = 'O'
AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
```

**Translation Tables:**
```sql
AND TABLE_TL.LANGUAGE = USERENV('LANG')
```

**Date-Tracked Tables:**
```sql
AND TRUNC(SYSDATE) BETWEEN TABLE.EFFECTIVE_START_DATE AND TABLE.EFFECTIVE_END_DATE
```

**Latest Salary Component:**
```sql
AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
    SELECT MAX(TRUNC(LAST_UPDATE_DATE))
    FROM CMP_SALARY_SIMPLE_COMPNTS
    WHERE PERSON_ID = CSSC.PERSON_ID
)
```

---

**END OF TABLE REFERENCE**

**Status:** Production-Ready  
**Last Updated:** 07-Jan-2026  
**Coverage:** Complete ORC schema  
**Usage:** Quick reference during development
