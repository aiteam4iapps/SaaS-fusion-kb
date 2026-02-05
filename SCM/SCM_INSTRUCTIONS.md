# SCM Module Instructions

**Domain:** Oracle Fusion Supply Chain Management
**Location:** `SaaS-main/SCM/`  
**Last Validated:** 22-12-25

---

## ✅ Validation Status

| Module | Tables | CTEs | Templates | Status |
|--------|--------|------|-----------|--------|
| **PO (Purchasing)** | 60+ | 13 | 4 | ✅ VALIDATED |
| **INV (Inventory)** | 40+ | 9 | 2 | ✅ VALIDATED |
| **OM (Order Mgmt)** | TBD | TBD | TBD | ⏸️ NO QUERIES |
| **Cross-Module** | 20+ | N/A | 3 | ✅ VALIDATED |

**Reference Queries Analyzed:** 13  
**Validation Completion:** 100% (10 of 10 queries with assigned modules)

---

## 1. 📂 Module Navigation (Routes)

| Sub-Module | Instruction File | Repository File | Template File |
|------------|------------------|-----------------|---------------|
| **Purchasing** | [PO_MASTER](PO/PO_MASTER.md) | [PO_REPOS](PO/PO_REPOSITORIES.md) | [PO_TMPL](PO/PO_TEMPLATES.md) |
| **Inventory** | [INV_MASTER](INV/INV_MASTER.md) | [INV_REPOS](INV/INV_REPOSITORIES.md) | [INV_TMPL](INV/INV_TEMPLATES.md) |
| **Order Mgmt** | [OM_MASTER](OM/OM_MASTER.md) | [OM_REPOS](OM/OM_REPOSITORIES.md) | [OM_TMPL](OM/OM_TEMPLATES.md) |
| **Cross-Module** | [CROSS_MODULE_MASTER](CROSS_MODULE/CROSS_MODULE_MASTER.md) | N/A | [CROSS_MODULE_TMPL](CROSS_MODULE/CROSS_MODULE_TEMPLATES.md) |

---

## 2. 🔗 Shared Integration Rules (Cross-Module)

### A. Organization Definitions
*   **Inventory Org:** `ORGANIZATION_ID` in `INV` tables. Links to `HR_ORGANIZATION_UNITS_F_TL`.
*   **Business Unit:** `PRC_BU_ID` or `REQ_BU_ID` in `PO` tables. Links to `FUN_ALL_BUSINESS_UNITS_V`.
*   **Key Rule:** Never mix Inv Org and BU ID in joins without mapping.
*   **Multi-Tenant Rule:** Always include `ORG_ID` or `BU_ID` in WHERE clause for partitioning.

### B. Item Definition
*   **Master Table:** `EGP_SYSTEM_ITEMS_B` (modern) or `MTL_SYSTEM_ITEMS_B` (legacy)
*   **Key Rule:** Always join by `INVENTORY_ITEM_ID` AND `ORGANIZATION_ID`. Items are org-specific.
*   **Pattern:**
    ```sql
    WHERE ESIB.INVENTORY_ITEM_ID = IMT.INVENTORY_ITEM_ID
      AND ESIB.ORGANIZATION_ID = IMT.ORGANIZATION_ID
    ```

### C. Party Model
*   **Suppliers:** Shared with AP (`POZ_SUPPLIERS_V`). Join on `VENDOR_ID`.
*   **Customers:** Shared with AR (`HZ_CUST_ACCOUNTS`). Join on `CUST_ACCOUNT_ID`.
*   **Trading Partners:** `HZ_PARTIES` is the master party table.

### D. Procurement Integration (PO → INV → AP)
*   **PR to PO:** `POR_REQUISITION_LINES_ALL.PO_HEADER_ID`
*   **PO to Receipt:** `RCV_TRANSACTIONS.PO_HEADER_ID`
*   **Receipt to Invoice:** `AP_INVOICE_LINES_ALL.RCV_TRANSACTION_ID`
*   **Match Types:**
    - **2-Way Match:** PO + Invoice (no receipt)
    - **3-Way Match:** PO + Receipt + Invoice
    - **4-Way Match:** PO + Receipt + Inspection + Invoice

### E. Date-Effective Tables
*   **Person Names:** `PER_PERSON_NAMES_F` - Always filter by `EFFECTIVE_START_DATE` and `EFFECTIVE_END_DATE`
*   **Organizations:** `HR_ORGANIZATION_UNITS_F_TL` - Always filter by effective dates
*   **Pattern:**
    ```sql
    AND TRUNC(SYSDATE) BETWEEN TRUNC(PPNF.EFFECTIVE_START_DATE) 
                           AND TRUNC(PPNF.EFFECTIVE_END_DATE)
    AND PPNF.NAME_TYPE = 'GLOBAL'
    ```

---

## 3. 🛠️ Development Workflow (SQL Generation)

### Step 1: Consult Standards (The Rules)
*   **Performance:** Check `BASE_SQL_STANDARDS.md` (No ANSI joins, Use CTEs with hints)
*   **Naming:** Check `BASE_NAMING_CONVENTIONS.md`
*   **Module-Specific:** Check `PO_MASTER.md` or `INV_MASTER.md` for constraints

### Step 2: Select Template (The Skeleton)
*   **PO Reports:** Go to `PO/PO_TEMPLATES.md` (PO Detail, PR Detail, Supplier Master, Work Confirmation)
*   **INV Reports:** Go to `INV/INV_TEMPLATES.md` (On-Hand, Transactions)
*   **Cross-Module:** Go to `CROSS_MODULE/CROSS_MODULE_TEMPLATES.md` (P2P, GRN, Supplier Evaluation)
*   Copy the **Standard Header** and **Base Query Block**
*   *Do not start from a blank page.*

### Step 3: Check Repositories (The LEGO Bricks)
*   **PO Repositories:** `PO/PO_REPOSITORIES.md` (13 CTEs)
*   **INV Repositories:** `INV/INV_REPOSITORIES.md` (9 CTEs)
*   Look for pre-approved CTEs (PO_MASTER, PR_MASTER, SUPPLIER_MASTER, etc.)
*   **Reuse** these snippets instead of writing from scratch

### Step 4: Generate & Validate
*   Assemble the pieces (Template + Repositories + Constraints)
*   Ensure all standard columns included (`CREATED_BY`, `CREATION_DATE`, `ORG_ID`)
*   Validate against checklist:
    - [ ] Oracle Traditional Join Syntax (no ANSI joins)
    - [ ] CTE hints (`/*+ qb_name() MATERIALIZE */`)
    - [ ] Multi-tenant context (`ORG_ID`, `BU_ID`)
    - [ ] Date-effective filtering for person names
    - [ ] NULL handling (`NVL()` for calculations)
    - [ ] Exchange rate handling (`NVL(RATE, 1)`)

---

## 4. 📊 Module-Specific Capabilities

### PO (Purchasing) Module

**Core Functions:**
- Purchase Order management (PO, PR, Contracts)
- Supplier management and evaluation
- Negotiation/Tender management (RFQ, Bidding)
- Work confirmation for services
- Approval workflow tracking

**Key Reports (4 Templates):**
1. **PO Detail Report** - Comprehensive PO with approval workflow
2. **PR Detail Report** - Requisitions with approval tracking
3. **Supplier Master Report** - Supplier information with bank details
4. **Work Confirmation Report** - Service work confirmations

**Key CTEs (13):**
- PO_MASTER, PO_OPEN_LINES, PO_RCV_MASTER
- PO_APPROVER, PR_MASTER, PR_APPROVER
- SUPPLIER_MASTER, BUYER_MASTER, REQUESTER_MASTER
- NEGOTIATION_MASTER, BID_DETAILS
- WORK_CONFIRMATION_MASTER, ITEM_MASTER

**Critical Constraints:**
- Always use Oracle Traditional Syntax
- Include `PRC_BU_ID` in all multi-org queries
- Handle approval history with `RANK()` over `ACTION_DATE`
- Filter cancelled lines/schedules
- Handle retainage for contracts
- UOM display logic (Ea → Each, MON → Months, YRS → Years)

---

### INV (Inventory) Module

**Core Functions:**
- On-hand inventory tracking
- Material transactions (Issue, Receipt, Transfer, Adjustment)
- Locator/Bin management
- Lot & Serial control
- Cost tracking and valuation
- Project-based inventory

**Key Reports (2 Templates):**
1. **Inventory On-Hand Report** - Current stock with locators and projects
2. **Inventory Transaction Report** - Comprehensive transaction history

**Key CTEs (9):**
- INV_ITEM_MASTER, INV_ONHAND_MASTER
- INV_TRX_MASTER, TRX_TYPE
- INV_ORG, LOCATOR_V
- ITEM_DETAILS, COST, RECEIPT

**Critical Constraints:**
- **ALWAYS** include `ORGANIZATION_ID` in item joins
- Use `FND_FLEX_EXT.GET_SEGS()` for locator concatenated segments
- Filter transaction dates by period or year
- Check costing interface status
- Verify lot/serial control flags
- Handle subinventory transfers (from/to)
- Match receipts to source documents (PO, Sales Order, etc.)

---

### Cross-Module Integration

**Core Scenarios:**
- **Procure to Pay (P2P):** PR → PO → Receipt → Invoice → Payment
- **GRN Tracking:** PO → Receipt → Invoice Matching
- **Work Confirmation:** Service PO → WC → Receipt → Invoice
- **Supplier Evaluation:** Initiative → Qualification → Evaluation

**Key Reports (3 Templates):**
1. **Procure to Pay Report** - End-to-end P2P process tracking
2. **GRN Report** - Receipt matching with invoices
3. **Supplier Evaluation Report** - Supplier performance tracking

**Integration Patterns (7):**
- PR to PO Link
- PO to Receipt Link
- Receipt to Invoice Link (3-Way Match)
- Invoice to Payment Link
- Work Confirmation to Receipt Link
- P2P Lead Time Calculation
- GRN Status Logic

**Critical Constraints:**
- Calculate lead times between stages
- Track savings (PR vs PO amounts)
- Handle partial receipts and invoices
- Validate GRN status comprehensively
- Check payment status (voided vs cleared)

---

## 5. 🎯 Quick Reference Guide

### Common Queries By Business Need

| Business Need | Module | Template |
|---------------|--------|----------|
| Track open POs | PO | PO Detail Report |
| View requisitions | PO | PR Detail Report |
| Supplier information | PO | Supplier Master Report |
| Service work confirmations | PO | Work Confirmation Report |
| Current stock levels | INV | On-Hand Report |
| Inventory movements | INV | Transaction Report |
| Full procurement cycle | Cross | P2P Report |
| Receipt matching | Cross | GRN Report |
| Supplier performance | Cross | Supplier Evaluation |

### Common Tables By Use Case

| Use Case | Key Tables |
|----------|------------|
| PO Header Info | `PO_HEADERS_ALL`, `POZ_SUPPLIERS_V` |
| PO Lines | `PO_LINES_ALL`, `PO_LINE_LOCATIONS_ALL` |
| PO Approval | `PO_ACTION_HISTORY`, `PER_PERSON_NAMES_F` |
| Requisitions | `POR_REQUISITION_HEADERS_ALL`, `POR_REQUISITION_LINES_ALL` |
| Receipts | `RCV_SHIPMENT_HEADERS`, `RCV_TRANSACTIONS` |
| On-Hand Qty | `INV_ONHAND_QUANTITIES_DETAIL` |
| Transactions | `INV_MATERIAL_TXNS` |
| Items | `EGP_SYSTEM_ITEMS_B/VL` |
| Suppliers | `POZ_SUPPLIERS_V`, `POZ_SUPPLIER_SITES_V` |
| Negotiations | `PON_AUCTION_HEADERS_ALL`, `PON_BID_HEADERS` |

---

## 6. 🧪 Testing Checklist

Before deploying any SCM report:

- [ ] Test with multiple Business Units
- [ ] Verify Organization ID filtering
- [ ] Check date parameter handling
- [ ] Validate multi-currency scenarios
- [ ] Test with partial receipts/invoices
- [ ] Verify NULL handling in calculations
- [ ] Check performance with large datasets
- [ ] Validate approval workflow retrieval
- [ ] Test cross-module joins (P2P scenarios)
- [ ] Verify person name date-effective filtering

---

## 7. 📚 Reference Documentation

### Module Documentation
- **PO Module:** [PO_MASTER.md](PO/PO_MASTER.md) - 60+ tables, 13 CTEs
- **INV Module:** [INV_MASTER.md](INV/INV_MASTER.md) - 40+ tables, 9 CTEs
- **Cross-Module:** [CROSS_MODULE_MASTER.md](CROSS_MODULE/CROSS_MODULE_MASTER.md)

### Validation Documentation
- **Validation Summary:** `.cursor/22-12-25/SCM_VALIDATION_SUMMARY.md`
- **Reference Queries:** `SAAS Query/SCM/` (13 SQL files)

### Related Modules
- **AP (Payables):** For invoice and payment integration
- **AR (Receivables):** For customer orders
- **GL (General Ledger):** For account coding

---

## 8. 🔧 Troubleshooting

### Issue: Duplicate Rows in PO Report
**Cause:** Multiple distributions or shipments per line  
**Solution:** Use `DISTINCT` or aggregate at appropriate level

### Issue: Missing Approval Dates
**Cause:** Multiple approvers or approval workflow not completed  
**Solution:** Use `RANK()` to get latest approver:
```sql
RANK() OVER (PARTITION BY PO_HEADER_ID ORDER BY ACTION_DATE DESC) AS RN
... WHERE RN = 1
```

### Issue: Inventory Transactions Missing Item Description
**Cause:** Item not assigned to organization  
**Solution:** Always use outer join and check `ORGANIZATION_ID`:
```sql
AND ESIB.INVENTORY_ITEM_ID = IMT.INVENTORY_ITEM_ID(+)
AND ESIB.ORGANIZATION_ID = IMT.ORGANIZATION_ID(+)
```

### Issue: Locator Name Not Showing
**Cause:** FND_FLEX_EXT function not used correctly  
**Solution:** Use proper syntax:
```sql
FND_FLEX_EXT.GET_SEGS('INV', 'MTLL', STRUCTURE_INSTANCE_NUMBER, 
                      INVENTORY_LOCATION_ID, SUBINVENTORY_ID)
```

### Issue: GRN Status Incorrect
**Cause:** Complex match logic not implemented  
**Solution:** Use comprehensive CASE statement from `CROSS_MODULE_MASTER.md`

---

## 9. 💡 Best Practices

### Performance
1. **Use CTEs with hints:** `/*+ qb_name(NAME) MATERIALIZE */`
2. **Filter early:** Apply WHERE conditions at CTE level
3. **Avoid cartesian products:** Always specify join conditions
4. **Use indexes:** Filter on `ORG_ID`, `BU_ID`, `CREATION_DATE`

### Maintainability
1. **Use templates:** Never start from blank page
2. **Reuse CTEs:** Copy from repository files
3. **Document parameters:** Always list parameters in header
4. **Follow naming:** Use standard aliases (PHA, PLA, RSH, etc.)

### Data Quality
1. **Handle NULLs:** Use `NVL()` for all calculations
2. **Validate dates:** Check effective date ranges for person tables
3. **Multi-tenant aware:** Always include ORG/BU context
4. **Currency conversion:** Apply exchange rates consistently

---

## 10. 🚀 Next Steps

### For New Developers
1. Read `PO_MASTER.md` and `INV_MASTER.md` for table mappings
2. Review templates in `PO_TEMPLATES.md` and `INV_TEMPLATES.md`
3. Copy a template and customize for your needs
4. Test thoroughly with diverse scenarios

### For Adding New Queries
1. Identify which module(s) the query belongs to
2. Check if tables are documented in MASTER files
3. Create new CTEs in REPOSITORIES files if needed
4. Add new templates to TEMPLATES files
5. Update validation summary

### For Cross-Module Development
1. Review `CROSS_MODULE_MASTER.md` for integration patterns
2. Use P2P or GRN templates as starting points
3. Verify all module-specific constraints
4. Test end-to-end data flow

---

**Document Version:** 1.0  
**Last Updated:** 22-12-25  
**Validation Coverage:** 100% (13 of 13 queries analyzed)
