# Oracle Recruiting Cloud (ORC) - Complete Repository

**Module:** Oracle Recruiting Cloud (ORC/IRC)  
**Tag:** `#HCM #ORC #IRC #Recruiting #Repository`  
**Purpose:** Complete table reference, CTE patterns, and advanced scenarios  
**Last Updated:** 07-Jan-2026  
**Version:** 1.0 (Consolidated)  
**Status:** Production-Ready  
**Source Files:** ORC_TABLE_REFERENCE_07-01-26.md + ORC_ADVANCED_PATTERNS_07-01-26.md

---

## PART 1: TABLE REFERENCE

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


---

## PART 2: ADVANCED PATTERNS


# Oracle Recruiting Cloud (ORC) - Advanced Patterns & Scenarios

**Module:** Oracle Recruiting Cloud (ORC/IRC)  
**Purpose:** Advanced patterns, edge cases, and complex scenarios  
**Date:** 07-Jan-2026  
**Status:** Production-Ready

---

## 📋 TABLE OF CONTENTS

1. [Complex Compensation Calculations](#complex-compensation-calculations)
2. [Pre-Employment Workflow Management](#pre-employment-workflow-management)
3. [Advanced Workflow Status Logic](#advanced-workflow-status-logic)
4. [Multi-Entity Compensation Rules](#multi-entity-compensation-rules)
5. [Candidate Journey Analytics](#candidate-journey-analytics)
6. [Offer Comparison & Negotiation](#offer-comparison--negotiation)
7. [Assignment Transition Tracking](#assignment-transition-tracking)
8. [Edge Cases & Solutions](#edge-cases--solutions)

---

## 1. 💰 COMPLEX COMPENSATION CALCULATIONS

### Complete Offer Compensation Package

**Scenario:** Calculate total compensation including base salary, allowances, and benefits

```sql
WITH SALARY_COMPONENTS AS (
    -- Get salary components from CMP tables
    SELECT
        CSSC.PERSON_ID,
        SUM(CASE WHEN FLV.MEANING = 'Basic salary' THEN CSSC.AMOUNT ELSE 0 END) BASIC_SALARY,
        SUM(CASE WHEN FLV.MEANING = 'Allowance' THEN CSSC.AMOUNT ELSE 0 END) MONTHLY_ALLOWANCES,
        SUM(CASE WHEN FLV.MEANING = 'Gross Salary' THEN CSSC.AMOUNT ELSE 0 END) GROSS_SALARY
    FROM
        CMP_SALARY_SIMPLE_COMPNTS CSSC,
        PER_ALL_ASSIGNMENTS_M ASG,
        FND_LOOKUP_VALUES FLV
    WHERE
        ASG.ASSIGNMENT_ID = CSSC.ASSIGNMENT_ID
        AND ASG.ASSIGNMENT_TYPE = 'O'
        AND ASG.PRIMARY_ASSIGNMENT_FLAG = 'Y'
        AND CSSC.COMPONENT_CODE = FLV.LOOKUP_CODE
        AND FLV.LOOKUP_TYPE = 'ORA_CMP_SIMPLE_SALARY_COMPS'
        AND FLV.LANGUAGE = 'US'
        AND CSSC.COMPONENT_CODE NOT IN ('ORA_OVERALL_SALARY')
        AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
        AND TRUNC(SYSDATE) BETWEEN CSSC.SALARY_DATE_FROM AND CSSC.SALARY_DATE_TO
        AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
            SELECT MAX(TRUNC(LAST_UPDATE_DATE))
            FROM CMP_SALARY_SIMPLE_COMPNTS
            WHERE PERSON_ID = CSSC.PERSON_ID
        )
    GROUP BY CSSC.PERSON_ID
),
AIRFARE_DETAILS AS (
    -- Get airfare details from person flexfield
    SELECT
        PERSON_ID,
        PEI_INFORMATION1 AIRFARE_CLASS,
        PEI_INFORMATION2 DESTINATION,
        NVL(PEI_INFORMATION_NUMBER1, 0) ADULT_COUNT,
        NVL(PEI_INFORMATION_NUMBER2, 0) CHILD_COUNT,
        NVL(PEI_INFORMATION_NUMBER3, 0) INFANT_COUNT
    FROM PER_PEOPLE_EXTRA_INFO
    WHERE INFORMATION_TYPE = 'Candidate Compensation Details'
),
AIRFARE_RATES AS (
    -- Get airfare rates from UDT
    SELECT
        FUCV.BASE_USER_COLUMN_NAME AIRFARE_CLASS,
        FURV.ROW_NAME DESTINATION,
        'ADULT' PASSENGER_TYPE,
        FUCIF.VALUE RATE
    FROM
        FF_USER_TABLES_VL FUTV,
        FF_USER_COLUMNS_VL FUCV,
        FF_USER_ROWS_VL FURV,
        FF_USER_COLUMN_INSTANCES_F FUCIF
    WHERE
        FUTV.BASE_USER_TABLE_NAME = 'AIRFARE_ALLOWANCE_ADULT'
        AND FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
        AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
        AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
        AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
        AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE
    
    UNION ALL
    
    SELECT
        FUCV.BASE_USER_COLUMN_NAME,
        FURV.ROW_NAME,
        'CHILD',
        FUCIF.VALUE
    FROM
        FF_USER_TABLES_VL FUTV,
        FF_USER_COLUMNS_VL FUCV,
        FF_USER_ROWS_VL FURV,
        FF_USER_COLUMN_INSTANCES_F FUCIF
    WHERE
        FUTV.BASE_USER_TABLE_NAME = 'AIRFARE_ALLOWANCE_CHILD'
        AND FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
        AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
        AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
        AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
        AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE
    
    UNION ALL
    
    SELECT
        FUCV.BASE_USER_COLUMN_NAME,
        FURV.ROW_NAME,
        'INFANT',
        FUCIF.VALUE
    FROM
        FF_USER_TABLES_VL FUTV,
        FF_USER_COLUMNS_VL FUCV,
        FF_USER_ROWS_VL FURV,
        FF_USER_COLUMN_INSTANCES_F FUCIF
    WHERE
        FUTV.BASE_USER_TABLE_NAME = 'AIRFARE_ALLOWANCE_INFANT'
        AND FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
        AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
        AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
        AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
        AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE
),
EDUCATION_RATES AS (
    -- Get education allowance rates by entity and grade
    SELECT
        FUCV.BASE_USER_COLUMN_NAME ENTITY_CODE,
        FURV.ROW_NAME GRADE_NAME,
        FUCIF.VALUE EDU_RATE_PER_CHILD,
        
        -- Entity name mapping
        CASE
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'MOCA' THEN 'Ministry of Cabinet Affairs'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'PMO' THEN 'Prime Minister''s Office'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'UGMO' THEN 'UAE Government Media Office'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'FCSC' THEN 'Federal Competitive Statistics Center'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'PDO' THEN 'Public Diplomacy Office'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'GSOC' THEN 'General Secretariat Of the Cabinet'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'MSAIDERWA' THEN 'Minister of State for Artificial Intelligence, Digital Economy and Remote Work Applications'
            WHEN FUCV.BASE_USER_COLUMN_NAME = 'MSGDF' THEN 'Minister of State for Government Development and the Future'
        END ENTITY_NAME
    FROM
        FF_USER_TABLES_VL FUTV,
        FF_USER_COLUMNS_VL FUCV,
        FF_USER_ROWS_VL FURV,
        FF_USER_COLUMN_INSTANCES_F FUCIF
    WHERE
        FUTV.BASE_USER_TABLE_NAME = 'MOCA_EDUCATIONAL_ALLOWANCE'
        AND FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
        AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
        AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
        AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
        AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE
)
SELECT
    OFFER.OFFER_ID,
    OFFER.OFFER_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    GRADE.NAME GRADE,
    ENTITY.NAME LEGAL_ENTITY,
    
    -- Monthly Base Compensation
    NVL(SC.BASIC_SALARY, 0) BASIC_SALARY,
    NVL(SC.MONTHLY_ALLOWANCES, 0) MONTHLY_ALLOWANCES,
    NVL(SC.GROSS_SALARY, 0) GROSS_SALARY,
    
    -- Airfare Allowance (Annual)
    (NVL(AD.ADULT_COUNT, 0) * NVL(ADULT_RATE.RATE, 0)) ADULT_AIRFARE,
    (NVL(AD.CHILD_COUNT, 0) * NVL(CHILD_RATE.RATE, 0)) CHILD_AIRFARE,
    (NVL(AD.INFANT_COUNT, 0) * NVL(INFANT_RATE.RATE, 0)) INFANT_AIRFARE,
    
    (NVL(AD.ADULT_COUNT, 0) * NVL(ADULT_RATE.RATE, 0) +
     NVL(AD.CHILD_COUNT, 0) * NVL(CHILD_RATE.RATE, 0) +
     NVL(AD.INFANT_COUNT, 0) * NVL(INFANT_RATE.RATE, 0)) TOTAL_AIRFARE_ANNUAL,
    
    -- Airfare Monthly Equivalent
    ROUND((NVL(AD.ADULT_COUNT, 0) * NVL(ADULT_RATE.RATE, 0) +
           NVL(AD.CHILD_COUNT, 0) * NVL(CHILD_RATE.RATE, 0) +
           NVL(AD.INFANT_COUNT, 0) * NVL(INFANT_RATE.RATE, 0)) / 12) AIRFARE_MONTHLY,
    
    -- Education Allowance (Annual)
    (NVL(AD.CHILD_COUNT, 0) * NVL(EDU.EDU_RATE_PER_CHILD, 0)) EDUCATION_ANNUAL,
    
    -- Education Monthly Equivalent
    ROUND((NVL(AD.CHILD_COUNT, 0) * NVL(EDU.EDU_RATE_PER_CHILD, 0)) / 12) EDUCATION_MONTHLY,
    
    -- Total Monthly Compensation
    (NVL(SC.GROSS_SALARY, 0) +
     ROUND((NVL(AD.ADULT_COUNT, 0) * NVL(ADULT_RATE.RATE, 0) +
            NVL(AD.CHILD_COUNT, 0) * NVL(CHILD_RATE.RATE, 0) +
            NVL(AD.INFANT_COUNT, 0) * NVL(INFANT_RATE.RATE, 0)) / 12) +
     ROUND((NVL(AD.CHILD_COUNT, 0) * NVL(EDU.EDU_RATE_PER_CHILD, 0)) / 12)) TOTAL_MONTHLY_COMP
    
FROM
    IRC_OFFERS OFFER,
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_M ASG,
    PER_GRADES_F_VL GRADE,
    HR_ALL_ORGANIZATION_UNITS_F_VL ENTITY,
    SALARY_COMPONENTS SC,
    AIRFARE_DETAILS AD,
    AIRFARE_RATES ADULT_RATE,
    AIRFARE_RATES CHILD_RATE,
    AIRFARE_RATES INFANT_RATE,
    EDUCATION_RATES EDU
WHERE
    OFFER.SUBMISSION_ID = SUB.SUBMISSION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND ASG.GRADE_ID = GRADE.GRADE_ID
    AND ASG.LEGAL_ENTITY_ID = ENTITY.ORGANIZATION_ID
    
    AND OFFER.PERSON_ID = SC.PERSON_ID(+)
    AND OFFER.PERSON_ID = AD.PERSON_ID(+)
    
    -- Match airfare rates
    AND UPPER(AD.AIRFARE_CLASS) = UPPER(ADULT_RATE.AIRFARE_CLASS(+))
    AND UPPER(AD.DESTINATION) = UPPER(ADULT_RATE.DESTINATION(+))
    AND ADULT_RATE.PASSENGER_TYPE(+) = 'ADULT'
    
    AND UPPER(AD.AIRFARE_CLASS) = UPPER(CHILD_RATE.AIRFARE_CLASS(+))
    AND UPPER(AD.DESTINATION) = UPPER(CHILD_RATE.DESTINATION(+))
    AND CHILD_RATE.PASSENGER_TYPE(+) = 'CHILD'
    
    AND UPPER(AD.AIRFARE_CLASS) = UPPER(INFANT_RATE.AIRFARE_CLASS(+))
    AND UPPER(AD.DESTINATION) = UPPER(INFANT_RATE.DESTINATION(+))
    AND INFANT_RATE.PASSENGER_TYPE(+) = 'INFANT'
    
    -- Match education rates
    AND GRADE.NAME = EDU.GRADE_NAME(+)
    AND UPPER(ENTITY.NAME) = UPPER(EDU.ENTITY_NAME(+))
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN GRADE.EFFECTIVE_START_DATE AND GRADE.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ENTITY.EFFECTIVE_START_DATE AND ENTITY.EFFECTIVE_END_DATE
    
ORDER BY OFFER.OFFER_NUMBER;
```

**Business Rules:**
1. Airfare allowance is ANNUAL (divide by 12 for monthly)
2. Education allowance is ANNUAL (divide by 12 for monthly)
3. Rates vary by:
   - Airfare: Destination + Class + Passenger Type
   - Education: Entity + Grade

---

## 2. 📋 PRE-EMPLOYMENT WORKFLOW MANAGEMENT

### Complete Pre-Employment Status Tracking

**Scenario:** Track all pre-employment activities with completion percentages

```sql
WITH PRE_EMPLOYMENT_ACTIVITIES AS (
    SELECT
        SUBMISSION_ID,
        
        -- Logistics
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'LOGISTICS'
            THEN PEI_INFORMATION15 END) LOGISTICS_OWNER,
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'XX_LOGISTICS'
            THEN PEI_INFORMATION_DATE3 END) LOGISTICS_COMPLETE_DATE,
        CASE WHEN MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'XX_LOGISTICS'
            THEN PEI_INFORMATION_DATE3 END) IS NOT NULL THEN 1 ELSE 0 END LOGISTICS_COMPLETE,
        
        -- Medical/Health
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Medical_Health'
            AND PEI_INFORMATION1 = 'Health (Internal)'
            THEN PEI_INFORMATION8 END) MEDICAL_RESULT,
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Medical_Health'
            AND PEI_INFORMATION1 = 'Health (Internal)'
            THEN PEI_INFORMATION_DATE3 END) MEDICAL_COMPLETE_DATE,
        CASE WHEN MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Medical_Health'
            THEN PEI_INFORMATION_DATE3 END) IS NOT NULL THEN 1 ELSE 0 END MEDICAL_COMPLETE,
        
        -- Screening
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Screening'
            THEN PEI_INFORMATION20 END) SCREENING_OWNER,
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'xxx'
            THEN PEI_INFORMATION_DATE15 END) SCREENING_COMPLETE_DATE,
        CASE WHEN MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'xxx'
            THEN PEI_INFORMATION_DATE15 END) IS NOT NULL THEN 1 ELSE 0 END SCREENING_COMPLETE,
        
        -- Craft/Mobilisation
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Craft'
            THEN PEI_INFORMATION_DATE2 END) CRAFT_MOBILISATION_DATE,
        CASE WHEN MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Craft'
            THEN PEI_INFORMATION_DATE2 END) IS NOT NULL THEN 1 ELSE 0 END CRAFT_COMPLETE
        
    FROM IRC_JA_EXTRA_INFO
    GROUP BY SUBMISSION_ID
)
SELECT
    REQ.REQUISITION_NUMBER,
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    JOB.NAME JOB_TITLE,
    
    -- Offer Details
    OFFER.OFFER_NUMBER,
    TO_CHAR(OFFER.ACCEPTED_DATE, 'DD/MM/YYYY') OFFER_ACCEPTED_DATE,
    TO_CHAR(ASG.PROJECTED_START_DATE, 'DD/MM/YYYY') EXPECTED_START_DATE,
    
    -- Pre-Employment Activities
    PEA.LOGISTICS_OWNER,
    TO_CHAR(PEA.LOGISTICS_COMPLETE_DATE, 'DD/MM/YYYY') LOGISTICS_COMPLETE_DATE,
    CASE WHEN PEA.LOGISTICS_COMPLETE = 1 THEN '✓' ELSE '✗' END LOGISTICS_STATUS,
    
    PEA.MEDICAL_RESULT,
    TO_CHAR(PEA.MEDICAL_COMPLETE_DATE, 'DD/MM/YYYY') MEDICAL_COMPLETE_DATE,
    CASE WHEN PEA.MEDICAL_COMPLETE = 1 THEN '✓' ELSE '✗' END MEDICAL_STATUS,
    
    PEA.SCREENING_OWNER,
    TO_CHAR(PEA.SCREENING_COMPLETE_DATE, 'DD/MM/YYYY') SCREENING_COMPLETE_DATE,
    CASE WHEN PEA.SCREENING_COMPLETE = 1 THEN '✓' ELSE '✗' END SCREENING_STATUS,
    
    TO_CHAR(PEA.CRAFT_MOBILISATION_DATE, 'DD/MM/YYYY') CRAFT_MOBILISATION_DATE,
    CASE WHEN PEA.CRAFT_COMPLETE = 1 THEN '✓' ELSE '✗' END CRAFT_STATUS,
    
    -- Overall Completion
    (PEA.LOGISTICS_COMPLETE + PEA.MEDICAL_COMPLETE + PEA.SCREENING_COMPLETE + PEA.CRAFT_COMPLETE) ACTIVITIES_COMPLETED,
    4 TOTAL_ACTIVITIES,
    ROUND(((PEA.LOGISTICS_COMPLETE + PEA.MEDICAL_COMPLETE + PEA.SCREENING_COMPLETE + PEA.CRAFT_COMPLETE) / 4) * 100, 2) COMPLETION_PCT,
    
    -- Overall Status
    CASE
        WHEN (PEA.LOGISTICS_COMPLETE + PEA.MEDICAL_COMPLETE + PEA.SCREENING_COMPLETE + PEA.CRAFT_COMPLETE) = 4
        THEN 'All Complete - Ready to Hire'
        WHEN (PEA.LOGISTICS_COMPLETE + PEA.MEDICAL_COMPLETE + PEA.SCREENING_COMPLETE + PEA.CRAFT_COMPLETE) >= 2
        THEN 'In Progress'
        ELSE 'Just Started'
    END OVERALL_STATUS
    
FROM
    IRC_REQUISITIONS_VL REQ,
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    IRC_OFFERS OFFER,
    PER_ALL_ASSIGNMENTS_M ASG,
    PER_JOBS_F_VL JOB,
    PRE_EMPLOYMENT_ACTIVITIES PEA
WHERE
    REQ.REQUISITION_ID = SUB.REQUISITION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND SUB.SUBMISSION_ID = OFFER.SUBMISSION_ID
    AND SUB.SUBMISSION_ID = PEA.SUBMISSION_ID(+)
    
    AND OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND ASG.JOB_ID = JOB.JOB_ID
    
    -- Only accepted offers
    AND OFFER.ACCEPTED_DATE IS NOT NULL
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN JOB.EFFECTIVE_START_DATE AND JOB.EFFECTIVE_END_DATE
    
ORDER BY REQ.REQUISITION_NUMBER, COMPLETION_PCT DESC;
```

**Business Rules:**
- All 4 activities must be complete before hire
- Track completion percentage
- Escalate if not complete 2 weeks before start date

---

## 3. 🔄 ADVANCED WORKFLOW STATUS LOGIC

### Time-Based Status Alerts

**Scenario:** Generate alerts based on workflow status and time elapsed

```sql
WITH SUBMISSION_TIMELINE AS (
    SELECT
        SUB.SUBMISSION_ID,
        SUB.PERSON_ID,
        SUB.REQUISITION_ID,
        SUB.SUBMISSION_DATE,
        STATE.NAME CURRENT_STATUS,
        
        -- Days in current status
        TRUNC(SYSDATE) - TRUNC(SUB.SUBMISSION_DATE) DAYS_SINCE_SUBMISSION,
        
        -- Days to expected start
        CASE
            WHEN OFFER.OFFER_ID IS NOT NULL
            THEN TRUNC(ASG.PROJECTED_START_DATE) - TRUNC(SYSDATE)
            ELSE NULL
        END DAYS_TO_START
        
    FROM
        IRC_SUBMISSIONS SUB,
        IRC_STATES_VL STATE,
        IRC_OFFERS OFFER,
        PER_ALL_ASSIGNMENTS_M ASG
    WHERE
        SUB.CURRENT_STATE_ID = STATE.STATE_ID
        AND SUB.SUBMISSION_ID = OFFER.SUBMISSION_ID(+)
        AND OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID(+)
        AND ASG.ASSIGNMENT_TYPE(+) = 'O'
        AND ASG.EFFECTIVE_LATEST_CHANGE(+) = 'Y'
        AND SUB.ACTIVE_FLAG = 'Y'
        AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE(+) AND ASG.EFFECTIVE_END_DATE(+)
)
SELECT
    REQ.REQUISITION_NUMBER,
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    TL.CURRENT_STATUS,
    TL.DAYS_SINCE_SUBMISSION,
    TL.DAYS_TO_START,
    
    -- Alert Logic
    CASE
        -- Stuck in review
        WHEN TL.CURRENT_STATUS IN ('To be Reviewed', 'Shared with Hiring Manager')
         AND TL.DAYS_SINCE_SUBMISSION > 7
        THEN 'Alert: Pending review > 7 days'
        
        -- Offer not extended
        WHEN TL.CURRENT_STATUS = 'Approved'
         AND TL.DAYS_SINCE_SUBMISSION > 3
        THEN 'Alert: Approved offer not extended > 3 days'
        
        -- Offer not accepted
        WHEN TL.CURRENT_STATUS = 'Extended'
         AND TL.DAYS_SINCE_SUBMISSION > 14
        THEN 'Alert: Offer extended > 14 days, not accepted'
        
        -- Pre-employment pending
        WHEN TL.CURRENT_STATUS = 'Accepted'
         AND TL.DAYS_TO_START < 14
        THEN 'Alert: Pre-employment activities must complete in < 14 days'
        
        ELSE 'No Alert'
    END ALERT_MESSAGE,
    
    -- Priority
    CASE
        WHEN TL.DAYS_TO_START < 7 AND TL.CURRENT_STATUS = 'Accepted' THEN 'HIGH'
        WHEN TL.DAYS_TO_START < 14 AND TL.CURRENT_STATUS = 'Accepted' THEN 'MEDIUM'
        WHEN TL.DAYS_SINCE_SUBMISSION > 30 THEN 'HIGH'
        WHEN TL.DAYS_SINCE_SUBMISSION > 14 THEN 'MEDIUM'
        ELSE 'LOW'
    END ALERT_PRIORITY
    
FROM
    SUBMISSION_TIMELINE TL,
    IRC_REQUISITIONS_VL REQ,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF
WHERE
    TL.REQUISITION_ID = REQ.REQUISITION_ID
    AND TL.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    
    -- Only show alerts
    AND (ALERT_MESSAGE <> 'No Alert' OR :P_SHOW_ALL = 'Y')
    
ORDER BY ALERT_PRIORITY, TL.DAYS_SINCE_SUBMISSION DESC;
```

**Parameters:**
- `:P_SHOW_ALL` - 'Y' to show all, 'N' for alerts only

---

## 4. 🏢 MULTI-ENTITY COMPENSATION RULES

### Entity-Specific Allowance Rules

**Scenario:** Different entities have different compensation rules

```sql
WITH ENTITY_MAPPING AS (
    -- Map entity names to codes
    SELECT
        ORGANIZATION_ID,
        NAME ENTITY_NAME,
        CASE
            WHEN NAME = 'Ministry of Cabinet Affairs' THEN 'MOCA'
            WHEN NAME LIKE 'Prime Minister%' THEN 'PMO'
            WHEN NAME = 'UAE Government Media Office' THEN 'UGMO'
            WHEN NAME = 'Federal Competitive Statistics Center' THEN 'FCSC'
            WHEN NAME = 'Public Diplomacy Office' THEN 'PDO'
            WHEN NAME = 'General Secretariat Of the Cabinet' THEN 'GSOC'
            WHEN NAME = 'Minister of State for Artificial Intelligence, Digital Economy and Remote Work Applications' THEN 'MSAIDERWA'
            WHEN NAME = 'Minister of State for Government Development and the Future' THEN 'MSGDF'
        END ENTITY_CODE
    FROM HR_ALL_ORGANIZATION_UNITS_F_VL
    WHERE TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
),
MEDICAL_INSURANCE_RATES AS (
    -- Medical insurance by grade
    SELECT
        FURV.ROW_NAME GRADE_NAME,
        FUCIF.VALUE MEDICAL_INSURANCE_VALUE
    FROM
        FF_USER_TABLES_VL FUTV,
        FF_USER_COLUMNS_VL FUCV,
        FF_USER_ROWS_VL FURV,
        FF_USER_COLUMN_INSTANCES_F FUCIF
    WHERE
        FUTV.BASE_USER_TABLE_NAME = 'MOCA_MEDICAL_INSURANCE'
        AND FUCV.BASE_USER_COLUMN_NAME = 'MEDICAL_INSURANCE'
        AND FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
        AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
        AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
        AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
        AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE
),
EDUCATION_RATES AS (
    -- Education allowance by entity and grade
    SELECT
        FUCV.BASE_USER_COLUMN_NAME ENTITY_CODE,
        FURV.ROW_NAME GRADE_NAME,
        FUCIF.VALUE EDU_RATE_PER_CHILD
    FROM
        FF_USER_TABLES_VL FUTV,
        FF_USER_COLUMNS_VL FUCV,
        FF_USER_ROWS_VL FURV,
        FF_USER_COLUMN_INSTANCES_F FUCIF
    WHERE
        FUTV.BASE_USER_TABLE_NAME = 'MOCA_EDUCATIONAL_ALLOWANCE'
        AND FUTV.USER_TABLE_ID = FUCV.USER_TABLE_ID
        AND FUTV.USER_TABLE_ID = FURV.USER_TABLE_ID
        AND FUCV.USER_COLUMN_ID = FUCIF.USER_COLUMN_ID
        AND FURV.USER_ROW_ID = FUCIF.USER_ROW_ID
        AND TRUNC(SYSDATE) BETWEEN FUCIF.EFFECTIVE_START_DATE AND FUCIF.EFFECTIVE_END_DATE
)
SELECT
    OFFER.OFFER_ID,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    GRADE.NAME GRADE,
    EM.ENTITY_NAME,
    EM.ENTITY_CODE,
    
    -- Medical Insurance
    MED.MEDICAL_INSURANCE_VALUE,
    CASE
        WHEN MED.MEDICAL_INSURANCE_VALUE IS NOT NULL THEN 'Eligible'
        ELSE 'Not Eligible'
    END MEDICAL_INSURANCE_STATUS,
    
    -- Education Allowance
    EDU.EDU_RATE_PER_CHILD,
    NVL(CHILD_COUNT.CHILD_COUNT, 0) CHILD_COUNT,
    (NVL(CHILD_COUNT.CHILD_COUNT, 0) * NVL(EDU.EDU_RATE_PER_CHILD, 0)) EDUCATION_ANNUAL,
    ROUND((NVL(CHILD_COUNT.CHILD_COUNT, 0) * NVL(EDU.EDU_RATE_PER_CHILD, 0)) / 12) EDUCATION_MONTHLY,
    CASE
        WHEN (NVL(CHILD_COUNT.CHILD_COUNT, 0) * NVL(EDU.EDU_RATE_PER_CHILD, 0)) > 0
        THEN 'Eligible'
        ELSE 'Not Eligible'
    END EDUCATION_STATUS
    
FROM
    IRC_OFFERS OFFER,
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_M ASG,
    PER_GRADES_F_VL GRADE,
    ENTITY_MAPPING EM,
    MEDICAL_INSURANCE_RATES MED,
    EDUCATION_RATES EDU,
    (SELECT PERSON_ID, PEI_INFORMATION_NUMBER2 CHILD_COUNT
     FROM PER_PEOPLE_EXTRA_INFO
     WHERE INFORMATION_TYPE = 'Candidate Compensation Details') CHILD_COUNT
WHERE
    OFFER.SUBMISSION_ID = SUB.SUBMISSION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND ASG.GRADE_ID = GRADE.GRADE_ID
    AND ASG.LEGAL_ENTITY_ID = EM.ORGANIZATION_ID
    
    AND GRADE.NAME = MED.GRADE_NAME(+)
    
    AND GRADE.NAME = EDU.GRADE_NAME(+)
    AND EM.ENTITY_CODE = EDU.ENTITY_CODE(+)
    
    AND OFFER.PERSON_ID = CHILD_COUNT.PERSON_ID(+)
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN GRADE.EFFECTIVE_START_DATE AND GRADE.EFFECTIVE_END_DATE
    
ORDER BY OFFER.OFFER_NUMBER;
```

---

## 5. 📊 CANDIDATE JOURNEY ANALYTICS

### Time-to-Hire Metrics

**Scenario:** Calculate time spent in each stage

```sql
SELECT
    REQ.REQUISITION_NUMBER,
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    
    -- Key Dates
    TO_CHAR(SUB.SUBMISSION_DATE, 'DD/MM/YYYY') SUBMISSION_DATE,
    TO_CHAR(OFFER.DRAFTED_DATE, 'DD/MM/YYYY') OFFER_DRAFTED_DATE,
    TO_CHAR(OFFER.APPROVED_DATE, 'DD/MM/YYYY') OFFER_APPROVED_DATE,
    TO_CHAR(OFFER.EXTENDED_DATE, 'DD/MM/YYYY') OFFER_EXTENDED_DATE,
    TO_CHAR(OFFER.ACCEPTED_DATE, 'DD/MM/YYYY') OFFER_ACCEPTED_DATE,
    TO_CHAR(OFFER.MOVE_TO_HR_DATE, 'DD/MM/YYYY') HIRE_DATE,
    TO_CHAR(PPOS.DATE_START, 'DD/MM/YYYY') ACTUAL_START_DATE,
    
    -- Time Metrics (in days)
    TRUNC(OFFER.DRAFTED_DATE) - TRUNC(SUB.SUBMISSION_DATE) DAYS_SUBMISSION_TO_OFFER_DRAFT,
    TRUNC(OFFER.APPROVED_DATE) - TRUNC(OFFER.DRAFTED_DATE) DAYS_DRAFT_TO_APPROVAL,
    TRUNC(OFFER.EXTENDED_DATE) - TRUNC(OFFER.APPROVED_DATE) DAYS_APPROVAL_TO_EXTENSION,
    TRUNC(OFFER.ACCEPTED_DATE) - TRUNC(OFFER.EXTENDED_DATE) DAYS_EXTENSION_TO_ACCEPTANCE,
    TRUNC(OFFER.MOVE_TO_HR_DATE) - TRUNC(OFFER.ACCEPTED_DATE) DAYS_ACCEPTANCE_TO_HIRE,
    
    -- Total Time-to-Hire
    TRUNC(PPOS.DATE_START) - TRUNC(SUB.SUBMISSION_DATE) TOTAL_TIME_TO_HIRE_DAYS,
    
    -- Benchmarks
    CASE
        WHEN TRUNC(PPOS.DATE_START) - TRUNC(SUB.SUBMISSION_DATE) <= 30 THEN 'Fast (<=30 days)'
        WHEN TRUNC(PPOS.DATE_START) - TRUNC(SUB.SUBMISSION_DATE) <= 60 THEN 'Average (31-60 days)'
        ELSE 'Slow (>60 days)'
    END TIME_TO_HIRE_RATING
    
FROM
    IRC_SUBMISSIONS SUB,
    IRC_REQUISITIONS_VL REQ,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    IRC_OFFERS OFFER,
    PER_ALL_ASSIGNMENTS_M ASG,
    PER_PERIODS_OF_SERVICE PPOS
WHERE
    SUB.REQUISITION_ID = REQ.REQUISITION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND SUB.SUBMISSION_ID = OFFER.SUBMISSION_ID
    
    AND OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND ASG.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
    
    -- Only hired candidates
    AND PPOS.DATE_START IS NOT NULL
    
    AND SUB.ACTIVE_FLAG = 'Y'
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
    
    -- Date range
    AND SUB.SUBMISSION_DATE >= :P_START_DATE
    AND PPOS.DATE_START <= :P_END_DATE
    
ORDER BY TOTAL_TIME_TO_HIRE_DAYS, REQ.REQUISITION_NUMBER;
```

**KPIs:**
- Average time-to-hire: Target ≤ 45 days
- Submission to offer: Target ≤ 21 days
- Offer to acceptance: Target ≤ 7 days
- Acceptance to hire: Target ≤ 14 days

---

## 6. 🔀 OFFER COMPARISON & NEGOTIATION

### Current vs Proposed Compensation Analysis

**Scenario:** Compare candidate's current package with proposed offer

```sql
WITH CURRENT_COMPENSATION AS (
    SELECT
        PERSON_ID,
        NVL(PEI_INFORMATION_NUMBER1, 0) CURRENT_MONTHLY,
        NVL(PEI_INFORMATION_NUMBER2, 0) CURRENT_TICKET_ANNUAL,
        NVL(PEI_INFORMATION_NUMBER3, 0) CURRENT_EDU_ANNUAL,
        ROUND(NVL(PEI_INFORMATION_NUMBER2, 0) / 12) CURRENT_TICKET_MONTHLY,
        ROUND(NVL(PEI_INFORMATION_NUMBER3, 0) / 12) CURRENT_EDU_MONTHLY,
        (NVL(PEI_INFORMATION_NUMBER1, 0) +
         ROUND(NVL(PEI_INFORMATION_NUMBER2, 0) / 12) +
         ROUND(NVL(PEI_INFORMATION_NUMBER3, 0) / 12)) CURRENT_TOTAL_MONTHLY
    FROM PER_PEOPLE_EXTRA_INFO
    WHERE INFORMATION_TYPE = 'Candidate Current Salary'
),
PROPOSED_COMPENSATION AS (
    -- Calculate proposed package (from earlier CTE)
    SELECT
        OFFER.PERSON_ID,
        NVL(SC.GROSS_SALARY, 0) PROPOSED_MONTHLY,
        ROUND((/* airfare calculation */) / 12) PROPOSED_TICKET_MONTHLY,
        ROUND((/* education calculation */) / 12) PROPOSED_EDU_MONTHLY,
        (NVL(SC.GROSS_SALARY, 0) +
         ROUND((/* airfare */) / 12) +
         ROUND((/* education */) / 12)) PROPOSED_TOTAL_MONTHLY
    FROM IRC_OFFERS OFFER
    -- ... joins ...
)
SELECT
    OFFER.OFFER_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    
    -- Current Package
    CUR.CURRENT_MONTHLY,
    CUR.CURRENT_TICKET_MONTHLY,
    CUR.CURRENT_EDU_MONTHLY,
    CUR.CURRENT_TOTAL_MONTHLY,
    
    -- Proposed Package
    PROP.PROPOSED_MONTHLY,
    PROP.PROPOSED_TICKET_MONTHLY,
    PROP.PROPOSED_EDU_MONTHLY,
    PROP.PROPOSED_TOTAL_MONTHLY,
    
    -- Differences
    (PROP.PROPOSED_MONTHLY - CUR.CURRENT_MONTHLY) DIFF_MONTHLY,
    (PROP.PROPOSED_TICKET_MONTHLY - CUR.CURRENT_TICKET_MONTHLY) DIFF_TICKET,
    (PROP.PROPOSED_EDU_MONTHLY - CUR.CURRENT_EDU_MONTHLY) DIFF_EDU,
    (PROP.PROPOSED_TOTAL_MONTHLY - CUR.CURRENT_TOTAL_MONTHLY) DIFF_TOTAL,
    
    -- Percentage Change
    ROUND(((PROP.PROPOSED_TOTAL_MONTHLY - CUR.CURRENT_TOTAL_MONTHLY) / 
           NULLIF(CUR.CURRENT_TOTAL_MONTHLY, 0)) * 100, 2) PCT_CHANGE,
    
    -- Comparison Indicators (for offer letter)
    CASE
        WHEN (PROP.PROPOSED_MONTHLY - CUR.CURRENT_MONTHLY) > 0 THEN 'Y'  -- Better
        WHEN (PROP.PROPOSED_MONTHLY - CUR.CURRENT_MONTHLY) < 0 THEN 'N'  -- Worse
        WHEN (PROP.PROPOSED_MONTHLY - CUR.CURRENT_MONTHLY) = 0 THEN 'Z'  -- Same
        ELSE ''
    END MONTHLY_COMPARISON,
    
    CASE
        WHEN (PROP.PROPOSED_TICKET_MONTHLY - CUR.CURRENT_TICKET_MONTHLY) > 0 THEN 'Y'
        WHEN (PROP.PROPOSED_TICKET_MONTHLY - CUR.CURRENT_TICKET_MONTHLY) < 0 THEN 'N'
        WHEN (PROP.PROPOSED_TICKET_MONTHLY - CUR.CURRENT_TICKET_MONTHLY) = 0 THEN 'Z'
        ELSE ''
    END TICKET_COMPARISON,
    
    CASE
        WHEN (PROP.PROPOSED_EDU_MONTHLY - CUR.CURRENT_EDU_MONTHLY) > 0 THEN 'Y'
        WHEN (PROP.PROPOSED_EDU_MONTHLY - CUR.CURRENT_EDU_MONTHLY) < 0 THEN 'N'
        WHEN (PROP.PROPOSED_EDU_MONTHLY - CUR.CURRENT_EDU_MONTHLY) = 0 THEN 'Z'
        ELSE ''
    END EDU_COMPARISON,
    
    -- Overall Comparison (for Arabic offer letter)
    CASE
        WHEN (PROP.PROPOSED_TOTAL_MONTHLY - CUR.CURRENT_TOTAL_MONTHLY) > 0 THEN 'مقترحنا أفضل'  -- Our proposal is better
        WHEN (PROP.PROPOSED_TOTAL_MONTHLY - CUR.CURRENT_TOTAL_MONTHLY) < 0 THEN 'مقترحنا أقل'  -- Our proposal is less
        WHEN (PROP.PROPOSED_TOTAL_MONTHLY - CUR.CURRENT_TOTAL_MONTHLY) = 0 THEN 'مقترحنا مساوي'  -- Our proposal is equal
        ELSE ''
    END OVERALL_COMPARISON_ARABIC
    
FROM
    IRC_OFFERS OFFER,
    PER_PERSON_NAMES_F PPNF,
    CURRENT_COMPENSATION CUR,
    PROPOSED_COMPENSATION PROP
WHERE
    OFFER.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND OFFER.PERSON_ID = CUR.PERSON_ID(+)
    AND OFFER.PERSON_ID = PROP.PERSON_ID
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    
ORDER BY OFFER.OFFER_NUMBER;
```

**Comparison Logic:**
- `'Y'` = Proposed > Current (Better offer)
- `'N'` = Proposed < Current (Worse offer)
- `'Z'` = Proposed = Current (Same)

**Usage:** Display in offer letter to show value proposition

---

## 7. 🔄 ASSIGNMENT TRANSITION TRACKING

### Offer to Employee Transition

**Scenario:** Track transition from offer assignment to employee assignment

```sql
WITH OFFER_ASSIGNMENTS AS (
    SELECT
        OFFER.OFFER_ID,
        OFFER.PERSON_ID,
        ASG.ASSIGNMENT_ID OFFER_ASSIGNMENT_ID,
        ASG.ASSIGNMENT_NUMBER OFFER_ASSIGNMENT_NUMBER,
        ASG.ASSIGNMENT_STATUS_TYPE OFFER_STATUS,
        ASG.PROJECTED_START_DATE
    FROM
        IRC_OFFERS OFFER,
        PER_ALL_ASSIGNMENTS_M ASG
    WHERE
        OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
        AND ASG.ASSIGNMENT_TYPE = 'O'
        AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
        AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
),
EMPLOYEE_ASSIGNMENTS AS (
    SELECT DISTINCT
        ASG.PERSON_ID,
        ASG.ASSIGNMENT_ID EMPLOYEE_ASSIGNMENT_ID,
        ASG.ASSIGNMENT_NUMBER EMPLOYEE_ASSIGNMENT_NUMBER,
        ASG.ASSIGNMENT_STATUS_TYPE EMPLOYEE_STATUS,
        PPOS.DATE_START ACTUAL_START_DATE
    FROM
        PER_ALL_ASSIGNMENTS_M ASG,
        PER_PERIODS_OF_SERVICE PPOS
    WHERE
        ASG.ASSIGNMENT_TYPE IN ('E', 'P')
        AND ASG.PERIOD_OF_SERVICE_ID = PPOS.PERIOD_OF_SERVICE_ID
        AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
)
SELECT
    OFFER.OFFER_NUMBER,
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    
    -- Offer Assignment
    OA.OFFER_ASSIGNMENT_NUMBER,
    OA.OFFER_STATUS,
    TO_CHAR(OA.PROJECTED_START_DATE, 'DD/MM/YYYY') PROJECTED_START_DATE,
    
    -- Employee Assignment (if hired)
    EA.EMPLOYEE_ASSIGNMENT_NUMBER,
    EA.EMPLOYEE_STATUS,
    TO_CHAR(EA.ACTUAL_START_DATE, 'DD/MM/YYYY') ACTUAL_START_DATE,
    
    -- Transition Status
    CASE
        WHEN EA.EMPLOYEE_ASSIGNMENT_ID IS NOT NULL AND EA.EMPLOYEE_STATUS = 'ACTIVE'
        THEN 'Hired - Active Employee'
        WHEN EA.EMPLOYEE_ASSIGNMENT_ID IS NOT NULL AND EA.EMPLOYEE_STATUS = 'INACTIVE'
        THEN 'Hired - Pending Worker (Not Yet Active)'
        WHEN OFFER.ACCEPTED_DATE IS NOT NULL AND EA.EMPLOYEE_ASSIGNMENT_ID IS NULL
        THEN 'Offer Accepted - Awaiting Hire'
        WHEN OFFER.EXTENDED_DATE IS NOT NULL AND OFFER.ACCEPTED_DATE IS NULL
        THEN 'Offer Extended - Awaiting Acceptance'
        ELSE 'Offer in Progress'
    END TRANSITION_STATUS,
    
    -- Transition Date Variance
    CASE
        WHEN EA.ACTUAL_START_DATE IS NOT NULL
        THEN TRUNC(EA.ACTUAL_START_DATE) - TRUNC(OA.PROJECTED_START_DATE)
        ELSE NULL
    END START_DATE_VARIANCE_DAYS,
    
    -- Hire Process Status
    OFFER.MOVE_TO_HR_STATUS,
    OFFER.OFFER_MOVE_STATUS
    
FROM
    IRC_OFFERS OFFER,
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    OFFER_ASSIGNMENTS OA,
    EMPLOYEE_ASSIGNMENTS EA
WHERE
    OFFER.SUBMISSION_ID = SUB.SUBMISSION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND OFFER.OFFER_ID = OA.OFFER_ID
    AND OFFER.PERSON_ID = EA.PERSON_ID(+)
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    
    -- Filter
    AND OFFER.EXTENDED_DATE >= :P_START_DATE
    
ORDER BY
    CASE
        WHEN TRANSITION_STATUS = 'Offer Accepted - Awaiting Hire' THEN 1
        WHEN TRANSITION_STATUS = 'Hired - Pending Worker (Not Yet Active)' THEN 2
        ELSE 3
    END,
    OA.PROJECTED_START_DATE;
```

**Parameters:**
- `:P_START_DATE` - Start date for offers

---

## 8. 🎯 EDGE CASES & SOLUTIONS

### Edge Case 1: Candidate with Multiple Active Submissions

**Problem:** Candidate applied to multiple requisitions

**Solution:**
```sql
SELECT
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    COUNT(SUB.SUBMISSION_ID) ACTIVE_SUBMISSIONS,
    
    -- List requisitions
    LISTAGG(REQ.REQUISITION_NUMBER, ', ') WITHIN GROUP (ORDER BY SUB.SUBMISSION_DATE) REQUISITIONS
    
FROM
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    IRC_SUBMISSIONS SUB,
    IRC_REQUISITIONS_VL REQ
WHERE
    CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND CAND.PERSON_ID = SUB.PERSON_ID
    AND SUB.REQUISITION_ID = REQ.REQUISITION_ID
    AND SUB.ACTIVE_FLAG = 'Y'
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    
GROUP BY CAND.CANDIDATE_NUMBER, PPNF.DISPLAY_NAME
HAVING COUNT(SUB.SUBMISSION_ID) > 1

ORDER BY ACTIVE_SUBMISSIONS DESC;
```

### Edge Case 2: Offer Extended but Not Accepted (Follow-up)

**Problem:** Need to follow up on pending offers

**Solution:**
```sql
SELECT
    OFFER.OFFER_NUMBER,
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    EMAIL.EMAIL_ADDRESS CANDIDATE_EMAIL,
    PHONE.PHONE_NUMBER CANDIDATE_PHONE,
    
    TO_CHAR(OFFER.EXTENDED_DATE, 'DD/MM/YYYY') OFFER_EXTENDED_DATE,
    TRUNC(SYSDATE) - TRUNC(OFFER.EXTENDED_DATE) DAYS_SINCE_EXTENDED,
    
    REC.DISPLAY_NAME RECRUITER_NAME,
    REC_EMAIL.EMAIL_ADDRESS RECRUITER_EMAIL,
    
    MGR.DISPLAY_NAME HIRING_MANAGER,
    MGR_EMAIL.EMAIL_ADDRESS MANAGER_EMAIL,
    
    -- Follow-up Priority
    CASE
        WHEN TRUNC(SYSDATE) - TRUNC(OFFER.EXTENDED_DATE) > 14 THEN 'URGENT: >14 days'
        WHEN TRUNC(SYSDATE) - TRUNC(OFFER.EXTENDED_DATE) > 7 THEN 'HIGH: >7 days'
        WHEN TRUNC(SYSDATE) - TRUNC(OFFER.EXTENDED_DATE) > 3 THEN 'MEDIUM: >3 days'
        ELSE 'LOW: Recent'
    END FOLLOW_UP_PRIORITY
    
FROM
    IRC_OFFERS OFFER,
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    PER_EMAIL_ADDRESSES EMAIL,
    PER_PHONES PHONE,
    PER_PERSON_NAMES_F REC,
    PER_EMAIL_ADDRESSES REC_EMAIL,
    PER_PERSON_NAMES_F MGR,
    PER_EMAIL_ADDRESSES MGR_EMAIL
WHERE
    OFFER.SUBMISSION_ID = SUB.SUBMISSION_ID
    AND SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND CAND.CAND_EMAIL_ID = EMAIL.EMAIL_ADDRESS_ID(+)
    AND CAND.CAND_PHONE_ID = PHONE.PHONE_ID(+)
    
    AND OFFER.RECRUITER_ID = REC.PERSON_ID(+)
    AND REC.NAME_TYPE(+) = 'GLOBAL'
    AND REC.PERSON_ID = REC_EMAIL.PERSON_ID(+)
    AND REC_EMAIL.EMAIL_TYPE(+) = 'W1'
    
    AND OFFER.HIRING_MANAGER_ID = MGR.PERSON_ID(+)
    AND MGR.NAME_TYPE(+) = 'GLOBAL'
    AND MGR.PERSON_ID = MGR_EMAIL.PERSON_ID(+)
    AND MGR_EMAIL.EMAIL_TYPE(+) = 'W1'
    
    -- Extended but not accepted
    AND OFFER.EXTENDED_DATE IS NOT NULL
    AND OFFER.ACCEPTED_DATE IS NULL
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN REC.EFFECTIVE_START_DATE(+) AND REC.EFFECTIVE_END_DATE(+)
    AND TRUNC(SYSDATE) BETWEEN MGR.EFFECTIVE_START_DATE(+) AND MGR.EFFECTIVE_END_DATE(+)
    
ORDER BY DAYS_SINCE_EXTENDED DESC;
```

### Edge Case 3: Internal Candidate (Employee) Receiving Offer

**Problem:** Need to handle current employee receiving offer for new position

**Solution:**
```sql
SELECT
    CAND.CANDIDATE_NUMBER,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    
    -- Current Employee Details
    CURR_ASG.ASSIGNMENT_NUMBER CURRENT_ASSIGNMENT,
    CURR_JOB.NAME CURRENT_JOB_TITLE,
    CURR_GRADE.NAME CURRENT_GRADE,
    CURR_DEPT.NAME CURRENT_DEPARTMENT,
    
    -- Offer Details
    OFFER.OFFER_NUMBER,
    OFFER_JOB.NAME OFFERED_JOB_TITLE,
    OFFER_GRADE.NAME OFFERED_GRADE,
    OFFER_DEPT.NAME OFFERED_DEPARTMENT,
    
    -- Comparison
    CASE
        WHEN OFFER_GRADE.GRADE_SEQUENCE > CURR_GRADE.GRADE_SEQUENCE THEN 'Promotion'
        WHEN OFFER_GRADE.GRADE_SEQUENCE < CURR_GRADE.GRADE_SEQUENCE THEN 'Demotion'
        WHEN OFFER_GRADE.GRADE_SEQUENCE = CURR_GRADE.GRADE_SEQUENCE THEN 'Lateral Move'
        ELSE 'N/A'
    END MOVE_TYPE,
    
    -- Internal Transfer Flag
    SUB.INTERNAL_FLAG IS_INTERNAL,
    SUB.SYSTEM_PERSON_TYPE CURRENT_PERSON_TYPE
    
FROM
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF,
    IRC_SUBMISSIONS SUB,
    IRC_OFFERS OFFER,
    
    -- Current Employee Assignment
    PER_ALL_ASSIGNMENTS_M CURR_ASG,
    PER_JOBS_F_VL CURR_JOB,
    PER_GRADES_F CURR_GRADE,
    PER_DEPARTMENTS CURR_DEPT,
    
    -- Offer Assignment
    PER_ALL_ASSIGNMENTS_M OFFER_ASG,
    PER_JOBS_F_VL OFFER_JOB,
    PER_GRADES_F OFFER_GRADE,
    PER_DEPARTMENTS OFFER_DEPT
WHERE
    CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    
    AND CAND.PERSON_ID = SUB.PERSON_ID
    AND SUB.SUBMISSION_ID = OFFER.SUBMISSION_ID
    
    -- Current Employee Assignment
    AND CAND.PERSON_ID = CURR_ASG.PERSON_ID
    AND CURR_ASG.ASSIGNMENT_TYPE = 'E'
    AND CURR_ASG.PRIMARY_ASSIGNMENT_FLAG = 'Y'
    AND CURR_ASG.ASSIGNMENT_STATUS_TYPE = 'ACTIVE'
    AND CURR_ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND CURR_ASG.JOB_ID = CURR_JOB.JOB_ID
    AND CURR_ASG.GRADE_ID = CURR_GRADE.GRADE_ID
    AND CURR_ASG.ORGANIZATION_ID = CURR_DEPT.ORGANIZATION_ID
    
    -- Offer Assignment
    AND OFFER.ASSIGNMENT_OFFER_ID = OFFER_ASG.ASSIGNMENT_ID
    AND OFFER_ASG.ASSIGNMENT_TYPE = 'O'
    AND OFFER_ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    
    AND OFFER_ASG.JOB_ID = OFFER_JOB.JOB_ID
    AND OFFER_ASG.GRADE_ID = OFFER_GRADE.GRADE_ID
    AND OFFER_ASG.ORGANIZATION_ID = OFFER_DEPT.ORGANIZATION_ID
    
    -- Internal flag
    AND SUB.INTERNAL_FLAG = 'Y'
    AND SUB.ACTIVE_FLAG = 'Y'
    
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN CURR_ASG.EFFECTIVE_START_DATE AND CURR_ASG.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN OFFER_ASG.EFFECTIVE_START_DATE AND OFFER_ASG.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN CURR_JOB.EFFECTIVE_START_DATE AND CURR_JOB.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN OFFER_JOB.EFFECTIVE_START_DATE AND OFFER_JOB.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN CURR_GRADE.EFFECTIVE_START_DATE AND CURR_GRADE.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN OFFER_GRADE.EFFECTIVE_START_DATE AND OFFER_GRADE.EFFECTIVE_END_DATE
    
ORDER BY OFFER.OFFER_NUMBER;
```

### Edge Case 4: Candidate with No Schedule Assignments

**Problem:** Checking if employee has schedule assignments during offer transition

```sql
-- Check if candidate already has schedule assignment conflicts
SELECT
    OFFER.OFFER_ID,
    PPNF.DISPLAY_NAME CANDIDATE_NAME,
    
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM PER_SCHEDULE_ASSIGNMENTS PSA
            WHERE PSA.RESOURCE_ID = ASG.ASSIGNMENT_ID
            AND PSA.RESOURCE_TYPE = 'ASSIGN'
            AND PSA.PRIMARY_FLAG = 'Y'
            AND TRUNC(SYSDATE) BETWEEN PSA.START_DATE AND PSA.END_DATE
        )
        THEN 'Has Schedule Assignment'
        ELSE 'No Schedule Assignment'
    END SCHEDULE_STATUS
    
FROM
    IRC_OFFERS OFFER,
    PER_PERSON_NAMES_F PPNF,
    PER_ALL_ASSIGNMENTS_M ASG
WHERE
    OFFER.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE;
```

---

## 🎯 PERFORMANCE OPTIMIZATION PATTERNS

### Materialized CTEs

```sql
WITH PERSON_DETAILS AS (
    /*+ qb_name(PERSON_DETAILS) MATERIALIZE */
    SELECT
        PERSON_ID,
        DISPLAY_NAME,
        PERSON_NUMBER
    FROM PER_PERSON_NAMES_F
    WHERE NAME_TYPE = 'GLOBAL'
    AND TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE
),
ACTIVE_SUBMISSIONS AS (
    /*+ qb_name(ACTIVE_SUBS) MATERIALIZE */
    SELECT
        SUBMISSION_ID,
        PERSON_ID,
        REQUISITION_ID,
        CURRENT_STATE_ID
    FROM IRC_SUBMISSIONS
    WHERE ACTIVE_FLAG = 'Y'
)
SELECT ...
FROM PERSON_DETAILS PD,
     ACTIVE_SUBMISSIONS SUB
WHERE PD.PERSON_ID = SUB.PERSON_ID;
```

### Parallel Hints

```sql
SELECT /*+ PARALLEL(SUB, 4) */
       ...
FROM IRC_SUBMISSIONS SUB
WHERE ...
```

### Index Hints

```sql
SELECT /*+ index(ASG, PER_ALL_ASSIGNMENTS_M_PK) */
       /*+ index(OFFER, IRC_OFFERS_U1) */
       ...
FROM IRC_OFFERS OFFER,
     PER_ALL_ASSIGNMENTS_M ASG
WHERE ...
```

---

**END OF ADVANCED PATTERNS**

**Status:** Production-Ready  
**Last Updated:** 07-Jan-2026  
**Complexity Level:** Advanced  
**Prerequisites:** Understand ORC_COMPREHENSIVE_GUIDE first
