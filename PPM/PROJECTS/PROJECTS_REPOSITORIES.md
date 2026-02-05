# Projects Repository Patterns

**Purpose:** Standardized CTEs for Project Data.  
**Last Updated:** 22-12-25  
**Validation:** ✅ COMPLETED - All reference queries analyzed

---

## 1. Project Base Master
*Retrieves core project details with status and organization.*

```sql
PRJ_BASE AS (
    SELECT /*+ qb_name(PRJ_BASE) PARALLEL(PJF_PROJECTS_ALL_VL,4) */
           PPAV.PROJECT_ID
          ,PPAV.SEGMENT1                         AS PROJECT_NUMBER
          ,PPAV.NAME                             AS PROJECT_NAME
          ,PPAV.START_DATE
          ,PPAV.COMPLETION_DATE
          ,PPAV.CLOSED_DATE
          ,PPAV.ORG_ID
          ,PPSV.PROJECT_STATUS_NAME
          ,PPTV.PROJECT_TYPE
    FROM   PJF_PROJECTS_ALL_VL PPAV
          ,PJF_PROJECT_STATUSES_VL PPSV
          ,PJF_PROJECT_TYPES_VL PPTV
    WHERE  PPAV.PROJECT_STATUS_CODE              = PPSV.PROJECT_STATUS_CODE
      AND  PPAV.PROJECT_TYPE_ID                  = PPTV.PROJECT_TYPE_ID(+)
      AND  (PPAV.ORG_ID                          IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAV.SEGMENT1                        IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
      AND  (PPSV.PROJECT_STATUS_NAME             IN (:P_STATUS) OR 'All' IN (:P_STATUS || 'All'))
)
```

---

## 2. Project Detailed Information
*Comprehensive project details with manager, BU, and burden schedule.*

```sql
PRJ_DETAILS AS (
    SELECT /*+ qb_name(PRJ_DETAILS) PARALLEL(PJF_PROJECTS_ALL_B,2) */
           PPAB.PROJECT_ID
          ,PPAB.SEGMENT1
          ,PPAT.NAME
          ,PPSV.PROJECT_STATUS_NAME
          ,PPNF.LIST_NAME                        AS MANAGER_NAME
          ,PAPF.PERSON_NUMBER                    AS MANAGER_NUMBER
          ,HAOUT.NAME                            AS BU_NAME
          ,PPAB.ATTRIBUTE1                       AS INTERCOMPANY_CODE
          ,PPTT.PROJECT_TYPE
          ,PIRSV.IND_SCH_NAME                    AS BURDEN_SCHEDULE
          ,PEA.EMAIL_ADDRESS                     AS MGR_EMAIL
          ,PPAB.ORG_ID
    FROM   PJF_PROJECTS_ALL_B PPAB
          ,PJF_LATESTPROJECTMANAGER_V PLV
          ,PJF_PROJECTS_ALL_TL PPAT
          ,PJF_PROJECT_STATUSES_VL PPSV
          ,PER_ALL_PEOPLE_F PAPF
          ,PER_PERSON_NAMES_F_V PPNF
          ,HR_ORGANIZATION_UNITS_F_TL HAOUT
          ,PJF_PROJECT_TYPES_VL PPTT
          ,PJF_IND_RATE_SCH_VL PIRSV
          ,PER_EMAIL_ADDRESSES_V PEA
    WHERE  PPAB.PROJECT_ID                       = PLV.PROJECT_ID(+)
      AND  PPAB.PROJECT_ID                       = PPAT.PROJECT_ID
      AND  (USERENV('LANG'))                     = PPAT.LANGUAGE
      AND  PPAB.PROJECT_STATUS_CODE              = PPSV.PROJECT_STATUS_CODE
      AND  PLV.RESOURCE_SOURCE_ID                = PAPF.PERSON_ID(+)
      AND  PLV.RESOURCE_SOURCE_ID                = PPNF.PERSON_ID(+)
      AND  PPAB.ORG_ID                           = HAOUT.ORGANIZATION_ID(+)
      AND  (USERENV('LANG'))                     = HAOUT.LANGUAGE(+)
      AND  PPAB.PROJECT_TYPE_ID                  = PPTT.PROJECT_TYPE_ID(+)
      AND  PPAB.COST_IND_RATE_SCH_ID             = PIRSV.IND_RATE_SCH_ID(+)
      AND  PAPF.PRIMARY_EMAIL_ID                 = PEA.EMAIL_ADDRESS_ID(+)
      AND  SYSDATE >= PAPF.EFFECTIVE_START_DATE(+)  AND SYSDATE < NVL(PAPF.EFFECTIVE_END_DATE(+), DATE '4712-12-31') + 1
      AND  SYSDATE >= PPNF.EFFECTIVE_START_DATE(+)  AND SYSDATE < NVL(PPNF.EFFECTIVE_END_DATE(+), DATE '4712-12-31') + 1
      AND  SYSDATE >= HAOUT.EFFECTIVE_START_DATE(+) AND SYSDATE < NVL(HAOUT.EFFECTIVE_END_DATE(+), DATE '4712-12-31') + 1
)
```

---

## 3. Project Class - Contract Type
*Retrieves project classification for Contract Type.*

```sql
PRJ_CLASS_CT AS (
    SELECT /*+ qb_name(PRJ_CLASS_CT) PARALLEL(PJF_PROJECT_CLASSES,2) */
           PPC.PROJECT_ID
          ,PCCV.CLASS_CODE
          ,PCLV.CLASS_CATEGORY
    FROM   PJF_PROJECT_CLASSES PPC
          ,PJF_CLASS_CODES_VL PCCV
          ,PJF_CLASS_CATEGORIES_VL PCLV
    WHERE  PPC.CLASS_CODE_ID                     = PCCV.CLASS_CODE_ID
      AND  PPC.CLASS_CATEGORY_ID                 = PCLV.CLASS_CATEGORY_ID
      AND  PCLV.CLASS_CATEGORY                   = 'Contract Type'
)
```

---

## 4. Project Class - Market
*Retrieves project classification for Market segmentation.*

```sql
PRJ_CLASS_MT AS (
    SELECT /*+ qb_name(PRJ_CLASS_MT) PARALLEL(PJF_PROJECT_CLASSES,2) */
           PPC.PROJECT_ID
          ,PCCV.CLASS_CODE                       AS MARKET_CODE
          ,PCLV.CLASS_CATEGORY
    FROM   PJF_PROJECT_CLASSES PPC
          ,PJF_CLASS_CODES_VL PCCV
          ,PJF_CLASS_CATEGORIES_VL PCLV
    WHERE  PPC.CLASS_CODE_ID                     = PCCV.CLASS_CODE_ID
      AND  PPC.CLASS_CATEGORY_ID                 = PCLV.CLASS_CATEGORY_ID
      AND  PCLV.CLASS_CATEGORY                   = 'Market'
)
```

---

## 5. Project Customer Details
*Complex customer identification (both direct and contract-based).*

```sql
PRJ_CUSTOMER AS (
    SELECT /*+ qb_name(PRJ_CUSTOMER) MATERIALIZE PARALLEL(2) */
           PROJECT_ID
          ,PARTY_NUMBER
          ,PARTY_NAME
          ,PARTY_ID
    FROM (
        -- Method 1: Direct from Project Parties
        SELECT /*+ qb_name(PRJ_CUST_A) PARALLEL(PJF_PROJECT_PARTIES,2) */
               PPAB.PROJECT_ID
              ,HP.PARTY_NUMBER
              ,HP.PARTY_NAME
              ,HP.PARTY_ID
        FROM   PJF_PROJECT_PARTIES PPP
              ,HZ_PARTIES HP
              ,PJF_PROJECTS_ALL_B PPAB
        WHERE  PPP.PROJECT_PARTY_TYPE            = 'CO'
          AND  PPP.RESOURCE_SOURCE_ID            = HP.PARTY_ID
          AND  PPP.PROJECT_ID                    = PPAB.PROJECT_ID
          AND  (PPAB.CLIN_LINKED_CODE            IS NULL
                OR (PPAB.CLIN_LINKED_CODE        IS NOT NULL
                    AND NOT EXISTS (
                        SELECT 1
                        FROM   PJB_CNTRCT_PROJ_LINKS
                              ,OKC_K_LINES_B
                        WHERE  PJB_CNTRCT_PROJ_LINKS.PROJECT_ID = PPAB.PROJECT_ID
                          AND  PJB_CNTRCT_PROJ_LINKS.ACTIVE_FLAG = 'Y'
                          AND  PJB_CNTRCT_PROJ_LINKS.MAJOR_VERSION = OKC_K_LINES_B.MAJOR_VERSION
                          AND  OKC_K_LINES_B.ID          = PJB_CNTRCT_PROJ_LINKS.CONTRACT_LINE_ID
                          AND  OKC_K_LINES_B.VERSION_TYPE IN ('A', 'C')
                          AND  OKC_K_LINES_B.STS_CODE    IN ('ACTIVE', 'EXPIRED', 'HOLD', 'CLOSED')
                    )
                   )
               )
        
        UNION ALL
        
        -- Method 2: From Contract Billing Plans
        SELECT DISTINCT /*+ qb_name(PRJ_CUST_B) PARALLEL(PJB_CNTRCT_PROJ_LINKS,2) */
               PPAB.PROJECT_ID
              ,HP.PARTY_NUMBER
              ,HP.PARTY_NAME
              ,HP.PARTY_ID
        FROM   PJB_CNTRCT_PROJ_LINKS PCPL
              ,PJB_BILL_PLANS_B PBPB
              ,OKC_K_HEADERS_ALL_B OKHAB
              ,OKC_K_LINES_B OKLB
              ,HZ_PARTIES HP
              ,HZ_CUST_ACCOUNTS HCA
              ,PJF_PROJECTS_ALL_B PPAB
        WHERE  PPAB.PROJECT_ID                   = PCPL.PROJECT_ID
          AND  OKHAB.ID                          = PCPL.CONTRACT_ID
          AND  OKHAB.MAJOR_VERSION               = PCPL.MAJOR_VERSION
          AND  OKHAB.TEMPLATE_YN                 = 'N'
          AND  OKLB.ID                           = PCPL.CONTRACT_LINE_ID
          AND  OKLB.VERSION_TYPE                 IN ('A', 'C')
          AND  OKLB.STS_CODE                     IN ('ACTIVE', 'EXPIRED', 'HOLD', 'CLOSED')
          AND  OKLB.MAJOR_VERSION                = PCPL.MAJOR_VERSION
          AND  PBPB.BILL_PLAN_ID                 = OKLB.BILL_PLAN_ID
          AND  PBPB.MAJOR_VERSION                = OKLB.MAJOR_VERSION
          AND  PCPL.ACTIVE_FLAG                  = 'Y'
          AND  HCA.CUST_ACCOUNT_ID               = PBPB.BILL_TO_CUST_ACCT_ID
          AND  HCA.PARTY_ID                      = HP.PARTY_ID
          AND  PPAB.CLIN_LINKED_CODE             IS NOT NULL
    )
)
```

---

## 6. Project Resources (Team Members)
*Retrieves active project team members with contact details.*

```sql
PRJ_RESOURCE AS (
    SELECT /*+ qb_name(PRJ_RESOURCE) MATERIALIZE PARALLEL(2) */
           PPP.PROJECT_PARTY_ID
          ,PPP.PROJECT_ID
          ,PPP.RESOURCE_SOURCE_ID
          ,PAP.PERSON_NUMBER                     AS RESOURCE_SOURCE_NUMBER
          ,PPN.LIST_NAME                         AS RESOURCE_SOURCE_NAME
          ,PPP.PROJECT_PARTY_TYPE
          ,PPP.PROJECT_ROLE_ID
          ,PRT.PROJECT_ROLE_NAME
          ,PRT.DESCRIPTION                       AS PROJECT_ROLE_DESCRIPTION
          ,HRO.NAME                              AS ORGANIZATION_NAME
          ,PPH.PHONE_NUMBER
          ,PEA.EMAIL_ADDRESS                     AS DIR_EMAIL
          ,PPJ.NAME                              AS JOB_TITLE
          ,(CASE WHEN SYSDATE BETWEEN PPP.START_DATE_ACTIVE
                                  AND NVL(PPP.END_DATE_ACTIVE, DATE '4712-12-31')
                 THEN 'Y' ELSE 'N' END)          AS ACTIVE_FLAG
    FROM   PJF_PROJECT_PARTIES PPP
          ,PER_ALL_PEOPLE_F PAP
          ,PER_PERSON_NAMES_F_V PPN
          ,PJF_PROJ_ROLE_TYPES_VL PRT
          ,PER_PHONES_V PPH
          ,PER_EMAIL_ADDRESSES_V PEA
          ,PER_ALL_ASSIGNMENTS_F PAA
          ,PER_DEPARTMENTS HRO
          ,PER_JOBS_F_VL PPJ
    WHERE  PPP.RESOURCE_SOURCE_ID                = PAP.PERSON_ID
      AND  PAP.PERSON_ID                         = PPN.PERSON_ID
      AND  PPP.PROJECT_ROLE_ID                   = PRT.PROJECT_ROLE_ID
      AND  PAP.PRIMARY_PHONE_ID                  = PPH.PHONE_ID(+)
      AND  PAP.PRIMARY_EMAIL_ID                  = PEA.EMAIL_ADDRESS_ID(+)
      AND  PPP.RESOURCE_SOURCE_ID                = PAA.PERSON_ID(+)
      AND  PAA.ORGANIZATION_ID                   = HRO.ORGANIZATION_ID(+)
      AND  PAA.JOB_ID                            = PPJ.JOB_ID(+)
      AND  GREATEST(SYSDATE, PPP.START_DATE_ACTIVE) >= PAP.EFFECTIVE_START_DATE
      AND  GREATEST(SYSDATE, PPP.START_DATE_ACTIVE) < NVL(PAP.EFFECTIVE_END_DATE, DATE '4712-12-31') + 1
      AND  GREATEST(SYSDATE, PPP.START_DATE_ACTIVE) >= PPN.EFFECTIVE_START_DATE
      AND  GREATEST(SYSDATE, PPP.START_DATE_ACTIVE) < NVL(PPN.EFFECTIVE_END_DATE, DATE '4712-12-31') + 1
      AND  PPP.START_DATE_ACTIVE                 >= PAA.EFFECTIVE_START_DATE(+)
      AND  PPP.START_DATE_ACTIVE                 < NVL(PAA.EFFECTIVE_END_DATE(+), DATE '4712-12-31') + 1
      AND  (PAA.ASSIGNMENT_STATUS_TYPE           IN ('ACTIVE','SUSPENDED'))
      AND  PPP.START_DATE_ACTIVE                 >= HRO.EFFECTIVE_START_DATE(+)
      AND  PPP.START_DATE_ACTIVE                 < NVL(HRO.EFFECTIVE_END_DATE(+), DATE '4712-12-31') + 1
      AND  PPP.START_DATE_ACTIVE                 >= PPJ.EFFECTIVE_START_DATE(+)
      AND  PPP.START_DATE_ACTIVE                 < NVL(PPJ.EFFECTIVE_END_DATE(+), DATE '4712-12-31') + 1
      AND  SYSDATE BETWEEN PPP.START_DATE_ACTIVE AND NVL(PPP.END_DATE_ACTIVE, DATE '4712-12-31')
      AND  PPP.PROJECT_PARTY_TYPE                = 'IN'
      AND  NVL(PAA.PRIMARY_FLAG,'Y')             = 'Y'
      AND  NVL(PAA.ASSIGNMENT_TYPE,'E')          IN ('E','C')
)
```

---

## 7. Budget Plan Base
*Base CTE for budget and forecast data.*

```sql
PRJ_PLAN_BASE AS (
    SELECT /*+ qb_name(PRJ_PLAN_BASE) MATERIALIZE PARALLEL(PJO_PLAN_LINES,4) */
           PPVV.PROJECT_ID
          ,PPVV.PLAN_CLASS_CODE
          ,PPL.TOTAL_TC_RAW_COST
          ,PPL.TOTAL_TC_BRDND_COST
          ,PPL.TOTAL_TC_REVENUE
          ,PPVV.PLAN_STATUS_CODE
          ,PPVV.CURRENT_PLAN_STATUS_FLAG
          ,PPVV.SUBMITTED_DATE
    FROM   PJO_PLAN_LINES PPL
          ,PJO_PLANNING_ELEMENTS PPE
          ,PJO_PLAN_VERSIONS_VL PPVV
          ,PJF_PROJECTS_ALL_VL PPAV
    WHERE  PPL.PLANNING_ELEMENT_ID               = PPE.PLANNING_ELEMENT_ID
      AND  PPL.PLAN_VERSION_ID                   = PPE.PLAN_VERSION_ID
      AND  PPE.PLAN_VERSION_ID                   = PPVV.PLAN_VERSION_ID
      AND  PPE.PROJECT_ID                        = PPVV.PROJECT_ID
      AND  PPVV.PROJECT_ID                       = PPAV.PROJECT_ID
      AND  PPVV.PLAN_CLASS_CODE                  IN ('BUDGET','FORECAST')
      AND  (PPAV.ORG_ID                          IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))
      AND  (PPAV.SEGMENT1                        IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
)
```

---

## 8. Latest Budget
*Latest baselined budget for a given period.*

```sql
PRJ_BUDGET AS (
    SELECT /*+ qb_name(PRJ_BUDGET) PARALLEL(2) */
           PPB.PROJECT_ID
          ,SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))                                    AS BUDGET_RAW_COST
          ,(SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0)) - SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))) AS BUDGET_BURDEN_COST
          ,SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0))                                  AS BUDGET_TOTAL_COST
          ,SUM(NVL(PPB.TOTAL_TC_REVENUE,0))                                     AS BUDGET_REVENUE
    FROM   PRJ_PLAN_BASE PPB
    WHERE  PPB.PLAN_CLASS_CODE                   IN ('BUDGET')
      AND  PPB.PLAN_STATUS_CODE                  = 'B'
      AND  PPB.SUBMITTED_DATE                    = (SELECT MAX(SUBMITTED_DATE)
                                                     FROM PRJ_PLAN_BASE PPB2
                                                     WHERE PPB2.PROJECT_ID = PPB.PROJECT_ID
                                                       AND PPB2.PLAN_CLASS_CODE = PPB.PLAN_CLASS_CODE
                                                       AND PPB2.PLAN_STATUS_CODE = PPB.PLAN_STATUS_CODE
                                                       AND PPB2.SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD))
    GROUP BY PPB.PROJECT_ID
)
```

---

## 9. Latest Forecast (Cumulative)
*Latest baselined forecast (inception-to-date).*

```sql
PRJ_FORECAST AS (
    SELECT /*+ qb_name(PRJ_FORECAST) PARALLEL(2) */
           PPB.PROJECT_ID
          ,SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))                                    AS FORECAST_RAW_COST
          ,(SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0)) - SUM(NVL(PPB.TOTAL_TC_RAW_COST,0))) AS FORECAST_BURDEN_COST
          ,SUM(NVL(PPB.TOTAL_TC_BRDND_COST,0))                                  AS FORECAST_TOTAL_COST
          ,SUM(NVL(PPB.TOTAL_TC_REVENUE,0))                                     AS FORECAST_REVENUE
    FROM   PRJ_PLAN_BASE PPB
    WHERE  PPB.PLAN_CLASS_CODE                   IN ('FORECAST')
      AND  PPB.PLAN_STATUS_CODE                  = 'B'
      AND  PPB.SUBMITTED_DATE                    = (SELECT MAX(SUBMITTED_DATE)
                                                     FROM PRJ_PLAN_BASE PPB2
                                                     WHERE PPB2.PROJECT_ID = PPB.PROJECT_ID
                                                       AND PPB2.PLAN_CLASS_CODE = PPB.PLAN_CLASS_CODE
                                                       AND PPB2.PLAN_STATUS_CODE = PPB.PLAN_STATUS_CODE
                                                       AND PPB2.SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD))
    GROUP BY PPB.PROJECT_ID
)
```

---

## 10. Contingency Details
*Extracts contingency from forecast plans.*

```sql
PRJ_CONTINGENCY AS (
    SELECT /*+ qb_name(PRJ_CONTINGENCY) PARALLEL(2) */
           PSB.PROJECT_ID
          ,SUM(NVL(PSB.TOTAL_PFC_REVENUE,0))     AS REVENUE_CON
          ,SUM(NVL(PSB.TOTAL_PFC_RAW_COST,0))    AS RAW_COST_CON
          ,SUM(NVL(PSB.TOTAL_PFC_BRDND_COST,0))  AS TOTAL_COST_CON
          ,(SUM(NVL(PSB.TOTAL_PFC_BRDND_COST,0)) - SUM(NVL(PSB.TOTAL_PFC_RAW_COST,0))) AS BURDEN_COST_CON
    FROM   PRJ_CONT_SUB PSB
          ,PJF_RBS_ELEMENTS_VL PREV
          ,PJF_RBS_ELEMENT_NAMES_VL PRENV
    WHERE  PSB.RBS_ELEMENT_ID                    = PREV.RBS_ELEMENT_ID
      AND  PREV.RBS_ELEMENT_NAME_ID              = PRENV.RBS_ELEMENT_NAME_ID
      AND  PRENV.NAME                            = 'Contingency'
    GROUP BY PSB.PROJECT_ID
)
```

---

## 11. Project Contract Links
*Links projects to contracts for performance reporting.*

```sql
PRJ_CON_COST_LINK AS (
    -- For non-CLIN projects
    SELECT PCPL.CONTRACT_ID
          ,PCPL.CONTRACT_LINE_ID
          ,PCPL.ACTIVE_FLAG
          ,PPAB.PROJECT_ID
          ,PPEB.PROJ_ELEMENT_ID                  AS TASK_ID
          ,PCPL.PROJ_ELEMENT_ID                  AS ASSOCIATED_TASK_ID
    FROM   PJB_CNTRCT_PROJ_LINKS PCPL
          ,PJF_PROJECTS_ALL_B PPAB
          ,PJF_PROJ_ELEMENTS_B PPEB
    WHERE  PPAB.PROJECT_ID                       = PCPL.PROJECT_ID
      AND  PPEB.PROJECT_ID                       = PPAB.PROJECT_ID
      AND  NVL(PPAB.CLIN_LINKED_CODE,'P')        = 'P'
      AND  PCPL.BILLING_TYPE_CODE                IN ('EX', 'IP')
      AND  PCPL.VERSION_TYPE                     = 'C'
      AND  (PPAB.ORG_ID                          IN (:P_PRJ_BU) OR 'All' IN (:P_PRJ_BU || 'All'))
      AND  (PCPL.PROJECT_ID                      IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
    
    UNION ALL
    
    -- For CLIN projects
    SELECT PCPL.CONTRACT_ID
          ,PCPL.CONTRACT_LINE_ID
          ,PCPL.ACTIVE_FLAG
          ,PPAB.PROJECT_ID
          ,PPEB.PROJ_ELEMENT_ID                  AS TASK_ID
          ,PCPL.PROJ_ELEMENT_ID                  AS ASSOCIATED_TASK_ID
    FROM   PJB_CNTRCT_PROJ_LINKS PCPL
          ,PJF_PROJECTS_ALL_B PPAB
          ,PJF_PROJ_ELEMENTS_B PPEB
    WHERE  PPAB.PROJECT_ID                       = PCPL.PROJECT_ID
      AND  PPAB.PROJECT_ID                       = PPEB.PROJECT_ID
      AND  NVL(PPAB.CLIN_LINKED_CODE,'T')        = 'T'
      AND  PPEB.CLIN_ELEMENT_ID                  = PCPL.PROJ_ELEMENT_ID
      AND  PCPL.BILLING_TYPE_CODE                IN ('EX', 'IP')
      AND  PCPL.VERSION_TYPE                     = 'C'
      AND  (PPAB.ORG_ID                          IN (:P_PRJ_BU) OR 'All' IN (:P_PRJ_BU || 'All'))
      AND  (PCPL.PROJECT_ID                      IN (:P_PRJ_NUM) OR 'All' IN (:P_PRJ_NUM || 'All'))
)
```

---

## 12. Revenue Distribution Details
*Cumulative revenue recognized by project.*

```sql
PRJ_REVENUE AS (
    SELECT /*+ qb_name(PRJ_REVENUE_BASE) PARALLEL(PJB_REV_DISTRIBUTIONS,4) */
           PRD.TRANSACTION_PROJECT_ID            AS PROJECT_ID
          ,SUM(NVL(PRD.TRNS_CURR_REVENUE_AMT,0)) AS TRNS_CURR_REVENUE_AMT
          ,SUM(NVL(PRD.LEDGER_CURR_REVENUE_AMT,0)) AS LEDGER_CURR_REVENUE_AMT
    FROM   PJB_REV_DISTRIBUTIONS PRD
    WHERE  TRUNC(PRD.GL_DATE)                    <= LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PRD.TRANSACTION_PROJECT_ID
)
```

---

## 13. Invoice Amount Details
*Cumulative invoiced amount by project.*

```sql
PRJ_INVOICE AS (
    SELECT /*+ qb_name(PRJ_INVOICE) PARALLEL(PJB_INV_LINE_DISTS,4) */
           PILD.TRANSACTION_PROJECT_ID           AS PROJECT_ID
          ,SUM(NVL(PILD.TRNS_CURR_BILLED_AMT,0)) AS TRNS_CURR_INV_AMT
          ,SUM(NVL(PILD.LEDGER_CURR_BILLED_AMT,0)) AS LEDGER_CURR_INV_AMT
    FROM   PJB_INV_LINE_DISTS PILD
    WHERE  TRUNC(PILD.INVOICE_DATE)              <= LAST_DAY(:P_REPORT_PERIOD)
    GROUP BY PILD.TRANSACTION_PROJECT_ID
)
```

---

## 14. Contract Details
*Contract header and line details with customer.*

```sql
OKC_CONTRACT_DETAILS AS (
    SELECT CONTRACTS.CONTRACT_NUMBER
          ,CONTRACTS.CONTRACT_LINE_NUMBER
          ,CONTRACTS.CONTRACT_TYPE
          ,CONTRACTS.CONTRACT_AMOUNT
          ,CUSTOMERS.CUSTOMER_NUMBER
          ,CUSTOMERS.CUSTOMER_NAME
          ,CONTRACTS.CONTRACT_ID
          ,CONTRACTS.CONTRACT_LINE_ID
          ,CONTRACTS.CONTRACT_TYPE_ID
          ,CONTRACTS.MAJOR_VERSION
    FROM (
        SELECT OKHV.ID                           AS CONTRACT_ID
              ,OKLV.ID                           AS CONTRACT_LINE_ID
              ,OKHV.CONTRACT_TYPE_ID
              ,OKLV.MAJOR_VERSION
              ,OKHV.CONTRACT_NUMBER
              ,OKLV.LINE_NUMBER                  AS CONTRACT_LINE_NUMBER
              ,OKLV.LINE_AMOUNT                  AS CONTRACT_AMOUNT
              ,OCTV.NAME                         AS CONTRACT_TYPE
              ,HZCA.PARTY_ID
        FROM   OKC_K_LINES_VL OKLV
              ,OKC_K_HEADERS_VL OKHV
              ,PJB_BILL_PLANS_VL PBPV
              ,OKC_CONTRACT_TYPES_VL OCTV
              ,HZ_CUST_ACCOUNTS HZCA
        WHERE  OKLV.DNZ_CHR_ID                   = OKHV.ID
          AND  OKLV.MAJOR_VERSION                = OKHV.MAJOR_VERSION
          AND  OKLV.BILL_PLAN_ID                 = PBPV.BILL_PLAN_ID(+)
          AND  OKLV.MAJOR_VERSION                = PBPV.MAJOR_VERSION(+)
          AND  OKHV.CONTRACT_TYPE_ID             = OCTV.CONTRACT_TYPE_ID(+)
          AND  PBPV.BILL_TO_CUST_ACCT_ID         = HZCA.CUST_ACCOUNT_ID(+)
          AND  ((OKLV.VERSION_TYPE = 'C')        OR (OKLV.VERSION_TYPE IS NULL))
          AND  ((OKHV.VERSION_TYPE = 'C')        OR (OKHV.VERSION_TYPE IS NULL))
          AND  ((OKHV.TEMPLATE_YN = 'N')         OR (OKHV.TEMPLATE_YN IS NULL))
          AND  ((OKLV.JTOT_OBJECT1_CODE = 'USER_FREE_FORM_PROJECT_BASED')
                OR (OKLV.JTOT_OBJECT1_CODE = 'USER_ITEM_PROJECT_BASED'))
    ) CONTRACTS
    ,(
        SELECT HZP.PARTY_ID
              ,HZP.PARTY_NAME                    AS CUSTOMER_NAME
              ,HZP.PARTY_NUMBER                  AS CUSTOMER_NUMBER
        FROM   HZ_PARTIES HZP
              ,HZ_ORGANIZATION_PROFILES HZOP
              ,(
                SELECT HZCA.CODE_ASSIGNMENT_ID
                      ,HZCA.OWNER_TABLE_ID
                FROM   HZ_CODE_ASSIGNMENTS HZCA
                WHERE  HZCA.CLASS_CATEGORY       = 'ORGANIZATION_TYPE'
                  AND  HZCA.OWNER_TABLE_NAME     = 'HZ_PARTIES'
                  AND  HZCA.PRIMARY_FLAG         = 'Y'
                  AND  HZCA.STATUS               = 'A'
               ) HZC
        WHERE  HZP.PARTY_ID                      = HZOP.PARTY_ID(+)
          AND  HZP.PARTY_ID                      = HZC.OWNER_TABLE_ID(+)
          AND  TRUNC(SYSDATE)                    BETWEEN HZOP.EFFECTIVE_START_DATE(+) AND HZOP.EFFECTIVE_END_DATE(+)
          AND  HZOP.EFFECTIVE_LATEST_CHANGE(+)   = 'Y'
    ) CUSTOMERS
    WHERE CONTRACTS.PARTY_ID                     = CUSTOMERS.PARTY_ID(+)
)
```

---

**END OF PROJECTS_REPOSITORIES.md**

**Note:** All CTEs use Oracle Traditional Join Syntax and include appropriate performance hints (`/*+ qb_name() PARALLEL() MATERIALIZE */`). Always apply multi-tenant filtering (`ORG_ID IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All')`) and date-effectiveness for person tables.
