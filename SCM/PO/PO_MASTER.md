# Purchasing Master Instructions

**Module:** Purchasing (PO)
**Tag:** `#SCM #PO #Purchasing`
**Status:** Active

---

## 1. 🚨 Critical PO Constraints

1.  **Open PO Status:**
    *   **Rule:** `AND CLOSED_CODE NOT IN ('CLOSED', 'FINALLY CLOSED')`
    *   **Why:** For "Open PO" reports, you must exclude closed documents.

2.  **Line Locations (Shipments):**
    *   **Rule:** Always join `PO_LINE_LOCATIONS_ALL` for quantity and receiving details.
    *   **Why:** `PO_LINES_ALL` only holds the item/price. The "Balance" is on the shipment.

3.  **Distributions (Accounts):**
    *   **Rule:** Join `PO_DISTRIBUTIONS_ALL` for Cost Centers and Project info.

4.  **Buyer/Agent Column (CRITICAL):**
    *   **Rule:** Use `PO_HEADERS_ALL.AGENT_ID` (NOT `BUYER_ID`)
    *   **Why:** `BUYER_ID` does not exist in `PO_HEADERS_ALL`. `AGENT_ID` links to `PER_ALL_PEOPLE_F.PERSON_ID` for buyer information.

5.  **Payment Terms Table (CRITICAL):**
    *   **Rule:** Use `AP_TERMS` table (NOT `AP_TERMS_NAME`)
    *   **Column:** `AP_TERMS.NAME` (NOT `TERM_NAME`)
    *   **Join:** `PO_HEADERS_ALL.TERMS_ID = AP_TERMS.TERM_ID`

6.  **Purchase Requisition Table (CRITICAL):**
    *   **Rule:** Use `POR_REQUISITION_HEADERS_ALL` (NOT `PO_REQUISITION_HEADERS_ALL`)
    *   **PR Number Column:** `POR_REQUISITION_HEADERS_ALL.REQUISITION_NUMBER` (NOT `SEGMENT1`)

7.  **PO to PR Link (CRITICAL):**
    *   **Rule:** Join PO and PR through distribution tables:
    *   **Path:** `PO_DISTRIBUTIONS_ALL.REQ_DISTRIBUTION_ID` = `POR_REQ_DISTRIBUTIONS_ALL.DISTRIBUTION_ID`
    *   Then: `POR_REQ_DISTRIBUTIONS_ALL.REQUISITION_LINE_ID` = `POR_REQUISITION_LINES_ALL.REQUISITION_LINE_ID`
    *   Then: `POR_REQUISITION_LINES_ALL.REQUISITION_HEADER_ID` = `POR_REQUISITION_HEADERS_ALL.REQUISITION_HEADER_ID`
    *   **Why:** `PO_LINES_ALL` does NOT have `REQUISITION_HEADER_ID` or `REQ_HEADER_ID` columns.

8.  **Recoverable Tax Amount (CRITICAL):**
    *   **Rule:** Tax is stored in `PO_DISTRIBUTIONS_ALL.RECOVERABLE_TAX` (NOT in `PO_LINE_LOCATIONS_ALL`)
    *   **Calculation:** Sum `RECOVERABLE_TAX` from distributions grouped by `PO_HEADER_ID`, `PO_LINE_ID`, `LINE_LOCATION_ID`

9.  **Supplier Contact Columns:**
    *   **Rule:** Use `POZ_SUPPLIER_CONTACTS_V.FULL_NAME` for contact name (NOT `CONTACT_NAME`)
    *   **Email:** `POZ_SUPPLIER_CONTACTS_V.EMAIL_ADDRESS`
    *   **Note:** No `PRIMARY_FLAG` or `CONTACT_ID` columns exist in this view.

10. **Supplier Site Address:**
    *   **Rule:** Address columns available: `ADDRESS_LINE1`, `ADDRESS_LINE2`, `ADDRESS_LINE3`, `CITY`, `STATE`, `COUNTRY`
    *   **Note:** No `POSTAL_CODE` or `ZIP_CODE` column exists in `POZ_SUPPLIER_SITES_V`

11. **Purchase Requisition Status Column (CRITICAL):**
    *   **Rule:** Use `POR_REQUISITION_HEADERS_ALL.DOCUMENT_STATUS` (NOT `STATUS_CODE`)
    *   **Why:** The correct column name for PR status is `DOCUMENT_STATUS`, not `STATUS_CODE`

12. **PR Amount Calculation (CRITICAL):**
    *   **Rule:** Use `POR_REQUISITION_LINES_ALL.ASSESSABLE_VALUE` with fallback logic
    *   **Calculation:** `NVL(ASSESSABLE_VALUE, CASE WHEN CURRENCY_UNIT_PRICE IS NOT NULL AND QUANTITY IS NOT NULL THEN (CURRENCY_UNIT_PRICE * QUANTITY * NVL(RATE, 1)) ELSE NVL(CURRENCY_AMOUNT, 0) * NVL(RATE, 1) END)`
    *   **Why:** `ASSESSABLE_VALUE` is the primary amount field, with fallback to calculated values

13. **PR Line to PO Direct Link (CRITICAL):**
    *   **Rule:** `POR_REQUISITION_LINES_ALL.PO_HEADER_ID` provides direct link to PO (if PR converted to PO)
    *   **Why:** PR lines can have direct `PO_HEADER_ID` reference when converted to PO, in addition to distribution-level link

14. **PR Distribution Charge Account (CRITICAL):**
    *   **Rule:** Use `POR_REQ_DISTRIBUTIONS_ALL.CODE_COMBINATION_ID` (NOT `CHARGE_ACCOUNT_ID`)
    *   **Why:** The column name is `CODE_COMBINATION_ID`, which links to `GL_CODE_COMBINATIONS.CODE_COMBINATION_ID`

15. **PR Status Lookup (CRITICAL):**
    *   **Rule:** Use `FND_LOOKUP_VALUES_TL` with `LOOKUP_TYPE = 'POR_DOCUMENT_STATUS'`
    *   **Filter:** `VIEW_APPLICATION_ID = 0`, `SET_ID = 0`, `LANGUAGE = USERENV('LANG')`
    *   **Why:** PR status meanings are stored in FND lookup, not directly in PR header table

16. **PR Requester Name (CRITICAL):**
    *   **Rule:** Can use `PER_PERSON_NAMES_F.FIRST_NAME || ' ' || PER_PERSON_NAMES_F.LAST_NAME` (alternative to `FULL_NAME`)
    *   **Date-Effective:** Must filter `TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE`
    *   **Filter:** `NAME_TYPE = 'GLOBAL'`
    *   **Why:** Both `FULL_NAME` and concatenated `FIRST_NAME || LAST_NAME` are valid, depending on requirements

17. **PO Amount Calculation from Distributions (CRITICAL):**
    *   **Rule:** Calculate PO amount as `(NONRECOVERABLE_TAX + TAX_EXCLUSIVE_AMOUNT) * RATE` from `PO_DISTRIBUTIONS_ALL`
    *   **Alternative:** Can also use `AMOUNT` from `PO_LINE_LOCATIONS_ALL` or sum from distributions
    *   **Why:** Distribution-level calculation provides more accurate amounts when tax is involved
    *   **Note:** Multiply by `PO_HEADERS_ALL.RATE` if currency conversion is needed

18. **PO Status Column Alternatives (CRITICAL):**
    *   **Rule:** Can use either `PO_HEADERS_ALL.DOCUMENT_STATUS` or `PO_HEADERS_ALL.TYPE_LOOKUP_CODE` for PO status
    *   **Why:** `DOCUMENT_STATUS` may be preferred in P2P reports, while `TYPE_LOOKUP_CODE` is used in standard PO reports
    *   **Note:** Both columns exist and serve different purposes - choose based on report requirements

19. **Buyer Name Column Alternatives (CRITICAL):**
    *   **Rule:** Can use `PER_PERSON_NAMES_F.DISPLAY_NAME`, `FULL_NAME`, or `FIRST_NAME || ' ' || LAST_NAME`
    *   **Why:** `DISPLAY_NAME` may be preferred in P2P reports, while `FULL_NAME` is standard
    *   **Date-Effective:** All patterns require `TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE` and `NAME_TYPE = 'GLOBAL'`

20. **Business Unit Source Alternatives (CRITICAL):**
    *   **Rule:** Can use `FUN_ALL_BUSINESS_UNITS_V` (Financial BU view) or `HR_ALL_ORGANIZATION_UNITS` (HR Org view)
    *   **Financial BU:** `FUN_ALL_BUSINESS_UNITS_V.BU_ID` and `BU_NAME` - preferred for P2P/Financial reports
    *   **HR Org:** `HR_ALL_ORGANIZATION_UNITS.ORGANIZATION_ID` and `NAME` - used in standard PO reports
    *   **Why:** Financial BU view aligns with AP/AR modules and provides better integration for P2P reports

21. **Supplier Address Table (CRITICAL):**
    *   **Rule:** Use `POZ_SUPPLIER_ADDRESS_V` (separate from `POZ_SUPPLIER_SITES_V`) for address details
    *   **Columns:** `ADDRESS1`, `ADDRESS2`, `CITY`, `PHONE_NUMBER`
    *   **Join:** `POZ_SUPPLIER_SITES_V.PARTY_SITE_ID = POZ_SUPPLIER_ADDRESS_V.PARTY_SITE_ID`
    *   **Why:** Address information is stored in a separate view from site information

22. **Vendor Type Lookup (CRITICAL):**
    *   **Rule:** Use `FND_LOOKUP_VALUES_TL` with `LOOKUP_TYPE = 'ORA_POZ_VENDOR_TYPE'` (NOT `'VENDOR_TYPE'`)
    *   **Filter:** `VIEW_APPLICATION_ID = 0`, `SET_ID = 0`, `LANGUAGE = USERENV('LANG')`
    *   **Why:** Supplier-specific vendor type lookup uses different lookup type than standard vendor type

23. **Vendor Status Source (CRITICAL):**
    *   **Rule:** Use `HZ_PARTIES.STATUS` for vendor status (NOT `POZ_SUPPLIERS_V.ENABLED_FLAG`)
    *   **Join:** `POZ_SUPPLIERS_V.PARTY_ID = HZ_PARTIES.PARTY_ID`
    *   **Status Values:** `'A'` = Active, `'I'` = Inactive
    *   **Decode:** `DECODE(HP.STATUS, 'A', 'Active', 'I', 'Inactive', 'Inactive')`
    *   **Why:** Party-level status provides more accurate vendor status than supplier-level enabled flag

24. **Tax Profile Table (CRITICAL):**
    *   **Rule:** Use `ZX_PARTY_TAX_PROFILE` for tax registration and classification (NOT `ZX_REGISTRATIONS`)
    *   **Columns:** `REP_REGISTRATION_NUMBER` (tax registration number), `TAX_CLASSIFICATION_CODE`
    *   **Join:** `POZ_SUPPLIERS_V.PARTY_ID = ZX_PARTY_TAX_PROFILE.PARTY_ID`
    *   **Why:** Party tax profile is the primary source for supplier tax information

25. **Business Classifications for Trade License (CRITICAL):**
    *   **Rule:** Use `POZ_BUSINESS_CLASSIFICATIONS_V` to retrieve trade license number
    *   **Filter:** `STATUS = 'A'` for active classifications
    *   **Pattern:** Search for classifications where `DISPLAYED_FIELD` or `CERTIFYING_AGENCY` contains 'TRADE LICENSE' or 'LICENSE'
    *   **Column:** `CERTIFICATE_NUMBER` contains the trade license number
    *   **Why:** Trade license is stored as a business classification, not as a direct attribute

26. **Supplier Bank Account Join Pattern (CRITICAL):**
    *   **Rule:** Join `IBY_EXT_BANK_ACCOUNTS` via `IBY_ACCOUNT_OWNERS`, `IBY_EXTERNAL_PAYEES_ALL`, and `IBY_PMT_INSTR_USES_ALL`
    *   **Path:** `IBY_EXT_BANK_ACCOUNTS.EXT_BANK_ACCOUNT_ID = IBY_ACCOUNT_OWNERS.EXT_BANK_ACCOUNT_ID`
    *   Then: `IBY_ACCOUNT_OWNERS.ACCOUNT_OWNER_PARTY_ID = IBY_EXTERNAL_PAYEES_ALL.PAYEE_PARTY_ID`
    *   Then: `IBY_ACCOUNT_OWNERS.EXT_BANK_ACCOUNT_ID = IBY_PMT_INSTR_USES_ALL.INSTRUMENT_ID`
    *   Then: `IBY_EXTERNAL_PAYEES_ALL.EXT_PAYEE_ID = IBY_PMT_INSTR_USES_ALL.EXT_PMT_PARTY_ID`
    *   **Filter:** `IBY_ACCOUNT_OWNERS.PRIMARY_FLAG = 'Y'` for primary bank account
    *   **Bank Details:** Join `IBY_EXT_BANK_ACCOUNTS.BANK_ID = CE_BANKS_V.BANK_PARTY_ID` for bank name and number
    *   **Why:** Supplier bank accounts require complex join through multiple IBY tables to link to supplier party

27. **Payment Terms Translated Table (CRITICAL):**
    *   **Rule:** Use `AP_TERMS_TL` (translated table) instead of `AP_TERMS` for multilingual support
    *   **Filter:** `AP_TERMS_TL.LANGUAGE = USERENV('LANG')`
    *   **Column:** `AP_TERMS_TL.NAME` for payment term name
    *   **Join:** `POZ_SUPPLIER_SITES_V.TERMS_ID = AP_TERMS_TL.TERM_ID`
    *   **Why:** Translated table provides payment term names in user's language

---

## 2. 🗺️ Schema Map

| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PHA** | `PO_HEADERS_ALL` | PO Header (Supplier, Number, AGENT_ID for Buyer) |
| **PLA** | `PO_LINES_ALL` | PO Line (Item, Price, Description, UOM) |
| **PLLA** | `PO_LINE_LOCATIONS_ALL`| Shipment (Qty Ordered, Qty Received, Amount, Need By Date) |
| **PDA** | `PO_DISTRIBUTIONS_ALL` | GL Account, Project coding, REQ_DISTRIBUTION_ID, RECOVERABLE_TAX |
| **PRDA** | `POR_REQ_DISTRIBUTIONS_ALL` | PR Distributions (links PO to PR via DISTRIBUTION_ID) |
| **PRLA** | `POR_REQUISITION_LINES_ALL` | Requisition Lines (links to PR distributions) |
| **PRHA**| `POR_REQUISITION_HEADERS_ALL` | Requisition Header (REQUISITION_NUMBER, DOCUMENT_STATUS, REQUESTER_ID) |
| **PRLA** | `POR_REQUISITION_LINES_ALL` | Requisition Lines (ASSESSABLE_VALUE, CURRENCY_UNIT_PRICE, QUANTITY, PO_HEADER_ID) |
| **PRDA** | `POR_REQ_DISTRIBUTIONS_ALL` | PR Distributions (CODE_COMBINATION_ID, DISTRIBUTION_NUMBER) |
| **POS** | `POZ_SUPPLIERS_V` | Supplier Master (VENDOR_NAME, SEGMENT1 as Supplier Number, PARTY_ID, VENDOR_TYPE_LOOKUP_CODE, CREATION_DATE) |
| **PSS** | `POZ_SUPPLIER_SITES_V` | Supplier Site (PARTY_SITE_NAME, PARTY_SITE_ID, TERMS_ID, PRC_BU_ID) |
| **PSAV** | `POZ_SUPPLIER_ADDRESS_V` | Supplier Address (ADDRESS1, ADDRESS2, CITY, PHONE_NUMBER) |
| **PSC** | `POZ_SUPPLIER_CONTACTS_V` | Supplier Contacts (FULL_NAME, EMAIL_ADDRESS) |
| **PBCV** | `POZ_BUSINESS_CLASSIFICATIONS_V` | Business Classifications (CERTIFICATE_NUMBER, DISPLAYED_FIELD, CERTIFYING_AGENCY, STATUS) |
| **HP** | `HZ_PARTIES` | Party Master (STATUS: 'A' = Active, 'I' = Inactive) |
| **ZPTP** | `ZX_PARTY_TAX_PROFILE` | Tax Profile (REP_REGISTRATION_NUMBER, TAX_CLASSIFICATION_CODE) |
| **IEBA** | `IBY_EXT_BANK_ACCOUNTS` | External Bank Accounts (BANK_ACCOUNT_NUM, BANK_ACCOUNT_NAME, BANK_ID) |
| **IAO** | `IBY_ACCOUNT_OWNERS` | Account Owners (PRIMARY_FLAG, ACCOUNT_OWNER_PARTY_ID) |
| **IEPA** | `IBY_EXTERNAL_PAYEES_ALL` | External Payees (PAYEE_PARTY_ID, SUPPLIER_SITE_ID, EXT_PAYEE_ID) |
| **IPIUA** | `IBY_PMT_INSTR_USES_ALL` | Payment Instrument Uses (INSTRUMENT_ID, EXT_PMT_PARTY_ID) |
| **CE** | `CE_BANKS_V` | Banks (BANK_NAME, BANK_NUMBER, BANK_PARTY_ID) |
| **AT** | `AP_TERMS` | Payment Terms (TERM_ID, NAME) |
| **APT** | `AP_TERMS_TL` | Payment Terms Translated (TERM_ID, NAME, LANGUAGE) |
| **FLVT** | `FND_LOOKUP_VALUES_TL` | Lookups (POR_DOCUMENT_STATUS, ORA_POZ_VENDOR_TYPE) |

---
