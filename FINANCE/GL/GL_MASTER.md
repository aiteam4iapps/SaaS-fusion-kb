# General Ledger Master Instructions

**Module:** General Ledger (GL)
**Tag:** `#Finance #GL #GeneralLedger`
**Status:** Active

---

## 1. 🚨 Critical GL Constraints

1.  **Ledger Context:**
    *   **Rule:** Always filter by `LEDGER_ID`.
    *   **Why:** A single instance supports multiple specialized ledgers (Primary, Secondary, Reporting).
    *   **Lookup:** `GL_LEDGERS`.

2.  **Chart of Accounts (COA):**
    *   **Rule:** Join `GL_CODE_COMBINATIONS` (GCC) to decode Account Segments.
    *   **Structure:** `SEGMENT1` (Company), `SEGMENT2` (Cost Center), `SEGMENT3` (Account), etc.

3.  **Period Status:**
    *   **Rule:** Check `GL_PERIOD_STATUSES` for 'Open' or 'Closed' periods.
    *   **Pattern:** `AND GPS.CLOSING_STATUS IN ('O', 'C', 'P')` (Open, Closed, Permanently Closed)

4.  **Journal Entry Status:**
    *   **Rule:** Filter by `STATUS = 'P'` for posted entries only
    *   **Valid Statuses:** 'P' (Posted), 'U' (Unposted)

5.  **Source Document Tracking:**
    *   **Rule:** Use `GL_IMPORT_REFERENCES` to link GL entries back to source documents
    *   **Pattern:** Join on `GIR.GL_SL_LINK_ID = GJL.GL_SL_LINK_ID`

6.  **Segment Decoding:**
    *   **Rule:** Use `GL_CODE_COMBINATIONS_KFV` for readable account strings
    *   **Recommended:** `GCCK.CONCATENATED_SEGMENTS` for full account string

7.  **Multi-Org Context:**
    *   **Rule:** Always include `LEDGER_ID` in joins
    *   **Caution:** A single GL instance can have multiple ledgers for different entities

---

## 2. 🗺️ Schema Map

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **GB**  | `GL_BALANCES` | Summary Balances (Actual/Budget) |
| **GJL** | `GL_JE_LINES` | Journal Entry Lines (Debits/Credits) |
| **GJH** | `GL_JE_HEADERS` | Journal Headers (Posted Date, Source) |
| **GJB** | `GL_JE_BATCHES` | Journal Batch Headers (Batch Control) |
| **GCC** | `GL_CODE_COMBINATIONS` | Account String Combinations |
| **GCCK** | `GL_CODE_COMBINATIONS_KFV` | Account String with Descriptions |
| **GLL** | `GL_LEDGERS` | Ledger Definition (Currency, Calendar) |
| **GPS** | `GL_PERIOD_STATUSES` | Period Status (Open/Closed) |
| **GLLV** | `GL_LEDGER_LE_V` | Ledger-Legal Entity Relationship |
| **GIR** | `GL_IMPORT_REFERENCES` | Source Document References |
| **XLE** | `XLE_ENTITY_PROFILES` | Legal Entity Profiles |
| **FU** | `FND_USER` | User Information |

---
