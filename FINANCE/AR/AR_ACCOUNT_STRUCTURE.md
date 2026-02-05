# Accounts Receivable - Account Structure

**Document Purpose:** Defines the Chart of Accounts structure for Accounts Receivable in Project K.  
**Last Updated:** January 5, 2026  
**Source:** Natural Account Structure Analysis

---

## 📋 Overview

This document provides comprehensive details about the Account Receivable (AR) account structure, including Natural Account codes, control account configurations, and segment combinations used in Project K.

---

## 🎯 Natural Accounts for AR Customer Control Accounts

Project K uses **2 primary Natural Accounts** for managing Accounts Receivable with customers:

| Natural Account | Usage | Count | Percentage | Primary Purpose |
|-----------------|-------|-------|------------|-----------------|
| **32010119** | Trade Receivables | 181 | 47% | Standard customer trade receivables with project tracking |
| **32050102** | Intercompany Receivables | 203 | 53% | Intercompany customer receivables between entities |

**Total Customer Control Accounts:** 384

---

## 🏗️ Account Structure by Natural Account

### 1. Natural Account: 32010119 (Trade Receivables)

**Characteristics:**
- **Account Type:** Asset
- **Control Account:** Customer Control Account
- **Financial Category:** Accounts receivable
- **Primary Use:** Trade receivables with project and contract type tracking
- **Posting Allowed:** TRUE
- **Reconciliation:** No

**Typical Structure:**
```
Entity.32010119.000.ProjectCode.ContractType.InterCompany.0000.0000
```

**Common Patterns:**
- Standard Trade AR: `XXX.32010119.000.0000.0000.AAA.0000.0000`
- Project-based AR: `XXX.32010119.000.[ProjectID].0000.AAA.0000.0000`
- Contract-type AR: `XXX.32010119.000.0000.[LSUM|MIX|REIM|URAT].AAA.0000.0000`
- IC Project AR: `XXX.32010119.000.[ProjectID].[ContractType].[IC_Entity].0000.0000`

**Contract Types Used:**
- `0000` - Standard contracts
- `LSUM` - Lump Sum contracts
- `MIX` - Mixed contracts
- `REIM` - Reimbursable contracts
- `URAT` - Unit Rate contracts

**Project Code Examples:**
- `0213`, `0332`, `0366`, `0367`, `0412`, `0421`, `0459`, `0504`, `0505`, `0519`, `0547`, `0562`, `0563`, `0564`, `0565`, `0568`, `0571`, `0579`, `0580`, `0583`, `0585`, `0586`, `0588`, `0589`, `0591`, `0597`, `0598`, `0599`, `0601`, `0605`, `0607`, `0608`, `0609`, `0610`, `0612`, `0613`, `0616`, `0626`, `0627`, `0630`, `0634`, `0635`, `0636`, `0638`, `0642`, `0643`, `0644`, `0651`, `0654`, `0657`, `0660`

---

### 2. Natural Account: 32050102 (Intercompany Receivables)

**Characteristics:**
- **Account Type:** Asset
- **Control Account:** Customer Control Account
- **Financial Category:** Accounts receivable
- **Primary Use:** Intercompany receivables between legal entities
- **Posting Allowed:** TRUE
- **Reconciliation:** No

**Typical Structure:**
```
Entity.32050102.000.0000.0000.TradingPartner.0000.0000
```

**Common Patterns:**
- IC Entity-to-Entity: `Entity1.32050102.000.0000.0000.Entity2.0000.0000`
- IC with Project: `Entity1.32050102.000.[ProjectID].0000.Entity2.0000.0000`
- IC with Contract: `Entity1.32050102.000.0000.[ContractType].Entity2.0000.0000`

**Intercompany Trading Partners (Segment6):**
- `AAA` - Default/General
- `AZB` - Azerbaijan Entity
- `CHI` - Specific subsidiary
- `DMC` - DMC Entity
- `DMG` - DMG Entity
- `GEO` - Georgia Entity
- `HEK` - HEK subsidiary
- `JSH` - JSH subsidiary
- `KAD` - KAD Entity
- `KAU` - KAU Entity
- `KCA` - KCA Entity
- `KCH` - KCH subsidiary
- `KEG` - KEG subsidiary
- `KGH` - KGH subsidiary
- `KGS` - KGS subsidiary
- `KGU` - KGU subsidiary
- `KGZ` - KGZ subsidiary
- `KHO` - KHO subsidiary
- `KID` - KID Entity
- `KIN` - KIN subsidiary
- `KIQ` - KIQ subsidiary
- `KKU` - KKU subsidiary
- `KKW` - KKW subsidiary
- `KKZ` - KKZ Entity
- `KMB` - KMB Entity
- `KOM` - KOM subsidiary
- `KPB` - KPB Entity
- `KQT` - KQT subsidiary
- `KSA` - KSA subsidiary
- `KST` - KST subsidiary
- `KTS` - KTS subsidiary
- `KUK` - KUK subsidiary
- `TAL` - TAL subsidiary

---

## 🏢 Entity Distribution

### Primary Entities Using AR Accounts:

| Entity Code | Entity Name | Description |
|-------------|-------------|-------------|
| `DMC` | DMC Entity | Primary operating entity |
| `KAD` | KAD Entity | Operating entity |
| `KID` | KID Entity | Operating entity |
| `KKZ` | KKZ Entity | Operating entity |
| `KMB` | KMB Entity | Operating entity |
| `KPB` | KPB Entity | Operating entity |
| `KSA` | KSA Subsidiary | Subsidiary entity |
| `KQT` | KQT Subsidiary | Subsidiary entity |
| `KKU` | KKU Subsidiary | Subsidiary entity |
| `AZB` | Azerbaijan | Regional entity |
| `GEO` | Georgia | Regional entity |
| `CHI` | CHI Subsidiary | Subsidiary entity |
| `KEG` | KEG Subsidiary | Subsidiary entity |
| `KIN` | KIN Subsidiary | Subsidiary entity |
| `TAL` | TAL Subsidiary | Subsidiary entity |

---

## 📊 Account Combination Examples

### Example 1: Standard Trade Receivable
```
DMC.32010119.000.0000.0000.AAA.0000.0000
```
- **Entity:** DMC
- **Natural Account:** 32010119 (Trade AR)
- **Cost Center:** 000 (Default)
- **Project:** 0000 (No specific project)
- **Contract Type:** 0000 (Standard)
- **InterCompany:** AAA (Default)

### Example 2: Project-based Lump Sum AR
```
KAD.32010119.000.0459.LSUM.AAA.0000.0000
```
- **Entity:** KAD
- **Natural Account:** 32010119 (Trade AR)
- **Cost Center:** 000 (Default)
- **Project:** 0459 (Specific project)
- **Contract Type:** LSUM (Lump Sum)
- **InterCompany:** AAA (No IC)

### Example 3: Intercompany Receivable
```
DMC.32050102.000.0000.0000.KKZ.0000.0000
```
- **Entity:** DMC (Selling entity)
- **Natural Account:** 32050102 (IC AR)
- **Cost Center:** 000 (Default)
- **Project:** 0000 (No project)
- **Contract Type:** 0000 (Standard)
- **InterCompany:** KKZ (Buying entity)

### Example 4: IC AR with Project and Contract
```
KID.32050102.000.0565.REIM.KKZ.0000.0000
```
- **Entity:** KID (Selling entity)
- **Natural Account:** 32050102 (IC AR)
- **Cost Center:** 000 (Default)
- **Project:** 0565 (Specific project)
- **Contract Type:** REIM (Reimbursable)
- **InterCompany:** KKZ (Buying entity)

### Example 5: Unit Rate Contract AR
```
KKZ.32010119.000.0612.URAT.AAA.0000.0000
```
- **Entity:** KKZ
- **Natural Account:** 32010119 (Trade AR)
- **Cost Center:** 000 (Default)
- **Project:** 0612 (Specific project)
- **Contract Type:** URAT (Unit Rate)
- **InterCompany:** AAA (External customer)

---

## 🔍 Key Design Patterns

### 1. Segment Usage Strategy

| Segment | Column Name | AR Usage | Notes |
|---------|-------------|----------|-------|
| Segment1 | Entity | ✅ Required | Legal entity/balancing segment |
| Segment2 | NaturalAccount | ✅ Required | 32010119 or 32050102 |
| Segment3 | CostCenter | ⚪ Default (000) | Typically not used for AR |
| Segment4 | Project | ✅ Conditional | Used when AR tied to specific project |
| Segment5 | ContractType | ✅ Conditional | LSUM, MIX, REIM, URAT, or 0000 |
| Segment6 | InterCompany | ✅ Required | Trading partner for IC, AAA for external |
| Segment7 | Future1 | ⚪ Reserved (0000) | Not currently used |
| Segment8 | Future2 | ⚪ Reserved (0000) | Not currently used |

### 2. Account Determination Logic

**For Trade AR (32010119):**
```
IF Customer = External THEN
    InterCompany = 'AAA'
    IF Project-based THEN
        Project = [Project_ID]
        ContractType = [LSUM|MIX|REIM|URAT]
    ELSE
        Project = '0000'
        ContractType = '0000'
    END IF
END IF
```

**For IC AR (32050102):**
```
IF Customer = Internal Entity THEN
    InterCompany = [Trading_Partner_Entity]
    Project = [Project_ID or '0000']
    ContractType = [Type or '0000']
END IF
```

---

## 📈 Usage Statistics

### By Natural Account:
- **32010119 (Trade AR):** 181 accounts (47%)
- **32050102 (IC AR):** 203 accounts (53%)

### By Account Attribute:
- **Enabled Accounts:** 384 (100%)
- **Allow Posting:** 384 (100%)
- **Preserve Attributes:** Mix of TRUE/FALSE based on historical setup
- **Date-restricted:** ~10 accounts have To Date set

### Project-Based AR:
- **With Projects:** ~120 accounts (31%)
- **Standard (No Project):** ~264 accounts (69%)

### Contract Type Distribution:
- **Standard (0000):** ~55%
- **LSUM:** ~12%
- **REIM:** ~18%
- **MIX:** ~8%
- **URAT:** ~7%

---

## 🔗 Related Tables and Views

### Key Oracle Fusion Tables:

| Table Name | Description | Key Columns |
|------------|-------------|-------------|
| `GL_CODE_COMBINATIONS` | Chart of Accounts | `CODE_COMBINATION_ID`, `SEGMENT1-8` |
| `RA_CUSTOMER_TRX_ALL` | AR Transactions | `CUSTOMER_TRX_ID`, `CODE_COMBINATION_ID` |
| `RA_CUSTOMER_TRX_LINES_ALL` | AR Transaction Lines | `CUSTOMER_TRX_LINE_ID`, `CODE_COMBINATION_ID` |
| `RA_CUST_TRX_LINE_GL_DIST_ALL` | AR GL Distributions | `CUST_TRX_LINE_GL_DIST_ID`, `CODE_COMBINATION_ID` |
| `HZ_CUST_ACCOUNTS` | Customer Accounts | `CUST_ACCOUNT_ID` |
| `HZ_PARTIES` | Customer Parties | `PARTY_ID`, `PARTY_NAME` |

---

## 💡 Best Practices

### 1. Account Selection Guidelines

✅ **Use 32010119 when:**
- Customer is external (third-party)
- Transaction tied to a project
- Contract type tracking required
- Standard trade receivables

✅ **Use 32050102 when:**
- Customer is an internal legal entity
- Intercompany transaction
- IC reconciliation required
- Cross-entity billing

### 2. Segment Population Rules

- **Segment1 (Entity):** Always populate with selling entity
- **Segment2 (Natural Account):** 32010119 or 32050102 based on customer type
- **Segment3 (Cost Center):** Default to '000' for AR
- **Segment4 (Project):** Populate if project-based revenue; otherwise '0000'
- **Segment5 (Contract Type):** Use appropriate contract type or '0000'
- **Segment6 (InterCompany):** Trading partner code for IC; 'AAA' for external
- **Segment7-8 (Future):** Always '0000' for now

### 3. Query Optimization Tips

```sql
-- Example: Query AR by Natural Account
SELECT 
    gcc.SEGMENT1 AS Entity,
    gcc.SEGMENT2 AS NaturalAccount,
    gcc.SEGMENT4 AS Project,
    gcc.SEGMENT5 AS ContractType,
    gcc.SEGMENT6 AS InterCompany,
    COUNT(*) AS TransactionCount
FROM 
    GL_CODE_COMBINATIONS gcc
WHERE 
    gcc.SEGMENT2 IN ('32010119', '32050102')
    AND gcc.ENABLED_FLAG = 'Y'
GROUP BY 
    gcc.SEGMENT1, gcc.SEGMENT2, gcc.SEGMENT4, 
    gcc.SEGMENT5, gcc.SEGMENT6
ORDER BY 
    gcc.SEGMENT1, gcc.SEGMENT2;
```

---

## 🔄 Maintenance and Updates

### Version History:
- **v1.0** (Jan 2026): Initial documentation based on current COA structure
- Total accounts documented: 384

### Update Schedule:
- Review quarterly when new projects/entities added
- Update after any COA restructuring
- Validate after major system upgrades

### Data Source:
- **File:** Natural Account Structure.csv
- **Date Extracted:** January 5, 2026
- **Total Records:** 6,510 accounts (384 AR Customer Control Accounts)

---

## 📞 Contact & References

### Related Documentation:
- [`ENV_METADATA.md`](../../CONFIGURATION/ENV_METADATA.md) - COA segment definitions
- [`AR_MASTER.md`](AR_MASTER.md) - AR module master documentation
- [`AR_REPOSITORIES.md`](AR_REPOSITORIES.md) - AR data sources and queries

### For Questions:
- **Functional:** Finance AR Team
- **Technical:** ERP Technical Team
- **Data:** Data Governance Team

---

**End of Document**

