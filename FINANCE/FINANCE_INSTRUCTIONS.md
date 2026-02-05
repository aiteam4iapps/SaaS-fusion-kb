# Finance Module Instructions

**Domain:** Oracle Fusion Financials  
**Location:** `FUSION_SAAS/FINANCE/`  
**Status:** ✅ Validated & Production-Ready  
**Last Validation:** 22-12-25 (All 22 reference queries analyzed)

---

## 📋 Validation Status

✅ **COMPREHENSIVE VALIDATION COMPLETED**

All Finance modules have been validated against 22 production reference queries from `SAAS Query\Finance`:
- **Tables Documented:** 49 new tables added across all modules
- **CTEs Created:** 29 reusable Common Table Expressions
- **Templates:** 22 production-ready report templates
- **Compliance:** 100% adherence to Oracle Fusion SQL standards

**Validation Report:** See `.cursor/22-12-25/FINAL_VALIDATION_REPORT.md` for complete details.

---

## 1. 📂 Module Navigation (Routes)

| Sub-Module | Instruction File | Repository File | Template File | Status |
|------------|------------------|-----------------|---------------|--------|
| **Payables (AP)** | [AP_MASTER](AP/AP_MASTER.md) | [AP_REPOS](AP/AP_REPOSITORIES.md) | [AP_TMPL](AP/AP_TEMPLATES.md) | ✅ 5 queries validated |
| **Receivables (AR)** | [AR_MASTER](AR/AR_MASTER.md) | [AR_REPOS](AR/AR_REPOSITORIES.md) | [AR_TMPL](AR/AR_TEMPLATES.md) | ✅ 5 queries validated |
| **Gen. Ledger (GL)** | [GL_MASTER](GL/GL_MASTER.md) | [GL_REPOS](GL/GL_REPOSITORIES.md) | [GL_TMPL](GL/GL_TEMPLATES.md) | ✅ 2 queries validated |
| **Cash Mgmt (CM)** | [CM_MASTER](CM/CM_MASTER.md) | [CM_REPOS](CM/CM_REPOSITORIES.md) | [CM_TMPL](CM/CM_TEMPLATES.md) | ✅ 5 queries validated |
| **Fixed Assets (FA)** | [FA_MASTER](FA/FA_MASTER.md) | [FA_REPOS](FA/FA_REPOSITORIES.md) | [FA_TMPL](FA/FA_TEMPLATES.md) | ✅ 1 query validated |
| **Cross-Module** | [CROSS_MASTER](CROSS_MODULE/CROSS_MODULE_MASTER.md) | N/A | [CROSS_TMPL](CROSS_MODULE/CROSS_MODULE_TEMPLATES.md) | ✅ 4 queries validated |

---

## 2. 🔗 Shared Integration Rules (Cross-Module)

### A. Subledger Accounting (SLA)
*   **Concept:** All sub-modules (AP, AR, FA) must send journals to GL.
*   **Check:** Use `XLA_AE_HEADERS` and `XLA_AE_LINES` to trace the flow.
*   **Rule:** `APPLICATION_ID` is critical (200=AP, 222=AR, 140=FA).

### B. Period Close
*   **Control:** Periods must be open in GL to post journals.
*   **Alignment:** Subledger periods usually close *before* the GL period closes.

### C. Currency
*   **Rule:** Always handle **entered** vs **accounted** amounts.
*   **Formula:** `NVL(ACCOUNTED_DR, 0) - NVL(ACCOUNTED_CR, 0)`.

---

## 3. 🛠️ Development Workflow (SQL Generation)
*To generate SQL scripts, you MUST follow this sequence to ensure compliance.*

### Step 1: Consult Standards (The Rules)
*   **Performance:** Check `BASE_SQL_STANDARDS.md` (e.g., No ANSI joins, Use `exist` over `in`).
*   **Naming:** Check `BASE_NAMING_CONVENTIONS.md` (e.g., `xx<client>_<module>_<name>`).

### Step 2: Select Template (The Skeleton)
*   Go to the `.../TEMPLATES` folder for your module (e.g., `AR/AR_TEMPLATES.md`).
*   Copy the **Standard Header** and **Base Query Block**.
*   *Do not start from a blank page.*

### Step 3: Check Repositories (The LEGO Bricks)
*   Go to the `.../REPOSITORIES` folder (e.g., `AR/AR_REPOSITORIES.md`).
*   Look for pre-approved sub-queries (e.g., "Get Customer Name", "Get Payment Terms").
*   **Reuse** these snippets instead of writing from scratch.

### Step 4: Generate & Validate
*   Assemble the pieces.
*   Ensure all standard columns (`CREATED_BY`, `CREATION_DATE`) are included.
*   **Validate** against the checklist in Step 1 before saving.

---

## 4. 🚨 Critical SQL Standards

### 🚫 AMPERSAND RULE (CRITICAL - APPLIES TO ALL QUERIES)
> [!CRITICAL]
> **NEVER use ampersand (&) symbol ANYWHERE in SQL queries, including comments.**
> Ampersand triggers lexical parameter prompts in Oracle BI Tools (OTBI, BI Publisher) causing query failures.

**Common Violations to Avoid:**
- ❌ WRONG: `-- Currency & Amounts`
- ✅ CORRECT: `-- Currency AND Amounts`
- ❌ WRONG: `-- PROJECT & INTERCOMPANY`
- ✅ CORRECT: `-- PROJECT AND INTERCOMPANY`
- ❌ WRONG: `-- Balance & Charges`
- ✅ CORRECT: `-- Balance AND Charges`

### AR Transaction Types
*   **Rule:** When joining `RA_CUSTOMER_TRX_ALL` to `RA_CUST_TRX_TYPES_ALL`, you **MUST** use `CUST_TRX_TYPE_SEQ_ID`.
*   **Prohibited:** Do NOT use `CUST_TRX_TYPE_ID`. It will cause data loss or incorrect joins in this environment.

### AP Module Critical Filters
*   **Invoices:** Always filter `CANCELLED_DATE IS NULL` (unless audit report)
*   **Payments:** Always filter `VOID_DATE IS NULL` (unless void analysis)
*   **Prepayments:** Use `INVOICE_TYPE_LOOKUP_CODE = 'PREPAYMENT'` for prepayment invoices

### AR Module Critical Filters
*   **Sign Reversal:** Credit Memos ('CM') and Payments ('PMT') must multiply by -1
*   **Exchange Rate:** Use `NVL(EXCHANGE_RATE, 1)` for functional currency
*   **Reversed Receipts:** Exclude using `NOT EXISTS` check against `AR_CASH_RECEIPT_HISTORY_ALL` with `STATUS = 'REVERSED'`

### GL Module Critical Filters
*   **Posted Journals:** Filter by `STATUS = 'P'` for posted entries
*   **Ledger Context:** Always include `LEDGER_ID` in queries

### CM Module Critical Filters
*   **Reconciliation:** Check `CE_STATEMENT_LINES.STATUS` for 'RECONCILED' vs 'UNRECONCILED'
*   **Payment Integration:** Link via `APPLICATION_ID = 200` (AP) or `222` (AR)

### FA Module Critical Filters
*   **Current Assets:** Filter by `TRANSACTION_HEADER_ID_OUT IS NULL`
*   **Current Distribution:** Filter by `DATE_INEFFECTIVE IS NULL`

---

## 5. 📊 Module-Specific Capabilities

### AP Module (Accounts Payable)
**Use When:** Supplier invoices, payments, prepayments, aging, supplier statements

**Key Features:**
- 14-bucket aging with prepayment tracking
- Invoice approval workflow tracking
- Payment vouchers with bank details
- Supplier ledger with opening balance
- SLA integration for GL posting

**Key Tables:** `AP_INVOICES_ALL`, `AP_CHECKS_ALL`, `AP_PAYMENT_SCHEDULES_ALL`, `POZ_SUPPLIERS_V`

**Templates Available:** Aging (14-bucket), Invoice Register, Ledger/Statement, Payment Voucher

---

### AR Module (Accounts Receivable)
**Use When:** Customer invoices, receipts, aging, customer statements, credit memos

**Key Features:**
- 8-bucket aging with customer site details
- Receipt applications and tracking
- Customer ledger with running balance
- Credit memo and debit memo handling
- Exchange gain/loss tracking

**Key Tables:** `RA_CUSTOMER_TRX_ALL`, `AR_CASH_RECEIPTS_ALL`, `AR_PAYMENT_SCHEDULES_ALL`, `HZ_CUST_ACCOUNTS`

**Templates Available:** Aging (8-bucket), Transaction Register, Receipt Register, Customer Ledger/Statement

---

### GL Module (General Ledger)
**Use When:** Journal entries, trial balance, account analysis, financial statements

**Key Features:**
- Journal voucher printing with batch details
- Comprehensive journal register
- Enhanced trial balance with segment breakdown
- Source document tracking via `GL_IMPORT_REFERENCES`
- Period-to-date and year-to-date balances

**Key Tables:** `GL_JE_HEADERS`, `GL_JE_LINES`, `GL_BALANCES`, `GL_CODE_COMBINATIONS`

**Templates Available:** Journal Voucher, Register Report, Enhanced Trial Balance

---

### CM Module (Cash Management)
**Use When:** Bank statements, reconciliation, cash flow analysis, payment/receipt vouchers

**Key Features:**
- Bank statement processing
- Reconciliation tracking (matched vs unmatched)
- Cash flow analysis with running balance
- Integration with AP payments and AR receipts
- Bank account management

**Key Tables:** `CE_BANK_ACCOUNTS`, `CE_STATEMENT_HEADERS`, `CE_STATEMENT_LINES`, `CE_PAYMENT_TRANSACTIONS`

**Templates Available:** Payment Voucher, Receipt Voucher, Bank Statement, Reconciliation Report, Cash Management Details

---

### FA Module (Fixed Assets)
**Use When:** Asset register, depreciation schedules, asset retirements, asset adjustments

**Key Features:**
- Comprehensive asset register with depreciation
- Period-by-period depreciation schedule
- Retirement tracking with gain/loss calculation
- Distribution tracking (location, employee, GL accounts)
- Multiple book support (Corporate, Tax, IFRS)

**Key Tables:** `FA_ADDITIONS_B`, `FA_BOOKS`, `FA_DISTRIBUTION_HISTORY`, `FA_DEPRN_SUMMARY`

**Templates Available:** Asset Register, Depreciation Schedule, Retirement Report

---

### Cross-Module Integration
**Use When:** Account analysis, sales order tracking, tax reporting, subledger reconciliation

**Key Features:**
- Account analysis with source drill-down (GL + AP + AR + FA)
- Sales order to cash tracking (OM + AR + CM)
- Tax reporting (AR + AP + Tax)
- SLA integration patterns

**Key Tables:** `XLA_TRANSACTION_ENTITIES`, `XLA_EVENTS`, `XLA_AE_HEADERS`, `XLA_AE_LINES`

**Templates Available:** Account Analysis, Sales Order Analysis, Sales Tax Register

---

## 6. 🎯 Quick Reference Guide

### When to Use Each Module

| Requirement | Module | Template to Use |
|-------------|--------|-----------------|
| Supplier outstanding balances | AP | AP Aging (14-bucket) |
| Invoice approval tracking | AP | AP Invoice Register |
| Supplier statement/ledger | AP | AP Ledger/Statement |
| Payment voucher for bank | AP/CM | AP Payment Voucher or CM Payment Voucher |
| Customer outstanding balances | AR | AR Aging (8-bucket) |
| Invoice listing with details | AR | AR Transaction Register |
| Receipt tracking | AR | AR Receipt Register |
| Customer statement/ledger | AR | AR Customer Ledger/Statement |
| Journal entry print | GL | GL Journal Voucher |
| Journal register for period | GL | GL Register Report |
| Trial balance | GL | Enhanced Trial Balance |
| Bank statement | CM | Bank Statement Report |
| Bank reconciliation | CM | Bank Statement Reconciliation |
| Cash flow analysis | CM | Cash Management Details |
| Asset register | FA | Fixed Asset Register |
| Depreciation schedule | FA | Asset Depreciation Schedule |
| Asset retirement | FA | Asset Retirement Report |
| Account analysis by source | Cross-Module | Account Analysis Report |
| Order to cash tracking | Cross-Module | Sales Order Analysis |
| Tax reporting | Cross-Module | Sales Tax Register |

---

## 7. 🔧 Development Best Practices

### 1. Always Start with Templates
Never write queries from scratch. Always use templates from `*_TEMPLATES.md` files as starting point.

### 2. Reuse Repository CTEs
Check `*_REPOSITORIES.md` for pre-built CTEs before creating new joins. This ensures:
- Correct join conditions
- Proper filters applied
- Performance hints included
- Standard business rules enforced

### 3. Follow the 4-Step Workflow
1. **Consult Standards** - Check `*_MASTER.md` for module constraints
2. **Select Template** - Copy from `*_TEMPLATES.md`
3. **Check Repositories** - Use CTEs from `*_REPOSITORIES.md`
4. **Generate & Validate** - Apply all constraints and validate

### 4. Performance Optimization
- Use `/*+ qb_name(NAME) MATERIALIZE */` hints on all CTEs
- Filter by date range at earliest level
- Include `ORG_ID` or `LEDGER_ID` in joins for partition pruning
- Use Oracle Traditional Join Syntax (not ANSI)

### 5. Testing Checklist
Before deploying any query:
- [ ] Uses Oracle Traditional Join Syntax (no INNER JOIN/LEFT JOIN)
- [ ] All CTEs have `qb_name` hints
- [ ] Multi-tenant context included (`ORG_ID`/`BU_ID`/`LEDGER_ID`)
- [ ] Module-specific filters applied (e.g., `CANCELLED_DATE IS NULL` for AP)
- [ ] Exchange rates handled (`NVL(EXCHANGE_RATE, 1)`)
- [ ] Sign reversal for AR CM/PMT transactions
- [ ] Standard audit columns included (`CREATED_BY`, `CREATION_DATE`)

---

## 8. 📚 Reference Documentation

### Validation Reports
- **Comprehensive Report:** `.cursor/22-12-25/FINAL_VALIDATION_REPORT.md`
- **Validation Summary:** `.cursor/22-12-25/FINANCE_VALIDATION_SUMMARY.md`

### Module Documentation
- **AP Module:** `AP/AP_MASTER.md` (10 tables, 7 CTEs, 4 templates)
- **AR Module:** `AR/AR_MASTER.md` (14 tables, 6 CTEs, 4 templates)
- **GL Module:** `GL/GL_MASTER.md` (7 tables, 5 CTEs, 3 templates)
- **CM Module:** `CM/CM_MASTER.md` (7 tables, 6 CTEs, 5 templates)
- **FA Module:** `FA/FA_MASTER.md` (11 tables, 5 CTEs, 3 templates)
- **Cross-Module:** `CROSS_MODULE/CROSS_MODULE_MASTER.md` (3 templates)

### System Instructions
- **Repository Rule:** See `SYSTEM_INSTRUCTIONS.md` for mandatory workflow
- **Base Standards:** Oracle Traditional Syntax, CTE Hints, Multi-Tenant Awareness

---

## 9. 🆘 Troubleshooting

### Common Issues and Solutions

**Issue:** Query returns no data
- **Check:** Verify `ORG_ID`/`BU_ID`/`LEDGER_ID` matches your test organization
- **Check:** Verify date ranges include test data
- **Check:** Verify filters (e.g., `CANCELLED_DATE IS NULL`) aren't excluding valid data

**Issue:** Duplicate rows returned
- **Check:** Missing `ORG_ID` in join conditions
- **Check:** Multiple distributions/lines without proper aggregation
- **Solution:** Add `DISTINCT` or proper `GROUP BY`

**Issue:** Performance is slow
- **Check:** CTE hints included (`/*+ qb_name() MATERIALIZE */`)
- **Check:** Date filters applied early in query
- **Check:** Indexes exist on join columns
- **Solution:** Use partition pruning with `ORG_ID`/`LEDGER_ID`

**Issue:** Exchange rate errors (division by zero)
- **Check:** Using `NVL(EXCHANGE_RATE, 1)` pattern
- **Solution:** Always wrap exchange rates with `NVL(column, 1)`

**Issue:** AR amounts incorrect
- **Check:** Sign reversal for CM/PMT transactions
- **Solution:** Use `CASE WHEN CLASS IN ('CM', 'PMT') THEN AMOUNT * -1 ELSE AMOUNT END`

---

## 10. 📞 Support & Updates

### For New Requirements
1. Check if existing template covers the requirement
2. Review similar queries in validation report
3. Reuse CTEs from repositories
4. Follow 4-step workflow

### For Issues
1. Consult module-specific `*_MASTER.md` for constraints
2. Review validation report for reference patterns
3. Check troubleshooting section above

### Version History
- **22-12-25:** Initial comprehensive validation completed (22 queries, 100% coverage)
- **Next Review:** As needed for new requirements

---

**Status:** ✅ All modules validated and production-ready  
**Compliance:** 100% adherence to Oracle Fusion SQL standards  
**Coverage:** 22 reference queries analyzed and patterns extracted

