# Cross-Module Integration Master

**Purpose:** Cross-module integration patterns and tables  
**Scope:** Queries spanning PO, INV, AP, AR, and other modules  
**Tag:** `#SCM #CrossModule #Integration`

---

## 1. 🌐 Cross-Module Scenarios

### Procure to Pay (P2P) Process
**Modules Involved:** PO → INV → AP  
**Flow:** Requisition → PO → Receipt → Invoice → Payment  
**Key Integration Points:**
- PR to PO: `POR_REQUISITION_LINES_ALL.PO_HEADER_ID`
- PO to Receipt: `RCV_TRANSACTIONS.PO_HEADER_ID`
- Receipt to Invoice: `AP_INVOICE_LINES_ALL.RCV_TRANSACTION_ID`
- Invoice to Payment: `AP_INVOICE_PAYMENTS_ALL.INVOICE_ID`

### Goods Received Notes (GRN) Tracking
**Modules Involved:** PO → INV → AP  
**Flow:** PO → Receipt → Invoice Matching  
**Match Types:**
- **2-Way Match:** PO + Invoice (no receipt required)
- **3-Way Match:** PO + Receipt + Invoice
- **4-Way Match:** PO + Receipt + Inspection + Invoice

### Work Confirmation Process
**Modules Involved:** PO → Services  
**Flow:** Service PO → Work Confirmation → Receipt → Invoice  
**Key Tables:**
- `PO_WC_HEADERS` - Work confirmation header
- `PO_WC_LINES` - Work confirmation lines
- `RCV_TRANSACTIONS` - Work confirmation receipts

### Supplier Evaluation
**Modules Involved:** Supplier Qualification → Performance  
**Flow:** Initiative → Qualification → Evaluation  
**Key Tables:**
- `POQ_INITIATIVES` - Qualification initiatives
- `POQ_QUALIFICATIONS` - Supplier qualifications
- `POQ_INITIATIVE_SUPPLIERS` - Suppliers in initiative

---

## 2. 🗺️ Cross-Module Schema Map

### Procure to Pay Tables
| Alias | Table Name | Module | Purpose |
|-------|------------|--------|---------|
| **PRHA** | `POR_REQUISITION_HEADERS_ALL` | PO | Requisition header |
| **PRLA** | `POR_REQUISITION_LINES_ALL` | PO | Requisition lines |
| **PHA** | `PO_HEADERS_ALL` | PO | Purchase order header |
| **PLA** | `PO_LINES_ALL` | PO | Purchase order lines |
| **PLLA** | `PO_LINE_LOCATIONS_ALL` | PO | PO shipments |
| **PDA** | `PO_DISTRIBUTIONS_ALL` | PO | PO distributions |
| **RSH** | `RCV_SHIPMENT_HEADERS` | INV | Receipt header |
| **RSL** | `RCV_SHIPMENT_LINES` | INV | Receipt lines |
| **RT** | `RCV_TRANSACTIONS` | INV | Receipt transactions |
| **AIA** | `AP_INVOICES_ALL` | AP | Invoice header |
| **AILA** | `AP_INVOICE_LINES_ALL` | AP | Invoice lines |
| **ACA** | `AP_CHECKS_ALL` | AP | Payment checks |
| **AIPA** | `AP_INVOICE_PAYMENTS_ALL` | AP | Invoice payments |

### Supplier & Party Tables
| Alias | Table Name | Module | Purpose |
|-------|------------|--------|---------|
| **PSV** | `POZ_SUPPLIERS_V` | Supplier | Supplier master |
| **PSSV** | `POZ_SUPPLIER_SITES_V` | Supplier | Supplier sites |
| **HP** | `HZ_PARTIES` | Party | Trading partner parties |

### Item & Organization Tables
| Alias | Table Name | Module | Purpose |
|-------|------------|--------|---------|
| **ESIV** | `EGP_SYSTEM_ITEMS_VL` | Item | Item master |
| **FABUV** | `FUN_ALL_BUSINESS_UNITS_V` | Org | Business units |
| **IOP** | `INV_ORG_PARAMETERS` | INV | Organization parameters |

### Financial Tables
| Alias | Table Name | Module | Purpose |
|-------|------------|--------|---------|
| **GCC** | `GL_CODE_COMBINATIONS` | GL | Chart of accounts |
| **APT** | `AP_TERMS_TL` | AP | Payment terms |

### Work Confirmation Tables
| Alias | Table Name | Module | Purpose |
|-------|------------|--------|---------|
| **PWH** | `PO_WC_HEADERS` | PO | Work confirmation header |
| **PWL** | `PO_WC_LINES` | PO | Work confirmation lines |

### Supplier Qualification Tables
| Alias | Table Name | Module | Purpose |
|-------|------------|--------|---------|
| **PI** | `POQ_INITIATIVES` | Qual | Supplier initiatives |
| **PQ** | `POQ_QUALIFICATIONS` | Qual | Supplier qualifications |
| **PIS** | `POQ_INITIATIVE_SUPPLIERS` | Qual | Initiative suppliers |

---

## 3. 🔗 Critical Integration Patterns

### PR to PO Link
**Pattern:** Link requisition to purchase order
```sql
FROM   POR_REQUISITION_LINES_ALL PRLA
      ,PO_HEADERS_ALL PHA
      ,PO_DISTRIBUTIONS_ALL PDA
WHERE  PRLA.PO_HEADER_ID = PHA.PO_HEADER_ID(+)
  AND  PDA.REQ_DISTRIBUTION_ID = PRDA.DISTRIBUTION_ID(+)
```

### PO to Receipt Link
**Pattern:** Link purchase order to goods receipt
```sql
FROM   PO_HEADERS_ALL PHA
      ,PO_LINE_LOCATIONS_ALL PLLA
      ,RCV_TRANSACTIONS RT
      ,RCV_SHIPMENT_LINES RSL
WHERE  RT.PO_HEADER_ID = PHA.PO_HEADER_ID(+)
  AND  RT.PO_LINE_ID = PLA.PO_LINE_ID(+)
  AND  RT.SHIPMENT_LINE_ID = RSL.SHIPMENT_LINE_ID(+)
  AND  RT.TRANSACTION_TYPE = 'RECEIVE'
```

### Receipt to Invoice Link (3-Way Match)
**Pattern:** Match receipts to invoices
```sql
FROM   RCV_TRANSACTIONS RT
      ,AP_INVOICE_LINES_ALL AILA
      ,AP_INVOICES_ALL AIA
WHERE  RT.TRANSACTION_ID = AILA.RCV_TRANSACTION_ID(+)
  AND  AILA.INVOICE_ID = AIA.INVOICE_ID(+)
  AND  AILA.PO_DISTRIBUTION_ID = PDA.PO_DISTRIBUTION_ID(+)
```

### Invoice to Payment Link
**Pattern:** Track invoice payments
```sql
FROM   AP_INVOICES_ALL AIA
      ,AP_INVOICE_PAYMENTS_ALL AIPA
      ,AP_CHECKS_ALL ACA
WHERE  AIA.INVOICE_ID = AIPA.INVOICE_ID(+)
  AND  AIPA.CHECK_ID = ACA.CHECK_ID(+)
  AND  ACA.STATUS_LOOKUP_CODE <> 'VOIDED'
```

### Work Confirmation to Receipt Link
**Pattern:** Link work confirmation to receipt
```sql
FROM   PO_WC_HEADERS PWH
      ,PO_WC_LINES PWL
      ,RCV_SHIPMENT_LINES RSL
      ,RCV_TRANSACTIONS RT
WHERE  PWH.WORK_CONFIRMATION_ID = PWL.WORK_CONFIRMATION_ID
  AND  PWL.WORK_CONFIRMATION_ID = RSL.WORK_CONFIRMATION_ID(+)
  AND  PWL.WORK_CONFIRMATION_LINE_ID = RSL.WORK_CONFIRMATION_LINE_ID(+)
  AND  RSL.SHIPMENT_LINE_ID = RT.SHIPMENT_LINE_ID(+)
  AND  RT.TRANSACTION_TYPE = 'RECEIVE'
```

---

## 4. 🚨 Critical Cross-Module Constraints

### P2P Lead Time Calculation
**Rule:** Calculate time from PR approval to PO approval
```sql
(TRUNC(PHA.APPROVED_DATE) - TRUNC(PRHA.APPROVED_DATE)) AS LEAD_TIME_DAYS
```

### P2P Savings Calculation
**Rule:** Calculate savings between PR and PO amounts
```sql
(PR.PR_VALUE_AED - PO.PO_VALUE_AED) AS SAVINGS
```

### GRN Pending Invoice Amount
**Rule:** Calculate receipts not yet invoiced
```sql
(NVL(RECEIPT_VALUE, 0) - NVL(INVOICE_VALUE, 0)) AS GRN_PENDING_INVOICE
```

### GRN Status Logic
**Critical Pattern:** Determine GRN processing status
```sql
CASE 
    WHEN RECEIPT_NUMBER IS NOT NULL AND INVOICE_NUM IS NOT NULL 
         AND VALIDATION_STATUS = 'VALIDATED' 
         AND APPROVAL_STATUS IN ('Manually approved', 'Workflow approved', 'Approved', 'Not required')
         AND (RECEIPT_VALUE - INVOICE_VALUE) > 0 
    THEN 'Y'  -- Pending Invoice
    
    WHEN RECEIPT_NUMBER IS NOT NULL AND INVOICE_NUM IS NULL 
         AND (RECEIPT_VALUE) > 0 
    THEN 'Y'  -- No Invoice Yet
    
    WHEN RECEIPT_NUMBER IS NOT NULL AND INVOICE_NUM IS NOT NULL 
         AND VALIDATION_STATUS = 'VALIDATED' 
         AND (RECEIPT_VALUE - INVOICE_VALUE) <= 0 
    THEN 'N'  -- Fully Invoiced
    
    ELSE 'N'
END AS GRN_OPEN_STATUS
```

### Work Confirmation Amount Aggregation
**Rule:** Sum work confirmation amounts
```sql
SUM(PWL.AMOUNT) + PWH.PREVIOUSLY_APPROVED_AMOUNT AS TOTAL_WC_AMOUNT
```

### Supplier Evaluation Date Filtering
**Rule:** Filter qualifications by effective date
```sql
AND TRUNC(SYSDATE) BETWEEN NVL(PQ.EFFECTIVE_START_DATE, TRUNC(SYSDATE)) 
                       AND NVL(PQ.EFFECTIVE_END_DATE, TRUNC(SYSDATE))
```

---

## 5. 📊 Cross-Module Reporting Scenarios

### Complete P2P Cycle
**Requirement:** Track entire procure-to-pay process  
**Modules:** PO (PR + PO) → INV (Receipt) → AP (Invoice + Payment)  
**Key Metrics:**
- Lead times (PR to PO, PO to Receipt, Receipt to Invoice)
- Savings (PR vs PO amounts)
- Open obligations (PO - Receipt, Receipt - Invoice)
- Payment status

### GRN Reconciliation
**Requirement:** Match receipts to invoices  
**Modules:** PO → INV → AP  
**Key Metrics:**
- Pending receipts (not invoiced)
- Invoice variances
- Retainage tracking

### Supplier Performance
**Requirement:** Track supplier delivery and quality  
**Modules:** PO → INV → Supplier Qual  
**Key Metrics:**
- On-time delivery rate
- Quality scores
- Qualification status

---

## 6. 🎯 Integration Best Practices

### Multi-Module Join Strategy
1. **Start with anchor table** (usually PO or PR)
2. **Add receiving layer** (left outer join for partial receipts)
3. **Add AP layer** (left outer join for pending invoices)
4. **Filter at appropriate level** (avoid cartesian products)

### Performance Optimization
1. **Use CTEs** with proper hints (`/*+ qb_name() MATERIALIZE */`)
2. **Filter early** at CTE level
3. **Aggregate before joining** when possible
4. **Include ORG_ID/BU_ID** for partition pruning

### Data Consistency
1. **Check NULL values** with `NVL()` for calculations
2. **Handle outer joins** carefully
3. **Validate date ranges** across modules
4. **Verify currency conversions** (PO currency vs AP currency)

---

## 7. 📝 Common Integration Issues & Solutions

### Issue: Duplicate Rows
**Cause:** Multiple distributions or schedules  
**Solution:** Use `DISTINCT` or aggregate at appropriate level

### Issue: Missing Receipts
**Cause:** Receipt not yet created or voided  
**Solution:** Use left outer join and show NULL

### Issue: Invoice Mismatch
**Cause:** Partial invoicing or invoice reversals  
**Solution:** Check `CANCELLED_DATE` and aggregate invoice lines

### Issue: Currency Misalignment
**Cause:** PO currency differs from invoice currency  
**Solution:** Use `EXCHANGE_RATE` and convert to functional currency

---

**Last Updated:** 22-12-25  
**Validation Status:** ✅ Validated against 3 cross-module reference queries

