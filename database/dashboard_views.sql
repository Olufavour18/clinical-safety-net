-- =============================================================================
-- Simple reporting views for the demo dashboard
-- DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE
-- =============================================================================

-- Summary metrics
CREATE OR REPLACE VIEW v_screening_summary AS
SELECT
    COUNT(*) FILTER (WHERE status IN ('clear', 'approved', 'rejected', 'flagged', 'pending_review', 'held', 'error')) AS total_prescriptions_touched,
    COUNT(*) FILTER (WHERE status = 'clear') AS clear_count,
    COUNT(*) FILTER (WHERE status IN ('flagged', 'pending_review')) AS flagged_or_pending,
    COUNT(*) FILTER (WHERE status = 'approved') AS pharmacist_approvals,
    COUNT(*) FILTER (WHERE status = 'rejected') AS pharmacist_rejections,
    COUNT(*) FILTER (WHERE status = 'error' OR screening_status = 'INCOMPLETE') AS screening_failures
FROM prescriptions;

-- Finding type distribution
CREATE OR REPLACE VIEW v_finding_type_counts AS
SELECT
    finding_type,
    severity,
    COUNT(*) AS finding_count
FROM safety_findings
GROUP BY finding_type, severity
ORDER BY finding_count DESC;

-- Recent audit activity
CREATE OR REPLACE VIEW v_recent_audit AS
SELECT
    audit_id,
    prescription_id,
    patient_id,
    event_type,
    actor,
    reason,
    timestamp
FROM audit_logs
ORDER BY timestamp DESC
LIMIT 100;

-- Pharmacist review turnaround (requires reviewed_at and a linked submitted_at)
CREATE OR REPLACE VIEW v_review_turnaround AS
SELECT
    pr.review_id,
    pr.prescription_id,
    pr.pharmacist_id,
    pr.decision,
    pr.reviewed_at,
    p.submitted_at,
    EXTRACT(EPOCH FROM (pr.reviewed_at - p.submitted_at)) / 60.0 AS review_minutes
FROM pharmacist_reviews pr
JOIN prescriptions p ON p.prescription_id = pr.prescription_id
WHERE pr.decision IN ('APPROVE', 'REJECT');
