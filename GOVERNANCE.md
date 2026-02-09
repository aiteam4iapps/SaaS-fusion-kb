---
tags: [OracleFusion, Governance, Security, RBAC]
module: ADMIN
version: 1.0.0
last_updated: 2025-12-12
---

# Knowledge Base Governance & Access Control

**Purpose:** Define strategies to centralize the SQL Knowledge Base, enforce standards through Role-Based Access Control (RBAC), and manage distribution.

---

## 1. Centralization Strategy

### The "Golden Source" Repository

The Knowledge Base (KB) must reside in a version-controlled **Git Repository** (e.g., GitHub, GitLab). This ensures:

- **Version History:** Who changed a standard and when.
- **Review Process:** Changes require approval via Pull Requests (PR).

---

## 2. Hybrid Distribution Strategy (Git vs AI)

### The "Source of Truth" vs. "Consumption"

- **Git (Source of Truth):** Perfect for Control.
- **ByteRover / Openmemory (Consumption):** Perfect for Access.

### 🚀 Recommended Architecture: The "Push" Model

1. **Write Layer (Git):** Humans edit Markdown files. Approvals happen via PR.
2. **Read Layer (AI Memory):** On merge, CI/CD pushes content to ByteRover.

> [!IMPORTANT]
> **Do NOT edit directly in ByteRover.** Treat the Memory Store as a _ReadOnly Cache_ of the Git repository.

---

## 3. Real-World Example: "The Exchange Rate Rule"

### A. In Git (The Law)

**File:** `FINANCE/AR/AR_SQL_STANDARDS.md`
**Content:** `ALWAYS use NVL(EXCHANGE_RATE, 1)`
**Metadata:** _Author:_ Sarah (Lead) | _Approver:_ Mike (Finance Lead)

### B. In ByteRover (The Brain)

**Context Chunk:** "When calculating AR amounts, if the currency is functional, the exchange rate is NULL. You must use NVL(rate, 1)."
**Usage:** Agent reads this chunk to answer user questions.

---

## 4. Role-Based Access Control (RBAC)

| Role                     | Description              | Access Level            |
| ------------------------ | ------------------------ | ----------------------- |
| **Guardian / Architect** | Senior Leads             | **Write (Admin)**       |
| **Module Lead**          | SME (e.g., Finance Lead) | **Write (Module Only)** |
| **Developer**            | Report Developers        | **Read Only**           |

**Rule:** No merge to `main` is allowed unless approved by the Code Owner of that directory.

this is a test txt
