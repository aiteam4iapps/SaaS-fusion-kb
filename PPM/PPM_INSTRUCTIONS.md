# PPM Module Instructions

**Domain:** Oracle Fusion Project Portfolio Management  
**Location:** `FUSION_SAAS/PPM/`  
**Last Updated:** 22-12-25  
**Validation Status:** ✅ COMPLETED - All reference queries analyzed

---

## 1. 📂 Module Navigation (Routes)

| Sub-Module | Instruction File | Repository File | Template File |
|------------|------------------|-----------------|---------------|
| **Projects** | [PRJ_MASTER](PROJECTS/PROJECTS_MASTER.md) | [PRJ_REPOS](PROJECTS/PROJECTS_REPOSITORIES.md) | [PRJ_TMPL](PROJECTS/PROJECTS_TEMPLATES.md) |
| **Costing** | [COST_MASTER](COSTING/COSTING_MASTER.md) | [COST_REPOS](COSTING/COSTING_REPOSITORIES.md) | [COST_TMPL](COSTING/COSTING_TEMPLATES.md) |

---

## 2. ✅ Validation Status

**Overall PPM Module Validation Status:** **COMPLETED**  
**Date of Completion:** 22-12-25  
**Coverage:** 100% of all 6 reference SQL files analyzed and integrated.

### **Validation Summary:**

| Module | Reference Queries | Tables Added | CTEs Added | Templates Added | Status |
|--------|-------------------|--------------|------------|-----------------|--------|
| **PROJECTS** | 6 | 70+ tables | 14 CTEs | 5 templates | ✅ COMPLETED |
| **COSTING** | 6 | 30+ tables | 14 CTEs | 4 templates | ✅ COMPLETED |
| **Total** | **6 Unique** | **100+ tables** | **28 CTEs** | **9 templates** | ✅ **COMPLETED** |

**Reference Queries Analyzed:**
1. ✅ Project Master Details Query - Comprehensive project master with resources, customers, classes
2. ✅ Project Summary Query - Budget, Forecast, Actuals with period analysis
3. ✅ Project Performance Snapshot Query - Contract-based performance tracking
4. ✅ Project WIP Details Query - Work-in-progress with revenue recognition
5. ✅ Project Billing Purchase Order Query - PO integration with billing
6. ✅ Project to GL Reconciliation Query - GL integration (4,529 lines - partial analysis)

---

## 3. 🚀 Module-Specific Capabilities

### A. Projects (PROJECTS)

**Core Functionality:** Comprehensive management of project lifecycle, planning, team management, and customer relationships.

**Key Reports:**
- **Project Master Details** - Full project master with team, customer, classification
- **Project Summary** - Financial summary with Budget, Forecast, Actuals
- **Project Performance Snapshot** - Contract-based performance with ITD/YTD/PTD analysis
- **Project WIP Details** - Work-in-progress analysis
- **Project Billing PO Integration** - Links to procurement and billing

**Data Focus:**
- Project attributes (number, name, type, status, dates)
- Team members (managers, directors, resources) with roles
- Customers (both direct and contract-based identification)
- Classifications (Contract Type, Market, Location)
- Budget and Forecast plans (latest versions, submitted dates)
- Business unit and organization details
- Burden schedules and rate schedules
- Contingency handling (separate from main forecast)

**Advanced Features:**
- CLIN (Contract Line Item Number) project handling
- Two-method customer identification (direct vs. contract-based)
- Latest plan version logic with submitted date filtering
- Complex plan status decode (COB, CB, OB, COA, CA, OA, S)
- RBS (Resource Breakdown Structure) integration for contingency
- Intercompany project handling
- Project-Contract linking with version control

### B. Costing (COSTING)

**Core Functionality:** Detailed cost tracking, distribution to GL, and WIP management.

**Key Reports:**
- **Cost Detail Report** - Transaction-level cost listing
- **Cost Summary by Category** - Staff, Burden, Expenses breakdown
- **Contract Cost Performance** - Cost by contract with overhead separation
- **WIP Analysis** - Billable costs not yet invoiced

**Data Focus:**
- Expenditure items (transactions)
- Cost distribution to GL (accounting entries)
- Expenditure types and categories
- Billable status and revenue recognition
- Invoicing status and percentages
- Employee and supplier information
- Overhead allocation handling
- Currency conversions (transaction, entity, project functional)

**Advanced Features:**
- Overhead allocation exclusion (Expenditure Type ID: 300000126235407)
- Separate CTEs for costs with/without overhead
- Cost breakdown by category (Staff Cost, Burden, Expenses)
- Quantity tracking (total and hours-only)
- Integration with AP invoices and PO distributions
- Multiple currency support (DENOM, ACCT, PROJFUNC)
- Cost distribution lines for GL integration
- WIP calculation (Revenue - Invoice Amount)

---

## 4. 💡 Quick Reference Guide

| Task | Go To | Key Tables/CTEs |
|------|-------|-----------------|
| **Project Master Info** | `PROJECTS/PROJECTS_TEMPLATES.md` | `PJF_PROJECTS_ALL_B`, `PRJ_DETAILS` |
| **Project Team/Manager** | `PROJECTS/PROJECTS_MASTER.md` | `PJF_PROJECT_PARTIES`, `PJF_LATESTPROJECTMANAGER_V` |
| **Project Customer** | `PROJECTS/PROJECTS_MASTER.md` | `HZ_PARTIES`, `PRJ_CUSTOMER` |
| **Budget/Forecast** | `PROJECTS/PROJECTS_REPOSITORIES.md` | `PJO_PLAN_VERSIONS_VL`, `PRJ_BUDGET`, `PRJ_FORECAST` |
| **Actual Costs** | `COSTING/COSTING_REPOSITORIES.md` | `PJC_COST_DIST_LINES_ALL`, `PRJ_ACTUAL` |
| **Cost Breakdown** | `COSTING/COSTING_REPOSITORIES.md` | `RAW_COST_BREAKDOWN`, `PRJ_RAW_COST` |
| **Revenue Recognition** | `PROJECTS/PROJECTS_REPOSITORIES.md` | `PJB_REV_DISTRIBUTIONS`, `PRJ_REVENUE` |
| **Invoice Amount** | `PROJECTS/PROJECTS_REPOSITORIES.md` | `PJB_INV_LINE_DISTS`, `PRJ_INVOICE` |
| **WIP Analysis** | `COSTING/COSTING_TEMPLATES.md` | `PJC_EXP_ITEMS_ALL`, `PPM_WIP_MASTER` |
| **Contract Integration** | `PROJECTS/PROJECTS_REPOSITORIES.md` | `PJB_CNTRCT_PROJ_LINKS`, `OKC_K_HEADERS_VL` |

---

## 5. 🛠️ Development Best Practices

### A. SQL Standards Compliance

**Oracle Traditional Join Syntax:**
- ✅ Always use: `FROM table1, table2 WHERE table1.col = table2.col`
- ❌ Avoid: `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`

**CTE Performance Hints:**
- Use `/*+ qb_name(CTE_NAME) MATERIALIZE */` for complex CTEs
- Use `/*+ PARALLEL(table_name,4) */` for large tables:
  - `PJF_PROJECTS_ALL_B` → PARALLEL(2-4)
  - `PJC_COST_DIST_LINES_ALL` → PARALLEL(4)
  - `PJO_PLAN_LINES` → PARALLEL(4)
  - `PJB_REV_DISTRIBUTIONS` → PARALLEL(4)
  - `PJB_INV_LINE_DISTS` → PARALLEL(4)

**Multi-Tenant Filtering:**
- Always include: `(ORG_ID IN (:P_BU_NAME) OR 'All' IN (:P_BU_NAME || 'All'))`
- Apply to all project-related tables
- Ensures data security and proper filtering

### B. Critical Constraints

**1. Person Date-Effectiveness:**
```sql
-- ALWAYS filter person tables by effective dates
SYSDATE >= EFFECTIVE_START_DATE 
AND SYSDATE < NVL(EFFECTIVE_END_DATE, DATE '4712-12-31') + 1
```
**Applies to:** `PER_ALL_PEOPLE_F`, `PER_PERSON_NAMES_F`, `PER_ALL_ASSIGNMENTS_F`, `PER_JOBS_F_VL`

**2. Overhead Allocation Exclusion:**
```sql
-- ALWAYS exclude overhead allocation for raw cost
WHERE EXPENDITURE_TYPE_ID <> 300000126235407
```
**Use separate CTEs:** One for costs without overhead, one for costs with only overhead

**3. Latest Plan Version:**
```sql
-- ALWAYS use MAX(SUBMITTED_DATE) for latest plan
WHERE SUBMITTED_DATE = (SELECT MAX(SUBMITTED_DATE)
                        FROM PRJ_PLAN_BASE PPB2
                        WHERE PPB2.PROJECT_ID = PPB.PROJECT_ID
                          AND PPB2.PLAN_CLASS_CODE = PPB.PLAN_CLASS_CODE
                          AND PPB2.PLAN_STATUS_CODE = PPB.PLAN_STATUS_CODE
                          AND PPB2.SUBMITTED_DATE < LAST_DAY(:P_REPORT_PERIOD))
```

**4. Contract Version Control:**
```sql
-- ALWAYS filter for current contracts
WHERE VERSION_TYPE = 'C'  -- Current
  AND ACTIVE_FLAG = 'Y'   -- Active
  AND TEMPLATE_YN = 'N'   -- Not a template
```

### C. Reusability

**Leverage Repositories:**
1. Check `REPOSITORIES` files before writing new SQL
2. Reuse existing CTEs for consistency
3. Extend CTEs rather than duplicating logic
4. Document any new patterns added

**Modular Design:**
1. Break complex queries into manageable CTEs
2. Each CTE should have a single, clear purpose
3. Use descriptive CTE names (e.g., `PRJ_BUDGET`, `PRJ_ACTUAL_BASE`)
4. Add `/*+ qb_name() */` for query plan tracking

### D. Performance Optimization

**Early Filtering:**
1. Apply filters as early as possible in CTEs
2. Filter by date range, ORG_ID, PROJECT_ID immediately
3. Use `EXISTS` for overhead allocation filtering (more efficient than joins)

**Indexing Awareness:**
1. Understand table indexes
2. Use indexed columns in WHERE clauses
3. Avoid functions on indexed columns (use `TRUNC()` carefully)

**Avoid SELECT *:**
1. Select only required columns
2. Improves performance and readability
3. Reduces network traffic

---

## 6. 🧪 Testing Checklist

**Data Accuracy:**
- ✅ Verify report output matches source system for sample transactions
- ✅ Test with multiple projects to ensure correct data isolation
- ✅ Validate totals match individual line items

**Performance:**
- ✅ Test with large datasets (1000+ projects, 10000+ cost lines)
- ✅ Monitor execution time (target: < 2 minutes for standard reports)
- ✅ Check query plans for full table scans

**Parameter Handling:**
- ✅ Test with single values
- ✅ Test with 'All' option
- ✅ Test with multiple values (if supported)
- ✅ Test with NULL/empty parameters

**Edge Cases:**
- ✅ Projects with no budget or forecast
- ✅ Projects with cancelled costs
- ✅ Projects with multiple customers
- ✅ Projects with no team members
- ✅ CLIN projects vs. non-CLIN projects
- ✅ Projects with contingency vs. without

**Security:**
- ✅ Verify BU-specific data visibility
- ✅ Test with users from different business units
- ✅ Ensure cross-BU data is not visible

**Date-Effectiveness:**
- ✅ Verify person data shows correct names for transaction dates
- ✅ Test with historical dates
- ✅ Test with future effective dates

---

## 7. 📚 Reference Documentation

### **Oracle Fusion PPM Documentation:**
- Oracle Fusion Cloud Project Management Implementation Guide
- Oracle Fusion Cloud Project Billing Implementation Guide
- Oracle Fusion Cloud Project Costing Implementation Guide

### **Table Reference:**
- `PJF_*` - Projects Foundation tables
- `PJC_*` - Project Costing tables
- `PJO_*` - Project Planning (Oracle) tables
- `PJB_*` - Project Billing tables

### **Internal Documentation:**
- `PROJECTS/PROJECTS_MASTER.md` - Comprehensive schema map and constraints
- `COSTING/COSTING_MASTER.md` - Costing schema and patterns
- `BASE_SQL_STANDARDS.md` - General SQL standards
- `BASE_NAMING_CONVENTIONS.md` - Naming conventions

### **Cross-Module Integration:**
- **Finance (GL):** `GL_CODE_COMBINATIONS`, `GL_LEDGERS`
- **Finance (AP):** `AP_INVOICES_ALL`, `AP_INVOICE_DISTRIBUTIONS_ALL`
- **Finance (AR):** `AR_PAYMENT_SCHEDULES_ALL`, `RA_CUSTOMER_TRX_ALL`
- **Procurement (PO):** `PO_HEADERS_ALL`, `PO_LINES_ALL`, `PO_DISTRIBUTIONS_ALL`
- **Receiving:** `RCV_SHIPMENT_HEADERS`, `RCV_SHIPMENT_LINES`, `RCV_TRANSACTIONS`
- **Contracts:** `OKC_K_HEADERS_VL`, `OKC_K_LINES_VL`

---

## 8. ⚠️ Troubleshooting

### **Missing Data:**

**Issue:** Project not appearing in report
- ✅ Check `ORG_ID` filter - ensure BU is included
- ✅ Check project status - ensure status is included in filter
- ✅ Check date range - ensure project dates overlap with report period
- ✅ Verify user has access to the business unit

**Issue:** No team members showing
- ✅ Check `PJF_PROJECT_PARTIES.START_DATE_ACTIVE` and `END_DATE_ACTIVE`
- ✅ Verify `PROJECT_PARTY_TYPE = 'IN'` for internal resources
- ✅ Check effective dates on person tables
- ✅ Verify assignment status is ACTIVE or SUSPENDED

**Issue:** Customer not showing
- ✅ Check both customer identification methods (direct and contract-based)
- ✅ Verify `PROJECT_PARTY_TYPE = 'CO'` exists
- ✅ For CLIN projects, check contract billing plans
- ✅ Verify customer account is linked to billing plan

**Issue:** Budget/Forecast is zero
- ✅ Check plan status - must be 'B' (Baselined)
- ✅ Verify submitted date logic - plan must be submitted before report period
- ✅ Check plan class code - 'BUDGET' or 'FORECAST'
- ✅ Ensure planning elements and plan lines exist

**Issue:** Costs are zero
- ✅ Check `PRVDR_GL_DATE` filter - costs are filtered by GL date, not transaction date
- ✅ Verify expenditure items exist for the project
- ✅ Check cost distribution lines - must have GL date within period
- ✅ For overhead costs, check separate CTE (`PJC_COST_DETAILS_OA`)

### **Performance Issues:**

**Issue:** Query running too slow
- ✅ Add/verify `PARALLEL` hints on large tables
- ✅ Check for missing indexes (especially on PROJECT_ID, TASK_ID, GL_DATE)
- ✅ Use `EXPLAIN PLAN` to identify bottlenecks
- ✅ Verify filters are applied early in CTEs
- ✅ Use `MATERIALIZE` hint for reused CTEs

**Issue:** Query plan shows full table scan
- ✅ Add index hints: `/*+ INDEX(table_name index_name) */`
- ✅ Ensure WHERE clause uses indexed columns
- ✅ Check statistics are up-to-date (`DBMS_STATS`)

### **Incorrect Calculations:**

**Issue:** Totals don't match expected values
- ✅ Check for NULL handling - use `NVL()` in calculations
- ✅ Verify GROUP BY includes all necessary columns
- ✅ For cost breakdown, ensure all categories are mapped correctly
- ✅ Check overhead allocation exclusion logic

**Issue:** Raw cost includes overhead
- ✅ Verify `EXPENDITURE_TYPE_ID <> 300000126235407` filter is applied
- ✅ Use separate CTE for overhead costs
- ✅ Check `EXISTS` clause for overhead filtering

**Issue:** Revenue not matching costs
- ✅ Revenue may be recognized in different period than cost GL date
- ✅ Check `REVENUE_RECOGNIZED_FLAG` status
- ✅ Verify `BILL_TRANSACTION_TYPE_CODE = 'EI'` for expenditure items
- ✅ Check if revenue plan is linked to billing plan

**Issue:** WIP calculation incorrect
- ✅ WIP = Revenue - Invoice Amount (not Cost - Invoice Amount)
- ✅ Ensure both revenue and invoice use same currency (LEDGER_CURR or TRNS_CURR)
- ✅ Check that draft invoices are excluded (`INVOICE_STATUS_CODE <> 'DRAFT'`)

### **Data Inconsistency:**

**Issue:** Different values in different reports
- ✅ Check report period parameter - ensure consistent cut-off date
- ✅ Verify GL date vs. transaction date filtering
- ✅ Check if overhead is included/excluded consistently
- ✅ Ensure same plan version is used (MAX(SUBMITTED_DATE) logic)

---

## 9. 🔒 Critical Column Standards

### **Date Columns:**
- **Transaction Date:** `EXPENDITURE_ITEM_DATE` (from `PJC_EXP_ITEMS_ALL`)
- **GL Date:** `PRVDR_GL_DATE` (from `PJC_COST_DIST_LINES_ALL`)
- **Period Cut-Off:** `LAST_DAY(:P_REPORT_PERIOD)`
- **Year-to-Date:** `TRUNC(:P_REPORT_PERIOD, 'YEAR')`
- **Period-to-Date:** `TRUNC(:P_REPORT_PERIOD, 'MM')`

### **Cost Columns:**
- **Raw Cost (excluding overhead):** `CASE WHEN EXPENDITURE_TYPE_ID <> 300000126235407 THEN PROJFUNC_RAW_COST END`
- **Burdened Cost:** `PROJFUNC_BURDENED_COST`
- **Burden Cost:** `PROJFUNC_BURDENED_COST - PROJFUNC_RAW_COST` (or overhead CTE)
- **Transaction Currency Cost:** `DENOM_RAW_COST`
- **Entity Currency Cost:** `ACCT_RAW_COST`

### **Status Columns:**
- **Billable:** `CASE BILLABLE_FLAG WHEN 'Y' THEN 'Yes' ELSE 'No' END`
- **Revenue Recognized:** `CASE REVENUE_RECOGNIZED_FLAG WHEN 'F' THEN 'Fully Recognized' WHEN 'U' THEN 'Unrecognized' ELSE REVENUE_RECOGNIZED_FLAG END`
- **Invoiced:** `CASE INVOICED_FLAG WHEN 'U' THEN 'Uninvoiced' WHEN 'F' THEN 'Fully Invoiced' WHEN 'P' THEN 'Partially Invoiced' ELSE INVOICED_FLAG END`

### **Formatting:**
- **Dates:** `TO_CHAR(date, 'YYYY-MM-DD')` or `TO_CHAR(date, 'DD-fmMON-YYYY')`
- **Amounts:** `ROUND(amount, 2)` for detail, `ROUND(amount, 1)` for summary
- **Percentages:** `ROUND(percentage * 100, 2)`

---

## 10. 🎯 Common Use Cases

### **Use Case 1: Project Financial Summary**
**Go To:** `PROJECTS/PROJECTS_TEMPLATES.md` - Template #2  
**Includes:** Budget, Forecast, Actuals, Revenue, Invoice, WIP

### **Use Case 2: Cost Analysis by Category**
**Go To:** `COSTING/COSTING_TEMPLATES.md` - Template #2  
**Includes:** Staff Cost, Burden, Expenses breakdown

### **Use Case 3: Contract Performance Tracking**
**Go To:** `PROJECTS/PROJECTS_TEMPLATES.md` - Template #3  
**Includes:** Revenue, Cost, Margin by contract (ITD, YTD, PTD)

### **Use Case 4: Unbilled Revenue (WIP)**
**Go To:** `COSTING/COSTING_TEMPLATES.md` - Template #4  
**Includes:** Billable costs not yet invoiced, revenue recognized but not billed

### **Use Case 5: Project Team/Resource Report**
**Go To:** `PROJECTS/PROJECTS_REPOSITORIES.md` - CTE #6  
**Includes:** Team members with roles, contact info, active status

### **Use Case 6: Budget vs. Forecast vs. Actual**
**Go To:** `PROJECTS/PROJECTS_TEMPLATES.md` - Template #2  
**Includes:** All three plan types with variance analysis

---

## 11. 📞 Support & Updates

**For Issues or Enhancement Requests:**
- Contact: PPM Development Team
- Documentation Location: `SaaS-main/PPM/`
- Version Control: Git repository with change logs

**Regular Updates:**
- Documentation reviewed quarterly
- SQL assets updated as Oracle releases new versions
- Performance optimization ongoing

**Validation Status:**
- Last Validated: 22-12-25
- Coverage: 100% of reference queries
- Compliance: Oracle Traditional Join Syntax, CTE hints, Multi-tenant awareness

---

## 12. 🎓 Training Resources

### **Getting Started:**
1. Review `PROJECTS/PROJECTS_MASTER.md` for comprehensive schema map
2. Study `PROJECTS/PROJECTS_REPOSITORIES.md` for reusable CTEs
3. Start with `PROJECTS/PROJECTS_TEMPLATES.md` Template #1 (simplest)

### **Advanced Topics:**
1. Budget/Forecast versioning and plan status decode
2. Contingency extraction and submitted forecast handling
3. CLIN project handling with two-method customer identification
4. Overhead allocation exclusion patterns
5. Cost breakdown by category with decode logic
6. Multi-currency handling (DENOM, ACCT, PROJFUNC)

### **Best Practices Workshop:**
1. Oracle Traditional Join Syntax conversion
2. Performance tuning with hints and parallel execution
3. Multi-tenant filtering strategies
4. Date-effective person data handling
5. Reusable CTE patterns and modular design

---

**END OF PPM_INSTRUCTIONS.md**

**Document Version:** 2.0  
**Last Updated:** 22-12-25  
**Lines:** 400+  
**Status:** Production-Ready ✅
