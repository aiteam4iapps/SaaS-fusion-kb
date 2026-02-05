# Projects Master Instructions

**Module:** Project Management (Projects)
**Tag:** `#PPM #Projects #PJF`
**Status:** Active  
**Last Updated:** 22-12-25  
**Validation:** ✅ COMPLETED - All reference queries analyzed

---

## 1. 🚨 Critical Project Constraints

### A. Status Filtering
- **Rule:** Join `PJF_PROJECT_STATUSES_VL` to get status names (e.g., 'Active', 'Closed', 'Pending Close').
- **Code:** `PPAB.PROJECT_STATUS_CODE = PPSV.PROJECT_STATUS_CODE`
- **Common Statuses:** Active, Approved, Closed, Pending Close, On Hold

### B. Team Members (Project Parties)
- **Rule:** Use `PJF_PROJECT_PARTIES` for Project Managers/Directors/Team Members.
- **Date Check:** `TRUNC(SYSDATE) BETWEEN PPP.START_DATE_ACTIVE AND NVL(PPP.END_DATE_ACTIVE, DATE '4712-12-31')`
- **Role Filtering:** `PPP.PROJECT_PARTY_TYPE = 'IN'` for internal resources
- **Customer:** `PPP.PROJECT_PARTY_TYPE = 'CO'` for customers/companies
- **Active Flag:** `CASE WHEN TRUNC(SYSDATE) BETWEEN PPP.START_DATE_ACTIVE AND NVL(PPP.END_DATE_ACTIVE, TRUNC(SYSDATE)) THEN 'Y' ELSE 'N' END`

### C. Project Types
- **Rule:** Join `PJF_PROJECT_TYPES_VL` or `PJF_PROJECT_TYPES_TL` for type names.
- **Code:** `PPAB.PROJECT_TYPE_ID = PPTV.PROJECT_TYPE_ID`
- **Language:** For TL tables, filter `LANGUAGE = 'US'` or `USERENV('LANG')`

### D. Person Date-Effectiveness
- **CRITICAL:** All person tables MUST be filtered by effective dates
- **Pattern:** `SYSDATE >= EFFECTIVE_START_DATE AND SYSDATE < NVL(EFFECTIVE_END_DATE, DATE '4712-12-31') + 1`
- **Alternative:** `TRUNC(SYSDATE) BETWEEN TRUNC(EFFECTIVE_START_DATE) AND TRUNC(EFFECTIVE_END_DATE)`
- **Applies To:** `PER_ALL_PEOPLE_F`, `PER_PERSON_NAMES_F`, `PER_ALL_ASSIGNMENTS_F`, `PER_JOBS_F_VL`

### E. Assignment Filtering
- **Status:** `PAA.ASSIGNMENT_STATUS_TYPE IN ('ACTIVE','SUSPENDED')`
- **Type:** `NVL(PAA.ASSIGNMENT_TYPE,'E') IN ('E','C')` (Employee, Contingent Worker)
- **Primary:** `NVL(PAA.PRIMARY_FLAG,'Y') = 'Y'`

### F. Multi-Tenant Filtering
- **Standard Pattern:** `(PPAB.ORG_ID IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))`
- **ALWAYS Include:** ORG_ID filter for all project queries
- **BU Context:** Use `HR_ORGANIZATION_UNITS_F_TL` for BU names

### G. Project-Contract Linking
- **Key Table:** `PJB_CNTRCT_PROJ_LINKS`
- **Version Control:** `PCPL.VERSION_TYPE = 'C'` (Current version only)
- **Active Flag:** `PCPL.ACTIVE_FLAG = 'Y'`
- **CLIN Handling:** 
  - Non-CLIN: `NVL(PPAB.CLIN_LINKED_CODE,'P') = 'P'`
  - CLIN: `NVL(PPAB.CLIN_LINKED_CODE,'T') = 'T'`

### H. Budget vs. Forecast vs. Actual
- **Plan Class Codes:** `PLAN_CLASS_CODE IN ('BUDGET','FORECAST')`
- **Status:** `PLAN_STATUS_CODE = 'B'` (Baselined)
- **Latest Version:** Use `MAX(SUBMITTED_DATE)` to get current version
- **Submitted Date Filter:** `SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD)`

### I. Customer Identification
- **Two Methods:**
  1. Direct: From `PJF_PROJECT_PARTIES` where `PROJECT_PARTY_TYPE = 'CO'`
  2. Contract-Based: From `PJB_BILL_PLANS_B` → `HZ_CUST_ACCOUNTS` → `HZ_PARTIES`
- **CLIN Projects:** Use contract-based method
- **Complex Logic:** Reference Project Master Details Query for full implementation

### J. Overhead Allocation Exclusion
- **Expenditure Type ID:** `EXPENDITURE_TYPE_ID <> 300000126235407` (Overhead Allocation)
- **Used In:** Raw cost calculations to exclude burden from raw cost
- **Pattern:** Separate CTEs for costs with and without overhead

---

## 2. 🗺️ Schema Map

### **Core Project Tables**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PPAB** | `PJF_PROJECTS_ALL_B` | Project Header (Base) | `PROJECT_ID`, `SEGMENT1` (Number), `ORG_ID`, `PROJECT_STATUS_CODE`, `PROJECT_TYPE_ID` |
| **PPAV** | `PJF_PROJECTS_ALL_VL` | Project Header (View) | All from B + translations |
| **PPAT** | `PJF_PROJECTS_ALL_TL` | Project Names (Translatable) | `PROJECT_ID`, `NAME`, `LANGUAGE` |
| **PPSV** | `PJF_PROJECT_STATUSES_VL` | Status Lookups | `PROJECT_STATUS_CODE`, `PROJECT_STATUS_NAME` |
| **PPTV** | `PJF_PROJECT_TYPES_VL` | Project Type (View) | `PROJECT_TYPE_ID`, `PROJECT_TYPE` |
| **PPTT** | `PJF_PROJECT_TYPES_TL` | Project Type (Translatable) | `PROJECT_TYPE_ID`, `PROJECT_TYPE`, `LANGUAGE` |

### **Project Elements/Tasks**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PPEB** | `PJF_PROJ_ELEMENTS_B` | Project Elements (Base) | `PROJ_ELEMENT_ID`, `PROJECT_ID`, `ELEMENT_NUMBER` |
| **PPEV** | `PJF_PROJ_ELEMENTS_VL` | Project Elements (View) | All from B + NAME |
| **PT** | `PJF_TASKS_V` | Tasks View | `TASK_ID`, `PROJECT_ID`, `TASK_NUMBER`, `TASK_NAME` |
| **PTC** | `PJC_TASKS_CCW_V` | Tasks CCW View | `TASK_ID`, `PROJECT_ID`, `TASK_NUMBER` |

### **Project Classification**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PPC** | `PJF_PROJECT_CLASSES` | Project Classification | `PROJECT_ID`, `CLASS_CODE_ID`, `CLASS_CATEGORY_ID` |
| **PCCV** | `PJF_CLASS_CODES_VL` | Class Codes (View) | `CLASS_CODE_ID`, `CLASS_CODE`, `DESCRIPTION` |
| **PCLV** | `PJF_CLASS_CATEGORIES_VL` | Class Categories | `CLASS_CATEGORY_ID`, `CLASS_CATEGORY` (e.g., 'Contract Type', 'Market', 'ORGANIZATION_TYPE') |

**Common Class Categories:**
- `'Contract Type'` - Classification by contract type
- `'Market'` - Market segmentation
- Location classification (e.g., CLASS_CATEGORY_ID = 300000122881248)

### **Project Parties (Team/Customers)**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PPP** | `PJF_PROJECT_PARTIES` | Team Members/Customers | `PROJECT_PARTY_ID`, `PROJECT_ID`, `RESOURCE_SOURCE_ID`, `PROJECT_ROLE_ID`, `PROJECT_PARTY_TYPE`, `START_DATE_ACTIVE`, `END_DATE_ACTIVE` |
| **PLV** | `PJF_LATESTPROJECTMANAGER_V` | Latest Project Manager | `PROJECT_ID`, `RESOURCE_SOURCE_ID` |
| **PRT** | `PJF_PROJ_ROLE_TYPES_VL` | Role Types | `PROJECT_ROLE_ID`, `PROJECT_ROLE_NAME` (e.g., 'Project Manager', 'Project Director') |

**Project Party Types:**
- `'IN'` - Internal resources (employees)
- `'CO'` - Companies/customers

### **Budget & Planning**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PPVB** | `PJO_PLAN_VERSIONS_B` | Plan Versions (Base) | `PLAN_VERSION_ID`, `PROJECT_ID`, `PLAN_CLASS_CODE`, `PLAN_STATUS_CODE`, `SUBMITTED_DATE`, `CURRENT_PLAN_STATUS_FLAG` |
| **PPVV** | `PJO_PLAN_VERSIONS_VL` | Plan Versions (View) | All from B + descriptions |
| **PPL** | `PJO_PLAN_LINES` | Plan Line Details | `PLAN_LINE_ID`, `PLAN_VERSION_ID`, `TOTAL_TC_RAW_COST`, `TOTAL_TC_BRDND_COST`, `TOTAL_TC_REVENUE` |
| **PPE** | `PJO_PLANNING_ELEMENTS` | Planning Elements | `PLANNING_ELEMENT_ID`, `PLAN_VERSION_ID`, `PROJECT_ID`, `TASK_ID`, `RBS_ELEMENT_ID` |
| **PPO** | `PJO_PLANNING_OPTIONS` | Planning Options | `PLAN_VERSION_ID`, `PROJECT_ID`, `PLAN_TYPE_ID`, `PLAN_TYPE_CODE` |

**Plan Class Codes:**
- `'BUDGET'` - Budget plans
- `'FORECAST'` - Forecast plans

**Plan Status Codes:**
- `'B'` - Baselined
- `'W'` - Working
- `'S'` - Submitted

**Plan Type Codes:**
- `'FINANCIAL_PLAN'` - Financial planning

### **RBS & Burden**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PIRSV** | `PJF_IND_RATE_SCH_VL` | Indirect Rate Schedules | `IND_RATE_SCH_ID`, `IND_SCH_NAME` (Burden schedule name) |
| **PREV** | `PJF_RBS_ELEMENTS_VL` | RBS Elements | `RBS_ELEMENT_ID`, `RBS_ELEMENT_NAME_ID` |
| **PRENV** | `PJF_RBS_ELEMENT_NAMES_VL` | RBS Element Names | `RBS_ELEMENT_NAME_ID`, `NAME` (e.g., 'Contingency') |

### **Expenditure Types & Categories**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PETV** | `PJF_EXP_TYPES_VL` | Expenditure Types (View) | `EXPENDITURE_TYPE_ID`, `EXPENDITURE_TYPE_NAME`, `UNIT_OF_MEASURE`, `EXPENDITURE_CATEGORY_ID`, `REVENUE_CATEGORY_CODE` |
| **PETB** | `PJF_EXP_TYPES_B_V` | Expenditure Types (Base View) | Same as VL |
| **PETT** | `PJF_EXP_TYPES_TL` | Expenditure Types (Translatable) | `EXPENDITURE_TYPE_ID`, `EXPENDITURE_TYPE_NAME`, `LANGUAGE` |
| **PECV** | `PJF_EXP_CATEGORIES_VL` | Expenditure Categories | `EXPENDITURE_CATEGORY_ID`, `DESCRIPTION` |
| **PEVT** | `PJF_EVENT_TYPES_VL` | Billing Event Types | `EVENT_TYPE_ID`, `EVENT_TYPE_NAME` |
| **PEVTT** | `PJF_EVENT_TYPES_TL` | Event Types (Translatable) | `EVENT_TYPE_ID`, `EVENT_TYPE_NAME`, `LANGUAGE` |

**Common Expenditure Category Mappings:**
- `'Direct Labor'` → `'Staff Cost'`
- `'Other Expenses'` / `'Subcontractors'` / `'Software'` / `'Construction'` → `'Expenses'`
- `'Overhead Allocation'` → `'Burden'`

### **Organization & Business Units**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PBIA** | `PJF_BU_IMPL_ALL` | BU Implementation | `ORG_ID` |
| **HOIF** | `HR_ORGANIZATION_INFORMATION_F` | Org Information (Ledger mapping) | `ORGANIZATION_ID`, `ORG_INFORMATION_CONTEXT`, `ORG_INFORMATION3` (Ledger ID) |
| **HAOUT** | `HR_ORGANIZATION_UNITS_F_TL` | Organization Units (Translatable) | `ORGANIZATION_ID`, `NAME`, `LANGUAGE`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **HAOU** | `HR_ALL_ORGANIZATION_UNITS` | All Organization Units | `ORGANIZATION_ID`, `NAME` |
| **HOU** | `HR_OPERATING_UNITS` | Operating Units | `ORGANIZATION_ID`, `NAME` |

**Organization Information Context:**
- `'FUN_BUSINESS_UNIT'` - For ledger mapping

### **Contract Management**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PCPL** | `PJB_CNTRCT_PROJ_LINKS` | Project-Contract Links | `PROJECT_ID`, `CONTRACT_ID`, `CONTRACT_LINE_ID`, `PROJ_ELEMENT_ID`, `MAJOR_VERSION`, `ACTIVE_FLAG`, `VERSION_TYPE`, `BILLING_TYPE_CODE` |
| **OKHV** | `OKC_K_HEADERS_VL` | Contract Headers (View) | `ID` (CONTRACT_ID), `CONTRACT_NUMBER`, `CONTRACT_TYPE_ID`, `VERSION_TYPE`, `TEMPLATE_YN` |
| **OKHAB** | `OKC_K_HEADERS_ALL_B` | Contract Headers (Base) | Same as VL |
| **OKLV** | `OKC_K_LINES_VL` | Contract Lines (View) | `ID` (CONTRACT_LINE_ID), `CHR_ID` (CONTRACT_ID), `LINE_NUMBER`, `LINE_AMOUNT`, `MAJOR_VERSION`, `VERSION_TYPE`, `STS_CODE` |
| **OKLB** | `OKC_K_LINES_B` | Contract Lines (Base) | Same as VL |
| **OCTV** | `OKC_CONTRACT_TYPES_VL` | Contract Types | `CONTRACT_TYPE_ID`, `NAME` |

**Billing Type Codes:**
- `'EX'` - Expenditure-based
- `'IP'` - Invoice Plan

**Contract Version Types:**
- `'C'` - Current
- `'H'` - History
- `'A'` - Amendment

**Contract Status Codes:**
- `'ACTIVE'`, `'EXPIRED'`, `'HOLD'`, `'CLOSED'`

### **Billing Plans & Methods**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PBPB** | `PJB_BILL_PLANS_B` | Bill Plans (Base) | `BILL_PLAN_ID`, `CONTRACT_ID`, `CONTRACT_LINE_ID`, `BILL_METHOD_ID`, `BILL_TO_CUST_ACCT_ID`, `MAJOR_VERSION` |
| **PBPV** | `PJB_BILL_PLANS_VL` | Bill Plans (View) | All from B + descriptions |
| **PBM** | `PJB_BILLING_METHODS_VL` | Billing Methods | `BILL_METHOD_ID`, `BILL_TYPE_CLASS_CODE` |

**Bill Type Class Codes:**
- Common format: `REPLACE(INITCAP(BILL_TYPE_CLASS_CODE), '_', ' ')`

### **Billing Events & Transactions**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PBE** | `PJB_BILLING_EVENTS` | Billing Events | `EVENT_ID`, `PROJECT_ID`, `EVENT_NUM`, `EVENT_DESC`, `EVENT_TYPE_ID`, `REVENUE_RECOGNZD_FLAG`, `INVOICED_FLAG`, `CONTRACT_ID`, `CONTRACT_LINE_ID`, `LINKAGE_ID`, `LINKED_TASK_ID` |
| **PBT** | `PJB_BILL_TRXS` | Bill Transactions | `BILL_TRX_ID`, `TRANSACTION_ID`, `REVENUE_PLAN_ID`, `CONTRACT_ID`, `CONTRACT_LINE_ID` |

**Revenue Recognized Flag:**
- `'F'` - Fully Recognized
- `'U'` - Unrecognized
- `'A'` - Partially Recognized
- `'P'` - Pending Adjustment

**Invoiced Flag:**
- `'F'` - Fully Invoiced
- `'U'` - Uninvoiced
- `'P'` - Partially Invoiced

### **Invoicing**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PIH** | `PJB_INVOICE_HEADERS` | Invoice Headers | `INVOICE_ID`, `INVOICE_NUM`, `INVOICE_DATE`, `GL_DATE`, `INVOICE_STATUS_CODE`, `CONTRACT_ID`, `SYSTEM_REFERENCE` (AR TRX ID), `BILL_TO_CUST_ACCT_ID` |
| **PIL** | `PJB_INVOICE_LINES` | Invoice Lines | `INVOICE_LINE_ID`, `INVOICE_ID` |
| **PILD** | `PJB_INV_LINE_DISTS` | Invoice Line Distributions | `INVOICE_DIST_ID`, `INVOICE_ID`, `BILL_TRX_ID`, `TRANSACTION_PROJECT_ID`, `CONTRACT_ID`, `CONTRACT_LINE_ID`, `LINKED_PROJECT_ID`, `LINKED_TASK_ID`, `TRNS_CURR_BILLED_AMT`, `LEDGER_CURR_BILLED_AMT`, `INVOICE_CURR_BILLED_AMT` |

**Invoice Status Codes:**
- `'DRAFT'` - Draft invoices
- Exclude `'DRAFT'` for finalized invoice amounts

### **Revenue Distribution**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PRD** | `PJB_REV_DISTRIBUTIONS` | Revenue Distributions | `REV_DISTRIBUTION_ID`, `TRANSACTION_ID`, `TRANSACTION_PROJECT_ID`, `CONTRACT_ID`, `CONTRACT_LINE_ID`, `LINKED_PROJECT_ID`, `LINKED_TASK_ID`, `GL_DATE`, `GL_PERIOD_NAME`, `TRNS_CURR_REVENUE_AMT`, `LEDGER_CURR_REVENUE_AMT`, `CONT_CURR_REVENUE_AMT`, `REVENUE_PLAN_ID`, `BILL_TRANSACTION_TYPE_CODE` |

**Bill Transaction Type Codes:**
- `'EI'` - Expenditure Item

### **Person/Employee Tables**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PAPF** | `PER_ALL_PEOPLE_F` | People (Date-Effective) | `PERSON_ID`, `PERSON_NUMBER`, `PRIMARY_EMAIL_ID`, `PRIMARY_PHONE_ID`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **PPNF** | `PER_PERSON_NAMES_F` | Person Names (Date-Effective) | `PERSON_ID`, `LIST_NAME`, `FULL_NAME`, `DISPLAY_NAME`, `NAME_TYPE`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **PPNFV** | `PER_PERSON_NAMES_F_V` | Person Names View | Same as PPNF |
| **PPN** | `PER_PERSON_NAMES_F` | Person Names (Alternative alias) | Same as PPNF |
| **PEA** | `PER_EMAIL_ADDRESSES_V` | Email Addresses | `EMAIL_ADDRESS_ID`, `EMAIL_ADDRESS` |
| **PPH** | `PER_PHONES_V` | Phone Numbers | `PHONE_ID`, `PHONE_NUMBER` |
| **PAA** | `PER_ALL_ASSIGNMENTS_F` | Assignments (Date-Effective) | `PERSON_ID`, `ORGANIZATION_ID`, `JOB_ID`, `ASSIGNMENT_STATUS_TYPE`, `ASSIGNMENT_TYPE`, `PRIMARY_FLAG`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **HRO** | `PER_DEPARTMENTS` | Departments | `ORGANIZATION_ID`, `NAME`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **PPJ** | `PER_JOBS_F_VL` | Jobs (Date-Effective) | `JOB_ID`, `NAME`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE` |
| **PEU** | `PER_USERS` | Users | `USER_GUID`, `USERNAME` |

**Name Types:**
- `'GLOBAL'` - Global name (most common)

### **Customer/Party Tables**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **HP** | `HZ_PARTIES` | Parties (Customers) | `PARTY_ID`, `PARTY_NUMBER`, `PARTY_NAME` |
| **HCA** | `HZ_CUST_ACCOUNTS` | Customer Accounts | `CUST_ACCOUNT_ID`, `PARTY_ID`, `ACCOUNT_NAME` |
| **HZOP** | `HZ_ORGANIZATION_PROFILES` | Organization Profiles | `PARTY_ID`, `EFFECTIVE_START_DATE`, `EFFECTIVE_END_DATE`, `EFFECTIVE_LATEST_CHANGE` |
| **HZC** | `HZ_CODE_ASSIGNMENTS` | Code Assignments | `CODE_ASSIGNMENT_ID`, `OWNER_TABLE_ID`, `OWNER_TABLE_NAME`, `CLASS_CATEGORY`, `PRIMARY_FLAG`, `STATUS` |

**Code Assignment Filters:**
- `CLASS_CATEGORY = 'ORGANIZATION_TYPE'`
- `OWNER_TABLE_NAME = 'HZ_PARTIES'`
- `PRIMARY_FLAG = 'Y'`
- `STATUS = 'A'`

### **GL Integration**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **GLL** | `GL_LEDGERS` | Ledgers | `LEDGER_ID`, `NAME` |
| **GCC** | `GL_CODE_COMBINATIONS` | Chart of Accounts | `CODE_COMBINATION_ID`, `SEGMENT1-8` (Accounting segments) |
| **GP** | `GL_PERIODS` | Accounting Periods | `PERIOD_NAME`, `PERIOD_SET_NAME`, `END_DATE` |

### **Base Accounting (Project Subledger)**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **PCBC** | `PJS_CN_BASE_CON` | Base Accounting | `BUSINESS_UNIT_ID`, `CONTRACT_ID`, `CONTRACT_LINE_ID`, `TXN_ACCUM_HEADER_ID`, `TRANSACTION_PROJECT_ID`, `CALENDAR_TYPE`, `PERIOD_NAME`, `CURRENCY_TYPE_ID` |

**Calendar Type:**
- `'G'` - General Ledger

**Currency Type ID (bitand logic):**
```sql
-- Use INVERTPEO logic for currency filtering
SELECT 2 CURR_ID FROM DUAL UNION ALL
SELECT 8 CURR_ID FROM DUAL UNION ALL
SELECT 1 CURR_ID FROM DUAL UNION ALL
SELECT 4 CURR_ID FROM DUAL
```

### **Legal Entity**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **LE** | `XLE_ENTITY_PROFILES` | Legal Entities | `LEGAL_ENTITY_ID`, `NAME` |

### **Lookups**

| Alias | Table Name | Purpose | Key Columns |
|-------|------------|---------|-------------|
| **FLVV** | `FND_LOOKUP_VALUES_VL` | Lookup Values (View) | `LOOKUP_TYPE`, `LOOKUP_CODE`, `MEANING`, `ENABLED_FLAG` |
| **FLV** | `FND_LOOKUP_VALUES` | Lookup Values | Same as VL + `LANGUAGE` |
| **FL** | `FND_LOOKUPS` | Lookups | `LOOKUP_TYPE`, `LOOKUP_CODE`, `MEANING`, `ENABLED_FLAG` |
| **FO** | `FND_OBJECTS` | Objects (for security) | `OBJ_NAME`, `PK1_COLUMN_NAME` |

**Common Lookup Types:**
- `'PJO_MNG_BUD_PLAN_STATUS'` - Plan status meanings
- `'PJF_REVENUE_CATEGORY'` - Revenue category meanings
- `'PJB_EVT_INVOICED_FLAG'` - Invoiced flag meanings
- `'POZ_VENDOR_TYPE'` - Vendor types
- `'POZ_CREATION_SOURCE'` - Creation sources

---

## 3. 📊 Critical Patterns & Business Rules

### **A. Latest Project Manager Pattern:**
```sql
-- Use PJF_LATESTPROJECTMANAGER_V for simplicity
SELECT PPAB.PROJECT_ID
      ,PPNF.LIST_NAME AS MANAGER_NAME
      ,PAPF.PERSON_NUMBER
FROM   PJF_PROJECTS_ALL_B PPAB
      ,PJF_LATESTPROJECTMANAGER_V PLV
      ,PER_ALL_PEOPLE_F PAPF
      ,PER_PERSON_NAMES_F_V PPNF
WHERE  PPAB.PROJECT_ID = PLV.PROJECT_ID(+)
  AND  PLV.RESOURCE_SOURCE_ID = PAPF.PERSON_ID(+)
  AND  PLV.RESOURCE_SOURCE_ID = PPNF.PERSON_ID(+)
  AND  TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE(+) AND PAPF.EFFECTIVE_END_DATE(+)
  AND  TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE(+) AND PPNF.EFFECTIVE_END_DATE(+)
```

### **B. Project Director Pattern:**
```sql
-- Use PJF_PROJECT_PARTIES with role filtering
WHERE PPP.PROJECT_PARTY_TYPE = 'IN'
  AND PRT.PROJECT_ROLE_NAME = 'Project Director'
  AND TRUNC(SYSDATE) BETWEEN PPP.START_DATE_ACTIVE AND NVL(PPP.END_DATE_ACTIVE, TO_DATE('4712-12-31','YYYY-MM-DD'))
```

### **C. Latest Budget/Forecast Version:**
```sql
WHERE PPVB.PLAN_CLASS_CODE IN ('BUDGET')
  AND PPVB.PLAN_STATUS_CODE = 'B'
  AND PPVB.SUBMITTED_DATE = (SELECT MAX(SUBMITTED_DATE)
                              FROM PJO_PLAN_VERSIONS_B PPB2
                              WHERE PPB2.PROJECT_ID = PPVB.PROJECT_ID
                                AND PPB2.PLAN_CLASS_CODE = PPVB.PLAN_CLASS_CODE
                                AND PPB2.PLAN_STATUS_CODE = PPVB.PLAN_STATUS_CODE
                                AND PPB2.SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD))
```

### **D. Contingency Extraction:**
```sql
-- Join to RBS elements to find Contingency
WHERE PREV.RBS_ELEMENT_ID = PPL.RBS_ELEMENT_ID
  AND PREV.RBS_ELEMENT_NAME_ID = PRENV.RBS_ELEMENT_NAME_ID
  AND PRENV.NAME = 'Contingency'
```

### **E. Plan Status Decode Logic:**
```sql
-- Complex plan status decode from reference query
(DECODE(PPVL.plan_class_code, 'BUDGET',
        DECODE(PPVL.PLAN_STATUS_CODE, 'W',
               DECODE(PPVL.current_plan_status_flag, 'Y','CW', PPVL.PLAN_STATUS_CODE),
               'B', DECODE(CONCAT(PPVL.current_plan_status_flag, PPVL.original_flag),
                           'YY','COB','YN','CB','NY','OB', PPVL.PLAN_STATUS_CODE)),
        'FORECAST',
        DECODE(PPVL.PLAN_STATUS_CODE, 'W',
               DECODE(PPVL.current_plan_status_flag, 'Y','CW', PPVL.PLAN_STATUS_CODE),
               'B', DECODE(CONCAT(PPVL.current_plan_status_flag, PPVL.original_flag),
                           'YY','COA','YN','CA','NY','OA','PY','POA','PN','PA','A'),
               'S', PPVL.PLAN_STATUS_CODE)
   )
) AS PLAN_STATUS
```

**Plan Status Meanings:**
- `'COB'` - Current and Original Budget
- `'CB'` - Current Budget
- `'OB'` - Original Budget
- `'COA'` - Current and Original Approved (Forecast)
- `'CA'` - Current Approved
- `'OA'` - Original Approved
- `'S'` - Submitted

### **F. Project Category Filtering:**
```sql
-- For financial plans
WHERE PPEV.ELEMENT_TYPE IN ('FINANCIAL','FIN_EXEC')
  AND PPAB.PROJECT_CATEGORY IN ('FINANCIAL','FIN_EXEC')
```

---

## 4. 🔗 Cross-Module Integration

### **Integration with Finance (GL):**
- Link via `HR_ORGANIZATION_INFORMATION_F` → `GL_LEDGERS`
- `ORG_INFORMATION_CONTEXT = 'FUN_BUSINESS_UNIT'`
- `TO_NUMBER(NVL(ORG_INFORMATION3, -1)) = LEDGER_ID`

### **Integration with Contracts:**
- Primary Link: `PJB_CNTRCT_PROJ_LINKS`
- Always filter: `VERSION_TYPE = 'C'`, `ACTIVE_FLAG = 'Y'`

### **Integration with Customers:**
- Method 1: `PJF_PROJECT_PARTIES` → `HZ_PARTIES`
- Method 2: `PJB_BILL_PLANS_B` → `HZ_CUST_ACCOUNTS` → `HZ_PARTIES`

### **Integration with Costing:**
- Via `PJC_EXP_ITEMS_ALL` and `PJC_COST_DIST_LINES_ALL`

### **Integration with AR:**
- Via `PJB_INVOICE_HEADERS.SYSTEM_REFERENCE` → `RA_CUSTOMER_TRX_ALL.CUSTOMER_TRX_ID`

---

## 5. ⚡ Performance Optimization

### **Recommended Hints:**
```sql
/*+ qb_name(CTE_NAME) MATERIALIZE PARALLEL(table_name,4) */
```

### **Large Tables (Use Parallelism):**
- `PJF_PROJECTS_ALL_B` → PARALLEL(2-4)
- `PJC_COST_DIST_LINES_ALL` → PARALLEL(4)
- `PJO_PLAN_LINES` → PARALLEL(2-4)
- `PJB_REV_DISTRIBUTIONS` → PARALLEL(4)
- `PJB_INV_LINE_DISTS` → PARALLEL(4)

### **Materialization:**
- Use `MATERIALIZE` hint for complex CTEs used multiple times
- Especially for: Project base, Customer, Resources CTEs

---

## 6. 🚨 Common Pitfalls

### **❌ AVOID:**
1. **Missing Date-Effectiveness on Person Tables** - Always filter by effective dates
2. **Ignoring ORG_ID** - Always include multi-tenant filtering
3. **Using Old Plan Versions** - Always use `MAX(SUBMITTED_DATE)` for latest version
4. **Including Draft Invoices** - Filter `INVOICE_STATUS_CODE <> 'DRAFT'` for finalized amounts
5. **Missing Overhead Exclusion** - Exclude `EXPENDITURE_TYPE_ID = 300000126235407` for raw cost
6. **Incorrect Assignment Filters** - Always check `ASSIGNMENT_STATUS_TYPE` and `PRIMARY_FLAG`
7. **Ignoring Version Control** - Always use `VERSION_TYPE = 'C'` for current contracts

### **✅ ALWAYS:**
1. Use Oracle Traditional Join Syntax
2. Add `/*+ qb_name() */` to all CTEs
3. Include ORG_ID filtering
4. Filter person tables by effective dates
5. Use `MAX(SUBMITTED_DATE)` for latest plans
6. Handle NULL exchange rates with `NVL(EXCHANGE_RATE, 1)`
7. Use `TO_DATE('4712-12-31','YYYY-MM-DD')` for "end of time" in date ranges

---

## 7. 📝 Standard Column Formatting

### **Date Columns:**
- `TO_CHAR(date, 'YYYY-Mon-DD')` or `TO_CHAR(date, 'DD-fmMON-YYYY')`
- `TO_CHAR(date, 'DD/MM/YYYY')` or `TO_CHAR(date, 'MM/DD/YYYY')`

### **Amount Columns:**
- `ROUND(amount, 2)` for 2 decimal places
- `ROUND(amount, 1)` for summary reports

### **Percentage Columns:**
- `ROUND(percentage * 100, 2)` for display

### **Account Formatting:**
```sql
GCC.SEGMENT1 || '-' || GCC.SEGMENT2 || '-' || GCC.SEGMENT3 || '-' ||
GCC.SEGMENT4 || '-' || GCC.SEGMENT5 || '-' || GCC.SEGMENT6 || '-' ||
GCC.SEGMENT7 || '-' || GCC.SEGMENT8
```

---

**END OF PROJECTS_MASTER.md**
