# Setup Instructions

**Autonomous Clinical Drug-Interaction & Dosage Safety Net**  
DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE

---

## Prerequisites

- n8n (self-hosted or cloud) v1.x+
- PostgreSQL 14+ (or Supabase)
- Slack workspace (or equivalent messaging platform for approval cards)
- OpenAI-compatible API key (or other LLM provider supported by n8n AI Agent node) — used **only** for explanation, never for safety decisions
- Node.js (optional, for local testing of the safety engine)

---

## 1. Database Setup

```bash
# Create database
createdb clinical_safety_net

# Apply schema
psql -d clinical_safety_net -f database/schema.sql

# Load synthetic seed data
psql -d clinical_safety_net -f data/seed_data.sql
```

Verify:

```sql
SELECT COUNT(*) FROM patients;           -- expect 5
SELECT COUNT(*) FROM active_medications; -- expect 10
SELECT COUNT(*) FROM allergies;
SELECT COUNT(*) FROM clinical_labs;
```

---

## 2. Clinical Rules Dataset

The demo rules live at:

```
rules/clinical_rules_demo_v1.json
```

Options for loading inside n8n:

| Method | Notes |
|--------|-------|
| Read Binary File / Read File | Mount the project volume and point the node at the JSON file |
| HTTP Request | Serve the file from a static host or object storage |
| Set / Code node | Embed a minimal subset for pure demo (not recommended for full matrix) |
| Database | Optionally store rules in a `clinical_rules` table and query them |

Ensure the node that feeds the Safety Engine receives the full JSON object (including `metadata`, `normalization_map`, `drug_classes`, and `rules`).

---

## 3. Import n8n Workflow

1. Open n8n → Workflows → Import from File.  
2. Select `n8n/workflow_clinical_safety_net.json`.  
3. The workflow contains placeholder notes; complete the following configuration.

### 3.1 PostgreSQL Credential

Create an n8n credential of type **Postgres**:

- Host, port, database, user, password  
- Prefer SSL in non-local environments  
- Store password only in n8n credentials (never in Code nodes)

Attach the credential to nodes:

- 03 - Get Patient  
- 04 - Get Active Medications  
- 05 - Get Allergies  
- 06 - Get Clinical Labs  
- 16 - Audit Log  
(and any additional insert/update nodes you add)

**Parameter binding:** Replace the `$1` placeholders with n8n expressions, e.g.:

```
{{ $json.prescription.patient_id }}
```

or the appropriate path after Merge/Set nodes.

### 3.2 Safety Engine (Node 09)

1. Open **09 - Run Safety Engine**.  
2. Replace the placeholder code with the **entire contents** of `n8n/safety_engine.js`.  
3. Confirm the input shape matches what nodes 07/08 produce (prescription, patient, active_medications, allergies, labs, rules).

### 3.3 AI Agent (Node 11)

1. Open **11 - AI Clinical Explanation**.  
2. Set the system message to the content of `n8n/ai_agent_system_prompt.md`.  
3. Pass the structured `safety_result` + patient context as the user message.  
4. Configure your LLM credential (OpenAI, etc.).  
5. Temperature: keep low (e.g. 0.1–0.3) — explanation only, no creative clinical invention.

### 3.4 Slack (Node 12)

1. Create a Slack app with `chat:write` (and interactive components if using Block Kit buttons).  
2. Invite the bot to `#pharmacy-safety-review` (or your chosen channel).  
3. Create an n8n Slack credential and attach it.  
4. Optionally replace the plain-text message with Slack Block Kit containing Approve / Reject / Request Clarification buttons that POST to the Wait node’s resume webhook.

### 3.5 Wait Node (Node 13)

- Resume mode: **Webhook**.  
- Note the generated resume URL (or use a fixed path suffix).  
- Pharmacist decision payloads must include at minimum:  
  `prescription_id`, `pharmacist_id`, `decision`, `justification` (required for APPROVE/REJECT).

### 3.6 Webhook Security

- Prefer n8n’s webhook authentication (Header Auth, or custom validation in the Validate nodes).  
- For production prototypes, put the intake webhook behind an API gateway or mutual TLS.  
- Never log full patient payloads in unrestricted debug logs.

---

## 4. Environment / Secrets Checklist

| Secret / Config              | Storage location          | Used by                    |
|-----------------------------|---------------------------|----------------------------|
| Postgres connection         | n8n Credentials           | DB nodes                   |
| Slack bot token             | n8n Credentials           | Slack node                 |
| LLM API key                 | n8n Credentials           | AI Agent node              |
| Webhook auth header/token   | n8n Credentials / env     | Webhook validation         |
| Rules file path             | Workflow / volume mount   | Load Rules node            |

Do **not** hard-code secrets inside Code nodes.

---

## 5. Activate & Obtain URLs

1. Activate the workflow.  
2. Copy the **Production** webhook URL for `prescription-intake`.  
3. Note the Wait-node resume URL pattern for pharmacist decisions.

---

## 6. Smoke Test

```bash
curl -X POST "https://<your-n8n-host>/webhook/prescription-intake" \
  -H "Content-Type: application/json" \
  -d @examples/payload_clear.json
```

Use the bodies from `examples/webhook_payloads.json`.  
Expected behavior is documented in `tests/test_scenarios.md`.

---

## 7. Optional: Local Engine Unit Test

```bash
# From project root (Node.js)
node -e '
const fs = require("fs");
const rules = JSON.parse(fs.readFileSync("rules/clinical_rules_demo_v1.json","utf8"));
// Paste or require the runSafetyEngine function and assert outputs for TEST 1–6
'
```

(Full unit-test harness can be added under `tests/` as needed.)

---

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Always INCOMPLETE | Rules or patient not reaching engine | Check Merge/Set paths and rules load |
| AI invents interactions | System prompt not applied or temperature high | Re-apply system prompt; lower temperature |
| Wait never resumes | Wrong resume URL or missing fields | Validate callback payload against node 14 |
| Audit insert fails | Missing audit_id or FK violation | Generate UUID/nanoid for audit_id; ensure prescription row exists |
| Slack message empty | Expression paths wrong | Inspect execution data after AI node |

---

## Next Steps for a Production-Grade System (Out of Scope)

- Replace demo rules with a licensed, versioned clinical knowledge base  
- Add formal clinical governance and change control for rules  
- Implement role-based access and strong authentication for pharmacists  
- Add monitoring, alerting, and SLA for review turnaround  
- Complete regulatory and privacy assessments  
- Pen-test webhook and database surfaces  
