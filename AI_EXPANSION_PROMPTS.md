# AG Expansion Prompts

**Purpose:** Use these exact prompts when asking an AI (Claude, ChatGPT, etc.) to add new content to your `FUSION_SAAS` Knowledge Base.
**Why:** Ensuring the AI follows the *exact* same format as your AP/AR files is critical for maintaining the system's strict standards.

---

## 1. 🆕 Scenario: Adding a New Module
*Use this when you want to onboard a new module like General Ledger (GL), Fixed Assets (FA), or Supply Chain (SCM).*

**Copy-Paste this Prompt:**

> **Role:** You are the Senior Oracle Fusion Architect defined in `AGENT_PERSONA.md`.
>
> **Task:** Create the standard documentation package for the **[INSERT MODULE NAME, e.g., General Ledger]** module.
> **Output Location:** `FUSION_SAAS/FINANCE/[MODULE_CODE]/`
>
> **Requirements:**
> You must generate exactly 3 files, following the strict structure of the existing `AP` and `AR` folders:
>
> 1.  **`[CODE]_MASTER.md`**:
>     *   Define "Critical Constraints" (e.g., Application ID for XLA, specific date filters).
>     *   Define "Performance Optimization" (Index Hints, Join Order).
>     *   Define "Schema Map" (Key aliases and tables).
>
> 2.  **`[CODE]_REPOSITORIES.md`**:
>     *   Create optimized CTEs for the Core Entities (Header, Lines, etc.).
>     *   **Rules:**
>         *   MUST use `/*+ qb_name([CODE]_ENTITY) MATERIALIZE */` hints.
>         *   MUST include `ORG_ID` (or `LEDGER_ID`) in columns and WHERE clause.
>         *   MUST use Oracle Traditional Syntax `(+)`.
>
> 3.  **`[CODE]_TEMPLATES.md`**:
>     *   Create 1 standard report pattern (e.g., "GL Journal Register").
>     *   Use the `WITH ... SELECT` structure defined in `SYSTEM_INSTRUCTIONS.md`.
>
> **Context:**
> *   Reference `AP_MASTER.md` for the style guide.
> *   Ensure strict adherence to `SYSTEM_INSTRUCTIONS.md`.

---

## 2. 🧩 Scenario: Adding a New Repository CTE
*Use this when you need to add a new table or entity (e.g., "AP Holds") to an existing module.*

**Copy-Paste this Prompt:**

> **Role:** Senior Oracle Fusion Architect.
>
> **Task:** Create a standardized Repository CTE for the entity: **[INSERT ENTITY NAME, e.g., AP Holds]**.
>
> **Output:** A single SQL `WITH` block formatted for `[MODULE]_REPOSITORIES.md`.
>
> **Strict Constraints:**
> 1.  **Hint:** Must start with `/*+ qb_name([MOD]_[NAME]) MATERIALIZE */`.
> 2.  **Syntax:** Use ONLY Oracle Traditional Joins `(+)`. No ANSI.
> 3.  **Columns:** Include Primary Keys, `ORG_ID`, and Standard business columns.
> 4.  **Filters:** Include standard active filters (e.g., `CANCELLED_DATE IS NULL` or `STATUS = 'A'`).
>
> **Example Table:** `[INSERT TABLE NAME, e.g., AP_HOLDS_ALL]`
> **Desired Columns:** `[INSERT REQUIREMENTS, e.g., Hold Reason, Release Date]`

---

## 3. 📝 Scenario: Adding a New Instruction / Rule
*Use this when you discover a new "gotcha" or bug and want to codify it as a rule.*

**Copy-Paste this Prompt:**

> **Role:** Senior Oracle Fusion Architect.
>
> **Task:** Draft a new "Critical Constraint" for `[MODULE]_MASTER.md`.
>
> **Subject:** **[INSERT TOPIC, e.g., Handling Multi-Currency in POs]**
>
> **Format:**
> 1.  **Headline:** (e.g., "4. Currency Conversion Rule")
> 2.  **Rule:** The exact SQL `WHERE` clause or calculation required.
> 3.  **Why:** A one-sentence explanation of the business risk if missed.
> 4.  **Exception:** Any cases where this rule does not apply.
>
> **Draft content:** "[INSERT YOUR FINDING, e.g., PO headers have null rates for functional currency, need to use NVL(rate,1)]"

---

## 4. 🚀 Scenario: Create Complete HCM Suite
*Use this prompt to generate the entire Human Capital Management module (HR, Pay, Benefits) from scratch.*

**Copy-Paste this Prompt:**

> **Role:** Senior Oracle Fusion Architect.
>
> **Task:** Generate the comprehensive "Greenfield" documentation for the **HCM Module** in `FUSION_SAAS/HCM/`.
>
> **Objective:** Create the optimized directory structure and standard files for **Core HR (HR)**, **Payroll (PAY)**, and **Benefits (BEN)**.
>
> **Step 1: Directory Setup**
> *   Create folders: `FUSION_SAAS/HCM/HR/`, `FUSION_SAAS/HCM/PAY/`, `FUSION_SAAS/HCM/BEN/`.
> *   Create `FUSION_SAAS/HCM/HCM_INSTRUCTIONS.md` (Router).
>
> **Step 2: Generate Core HR (`/HR/`)**
> *   **Files:** `HR_MASTER.md`, `HR_REPOSITORIES.md`, `HR_TEMPLATES.md`.
> *   **Critical Rule:** ALL queries must handle **Date Comparision** (`TRUNC(SYSDATE) BETWEEN EFFECTIVE_START_DATE AND EFFECTIVE_END_DATE`).
> *   **Entities:** Worker (`PER_ALL_PEOPLE_F`), Assignment (`PER_ALL_ASSIGNMENTS_M`).
>
> **Step 3: Generate Payroll (`/PAY/`)**
> *   **Files:** `PAY_MASTER.md`, `PAY_REPOSITORIES.md`, `PAY_TEMPLATES.md`.
> *   **Critical Rule:** Filter by `PAYROLL_ID` and `TIME_PERIOD_ID`.
> *   **Entities:** Run Results (`PAY_RUN_RESULTS`), Element Entries (`PAY_ELEMENT_ENTRIES_F`).
>
> **Task:** Create `FUSION_SAAS/HCM/ANC/` documentation.
> **Files:** `ANC_MASTER.md`, `ANC_REPOSITORIES.md`, `ANC_TEMPLATES.md`.
> **Critical Rule:** `ANC_PER_ABS_ENTRIES` (Actual Leave) vs `ANC_PER_PLAN_ENROLLMENT`.
>
> **Step 4: Generate Benefits (`/BEN/`)**
> *   **Files:** `BEN_MASTER.md`, `BEN_REPOSITORIES.md`, `BEN_TEMPLATES.md`.
> *   **Critical Rule:** Handle "Life Events" (`BEN_PER_IN_LER`).
>
> **Constraints for ALL:**
> 1.  **Syntax:** Oracle Traditional Joins `(+)` ONLY.
> 2.  **Performance:** Use `qb_name` and `MATERIALIZE` hints.
> 3.  **Tenant:** Always join `BUSINESS_GROUP_ID` or `LEGAL_ENTITY_ID`.
>
> **Context:**
> *   Reference `AG_SYSTEM_INSTRUCTIONS.md`.
> *   Use the `AP_MASTER.md` file as the template for formatting.

---

## 5. 🏗️ Scenario: Migrate PPM Module
*Use this prompt to generate the Project Portfolio Management module (Projects, Costs).*

**Copy-Paste this Prompt:**

> **Role:** Senior Oracle Fusion Architect.
>
> **Task:** Generate the comprehensive documentation for the **PPM Module** in `FUSION_SAAS/PPM/`.
>
> **Objective:** Create standard files for **Projects (`/PROJECTS`)** and **Costing (`/COSTING`)**.
>
> **Step 1: Directory Setup**
> *   Create folders: `FUSION_SAAS/PPM/PROJECTS/`, `FUSION_SAAS/PPM/COSTING/`.
> *   Create `FUSION_SAAS/PPM/PPM_INSTRUCTIONS.md`.
>
> **Step 2: Generate Projects (`/PROJECTS/`)**
> *   **Files:** `PROJECTS_MASTER.md`, `PROJECTS_REPOSITORIES.md`, `PROJECTS_TEMPLATES.md`.
> *   **Critical Rule:** Join `PJF_PROJECTS_ALL_B` to `_TL` for names. Use `PJF_PROJECT_STATUSES_VL` for status.
> *   **Entities:** Project Master, Project Team (`PJF_PROJECT_PARTIES`).
>
> **Step 3: Generate Costing (`/COSTING/`)**
> *   **Files:** `COSTING_MASTER.md`, `COSTING_REPOSITORIES.md`, `COSTING_TEMPLATES.md`.
> *   **Critical Rule:** `PJC_EXP_ITEMS_ALL` is the base. Filter `BILLABLE_FLAG` and `REVENUE_RECOGNIZED_FLAG`.
> *   **Complex Logic:** Separate "Expenditures" (Time/Expense) from "Events" (Milestones).
>
> **Constraints:**
> *   Use `/*+ qb_name(PPM_XXX) */` hints.
> *   Include `ORG_ID` in all joins.
>
> **Context:**
> *   Reference `AG_SYSTEM_INSTRUCTIONS.md`.

