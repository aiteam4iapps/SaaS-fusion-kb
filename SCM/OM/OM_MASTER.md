# Order Management Master Instructions

**Module:** Order Management (OM)
**Tag:** `#SCM #OM #DOO`
**Status:** Active

---

## 1. 🚨 Critical OM Constraints

1.  **Fulfillment Lines:**
    *   **Rule:** Status resides on `DOO_FULFILL_LINES_ALL`, not just Header/Line.
    *   **Why:** An order line can be split into multiple shipments with different statuses.

2.  **Orchestration:**
    *   **Rule:** Join `DOO_ORCH_PROCESSES` if you need to trace the "Life Cycle" (Scheduled -> Awaiting Shipping -> Billed).

---

## 2. 🗺️ Schema Map (The "DOO" Tables)

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **DHA** | `DOO_HEADERS_ALL` | Order Header (Customer, Validated Date) |
| **DLA** | `DOO_LINES_ALL` | Order Line (Item, Price) |
| **DFLA**| `DOO_FULFILL_LINES_ALL`| Fulfillment (Shipping status, Inv Interface) |
| **DPA** | `DOO_PROCESS_ATTRIBUTES`| Flexfields/Attributes |

---
