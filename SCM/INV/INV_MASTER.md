# Inventory Master Instructions

**Module:** Inventory (INV)
**Tag:** `#SCM #INV #Inventory`
**Status:** Active

---

## 1. 🚨 Critical Inventory Constraints

1.  **Organizational Context:**
    *   **Rule:** Item tables MUST join `ORGANIZATION_ID`.
    *   **Why:** The same Item ID can exist in 50 different warehouses with different attributes.
    *   **Pattern:** `WHERE MSI.INVENTORY_ITEM_ID = T.ITEM_ID AND MSI.ORGANIZATION_ID = T.ORGANIZATION_ID`

2.  **Transaction Types:**
    *   **Rule:** Filter `MTL_MATERIAL_TRANSACTIONS` by `TRANSACTION_TYPE_ID` to distinguish Sales vs Receipts vs Adjustments.

---

## 2. 🗺️ Schema Map

### Core Inventory Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **IMT** | `INV_MATERIAL_TXNS` | Material transactions (all movements) |
| **IOP** | `INV_ORG_PARAMETERS` | Organization/Warehouse parameters |
| **IOQD** | `INV_ONHAND_QUANTITIES_DETAIL` | Current on-hand quantities |
| **IIL** | `INV_ITEM_LOCATIONS` | Inventory locators/bins |
| **ISI** | `INV_SECONDARY_INVENTORIES` | Subinventory details |
| **ITST** | `INV_TXN_SOURCE_TYPES_VL` | Transaction source types |
| **IRTH** | `INV_TXN_REQUEST_HEADERS` | Transaction request headers |
| **ITT** | `INV_TRANSACTION_TYPES_B` | Transaction types base |
| **ITTTL** | `INV_TRANSACTION_TYPES_TL` | Transaction types translated |
| **ISO** | `INV_SALES_ORDERS` | Sales order reference |

### Item Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **ESIB** | `EGP_SYSTEM_ITEMS_B` | Item master base |
| **ESITL** | `EGP_SYSTEM_ITEMS_TL` | Item master translated |
| **ESIV** | `EGP_SYSTEM_ITEMS_VL` | Item master view |
| **EIC** | `EGP_ITEM_CATEGORIES` | Item categories |
| **ECV** | `EGP_CATEGORIES_VL` | Category values |
| **IUOMV** | `INV_UNITS_OF_MEASURE_VL` | Unit of measure view |
| **IUOMB** | `INV_UNITS_OF_MEASURE_B` | Unit of measure base |
| **IUOMT** | `INV_UNITS_OF_MEASURE_TL` | Unit of measure translated |

### Receiving Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **RSH** | `RCV_SHIPMENT_HEADERS` | Receipt headers |
| **RSL** | `RCV_SHIPMENT_LINES` | Receipt lines |
| **RT** | `RCV_TRANSACTIONS` | Receipt transactions |

### Costing Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **CIT** | `CST_INV_TRANSACTIONS` | Cost inventory transactions |
| **CTCS** | `CST_TRANSACTIONS` | Cost transactions |
| **CPC** | `CST_PERPAVG_COST` | Perpetual average cost |

### Purchase Order Tables (INV context)
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PHA** | `PO_HEADERS_ALL` | PO headers for receiving |
| **PLA** | `PO_LINES_ALL` | PO lines for receiving |
| **PLLA** | `PO_LINE_LOCATIONS_ALL` | PO shipments for receiving |

### Project Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **PPAB** | `PJF_PROJECTS_ALL_B` | Project master |
| **PTV** | `PJF_TASKS_V` | Project tasks |

### Organization & GL Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **HOU** | `HR_ORGANIZATION_UNITS_F_TL` | Organization units |
| **GCC** | `GL_CODE_COMBINATIONS` | Chart of accounts |

### Lookup Tables
| Alias | Table Name | Purpose |
|-------|------------|---------|
| **FLV** | `FND_LOOKUP_VALUES` | Lookup values |
| **FLVV** | `FND_LOOKUP_VALUES_VL` | Lookup values view |

---

## 3. 🔑 Primary Key Fields

- **INV_MATERIAL_TXNS:** `TRANSACTION_ID`
- **INV_ONHAND_QUANTITIES_DETAIL:** Composite (INVENTORY_ITEM_ID, ORGANIZATION_ID, SUBINVENTORY_CODE, LOCATOR_ID)
- **INV_ITEM_LOCATIONS:** `INVENTORY_LOCATION_ID`
- **INV_SECONDARY_INVENTORIES:** Composite (ORGANIZATION_ID, SECONDARY_INVENTORY_NAME)
- **EGP_SYSTEM_ITEMS_B:** Composite (INVENTORY_ITEM_ID, ORGANIZATION_ID)
- **RCV_SHIPMENT_HEADERS:** `SHIPMENT_HEADER_ID`
- **RCV_TRANSACTIONS:** `TRANSACTION_ID`

---

## 4. 🚨 Critical Constraints & Business Rules

### Organization Context
**Rule:** ALWAYS include ORGANIZATION_ID in joins
```sql
AND IMT.ORGANIZATION_ID = IOP.ORGANIZATION_ID
AND ESIB.ORGANIZATION_ID = IMT.ORGANIZATION_ID
```

### Transaction Date Filtering
**Rule:** Filter by transaction year/period
```sql
AND TO_CHAR(IMT.TRANSACTION_DATE, 'YYYY') = :P_TRX_PERIOD
-- OR
AND TRUNC(IMT.TRANSACTION_DATE) BETWEEN :P_FROM_DATE AND :P_TO_DATE
```

### Transaction Type Filtering
**Rule:** Filter by transaction action
```sql
AND IMT.TRANSACTION_ACTION_ID = INV_ACTION.LOOKUP_CODE(+)
-- Common actions: Issue, Receipt, Transfer, Adjustment
```

### Receipt Transaction Type
**Rule:** Filter for receipts only
```sql
AND RT.TRANSACTION_TYPE = 'RECEIVE'
```

### Costing Interface Status
**Rule:** Check if transaction has been costed
```sql
CASE 
    WHEN IMT.JOB_DEFINITION_NAME IS NOT NULL 
    THEN 'Interfaced to costing'
    ELSE 'Pending interface to costing'
END AS COSTING_STATUS
```

### On-Hand Quantity Filtering
**Rule:** Filter zero quantities for active stock
```sql
AND SUM(IOQD.TRANSACTION_QUANTITY) <> 0
-- OR show all including zero
GROUP BY ... HAVING SUM(TRANSACTION_QUANTITY) <> 0
```

### Lot & Serial Control
**Rule:** Check if item is lot/serial controlled
```sql
CASE 
    WHEN ESIB.LOT_CONTROL_CODE = 2 THEN 'Y'
    ELSE 'N'
END AS LOT_CONTROLLED

CASE 
    WHEN ESIB.SERIAL_NUMBER_CONTROL_CODE != 1 THEN 'Y'
    ELSE 'N'
END AS SERIAL_CONTROLLED
```

### Locator Name Retrieval
**Critical Pattern:** Use FND_FLEX_EXT to get locator concatenated segments
```sql
NVL2(IIL.STRUCTURE_INSTANCE_NUMBER, 
     FND_FLEX_EXT.GET_SEGS('INV', 'MTLL', IIL.STRUCTURE_INSTANCE_NUMBER, 
                           IIL.INVENTORY_LOCATION_ID, IIL.SUBINVENTORY_ID), 
     NULL) AS LOCATOR_NAME
```

### Cost Calculation
**Rule:** Get average cost from costing tables
```sql
ROUND(AVG(CPC.UNIT_COST_AVERAGE), 5) AS ACTUAL_COST
```

### Project Context
**Rule:** Link transactions to projects where applicable
```sql
AND IOQD.PROJECT_ID = PPAB.PROJECT_ID(+)
AND IOQD.TASK_ID = PTV.TASK_ID(+)
```

### Transaction Source Type
**Rule:** Identify transaction source (PO, Sales Order, etc.)
```sql
AND IMT.TRANSACTION_SOURCE_TYPE_ID = ITST.TRANSACTION_SOURCE_TYPE_ID(+)
-- Common sources: Purchase Order, Sales Order, Inventory, Account
```

### Subinventory Transfer Handling
**Rule:** Handle transfer transactions (from/to subinv)
```sql
IMT.SUBINVENTORY_CODE AS FROM_SUBINV
,IMT.TRANSFER_SUBINVENTORY AS TO_SUBINV
```

### Receipt Matching (2-way, 3-way, 4-way)
**Rule:** Match receipts to POs and Invoices
```sql
-- PO to Receipt (2-way)
RT.PO_HEADER_ID = PHA.PO_HEADER_ID

-- Receipt to Invoice (3-way)
RSL.PO_DISTRIBUTION_ID = AILA.PO_DISTRIBUTION_ID
AND RT.TRANSACTION_ID = AILA.RCV_TRANSACTION_ID
```

### Date Effective Organization Names
**Rule:** Filter organization names by effective date
```sql
AND TRUNC(SYSDATE) BETWEEN TRUNC(HOU.EFFECTIVE_START_DATE) 
                       AND TRUNC(HOU.EFFECTIVE_END_DATE)
AND USERENV('LANG') = HOU.LANGUAGE
```

---
