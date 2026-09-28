# Architecture

**Autonomous Clinical Drug-Interaction & Dosage Safety Net**  
DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE

---

## High-Level Flow

```
┌─────────────────────┐
│  E-Prescription     │
│  (EHR / CPOE)       │
└──────────┬──────────┘
           │ POST /webhook/prescription-intake
           ▼
┌─────────────────────┐
│  n8n Webhook        │  01 - Receive Prescription
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Validate Input     │  02
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  PostgreSQL         │  03–06
│  • patients         │
│  • active_meds      │
│  • allergies        │
│  • clinical_labs    │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Normalize +        │  07–08
│  Load Rules JSON    │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  Deterministic      │  09 - Code Node
│  Safety Engine      │  (safety_engine.js)
└──────────┬──────────┘
           ▼
     ┌─────┴─────┐
     │  Decision │  10
     └─────┬─────┘
           │
     ┌─────┴──────────────────┐
     │                        │
 CLEAR                      FLAGGED
     │                        │
     ▼                        ▼
 Auto Clear              AI Explanation  11
     │                        │
     │                   Slack Review    12
     │                        │
     │                   Wait (Webhook)  13
     │                        │
     │                   Validate +      14–15
     │                   Process Decision
     │                        │
     └────────────┬───────────┘
                  ▼
           Audit Log (16)
                  │
                  ▼
           Respond / Continue
```

---

## Component Responsibilities

| Node / Component | Responsibility | Must NOT |
|------------------|----------------|----------|
| Webhook intake | Accept prescription payload | Trust unauthenticated callers in production |
| Validate Input | Schema & type checks | Invent clinical data |
| Postgres reads | Fetch patient context | Write clinical decisions |
| Safety Engine (Code) | Apply versioned rules deterministically | Call LLM or external “is this safe?” APIs |
| AI Agent | Explain findings already produced by the engine | Decide safety, invent interactions, approve/reject |
| Slack | Present structured review card | Execute clinical logic |
| Wait node | Pause until authorized human decision | Time-out into auto-approve |
| Decision validation | Check identity, decision enum, justification | Accept empty overrides |
| Audit Log | Immutable record of events | Allow deletion of override justifications |

---

## Data Contracts

### Intake payload (minimum)

```json
{
  "prescription_id": "RX-…",
  "patient_id": "PT-…",
  "drug_name": "string",
  "dose": number,
  "dose_unit": "string",
  "frequency": "string",
  "route": "string",
  "prescriber_id": "string (optional)"
}
```

### Safety engine output

```json
{
  "prescription_id": "…",
  "patient_id": "…",
  "screening_status": "CLEAR | FLAGGED | INCOMPLETE",
  "requires_pharmacist_review": boolean,
  "risk_level": "LOW | MODERATE | HIGH | CRITICAL | null",
  "findings": [
    {
      "type": "DRUG_INTERACTION | ALLERGY_CONFLICT | …",
      "severity": "…",
      "related_drug": "…",
      "rule_id": "…",
      "description": "…"
    }
  ],
  "engine_version": "1.0",
  "rules_version": "1.0",
  "screened_at": "ISO-8601"
}
```

### Pharmacist callback

```json
{
  "prescription_id": "…",
  "pharmacist_id": "…",
  "decision": "APPROVE | REJECT | REQUEST_CLARIFICATION",
  "justification": "string (required for APPROVE/REJECT)",
  "timestamp": "ISO-8601",
  "callback_token": "…"
}
```

---

## Rules Dataset Contract

Every rule carries:

- `rule_id`
- `rule_type`
- `severity`
- `source`
- `version`
- `effective_date`
- `review_status`

The top-level file is labeled:

> DEMO / SYNTHETIC CLINICAL RULES — NOT FOR CLINICAL USE

This structure is intentionally compatible with later replacement by an authoritative clinical knowledge source.

---

## Failure Modes (Fail-Safe)

| Failure | System behavior |
|---------|-----------------|
| Invalid intake | HTTP 400, no screening |
| Patient not found | SCREENING_INCOMPLETE, hold for review |
| Rules not loaded | SCREENING_INCOMPLETE, hold for review |
| Missing eGFR for renal-rule drug | SCREENING_INCOMPLETE finding |
| AI Agent failure | Still present findings to pharmacist; do not auto-clear |
| Invalid/expired callback | Reject decision, keep prescription on hold |
| Database write failure on audit | Surface error; do not silently drop the event |

---

## Extensibility Points

1. **Rules** — Swap `clinical_rules_demo_v1.json` for a validated knowledge base.  
2. **Normalization** — Extend `normalization_map` or integrate a terminology service.  
3. **Approval UI** — Replace Slack with a custom pharmacist worklist or EHR inbox.  
4. **Downstream** — After APPROVE, emit an event to a dispensing / e-MAR system.  
5. **Dashboard** — Query `audit_logs`, `safety_findings`, and `pharmacist_reviews` for the metrics listed in the project brief.
