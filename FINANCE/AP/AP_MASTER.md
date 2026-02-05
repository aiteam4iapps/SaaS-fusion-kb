# AP Master Instructions: Oracle Fusion Payables

**Module:** Accounts Payable (AP)
**Tag:** `#Finance #AP #Payables`
**Status:** Active

---

## 1. 🚨 Critical AP Constraints
*Violating these rules breaks the system.*

1.  **Cancelled Invoices:**
    *   **Rule:** `AND CANCELLED_DATE IS NULL`
    *   **Why:** Reporting on cancelled invoices causes financial discrepancies.
    *   **Exception:** Audit reports explicitly looking for cancellations.

2.  **Void Payments:**
    *   **Rule:** `AND VOID_DATE IS NULL`
    *   **Why:** Voided payments are not valid cash outflows.

3.  **XLA Application ID:**
    *   **Rule:** `AND APPLICATION_ID = 200`
    *   **Why:** Optimizes query by scanning only Payables partitions in Subledger Accounting.

4.  **Multi-Tenant Pruning:**
    *   **Rule:** `AND AIA.ORG_ID = FBU.BU_ID` (and similar Joins)
    *   **Why:** Partition pruning relies on `ORG_ID`.

---

## 2. ⚡ Performance Optimization
*Indices and Hints specific to AP.*

| Object | Optimal Access Path (Index) | Hint Syntax |
|--------|-----------------------------|-------------|
| **Invoice Header** | ORG_ID + CANCELLED_DATE | `/*+ INDEX(AIA AP_INVOICES_N24) */` |
| **Invoice Line** | INVOICE_ID | `/*+ INDEX(AIL AP_INVOICE_LINES_N1) */` |
| **Distribution** | INV_ID + LINE_NUM | `/*+ INDEX(AID AP_INVOICE_DISTRIBUTIONS_N32) */` |
| **Payment** | CHECK_ID | `/*+ INDEX(AC AP_CHECKS_PK) */` |

**Execution Strategy:**
*   For **Invoice-Driven** reports: Start with `AP_INVOICES_ALL` and use `/*+ LEADING(AIA AID) */`.
*   For **Payment-Driven** reports: Start with `AP_CHECKS_ALL` and use `/*+ LEADING(ACA AIP AIA) */`.

---

## 3. 🗺️ Schema Map (Key Tables)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **AIA** | `AP_INVOICES_ALL` | Invoice Headers (Supplier, Site, Amount) |
| **AIL** | `AP_INVOICE_LINES_ALL` | Invoice Lines (Item details) |
| **AID** | `AP_INVOICE_DISTRIBUTIONS_ALL`| Distributions (GL CCID, Project ID) |
| **ACA** | `AP_CHECKS_ALL` | Payments (Check Number, Date) |
| **AIP** | `AP_INVOICE_PAYMENTS_ALL` | Link between Invoice and Payment |
| **PSA** | `AP_PAYMENT_SCHEDULES_ALL` | Due Dates, Remaining Amounts |
| **POS** | `POZ_SUPPLIERS_V` | Supplier Names |
| **PSS** | `POZ_SUPPLIER_SITES_V` | Supplier Site Addresses |
| **ATV** | `AP_TERMS_VL` | Payment Terms (Name, Description) |
| **ALC** | `AP_LOOKUP_CODES` | Invoice Type Descriptions |
| **AIAHA** | `AP_INV_APRVL_HIST_ALL` | Invoice Approval History |
| **APHA** | `AP_PAYMENT_HISTORY_ALL` | Payment Accounting Status |
| **HP** | `HZ_PARTIES` | Party-based Suppliers (PARTY_ID) |
| **HPS** | `HZ_PARTY_SITES` | Party Site Information |
| **IPA** | `IBY_PAYMENTS_ALL` | Payment Instruments |
| **CBA** | `CE_BANK_ACCOUNTS` | Bank Account Details |
| **GLL** | `GL_LEDGERS` | Ledger/Currency Information |
| **FBU** | `FUN_ALL_BUSINESS_UNITS_V` | Business Unit Details |

---

## 4. 📋 Critical Business Logic Patterns

### 4.1 Validation Status Decode
*Maps APPROVAL_STATUS to user-friendly descriptions.*

```sql
DECODE (AIA.APPROVAL_STATUS,
    'FULL', 'FULLY APPLIED',
    'NEVER APPROVED', 'NEVER VALIDATED',
    'NEEDS REAPPROVAL', 'NEEDS REVALIDATION',
    'CANCELLED', 'CANCELLED',
    'UNPAID', 'UNPAID',
    'AVAILABLE', 'AVAILABLE',
    'UNAPPROVED', 'UNVALIDATED',
    'APPROVED', 'VALIDATED',
    'PERMANENT', 'PERMANENT PREPAYMENT',
    NULL
) VALIDATION_STATUS
```

### 4.2 Accounting Status
*Uses Oracle package to determine accounting status.*

```sql
AP_INVOICES_UTILITY_PKG.GET_ACCOUNTING_STATUS(AIA.INVOICE_ID) ACCOUNTING_STATUS
```
**Values:** `ACCOUNTED`, `PARTIALLY_ACCOUNTED`, `UNACCOUNTED`

### 4.3 Party-Based Supplier Handling
*For suppliers created via Party model (PARTY_ID not null).*

```sql
NVL(POS.VENDOR_NAME, 
    (SELECT party_name FROM hz_parties WHERE PARTY_ID = AIA.PARTY_ID)) SUPPLIER_NAME
```

### 4.4 Exchange Rate Handling
*Always default to 1 for functional currency.*

```sql
NVL(AIA.EXCHANGE_RATE, 1) EXCHANGE_RATE
```

### 4.5 Prepayment Application Logic
*Tracks prepayment usage through distribution linkage.*

```sql
-- For Prepayment Applied Amount
SELECT (SUM(AIDI.AMOUNT) * -1) APP_AMOUNT
FROM AP_INVOICE_DISTRIBUTIONS_ALL AIDP,
     AP_INVOICE_DISTRIBUTIONS_ALL AIDI
WHERE AIDP.INVOICE_DISTRIBUTION_ID = AIDI.PREPAY_DISTRIBUTION_ID
  AND AIDI.REVERSAL_FLAG = 'N'
  AND TRUNC(AIDI.ACCOUNTING_DATE) <= :P_DATE
  AND AIDP.INVOICE_ID = AIA.INVOICE_ID
```

---
