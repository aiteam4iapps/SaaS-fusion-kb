# Sourcing/Negotiations Master Instructions

**Module:** Sourcing/Negotiations (SOURCING)
**Tag:** `#SCM #SOURCING #Negotiations`
**Status:** Active

---

## 1. 🚨 Critical Sourcing/Negotiations Constraints

1.  **Negotiation Line Table (CRITICAL):**
    *   **Rule:** Use `PON_AUCTION_ITEM_PRICES_ALL` (NOT `PON_AUCTION_LINES_ALL`)
    *   **Why:** `PON_AUCTION_LINES_ALL` does not exist. All negotiation line details are in `PON_AUCTION_ITEM_PRICES_ALL`.

2.  **Negotiation Date Columns (CRITICAL):**
    *   **Rule:** Use `PON_AUCTION_HEADERS_ALL.OPEN_BIDDING_DATE` and `CLOSE_BIDDING_DATE` (NOT `OPEN_DATE` and `CLOSE_DATE`)
    *   **Why:** The correct column names for negotiation open and close dates are `OPEN_BIDDING_DATE` and `CLOSE_BIDDING_DATE`.

3.  **PR Number Direct Access (CRITICAL):**
    *   **Rule:** `REQUISITION_NUMBER` is available directly in `PON_AUCTION_ITEM_PRICES_ALL` (no join required)
    *   **Why:** No need to join through `POR_REQUISITION_LINES_ALL` to get PR Number. It's a direct column.

4.  **Negotiation Line Description (CRITICAL):**
    *   **Rule:** Use `PON_AUCTION_ITEM_PRICES_ALL.ITEM_DESCRIPTION` (NOT `DESCRIPTION`)
    *   **Why:** The column name is `ITEM_DESCRIPTION`, not `DESCRIPTION`.

5.  **Line Type Column (CRITICAL):**
    *   **Rule:** Use `PON_AUCTION_ITEM_PRICES_ALL.ORDER_TYPE_LOOKUP_CODE` for line type (NOT `LINE_TYPE`)
    *   **Why:** The actual column name is `ORDER_TYPE_LOOKUP_CODE`.

6.  **Requested Delivery Date (CRITICAL):**
    *   **Rule:** Use `PON_AUCTION_ITEM_PRICES_ALL.REQUESTED_DELIVERY_DATE` (NOT `NEED_BY_DATE`)
    *   **Why:** The column name is `REQUESTED_DELIVERY_DATE`, not `NEED_BY_DATE`.

7.  **Current Price (CRITICAL):**
    *   **Rule:** Use `PON_AUCTION_ITEM_PRICES_ALL.CURRENT_PRICE` directly (NOT `UNIT_PRICE`)
    *   **Why:** `UNIT_PRICE` column does not exist in this table. Use `CURRENT_PRICE` only.

8.  **Negotiation to PR Link:**
    *   **Rule:** Join to `POR_REQUISITION_HEADERS_ALL` via `PON_AUCTION_ITEM_PRICES_ALL.REQUISITION_NUMBER` = `POR_REQUISITION_HEADERS_ALL.REQUISITION_NUMBER`
    *   **Why:** This join is only needed for BU filtering and BU name output. PR Number is already available directly.

9.  **AUCTION_LINE_ID:**
    *   **Rule:** `AUCTION_LINE_ID` is not needed for reporting (internal ID only)
    *   **Why:** Use `LINE_NUMBER` for line identification in reports.

---

## 2. 🗺️ Schema Map

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PAH** | `PON_AUCTION_HEADERS_ALL` | Negotiation Header (Number, Title, Status, OPEN_BIDDING_DATE, CLOSE_BIDDING_DATE) |
| **PAIP** | `PON_AUCTION_ITEM_PRICES_ALL` | Negotiation Line (ITEM_DESCRIPTION, ORDER_TYPE_LOOKUP_CODE, REQUESTED_DELIVERY_DATE, CURRENT_PRICE, REQUISITION_NUMBER) |
| **PRHA** | `POR_REQUISITION_HEADERS_ALL` | Requisition Header (PR Number, BU) - joined via REQUISITION_NUMBER |
| **ECV** | `EGP_CATEGORIES_VL` | Category Names |
| **HAOU** | `HR_ALL_ORGANIZATION_UNITS` | Business Unit Names |

---

## 3. ⚡ Performance Optimization

| Object | Optimal Access Path | Hint Syntax |
|--------|---------------------|-------------|
| **Negotiation Header** | DOCUMENT_NUMBER | `/*+ INDEX(PAH PON_AUCTION_HEADERS_U1) */` |
| **Negotiation Lines** | AUCTION_HEADER_ID | `/*+ INDEX(PAIP PON_AUCTION_ITEM_PRICES_N1) */` |

---

## 4. 🔗 Integration Points

### A. Requisition Integration
*   **PR Number:** Direct column in `PON_AUCTION_ITEM_PRICES_ALL.REQUISITION_NUMBER`
*   **PR Link:** Join to `POR_REQUISITION_HEADERS_ALL` only for BU information
*   **Key Rule:** No need to join through `POR_REQUISITION_LINES_ALL` for PR Number

### B. Category Integration
*   **Master Table:** `EGP_CATEGORIES_VL`
*   **Key Rule:** Join via `PON_AUCTION_ITEM_PRICES_ALL.CATEGORY_ID` = `EGP_CATEGORIES_VL.CATEGORY_ID`

### C. Business Unit Integration
*   **BU Link:** Via `POR_REQUISITION_HEADERS_ALL.REQ_BU_ID` = `HR_ALL_ORGANIZATION_UNITS.ORGANIZATION_ID`
*   **Key Rule:** Only needed when filtering by BU or displaying BU name

---

