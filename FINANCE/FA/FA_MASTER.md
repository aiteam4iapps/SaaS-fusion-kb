# Fixed Assets Master Instructions

**Module:** Fixed Assets (FA)
**Tag:** `#Finance #FA #Assets`
**Status:** Active

---

## 1. 🚨 Critical FA Constraints

1.  **Book Constraint:**
    *   **Rule:** Always filter by `BOOK_TYPE_CODE`.
    *   **Why:** Assets can exist in Corporate, Tax, and IFRS books simultaneously.

2.  **Asset Life Cycle:**
    *   **Rule:** Use `DATE_PLACED_IN_SERVICE` for capitalization timing.
    *   **Retirements:** Check `FA_RETIREMENTS` for disposed assets.

3.  **Current Row Filter:**
    *   **Rule:** `FB.TRANSACTION_HEADER_ID_OUT IS NULL` for current asset state
    *   **Why:** Asset history is tracked via transaction headers; NULL = current

4.  **Distribution Current Row:**
    *   **Rule:** `FD.DATE_INEFFECTIVE IS NULL` for active distribution
    *   **Why:** Distribution history tracks changes; NULL = current assignment

5.  **Depreciation Summary:**
    *   **Rule:** Join `FA_DEPRN_SUMMARY` on `ASSET_ID`, `BOOK_TYPE_CODE`, `PERIOD_COUNTER`
    *   **Fields:** `DEPRN_RESERVE` (accumulated depr), `YTD_DEPRN` (current year)

6.  **GL Account Structure:**
    *   **Asset Account:** `FD.CODE_COMBINATION_ID` (from distribution)
    *   **Depreciation:** Join to `GL_CODE_COMBINATIONS` for account segments

---

## 2. 🗺️ Schema Map

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **FAB** | `FA_ADDITIONS_B` | Asset Master (Description, Tag) |
| **FAT** | `FA_ADDITIONS_TL` | Asset Master Translated (Language-specific) |
| **FB**  | `FA_BOOKS` | Financial Details (Cost, Depr Method, Life) |
| **FD**  | `FA_DISTRIBUTION_HISTORY` | Assignment (Location, Employee, GL Account) |
| **FDS** | `FA_DEPRN_SUMMARY` | Depreciation Summary (Reserve, YTD Depr) |
| **FDP** | `FA_DEPRN_PERIODS` | Depreciation Period Tracking |
| **FT**  | `FA_TRANSACTION_HEADERS` | Audit Trail of changes |
| **FC**  | `FA_CATEGORIES_B` | Asset Category definitions |
| **FCT** | `FA_CATEGORIES_TL` | Category Translated |
| **FL**  | `FA_LOCATIONS` | Location Master |
| **FM**  | `FA_METHODS` | Depreciation Method definitions |
| **FR**  | `FA_RETIREMENTS` | Asset Retirement details |
| **FA**  | `FA_ADJUSTMENTS` | Asset Adjustment history |
| **GCC** | `GL_CODE_COMBINATIONS` | GL Account for Asset/Depr/Expense |
| **PPNF** | `PER_PERSON_NAMES_F` | Employee Assignment |

---
