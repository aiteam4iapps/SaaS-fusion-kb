# Benefits Master Instructions

**Module:** Benefits
**Tag:** `#HCM #BEN #Benefits`
**Status:** Active

---

## 1. 🚨 Critical Benefits Constraints

1.  **Enrollment Status:**
    *   **Rule:** `AND PEN.PRTT_ENRT_RSLT_STAT_CD IS NULL` (Active) or `'VOIDED'` check.
    *   **Why:** Benefits history contains voided and backed-out enrollments.

2.  **Life Event Context:**
    *   **Rule:** Join `BEN_PER_IN_LER` to understand *why* an enrollment changed (Marriage, Birth, Open Enrollment).

3.  **Plan Types:**
    *   **Rule:** Filter `PL_TYP_ID` to separate Medical vs Dental vs Vision.

---

## 2. 🗺️ Schema Map

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PEN** | `BEN_PRTT_ENRT_RSLT_F` | Enrollment Results (The main table) |
| **PL** | `BEN_PL_F` | Plan Definitions (Aetna Gold, etc.) |
| **OPT** | `BEN_OPT_F` | Options (Employee Only, Family) |
| **PIL** | `BEN_PER_IN_LER` | Person Life Event (The Trigger) |

---
