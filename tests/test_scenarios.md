# Test Scenarios

**DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE**

Use the payloads in `examples/webhook_payloads.json` against the activated intake webhook.

---

## TEST 1 — No Interaction (CLEAR)

| Field | Value |
|-------|-------|
| Patient | PT-1005 (clean baseline, levothyroxine only) |
| New drug | Omeprazole 20 mg daily oral |
| Expected | `screening_status: CLEAR`, `requires_pharmacist_review: false`, empty findings |
| Path | Auto Clear → Audit Log |

---

## TEST 2 — Drug Interaction (HIGH)

| Field | Value |
|-------|-------|
| Patient | PT-1001 (active warfarin) |
| New drug | Ibuprofen 400 mg three times daily |
| Expected | `FLAGGED`, risk `HIGH`, finding type `DRUG_INTERACTION`, rule `DDI-DEMO-001` |
| Path | AI Explanation → Pharmacist Review → Wait |

---

## TEST 3 — Allergy Conflict (CRITICAL)

| Field | Value |
|-------|-------|
| Patient | PT-1003 (penicillin / beta-lactam allergy) |
| New drug | Amoxicillin 500 mg three times daily |
| Expected | `FLAGGED`, severity `CRITICAL` or `HIGH`, type `ALLERGY_CONFLICT`, rule `ALLERGY-DEMO-001` |
| Path | AI Explanation → Pharmacist Review |

---

## TEST 4 — Dose Outside Demo Range

| Field | Value |
|-------|-------|
| Patient | PT-1004 |
| New drug | Digoxin 0.5 mg daily (demo max 0.25 mg) |
| Expected | `FLAGGED`, type `DOSE_OUT_OF_RANGE`, rule `DOSE-DEMO-002` |
| Path | Pharmacist Review |

---

## TEST 5 — Renal Adjustment

| Field | Value |
|-------|-------|
| Patient | PT-1004 (eGFR 28) |
| New drug | Metformin 1000 mg twice daily |
| Expected | `FLAGGED`, type `RENAL_ADJUSTMENT`, rule `RENAL-DEMO-001` |
| Path | Pharmacist Review |

---

## TEST 6 — Multiple Simultaneous Findings

| Field | Value |
|-------|-------|
| Patient | PT-1002 (simvastatin + eGFR 42) |
| New drug | Clarithromycin 500 mg twice daily |
| Expected | At least `DRUG_INTERACTION` (DDI-DEMO-003) with simvastatin; possible additional context findings |
| Path | Pharmacist Review with multiple findings listed |

---

## TEST 7 — Screening Incomplete / Database Failure Simulation

| Method | Simulate missing patient or missing rules |
|--------|-------------------------------------------|
| Expected | `screening_status: INCOMPLETE` (or equivalent), `requires_pharmacist_review: true`, prescription held |
| Path | Do **not** auto-clear |

---

## TEST 8 — Pharmacist Override (Approve with Justification)

1. Trigger TEST 2 (or any flagged case).  
2. Receive Slack (or test) review card.  
3. POST to the Wait-node resume webhook:

```json
{
  "prescription_id": "RX-1002",
  "pharmacist_id": "PHARM-001",
  "decision": "APPROVE",
  "justification": "INR monitored; short course agreed with prescriber. Demo override.",
  "timestamp": "2025-09-23T10:15:00Z"
}
```

| Expected | Status → `approved`, audit row with justification, pharmacist_reviews row |

---

## TEST 8b — Reject

Same flow with `"decision": "REJECT"` and a clinical justification.  
Expected: status `rejected`, notification path (if configured), audit logged.

---

## TEST 8c — Request Clarification

`"decision": "REQUEST_CLARIFICATION"`.  
Expected: status `clarification_requested`, prescription remains on hold.

---

## Validation Checklist

- [ ] CLEAR path never invokes AI Agent  
- [ ] FLAGGED path always invokes AI Agent then Wait  
- [ ] APPROVE/REJECT without justification is rejected by node 14  
- [ ] Every terminal state writes an audit_logs record  
- [ ] Rule IDs in findings match the demo rules file  
- [ ] No real patient data appears in any log or message  
