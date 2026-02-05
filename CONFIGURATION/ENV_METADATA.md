# Environment Metadata Configuration

**Purpose:** Defines customer-specific mappings for Flexfields and COA.
**Usage:** The AI Agent reads this file to understand *your* specific data model.

---

## 1. 📊 Chart of Accounts (COA) Map
*Map `GL_CODE_COMBINATIONS` segments to Business Names.*

| Segment Column | Business Name | Description | Value Set Name |
|----------------|---------------|-------------|----------------|
| `SEGMENT1` | **Company** | Legal Entity / Balancing Segment | `XX_COMPANY_VS` |
| `SEGMENT2` | **Cost Center** | Department / Cost Owner | `XX_COST_CENTER_VS` |
| `SEGMENT3` | **Account** | Natural Account (Assets, Exp) | `XX_ACCOUNT_VS` |
| `SEGMENT4` | **Intercompany** | Trading Partner | `XX_INTERCO_VS` |
| `SEGMENT5` | **Product** | Product Line or LOB | `XX_PRODUCT_VS` |
| `SEGMENT6` | **Future1** | Reserved for future usage | `XX_FUTURE1_VS` |

---

## 2. 📋 Project K - Code Combination Segments Structure
*Chart of Accounts segment configuration for Project K environment.*

| Sequence Number | Name | Segment Code | Column Name | Prompt | Enabled |
|-----------------|------|--------------|-------------|--------|---------|
| 1 | Entity | Entity | `SEGMENT1` | Entity | ✓ |
| 2 | NaturalAccount | NaturalAccount | `SEGMENT2` | Natural Account | ✓ |
| 3 | CostCenter | CostCenter | `SEGMENT3` | Cost Center | ✓ |
| 4 | Project | Project | `SEGMENT4` | Project | ✓ |
| 5 | ContractType | ContractType | `SEGMENT5` | Contract Type | ✓ |
| 6 | InterCompany | InterCompany | `SEGMENT6` | InterCompany | ✓ |
| 7 | Future1 | Future1 | `SEGMENT7` | Future 1 | ✓ |
| 8 | Future2 | Future2 | `SEGMENT8` | Future2 | ✓ |

**Key Characteristics:**
- **Total Segments:** 8 enabled segments
- **Balancing Segment:** SEGMENT1 (Entity)
- **Natural Account:** SEGMENT2 (NaturalAccount)
- **Cost Center:** SEGMENT3 (CostCenter)
- **Project Tracking:** SEGMENT4 (Project)
- **Contract Management:** SEGMENT5 (ContractType)
- **Intercompany:** SEGMENT6 (InterCompany)
- **Reserved:** SEGMENT7 & SEGMENT8 (Future1, Future2)

---

## 3. 🔑 Key Flexfields (KFF)
*Map other critical KFF structures.*

### Assets (Fixed Assets)
*   **Table:** `FA_CATEGORIES_B`
*   **Segment1:** Major Category (e.g., Hardware)
*   **Segment2:** Minor Category (e.g., Laptop)

### Items (Inventory)
*   **Table:** `MTL_SYSTEM_ITEMS_B`
*   **Segment1:** Item Family
*   **Segment2:** SKU Number

---

## 4. 📝 Descriptive Flexfields (DFF)
*Map `ATTRIBUTE` columns to Business Purposes.*

### Accounts Payable
| Table Name | Column | Business Name | Usage Notes |
|------------|--------|---------------|-------------|
| `AP_INVOICES_ALL` | `ATTRIBUTE1` | **Legacy Invoices ID** | Migration reference |
| `AP_INVOICES_ALL` | `ATTRIBUTE2` | **Approval Route** | 'Fast' or 'Standard' |
| `AP_INVOICE_LINES_ALL` | `ATTRIBUTE1`| **Tax Authority** | Geo Code |

### Projects
| Table Name | Column | Business Name | Usage Notes |
|------------|--------|---------------|-------------|
| `PJF_PROJECTS_ALL_B` | `ATTRIBUTE1` | **Capital Request ID** | Capex Ref |
| `PJF_PROJECTS_ALL_B` | `ATTRIBUTE10`| **Region** | Sales Region |

### Accounts Receivable (Project K)
| Table Name | Column | Business Name | Usage Notes |
|------------|--------|---------------|-------------|
| `AR_CASH_RECEIPTS_ALL` | `ATTRIBUTE1` | **Project Number** | Project tracking for receipts |
| `RA_CUSTOMER_TRX_ALL` | `ATTRIBUTE1` | **E-Invoice Number** | Electronic invoice reference |
| `RA_CUSTOMER_TRX_ALL` | `ATTRIBUTE2` | **LUT Number** | Legal/Tax reference |
| `RA_CUSTOMER_TRX_LINES_ALL` | `ATTRIBUTE1` | **HSN Code** | Harmonized System Nomenclature |
| `RA_CUSTOMER_TRX_LINES_ALL` | `ATTRIBUTE2` | **Location** | Colombia-specific location |
| `RA_CUSTOMER_TRX_LINES_ALL` | `ATTRIBUTE3` | **Employee Information** | Employee details for tracking |

---

## 5. 🏢 Ledger & Org IDs
*Hardcoded IDs for specific environments (Dev/Test/Prod).*

| Environment | Ledger ID | Org ID (US) | Org ID (UK) |
|-------------|-----------|-------------|-------------|
| **DEV1** | `300000001` | `204` | `205` |
| **TEST** | `300000002` | `204` | `205` |
| **PROD** | `300000003` | `204` | `205` |
