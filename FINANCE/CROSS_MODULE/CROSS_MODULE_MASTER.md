# Cross-Module Master Instructions

**Module:** Cross-Module Integration Queries
**Tag:** `#Finance #CrossModule #Integration`
**Status:** Active

---

## 1. 🚨 Critical Cross-Module Constraints

1.  **Subledger Accounting (SLA) Integration:**
    *   **Rule:** Use `XLA_*` tables to link subledger transactions to GL
    *   **Application IDs:** AP=200, AR=222, FA=140, GL=101
    *   **Pattern:** `XLA_TRANSACTION_ENTITIES` → `XLA_EVENTS` → `XLA_AE_HEADERS` → `XLA_AE_LINES`
    *   **CRITICAL - XLA_AE_HEADERS Status Column:**
        *   **Correct Column:** `XLA_AE_HEADERS.ACCOUNTING_ENTRY_STATUS_CODE`
        *   **Incorrect Column:** `XLA_AE_HEADERS.ACCOUNTING_STATUS_CODE` (does not exist)
        *   **Usage:** `WHERE XAH.ACCOUNTING_ENTRY_STATUS_CODE = 'F'` (F = Final accounting entries)
        *   **Note:** Always use `ACCOUNTING_ENTRY_STATUS_CODE` when filtering for final accounting entries

2.  **Multi-Module Joins:**
    *   **Rule:** Always include `ORG_ID` or `LEDGER_ID` in cross-module joins
    *   **Why:** Ensures data isolation in multi-org environments

3.  **Period Alignment:**
    *   **Rule:** Use GL period as master calendar for cross-module reports
    *   **Pattern:** Join to `GL_PERIOD_STATUSES` for period boundaries

---

## 2. 🗺️ Schema Map (Cross-Module Integration)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **XTE** | `XLA_TRANSACTION_ENTITIES` | Subledger Entity (links source to SLA) |
| **XE** | `XLA_EVENTS` | Subledger Event (transaction event tracking) |
| **XAH** | `XLA_AE_HEADERS` | Accounting Entry Header |
| **XAL** | `XLA_AE_LINES` | Accounting Entry Lines (links to GL) |
| **XDL** | `XLA_DISTRIBUTION_LINKS` | Links source distributions to SLA |
| **GPS** | `GL_PERIOD_STATUSES` | GL Period Master |
| **GLL** | `GL_LEDGERS` | Ledger Master |
| **FBU** | `FUN_ALL_BUSINESS_UNITS_V` | Business Unit Master |

---

## 3. ⚡ Common Cross-Module Patterns

### Pattern 1: Account Analysis (GL + AP + AR)
*Analyze GL account activity by source module.*

**Key Tables:**
- `GL_JE_LINES` (GL journal lines)
- `GL_IMPORT_REFERENCES` (source document links)
- `AP_INVOICE_DISTRIBUTIONS_ALL` (AP source)
- `AR_DISTRIBUTIONS_ALL` (AR source)
- `XLA_AE_LINES` (SLA integration)

**Critical Join:**
```sql
GL_JE_LINES.GL_SL_LINK_ID = GL_IMPORT_REFERENCES.GL_SL_LINK_ID
GL_IMPORT_REFERENCES.GL_SL_LINK_TABLE = XLA_AE_LINES / AP_INVOICE_DISTRIBUTIONS / etc.
```

---

### Pattern 2: Sales Order Analysis (AR + OM + INV)
*Analyze sales orders from order to cash receipt.*

**Key Tables:**
- `OE_ORDER_HEADERS_ALL` (Order headers)
- `OE_ORDER_LINES_ALL` (Order lines)
- `RA_CUSTOMER_TRX_ALL` (AR invoices)
- `RA_CUSTOMER_TRX_LINES_ALL` (Invoice lines)
- `AR_CASH_RECEIPTS_ALL` (Receipts)
- `MTL_SYSTEM_ITEMS_B` (Items)

**Critical Join:**
```sql
OE_ORDER_LINES.LINE_ID = RA_CUSTOMER_TRX_LINES.INTERFACE_LINE_ATTRIBUTE6
RA_CUSTOMER_TRX.CUSTOMER_TRX_ID = AR_CASH_RECEIPTS via AR_RECEIVABLE_APPLICATIONS
```

---

### Pattern 3: Tax Reporting (AR + AP + GL)
*Analyze sales tax collected and paid.*

**Key Tables:**
- `ZX_LINES` (Tax lines - both AP and AR)
- `ZX_RATES_B` (Tax rates)
- `RA_CUSTOMER_TRX_ALL` (AR transactions)
- `AP_INVOICES_ALL` (AP invoices)
- `GL_JE_LINES` (GL postings)

**Critical Join:**
```sql
ZX_LINES.APPLICATION_ID = 222 (AR) or 200 (AP)
ZX_LINES.TRX_ID = CUSTOMER_TRX_ID or INVOICE_ID
```

---

## 4. 🔍 Best Practices for Cross-Module Queries

1.  **Start with Master Module:**
    *   Identify the primary module (usually GL for financial analysis)
    *   Build from master to detail

2.  **Use SLA as Integration Layer:**
    *   `XLA_*` tables provide standardized integration
    *   Avoid direct joins between subledger tables when possible

3.  **Performance Optimization:**
    *   Filter by date range at outermost level
    *   Use `MATERIALIZE` hints for large result sets
    *   Consider partitioning by `LEDGER_ID` or `ORG_ID`

4.  **Data Completeness:**
    *   Not all transactions post through SLA (e.g., manual journals)
    *   Use `LEFT JOIN` when optional integration expected

---

## 5. 📊 Common Use Cases

| Use Case | Modules Involved | Primary Driver |
|----------|------------------|----------------|
| Account Analysis | GL, AP, AR, FA | GL Account |
| Cash Flow Analysis | CM, AP, AR | Bank Account |
| Sales Analysis | OM, AR, INV | Sales Order |
| Tax Reporting | AR, AP, GL | Tax Code |
| Subledger Recon | GL, AP, AR, FA | GL Period |
| Intercompany Analysis | GL, AP, AR | Legal Entity |

---


