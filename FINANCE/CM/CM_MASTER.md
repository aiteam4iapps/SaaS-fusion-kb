# Cash Management Master Instructions

**Module:** Cash Management (CM)
**Tag:** `#Finance #CM #Cash`
**Status:** Active

---

## 1. 🚨 Critical CM Constraints

1.  **Bank Account Ownership:**
    *   **Rule:** Join `CE_BANK_ACCOUNTS` to `XLE_ENTITY_PROFILES` via `ACCOUNT_OWNER_ORG_ID`.
    *   **Why:** Accounts belong to Legal Entities.

2.  **Reconciliation:**
    *   **Rule:** `CE_STATEMENT_LINES.STATUS` determines if a line is Reconciled (REC) or Unreconciled (UNREC).
    *   **Check:** Use `CE_STATEMENT_RECONCILS_ALL` to find the matching payment/receipt

3.  **Payment Integration:**
    *   **Rule:** Link `CE_PAYMENT_TRANSACTIONS` to `AP_CHECKS_ALL` via `SOURCE_TRX_ID = CHECK_ID`
    *   **Application ID:** Use `APPLICATION_ID = 200` for Payables

4.  **Receipt Integration:**
    *   **Rule:** Link `CE_PAYMENT_TRANSACTIONS` to `AR_CASH_RECEIPTS_ALL` via `SOURCE_TRX_ID = CASH_RECEIPT_ID`
    *   **Application ID:** Use `APPLICATION_ID = 222` for Receivables

5.  **Bank Statement Status:**
    *   **Valid Statuses:** 'CURRENT' (Active), 'VOIDED' (Cancelled)
    *   **Filter:** Always check `CSH.STATEMENT_HEADER_ID IS NOT NULL` for loaded statements

6.  **GL Account Integration:**
    *   **Rule:** Join `CBA.ASSET_CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID`
    *   **Purpose:** Link bank account to GL cash account

---

## 2. 🗺️ Schema Map

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **CBA** | `CE_BANK_ACCOUNTS` | Internal Bank Accounts |
| **CBB** | `CE_BANK_BRANCHES_V` | Branch details |
| **CSH** | `CE_STATEMENT_HEADERS` | Bank Statement Header |
| **CSL** | `CE_STATEMENT_LINES` | Statement Transaction Lines |
| **CSR** | `CE_STATEMENT_RECONCILS_ALL` | Reconciliation Data (links Statement to Payments) |
| **CPT** | `CE_PAYMENT_TRANSACTIONS` | Payment side of Reconciliation |
| **IPA** | `IBY_PAYMENTS_ALL` | Payment Instrument Details |
| **ACA** | `AP_CHECKS_ALL` | AP Payment integration |
| **ACRA** | `AR_CASH_RECEIPTS_ALL` | AR Receipt integration |
| **GCC** | `GL_CODE_COMBINATIONS` | GL Account for Cash Accounts |
| **XLA** | `XLA_*` tables | Subledger Accounting integration |
| **XLE** | `XLE_ENTITY_PROFILES` | Legal Entity Profiles |

---
