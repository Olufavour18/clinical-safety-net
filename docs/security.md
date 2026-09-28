# Security & Environment Notes

**DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE**

---

## Design Principles Applied in the Prototype

1. **Fail safe**  
   If required patient data, labs, or rules cannot be retrieved or validated, the prescription is **not** auto-cleared. It is held for pharmacist review with a `SCREENING_INCOMPLETE` finding.

2. **Deterministic safety decisions**  
   Clinical risk is decided only by the Code-node rules engine. The AI Agent has no authority to clear, approve, or invent findings.

3. **Mandatory justification on override**  
   APPROVE and REJECT callbacks require a non-trivial justification string. The justification is stored in the audit trail and pharmacist_reviews table.

4. **No secrets in code**  
   Database, Slack, and LLM credentials live in n8n Credentials (or environment variables referenced by n8n). Code nodes never contain API keys.

5. **Synthetic data only**  
   Seed data uses fictional patients and fabricated rules. No real PHI is present or expected.

6. **Auditability**  
   Every significant event writes an audit_logs row containing actor, previous/new status, reason, and workflow execution ID.

---

## Recommended Hardening for Any Non-Demo Deployment

| Area | Recommendation |
|------|----------------|
| Webhook authentication | Header-based shared secret, mTLS, or signed JWT; validate in the first Code node |
| Pharmacist identity | Map Slack user / SSO identity to an authorized pharmacist_id; reject unknown actors |
| Callback replay | Include a one-time token (from Wait node) and reject duplicate or expired tokens |
| Data minimization | Avoid logging full medication lists or lab panels in unrestricted execution logs |
| Network | Place n8n and Postgres in a private network; expose only the authenticated webhook endpoints |
| Encryption | TLS everywhere; encrypt database at rest; consider column-level encryption for sensitive fields if real PHI is ever introduced |
| Access control | Separate credentials for read (patient context) vs write (audit / status updates) |
| Rule integrity | Sign and version the rules file; verify hash/signature before the Safety Engine runs |
| AI boundary | Keep the system prompt immutable in the workflow; monitor for prompt-injection attempts in free-text justification fields |
| Retention | Define retention and purge policies for audit_logs consistent with local regulation |

---

## Environment Variables (Example)

```bash
# n8n
N8N_HOST=...
N8N_PROTOCOL=https
WEBHOOK_URL=https://...

# Postgres (prefer n8n credential store)
DB_HOST=...
DB_PORT=5432
DB_NAME=clinical_safety_net
DB_USER=...
DB_PASSWORD=...          # never commit

# Slack
SLACK_BOT_TOKEN=xoxb-... # never commit

# LLM (explanation only)
OPENAI_API_KEY=...       # never commit

# Optional webhook shared secret
INTAKE_WEBHOOK_SECRET=...
APPROVAL_WEBHOOK_SECRET=...
```

---

## What This Prototype Explicitly Does Not Provide

- HIPAA / GDPR compliance program  
- Production identity and access management  
- Penetration-tested surfaces  
- Clinical validation of any rule  
- High-availability or disaster-recovery design  

Treat the repository as an engineering reference architecture, not a deployable clinical system.
