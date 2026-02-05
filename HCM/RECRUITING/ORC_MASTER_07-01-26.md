# Oracle Recruiting Cloud (ORC) - Master Instructions

**Module:** Oracle Recruiting Cloud (ORC/IRC)  
**Tag:** `#HCM #ORC #IRC #Recruiting`  
**Status:** Production-Ready  
**Last Updated:** 07-Jan-2026

---

## 1. 🚨 Critical ORC Constraints

*Violating these rules breaks recruiting reports.*

### 1.1 Offer Assignment Type
**Rule:** Offer assignments must have `ASSIGNMENT_TYPE = 'O'`

```sql
FROM
    IRC_OFFERS OFFER,
    PER_ALL_ASSIGNMENTS_M ASG
WHERE
    OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'  -- CRITICAL: 'O' = Offer
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
```

**Why:** Offers create temporary assignments (Type 'O') that convert to employee assignments (Type 'E') upon hire.

**Assignment Types:**
- `'E'` - Employee
- `'C'` - Contingent Worker
- `'O'` - Offer (pending worker)
- `'P'` - Pending Worker
- `'N'` - Nonworker

### 1.2 Active Submission Filter
**Rule:** Always filter by `ACTIVE_FLAG = 'Y'` for submissions

```sql
WHERE
    SUB.ACTIVE_FLAG = 'Y'
```

**Why:** Submissions can be archived/inactive. Active flag ensures current submissions only.

### 1.3 Language/Translation Filters
**Rule:** Always filter by `LANGUAGE = USERENV('LANG')` for translated tables

```sql
WHERE
    JOB_TL.LANGUAGE = USERENV('LANG')
```

**Why:** Translated tables (_TL suffix) have multiple rows per record (one per language).

**Common _TL Tables:**
- `PER_JOBS_F_TL`
- `PER_JOB_FAMILY_F_TL`
- `PER_LOCATION_DETAILS_F_TL`
- `HR_ORGANIZATION_UNITS_F_TL`

### 1.4 Effective Latest Change
**Rule:** Always filter by `EFFECTIVE_LATEST_CHANGE = 'Y'` for assignment queries

```sql
WHERE
    ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
```

**Why:** Assignments can have multiple records at the same effective date. Latest change flag ensures current record.

### 1.5 Latest Version Pattern (Flexfields)
**Rule:** Use MAX(CREATION_DATE) to get latest flexfield values

```sql
WHERE
    EXTRA.PERSON_ID = :PERSON_ID
    AND EXTRA.INFORMATION_TYPE = 'Candidate Current Salary'
    
    -- If multiple records exist, get latest
    AND EXTRA.CREATION_DATE = (
        SELECT MAX(CREATION_DATE)
        FROM PER_PEOPLE_EXTRA_INFO
        WHERE PERSON_ID = EXTRA.PERSON_ID
        AND INFORMATION_TYPE = EXTRA.INFORMATION_TYPE
    )
```

**Why:** Flexfields can be updated multiple times. Need latest only.

---

## 2. 🗺️ Schema Map

### 2.1 Recruiting Core Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **REQ** | `IRC_REQUISITIONS_VL` | Job Requisitions |
| **CAND** | `IRC_CANDIDATES` | Candidates |
| **SUB** | `IRC_SUBMISSIONS` | Applications/Submissions |
| **OFFER** | `IRC_OFFERS` | Job Offers |
| **PHASE** | `IRC_PHASES_VL` | Workflow Phases |
| **STATE** | `IRC_STATES_VL` | Workflow States |
| **ST** | `IRC_SOURCE_TRACKING` | Recruitment Sources |
| **IJEI** | `IRC_JA_EXTRA_INFO` | Submission Flexfields |

### 2.2 Person & Assignment Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAPF** | `PER_ALL_PEOPLE_F` | Person Master |
| **PPNF** | `PER_PERSON_NAMES_F` | Person Names |
| **ASG** | `PER_ALL_ASSIGNMENTS_M` | Assignments (including Type 'O') |
| **PPOS** | `PER_PERIODS_OF_SERVICE` | Employment Periods |
| **EXTRA** | `PER_PEOPLE_EXTRA_INFO` | Person Flexfields |
| **EMAIL** | `PER_EMAIL_ADDRESSES` | Email Addresses |
| **PHONE** | `PER_PHONES` / `PER_DISPLAY_PHONES_V` | Phone Numbers |
| **ADDR** | `PER_PERSON_ADDRESSES_V` | Addresses |

### 2.3 Organization Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **JOB** | `PER_JOBS_F_TL` | Job Definitions |
| **JF** | `PER_JOB_FAMILY_F_TL` | Job Families |
| **DEPT** | `PER_DEPARTMENTS` | Departments |
| **BU** | `FUN_ALL_BUSINESS_UNITS_V` | Business Units |
| **LE** | `PER_LEGAL_EMPLOYERS` | Legal Employers |
| **LOC** | `PER_LOCATION_DETAILS_F_TL` | Locations |
| **GRADE** | `PER_GRADES_F_VL` | Grades |

### 2.4 Compensation Tables

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **CSA** | `CMP_SALARY` | Offer Salary |
| **CSSC** | `CMP_SALARY_SIMPLE_COMPNTS` | Salary Components |
| **CSB** | `CMP_SALARY_BASES_VL` | Salary Basis |
| **PET** | `PAY_ELEMENT_TYPES_VL` | Pay Elements |

### 2.5 User-Defined Tables (UDT)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **FUTV** | `FF_USER_TABLES_VL` | UDT Definitions |
| **FUCV** | `FF_USER_COLUMNS_VL` | UDT Columns |
| **FURV** | `FF_USER_ROWS_VL` | UDT Rows |
| **FUCIF** | `FF_USER_COLUMN_INSTANCES_F` | UDT Values |

---

## 3. 📋 Standard Joins (Copy-Paste Ready)

### 3.1 Requisition to Submission Join

```sql
FROM
    IRC_REQUISITIONS_VL REQ,
    IRC_SUBMISSIONS SUB
WHERE
    REQ.REQUISITION_ID = SUB.REQUISITION_ID
    AND SUB.ACTIVE_FLAG = 'Y'
```

### 3.2 Submission to Candidate Join

```sql
FROM
    IRC_SUBMISSIONS SUB,
    IRC_CANDIDATES CAND,
    PER_PERSON_NAMES_F PPNF
WHERE
    SUB.PERSON_ID = CAND.PERSON_ID
    AND CAND.PERSON_ID = PPNF.PERSON_ID
    AND PPNF.NAME_TYPE = 'GLOBAL'
    AND SUB.ACTIVE_FLAG = 'Y'
    AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE AND PPNF.EFFECTIVE_END_DATE
```

### 3.3 Submission to Workflow Join

```sql
FROM
    IRC_SUBMISSIONS SUB,
    IRC_PHASES_VL PHASE,
    IRC_STATES_VL STATE
WHERE
    SUB.CURRENT_PHASE_ID = PHASE.PHASE_ID
    AND SUB.CURRENT_STATE_ID = STATE.STATE_ID
    AND SUB.ACTIVE_FLAG = 'Y'
```

### 3.4 Submission to Offer Join

```sql
FROM
    IRC_SUBMISSIONS SUB,
    IRC_OFFERS OFFER
WHERE
    SUB.SUBMISSION_ID = OFFER.SUBMISSION_ID
    AND SUB.ACTIVE_FLAG = 'Y'
```

### 3.5 Offer to Assignment Join (CRITICAL)

```sql
FROM
    IRC_OFFERS OFFER,
    PER_ALL_ASSIGNMENTS_M ASG
WHERE
    OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'  -- CRITICAL: Offer type
    AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
```

### 3.6 Offer to Salary Join

```sql
FROM
    IRC_OFFERS OFFER,
    PER_ALL_ASSIGNMENTS_M ASG,
    CMP_SALARY CSA
WHERE
    OFFER.ASSIGNMENT_OFFER_ID = ASG.ASSIGNMENT_ID
    AND ASG.ASSIGNMENT_TYPE = 'O'
    AND ASG.ASSIGNMENT_ID = CSA.ASSIGNMENT_ID
    AND TRUNC(SYSDATE) BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN CSA.DATE_FROM AND CSA.DATE_TO
```

### 3.7 Candidate Preferred Contact Join

```sql
FROM
    IRC_CANDIDATES CAND,
    PER_EMAIL_ADDRESSES EMAIL,
    PER_PHONES PHONE
WHERE
    CAND.CAND_EMAIL_ID = EMAIL.EMAIL_ADDRESS_ID(+)
    AND CAND.CAND_PHONE_ID = PHONE.PHONE_ID(+)
```

### 3.8 Requisition to Job/Department Join

```sql
FROM
    IRC_REQUISITIONS_VL REQ,
    PER_JOBS_F_TL JOB,
    PER_JOB_FAMILY_F_TL JF,
    PER_DEPARTMENTS DEPT
WHERE
    REQ.JOB_ID = JOB.JOB_ID
    AND JOB.LANGUAGE = USERENV('LANG')
    
    AND REQ.JOB_FAMILY_ID = JF.JOB_FAMILY_ID
    AND JF.LANGUAGE = USERENV('LANG')
    
    AND REQ.DEPARTMENT_ID = DEPT.ORGANIZATION_ID
    
    AND TRUNC(SYSDATE) BETWEEN JOB.EFFECTIVE_START_DATE AND JOB.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN JF.EFFECTIVE_START_DATE AND JF.EFFECTIVE_END_DATE
    AND TRUNC(SYSDATE) BETWEEN DEPT.EFFECTIVE_START_DATE AND DEPT.EFFECTIVE_END_DATE
```

---

## 4. 🔗 Flexfield Patterns

### 4.1 Submission Flexfield (IRC_JA_EXTRA_INFO)

**Scalar Subquery Pattern:**
```sql
(SELECT PEI_INFORMATION15
 FROM IRC_JA_EXTRA_INFO
 WHERE SUBMISSION_ID = SUB.SUBMISSION_ID
 AND PEI_INFORMATION_CATEGORY = 'LOGISTICS'
 AND ROWNUM = 1) LOGISTICS_OWNER
```

**Pivot Pattern (Multiple Categories):**
```sql
WITH SUBMISSION_EXTRA AS (
    SELECT
        SUBMISSION_ID,
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'LOGISTICS'
            THEN PEI_INFORMATION15 END) LOGISTICS_OWNER,
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Medical_Health'
            THEN PEI_INFORMATION8 END) MEDICAL_RESULT,
        MAX(CASE WHEN PEI_INFORMATION_CATEGORY = 'Screening'
            THEN PEI_INFORMATION20 END) SCREENING_OWNER
    FROM IRC_JA_EXTRA_INFO
    GROUP BY SUBMISSION_ID
)
```

### 4.2 Person Flexfield (PER_PEOPLE_EXTRA_INFO)

**Scalar Subquery Pattern:**
```sql
(SELECT PEI_INFORMATION_NUMBER1
 FROM PER_PEOPLE_EXTRA_INFO
 WHERE PERSON_ID = OFFER.PERSON_ID
 AND INFORMATION_TYPE = 'Candidate Current Salary'
 AND ROWNUM = 1) MONTHLY_ALLOWANCE
```

**Pivot Pattern (Multiple Types):**
```sql
WITH PERSON_EXTRA AS (
    SELECT
        PERSON_ID,
        
        -- Arabic Name
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Local Name'
            THEN PEI_INFORMATION1 || ' ' || PEI_INFORMATION2 || ' ' || PEI_INFORMATION3 END) ARABIC_NAME,
        
        -- Airfare
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Compensation Details'
            THEN PEI_INFORMATION1 END) AIRFARE_CLASS,
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Compensation Details'
            THEN PEI_INFORMATION_NUMBER1 END) ADULT_COUNT,
        
        -- Current Salary
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Current Salary'
            THEN PEI_INFORMATION_NUMBER1 END) CURRENT_MONTHLY,
        
        -- Personal
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Personal Details'
            THEN PEI_INFORMATION1 END) NATIONALITY,
        MAX(CASE WHEN INFORMATION_TYPE = 'Candidate Personal Details'
            THEN PEI_INFORMATION2 END) MARITAL_STATUS
        
    FROM PER_PEOPLE_EXTRA_INFO
    GROUP BY PERSON_ID
)
```

### 4.3 Requisition Attributes

**Pattern:**
```sql
SELECT
    REQ.REQUISITION_NUMBER,
    
    -- Custom Attributes (vary by implementation)
    REQ.ATTRIBUTE_CHAR1 JUSTIFICATION_TEXT,
    REQ.ATTRIBUTE_CHAR2 BUDGET_STATUS,
    REQ.ATTRIBUTE_CHAR3 CONTRACT_TYPE,
    REQ.ATTRIBUTE_CHAR4 IC_PM_ROLE,
    REQ.ATTRIBUTE_CHAR7 NEW_OR_REPLACEMENT,
    REQ.ATTRIBUTE_CHAR8 CLIENT_NAME,
    REQ.ATTRIBUTE_CHAR8 REPLACEMENT_EMP_ID,  -- Can be reused
    REQ.ATTRIBUTE_CHAR10 WORKER_CATEGORY,
    
    -- Lookup values
    (SELECT MEANING
     FROM HCM_LOOKUPS
     WHERE LOOKUP_CODE = REQ.JUSTIFICATION_CODE
     AND LOOKUP_TYPE = 'ORA_IRC_REQ_JUSTIFICATION') JUSTIFICATION
FROM IRC_REQUISITIONS_VL REQ
```

### 4.4 Offer Attributes

**Pattern:**
```sql
SELECT
    OFFER.OFFER_ID,
    
    -- Numeric Attributes (Salary Components)
    OFFER.ATTRIBUTE_NUMBER1 EMPLOYERS_ESI,
    OFFER.ATTRIBUTE_NUMBER2 BASIC_SALARY,
    OFFER.ATTRIBUTE_NUMBER3 HRA,
    OFFER.ATTRIBUTE_NUMBER4 SPECIAL_ALLOWANCE,
    OFFER.ATTRIBUTE_NUMBER5 GROSS_SALARY,
    OFFER.ATTRIBUTE_NUMBER6 EMPLOYERS_PF,
    OFFER.ATTRIBUTE_NUMBER7 TRANSPORT_ALLOWANCE,
    OFFER.ATTRIBUTE_NUMBER8 FLEXI_BENEFIT,
    OFFER.ATTRIBUTE_NUMBER9 FLEXI_BENEFIT_TOTAL,
    OFFER.ATTRIBUTE_NUMBER10 TOTAL_FIXED_CTC,
    OFFER.ATTRIBUTE_NUMBER11 TARGET_VARIABLE,
    OFFER.ATTRIBUTE_NUMBER12 ON_TARGET_COMPENSATION,
    
    -- Character Attributes
    OFFER.ATTRIBUTE_CHAR2 SEAT_CABIN,
    OFFER.ATTRIBUTE_CHAR3 ID_CARD,
    OFFER.ATTRIBUTE_CHAR4 BUSINESS_CARD,
    OFFER.ATTRIBUTE_CHAR5 DESK_LAPTOP_MACBOOK,
    OFFER.ATTRIBUTE_CHAR6 OPERATING_SYSTEM,
    OFFER.ATTRIBUTE_CHAR8 CANDIDATE_CATEGORY,
    OFFER.ATTRIBUTE_CHAR10 PREVIOUS_CTC,
    OFFER.ATTRIBUTE_CHAR13 STATUTORY_BONUS
    
FROM IRC_OFFERS OFFER
```

---

## 5. 📊 Standard Filters

### 5.1 Date Range Filtering

**Requisitions:**
```sql
AND REQ.OPEN_DATE >= :P_START_DATE
AND (REQ.CLOSE_DATE IS NULL OR REQ.CLOSE_DATE <= :P_END_DATE)
```

**Submissions:**
```sql
AND SUB.SUBMISSION_DATE >= :P_START_DATE
AND SUB.SUBMISSION_DATE <= :P_END_DATE
```

**Offers:**
```sql
AND OFFER.CREATION_DATE >= :P_START_DATE
AND OFFER.CREATION_DATE <= :P_END_DATE
```

### 5.2 Status Filtering

**Submission Status:**
```sql
-- Active only
AND SUB.ACTIVE_FLAG = 'Y'

-- Specific states
AND STATE.NAME IN ('Selected for Offer - Experienced', 'Selected for Offer - Fresher')
```

**Offer Status:**
```sql
-- Extended offers only
AND OFFER.EXTENDED_DATE IS NOT NULL

-- Accepted offers only
AND OFFER.ACCEPTED_DATE IS NOT NULL

-- Processed (hired) only
AND STATE.NAME = 'Processed'
AND OFFER.MOVE_TO_HR_STATUS = 'SUCCESS'
```

### 5.3 Requisition Filtering

**By Type:**
```sql
AND REQ.WORKER_TYPE_CODE = 'E'  -- Employee only
AND REQ.RECRUITING_TYPE_CODE = :P_TYPE
```

**By Organization:**
```sql
AND REQ.BUSINESS_UNIT_ID = :P_BU_ID
AND REQ.DEPARTMENT_ID = :P_DEPT_ID
AND REQ.LEGAL_EMPLOYER_ID = :P_LE_ID
```

**By People:**
```sql
AND REQ.HIRING_MANAGER_ID = :P_MANAGER_ID
AND REQ.RECRUITER_ID = :P_RECRUITER_ID
```

### 5.4 Candidate Type Filtering

**Internal vs External:**
```sql
-- Internal candidates
AND SUB.INTERNAL_FLAG = 'Y'

-- External candidates
AND SUB.INTERNAL_FLAG = 'N'

-- Using person type
AND EXISTS (
    SELECT 1
    FROM PER_PERSON_TYPE_USAGES_M PTU
    WHERE PTU.PERSON_ID = CAND.PERSON_ID
    AND PTU.SYSTEM_PERSON_TYPE IN ('EMP', 'CWK')
    AND TRUNC(SYSDATE) BETWEEN PTU.EFFECTIVE_START_DATE AND PTU.EFFECTIVE_END_DATE
    AND PTU.EFFECTIVE_LATEST_CHANGE = 'Y'
)
```

---

## 6. ⚠️ Common Pitfalls

### 6.1 Missing ASSIGNMENT_TYPE = 'O' Filter
**Problem:** Getting employee assignments instead of offer assignments  
**Cause:** Not filtering by assignment type  
**Solution:**
```sql
AND ASG.ASSIGNMENT_TYPE = 'O'
```

### 6.2 Multiple Language Rows
**Problem:** Cartesian product for translated tables  
**Cause:** Not filtering by LANGUAGE  
**Solution:**
```sql
AND JOB_TL.LANGUAGE = USERENV('LANG')
```

### 6.3 Inactive Submissions
**Problem:** Including archived/withdrawn submissions  
**Cause:** Not filtering by ACTIVE_FLAG  
**Solution:**
```sql
AND SUB.ACTIVE_FLAG = 'Y'
```

### 6.4 Multiple Flexfield Records
**Problem:** Getting old flexfield values  
**Cause:** Not using MAX(CREATION_DATE)  
**Solution:**
```sql
AND EXTRA.CREATION_DATE = (
    SELECT MAX(CREATION_DATE)
    FROM PER_PEOPLE_EXTRA_INFO
    WHERE PERSON_ID = EXTRA.PERSON_ID
    AND INFORMATION_TYPE = EXTRA.INFORMATION_TYPE
)
```

### 6.5 Missing EFFECTIVE_LATEST_CHANGE
**Problem:** Duplicate assignment records at same date  
**Cause:** Not filtering by EFFECTIVE_LATEST_CHANGE  
**Solution:**
```sql
AND ASG.EFFECTIVE_LATEST_CHANGE = 'Y'
```

### 6.6 Wrong Contact Info
**Problem:** Getting wrong email/phone for candidate  
**Cause:** Not using candidate's preferred contact IDs  
**Solution:**
```sql
-- Use candidate's preferred IDs
WHERE CAND.CAND_EMAIL_ID = EMAIL.EMAIL_ADDRESS_ID
AND CAND.CAND_PHONE_ID = PHONE.PHONE_ID
```

---

## 7. 💡 Calculation Patterns

### 7.1 Allowance Calculations (from UDT)

**Airfare Allowance:**
```sql
-- Get counts from flexfield
-- Get rates from UDT
-- Calculate total

SELECT
    -- Adult Allowance
    NVL(AIR.PEI_INFORMATION_NUMBER1, 0) * NVL(UDT_ADULT.VALUE, 0) ADULT_ALLOWANCE,
    
    -- Child Allowance
    NVL(AIR.PEI_INFORMATION_NUMBER2, 0) * NVL(UDT_CHILD.VALUE, 0) CHILD_ALLOWANCE,
    
    -- Infant Allowance
    NVL(AIR.PEI_INFORMATION_NUMBER3, 0) * NVL(UDT_INFANT.VALUE, 0) INFANT_ALLOWANCE,
    
    -- Total Annual
    (NVL(AIR.PEI_INFORMATION_NUMBER1, 0) * NVL(UDT_ADULT.VALUE, 0) +
     NVL(AIR.PEI_INFORMATION_NUMBER2, 0) * NVL(UDT_CHILD.VALUE, 0) +
     NVL(AIR.PEI_INFORMATION_NUMBER3, 0) * NVL(UDT_INFANT.VALUE, 0)) TOTAL_AIRFARE_ANNUAL,
    
    -- Total Monthly (Annual / 12)
    ROUND((NVL(AIR.PEI_INFORMATION_NUMBER1, 0) * NVL(UDT_ADULT.VALUE, 0) +
           NVL(AIR.PEI_INFORMATION_NUMBER2, 0) * NVL(UDT_CHILD.VALUE, 0) +
           NVL(AIR.PEI_INFORMATION_NUMBER3, 0) * NVL(UDT_INFANT.VALUE, 0)) / 12) TOTAL_AIRFARE_MONTHLY
FROM ...
```

**Education Allowance:**
```sql
-- Based on grade and entity
SELECT
    NVL(UDT_EDU.VALUE, 0) EDU_RATE_PER_CHILD,
    NVL(AIR.PEI_INFORMATION_NUMBER2, 0) CHILD_COUNT,
    
    -- Total Annual
    NVL(AIR.PEI_INFORMATION_NUMBER2, 0) * NVL(UDT_EDU.VALUE, 0) TOTAL_EDU_ANNUAL,
    
    -- Total Monthly
    ROUND((NVL(AIR.PEI_INFORMATION_NUMBER2, 0) * NVL(UDT_EDU.VALUE, 0)) / 12) TOTAL_EDU_MONTHLY
FROM ...
WHERE
    GRADE.NAME = UDT_EDU.ROW_NAME
    AND ENTITY.NAME = UDT_EDU.ENTITY_NA
```

### 7.2 Salary Component Aggregation

**Pattern:**
```sql
SELECT
    PERSON_ID,
    
    -- Basic Salary
    SUM(CASE WHEN FLV.MEANING = 'Basic salary' THEN CSSC.AMOUNT ELSE 0 END) BASIC,
    
    -- Allowances
    SUM(CASE WHEN FLV.MEANING = 'Allowance' THEN CSSC.AMOUNT ELSE 0 END) ALLOWANCES,
    
    -- Gross
    SUM(CASE WHEN FLV.MEANING = 'Gross Salary' THEN CSSC.AMOUNT ELSE 0 END) GROSS
    
FROM
    CMP_SALARY_SIMPLE_COMPNTS CSSC,
    FND_LOOKUP_VALUES FLV
WHERE
    CSSC.COMPONENT_CODE = FLV.LOOKUP_CODE
    AND FLV.LOOKUP_TYPE = 'ORA_CMP_SIMPLE_SALARY_COMPS'
    AND FLV.LANGUAGE = 'US'
    AND CSSC.COMPONENT_CODE NOT IN ('ORA_OVERALL_SALARY')
    AND NVL(CSSC.AMOUNT, 0) <> 0
    
    -- Latest update only
    AND TRUNC(CSSC.LAST_UPDATE_DATE) = (
        SELECT MAX(TRUNC(LAST_UPDATE_DATE))
        FROM CMP_SALARY_SIMPLE_COMPNTS
        WHERE PERSON_ID = CSSC.PERSON_ID
    )
    
    AND TRUNC(SYSDATE) BETWEEN CSSC.SALARY_DATE_FROM AND CSSC.SALARY_DATE_TO
    
GROUP BY PERSON_ID
```

### 7.3 Current vs Proposed Comparison

**Pattern:**
```sql
SELECT
    OFFER.OFFER_ID,
    
    -- Current (what candidate earns now)
    NVL(CURRENT.PEI_INFORMATION_NUMBER1, 0) CURRENT_MONTHLY,
    NVL(CURRENT.PEI_INFORMATION_NUMBER2, 0) CURRENT_TICKET,
    NVL(CURRENT.PEI_INFORMATION_NUMBER3, 0) CURRENT_EDUCATION,
    
    -- Proposed (what we're offering)
    NVL(PROPOSED.BASIC_SALARY, 0) + NVL(PROPOSED.ALLOWANCES, 0) PROPOSED_MONTHLY,
    NVL(CALCULATED_TICKET, 0) PROPOSED_TICKET,
    NVL(CALCULATED_EDU, 0) PROPOSED_EDUCATION,
    
    -- Differences
    ABS(NVL(PROPOSED_MONTHLY, 0) - NVL(CURRENT_MONTHLY, 0)) DIFF_MONTHLY,
    ABS(NVL(PROPOSED_TICKET, 0) - NVL(CURRENT_TICKET, 0)) DIFF_TICKET,
    ABS(NVL(PROPOSED_EDUCATION, 0) - NVL(CURRENT_EDUCATION, 0)) DIFF_EDUCATION,
    
    -- Comparison Indicator
    CASE
        WHEN (PROPOSED_MONTHLY - CURRENT_MONTHLY) > 0 THEN 'Y'  -- Better
        WHEN (PROPOSED_MONTHLY - CURRENT_MONTHLY) < 0 THEN 'N'  -- Worse
        WHEN (PROPOSED_MONTHLY - CURRENT_MONTHLY) = 0 THEN 'Z'  -- Same
        ELSE ''
    END MONTHLY_COMPARISON
    
FROM IRC_OFFERS OFFER
...
```

---

## 8. 🌐 Bilingual Patterns (Arabic/English)

### 8.1 Get Arabic Name

**Method 1: From PER_PERSON_NAMES_F:**
```sql
(SELECT FULL_NAME
 FROM PER_PERSON_NAMES_F
 WHERE PERSON_ID = :PERSON_ID
 AND NAME_TYPE = 'AE'  -- Arabic name type
 AND TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE) ARABIC_NAME
```

**Method 2: From Flexfield (IRC_JA_EXTRA_INFO):**
```sql
(SELECT PEI_INFORMATION3 || ' ' || PEI_INFORMATION1
 FROM IRC_JA_EXTRA_INFO
 WHERE SUBMISSION_ID = :SUBMISSION_ID
 AND PEI_INFORMATION_CATEGORY = 'Candidate Local Name'
 AND ROWNUM = 1) ARABIC_NAME
```

**Method 3: From Flexfield (PER_PEOPLE_EXTRA_INFO):**
```sql
EXTRA.PEI_INFORMATION1 || ' ' ||
NVL(EXTRA.PEI_INFORMATION2 || ' ', '') ||
NVL(EXTRA.PEI_INFORMATION3, '') ARABIC_NAME

WHERE EXTRA.INFORMATION_TYPE = 'Candidate Local Name'
```

### 8.2 Arabic Title Derivation

**Pattern:**
```sql
SELECT
    EXTRA.PEI_INFORMATION4 TITLE_ARABIC,  -- السيد or السيدة
    
    -- For formal address (Mr./Ms.)
    CASE
        WHEN EXTRA.PEI_INFORMATION4 = 'السيد' THEN 'المحترم'  -- Respected Mr.
        WHEN EXTRA.PEI_INFORMATION4 = 'السيدة' THEN 'المحترمة'  -- Respected Ms.
        ELSE ''
    END BA_TITLE,
    
    -- For document signature
    CASE
        WHEN EXTRA.PEI_INFORMATION4 = 'السيد' THEN 'المرشح'  -- Candidate (masculine)
        WHEN EXTRA.PEI_INFORMATION4 = 'السيدة' THEN 'المرشحة'  -- Candidate (feminine)
        ELSE ''
    END TITLE_SIGN
    
FROM PER_PEOPLE_EXTRA_INFO EXTRA
WHERE EXTRA.INFORMATION_TYPE = 'Candidate Local Name'
```

### 8.3 Arabic Month Names

**Method 1: From Lookup:**
```sql
(SELECT MEANING
 FROM HCM_LOOKUPS
 WHERE LOOKUP_TYPE = 'EPG_MON_AR_NAME'
 AND LOOKUP_CODE = TO_CHAR(SYSDATE, 'Mon', 'NLS_DATE_LANGUAGE = AMERICAN')) ARABIC_MONTH
```

**Method 2: From DECODE:**
```sql
DECODE(TO_CHAR(SYSDATE, 'MM'),
    '01', 'يناير',   -- January
    '02', 'فبراير',  -- February
    '03', 'مارس',    -- March
    '04', 'أبريل',   -- April
    '05', 'مايو',    -- May
    '06', 'يونيو',   -- June
    '07', 'يوليو',   -- July
    '08', 'أغسطس',   -- August
    '09', 'سبتمبر',  -- September
    '10', 'أكتوبر',  -- October
    '11', 'نوفمبر',  -- November
    '12', 'ديسمبر'   -- December
) ARABIC_MONTH
```

---

## 9. 📅 Parameters

| Parameter | Format | Description | Example |
|-----------|--------|-------------|---------|
| `:P_START_DATE` | Date | Start date | TO_DATE('01-01-2024', 'DD-MM-YYYY') |
| `:P_END_DATE` | Date | End date | TO_DATE('31-12-2024', 'DD-MM-YYYY') |
| `:P_REQ_NUMBER` | String | Requisition number | '1234' |
| `:P_OFFER_ID` | Number | Offer ID | 300000933456103 |
| `:P_CANDIDATE_NUMBER` | String | Candidate number | '6367788' |
| `:P_HIRING_MANAGER_ID` | Number | Manager person ID | 300000001234567 |
| `:P_RECRUITER_ID` | Number | Recruiter person ID | 300000001234567 |
| `:P_BU_ID` | Number | Business unit ID | 100 |
| `:P_DEPT_ID` | Number | Department ID | 200 |
| `:P_LE_ID` | Number | Legal employer ID | 300 |

---

## 10. 🔍 Lookup Types Reference

### Common Recruiting Lookups

| Lookup Type | Purpose | Example Codes |
|-------------|---------|---------------|
| `ORA_IRC_REQ_JUSTIFICATION` | Requisition justification | 'REPLACEMENT', 'NEW_POSITION' |
| `ORA_IRC_SOURCE_TRACKING_MEDIUM` | Source medium | 'CAREER_SITE', 'REFERRAL', 'AGENCY' |
| `ORA_CMP_SIMPLE_SALARY_COMPS` | Salary component types | 'ORA_BASIC_SALARY', 'ORA_ALLOWANCE' |
| `CMP_SALARY_BASIS` | Salary basis | 'MONTHLY', 'ANNUAL', 'HOURLY' |
| `EPG_MON_AR_NAME` | Arabic month names | 'Jan', 'Feb', etc. |
| `NATIONALITY` | Nationality codes | 'AE', 'IN', 'US', etc. |
| `CONTRACT_TYPE` | Contract type | 'PERMANENT', 'FIXED_TERM' |

**Usage:**
```sql
SELECT
    HLK.LOOKUP_CODE,
    HLK.MEANING,
    HLK.DESCRIPTION
FROM HCM_LOOKUPS HLK
WHERE HLK.LOOKUP_TYPE = 'ORA_IRC_REQ_JUSTIFICATION'
```

---

**Last Updated:** 07-Jan-2026  
**Status:** Production-Ready  
**Source:** ORC Production Queries Analysis

