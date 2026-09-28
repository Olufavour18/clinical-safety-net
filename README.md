# Autonomous Clinical Drug-Interaction & Dosage Safety Net

[![Status](https://img.shields.io/badge/status-portfolio%20prototype-blue)](.)
[![Platform](https://img.shields.io/badge/orchestration-n8n-orange)](.)
[![Database](https://img.shields.io/badge/database-PostgreSQL%20%2F%20Supabase-336791)](.)
[![Safety](https://img.shields.io/badge/clinical%20use-NOT%20FOR%20PRODUCTION-critical)](.)

**Healthcare Clinical Decision Support Prototype — Portfolio Project**

> ⚠️ **DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE**  
> This is a technical portfolio prototype. It must **not** be used for real patient care, prescribing, or dispensing. All patient data and clinical rules are synthetic. Replace the rules dataset with an authoritative, validated clinical knowledge source before any real-world consideration.

---

## Overview

A hospital pharmacy **safety layer** built entirely around **n8n** that screens a new electronic prescription against a patient’s full active medication list, allergies, and renal/hepatic labs **before** the prescription is cleared for dispensing.

**Core design principle:**

```text
Deterministic clinical rules → safety findings → AI explanation → pharmacist human approval → audit log
```

The AI Agent **explains** findings only. It never decides clinical safety, invents interactions, or auto-approves prescriptions.

---

## Problem

Medication errors can occur when a new e-prescription is evaluated without considering:

- The patient’s complete active medication list  
- Known allergies and drug classes  
- Current renal and hepatic laboratory values  
- Dose ranges appropriate to the clinical context  

Manual review is essential but can be delayed under operational pressure.

---

## Solution

An **n8n-first** workflow that:

1. Receives a new e-prescription via webhook  
2. Retrieves synthetic patient profile, active meds, allergies, and labs  
3. Runs a **deterministic** safety engine against a versioned demo rules dataset  
4. Auto-clears prescriptions with **no** findings  
5. Routes flagged cases to an AI Agent for plain-language explanation  
6. Holds the prescription for pharmacist sign-off (Slack + Wait node)  
7. Logs every decision and override (with justification) to an audit database  

---

## Architecture

```text
E-Prescription
      ↓
n8n Webhook (01 - Receive Prescription)
      ↓
Validate Input (02)
      ↓
Patient Context (03–06)
  • Demographics & weight
  • Active medications
  • Allergies
  • Renal / hepatic labs
      ↓
Normalize + Load Rules (07–08)
      ↓
Deterministic Safety Engine (09 - Code Node)
      ↓
Safety Decision (10)
      ├── CLEAR  → Auto Clear → Audit Log
      └── FLAGGED
            ↓
        AI Clinical Explanation (11)
            ↓
        Pharmacist Review – Slack (12)
            ↓
        Wait for Webhook Event (13)
            ↓
        Validate Decision (14)
            ↓
        Process Decision (15)
            ↓
        Audit Log (16)
```

---

## Tech Stack

| Layer                    | Technology                          |
|--------------------------|-------------------------------------|
| Orchestration            | n8n                                 |
| Intake & approval        | Webhook nodes                       |
| Patient & audit data     | PostgreSQL / Supabase               |
| Deterministic engine     | n8n Code Node (JavaScript)          |
| Explanation              | AI Agent node (LangChain)           |
| Human-in-the-loop        | Wait node + Slack                   |
| Clinical rules           | Versioned JSON                      |
| Secrets                  | n8n Credentials / environment vars  |

---

## Key Features

- Drug–drug interaction screening  
- Allergy / class conflict detection  
- Duplicate therapy detection  
- Dose-range validation (demo ranges)  
- Renal adjustment checks (eGFR-based demo rules)  
- Hepatic adjustment checks (ALT-based demo rules)  
- AI-assisted plain-language explanation (findings only)  
- Pharmacist approval with **mandatory justification** on override  
- Full audit trail  
- Fail-safe behavior when data or rules are missing  
- Synthetic test patients and 8 documented test scenarios  

---

## Repository Structure

```text
clinical-safety-net/
├── README.md                          ← You are here
├── database/
│   ├── schema.sql                     ← Full relational schema
│   └── dashboard_views.sql            ← Reporting views
├── data/
│   └── seed_data.sql                  ← 5 synthetic patients + meds/labs/allergies
├── rules/
│   └── clinical_rules_demo_v1.json    ← DEMO rules (DDI, allergy, dose, renal, hepatic)
├── n8n/
│   ├── workflow_clinical_safety_net.json  ← Importable n8n workflow
│   ├── safety_engine.js               ← Deterministic engine (paste into Code node)
│   └── ai_agent_system_prompt.md      ← Strict explanation-only prompt
├── examples/
│   ├── webhook_payloads.json          ← Ready-to-POST test payloads
│   └── example_outputs.json           ← Sample engine responses
├── tests/
│   └── test_scenarios.md              ← 8 end-to-end test cases
├── docs/
│   ├── architecture.md
│   ├── setup.md                       ← Step-by-step setup
│   └── security.md
└── scripts/                           ← Reserved for helpers
```

---

## Quick Start

### 1. Database

```bash
createdb clinical_safety_net
psql -d clinical_safety_net -f database/schema.sql
psql -d clinical_safety_net -f data/seed_data.sql
```

### 2. n8n

1. Import `n8n/workflow_clinical_safety_net.json`
2. Paste the full contents of `n8n/safety_engine.js` into node **09 - Run Safety Engine**
3. Configure PostgreSQL, Slack, and LLM credentials
4. Set the AI Agent system message from `n8n/ai_agent_system_prompt.md`
5. Activate the workflow and copy the intake webhook URL

### 3. Test

```bash
curl -X POST "https://<your-n8n-host>/webhook/prescription-intake" \
  -H "Content-Type: application/json" \
  -d @examples/webhook_payloads.json
```

Use individual payloads from `examples/webhook_payloads.json` and follow `tests/test_scenarios.md`.

Full instructions: **[docs/setup.md](docs/setup.md)**

---

## Test Scenarios (Summary)

| # | Scenario                         | Expected result              |
|---|----------------------------------|------------------------------|
| 1 | No interaction                   | CLEAR (auto-clear)           |
| 2 | Warfarin + Ibuprofen             | HIGH interaction → review    |
| 3 | Amoxicillin + penicillin allergy | CRITICAL allergy → review    |
| 4 | Digoxin dose above demo range    | Dose flag → review           |
| 5 | Metformin + low eGFR             | Renal flag → review          |
| 6 | Multiple findings                | Multiple flags → review      |
| 7 | Missing data / rules             | SCREENING INCOMPLETE (hold)  |
| 8 | Pharmacist override              | Approved + justification logged |

---

## Safety Disclaimer

This project is a **technical demonstration** for portfolio and educational purposes only.

- All patient data is synthetic.  
- All clinical rules are synthetic and labeled **“DEMO / SYNTHETIC CLINICAL RULES — NOT FOR CLINICAL USE”**.  
- The engine and AI layers are **not** substitutes for validated clinical knowledge bases or professional judgment.  

Do **not** deploy against real patients without:

- Authoritative, regularly updated drug-interaction and dosing data  
- Clinical validation and governance  
- Appropriate security, privacy, and regulatory controls  
- Continuous human clinical oversight  

---

## License

Portfolio prototype. Free to use and adapt for non-clinical demonstration and learning.  
Always retain the **“NOT FOR CLINICAL USE”** labeling when presenting or sharing.
