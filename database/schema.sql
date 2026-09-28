-- =============================================================================
-- Autonomous Clinical Drug-Interaction & Dosage Safety Net
-- Database Schema (PostgreSQL / Supabase compatible)
-- DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE
-- Version: 1.0.0
-- =============================================================================

-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- PATIENTS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patients (
    patient_id          VARCHAR(32) PRIMARY KEY,
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    date_of_birth       DATE NOT NULL,
    sex                 VARCHAR(20) CHECK (sex IN ('male', 'female', 'other', 'unknown')),
    weight_kg           NUMERIC(6,2) CHECK (weight_kg > 0),
    height_cm           NUMERIC(5,1),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE patients IS 'Synthetic patient demographics. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- ACTIVE MEDICATIONS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS active_medications (
    medication_id       VARCHAR(32) PRIMARY KEY,
    patient_id          VARCHAR(32) NOT NULL REFERENCES patients(patient_id),
    drug_name           VARCHAR(200) NOT NULL,
    normalized_drug_name VARCHAR(200) NOT NULL,
    drug_class          VARCHAR(100),
    dose                NUMERIC(12,4) NOT NULL,
    dose_unit           VARCHAR(30) NOT NULL,
    frequency           VARCHAR(50) NOT NULL,
    route               VARCHAR(50) NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE,
    status              VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'discontinued', 'held', 'completed')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_active_meds_patient ON active_medications(patient_id);
CREATE INDEX idx_active_meds_status ON active_medications(status);
CREATE INDEX idx_active_meds_normalized ON active_medications(normalized_drug_name);

COMMENT ON TABLE active_medications IS 'Current active medication list per patient. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- ALLERGIES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS allergies (
    allergy_id          VARCHAR(32) PRIMARY KEY,
    patient_id          VARCHAR(32) NOT NULL REFERENCES patients(patient_id),
    allergen            VARCHAR(200) NOT NULL,
    allergen_class      VARCHAR(100),
    reaction            VARCHAR(200),
    severity            VARCHAR(20) NOT NULL
                        CHECK (severity IN ('mild', 'moderate', 'severe', 'life-threatening')),
    status              VARCHAR(20) NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'resolved', 'entered-in-error')),
    recorded_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_allergies_patient ON allergies(patient_id);

COMMENT ON TABLE allergies IS 'Patient allergy records. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- CLINICAL LABS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinical_labs (
    lab_id              VARCHAR(32) PRIMARY KEY,
    patient_id          VARCHAR(32) NOT NULL REFERENCES patients(patient_id),
    test_name           VARCHAR(100) NOT NULL,
    value               NUMERIC(12,4) NOT NULL,
    unit                VARCHAR(30) NOT NULL,
    reference_low       NUMERIC(12,4),
    reference_high      NUMERIC(12,4),
    collected_at        TIMESTAMPTZ NOT NULL,
    reported_at         TIMESTAMPTZ,
    status              VARCHAR(20) NOT NULL DEFAULT 'final'
                        CHECK (status IN ('preliminary', 'final', 'corrected', 'cancelled'))
);

CREATE INDEX idx_labs_patient ON clinical_labs(patient_id);
CREATE INDEX idx_labs_test_name ON clinical_labs(test_name);
CREATE INDEX idx_labs_collected ON clinical_labs(collected_at DESC);

COMMENT ON TABLE clinical_labs IS 'Synthetic laboratory results (renal/hepatic). DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- PRESCRIPTIONS (incoming e-prescriptions)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prescriptions (
    prescription_id     VARCHAR(32) PRIMARY KEY,
    patient_id          VARCHAR(32) NOT NULL REFERENCES patients(patient_id),
    drug_name           VARCHAR(200) NOT NULL,
    normalized_drug_name VARCHAR(200),
    dose                NUMERIC(12,4) NOT NULL,
    dose_unit           VARCHAR(30) NOT NULL,
    frequency           VARCHAR(50) NOT NULL,
    route               VARCHAR(50) NOT NULL,
    prescriber_id       VARCHAR(50),
    submitted_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status              VARCHAR(30) NOT NULL DEFAULT 'received'
                        CHECK (status IN (
                            'received',
                            'screening',
                            'clear',
                            'flagged',
                            'pending_review',
                            'approved',
                            'rejected',
                            'clarification_requested',
                            'held',
                            'error'
                        )),
    screening_status    VARCHAR(30),
    risk_level          VARCHAR(20),
    workflow_execution_id VARCHAR(100),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rx_patient ON prescriptions(patient_id);
CREATE INDEX idx_rx_status ON prescriptions(status);
CREATE INDEX idx_rx_submitted ON prescriptions(submitted_at DESC);

COMMENT ON TABLE prescriptions IS 'Incoming electronic prescriptions under safety screening. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- SAFETY FINDINGS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS safety_findings (
    finding_id          VARCHAR(32) PRIMARY KEY,
    prescription_id     VARCHAR(32) NOT NULL REFERENCES prescriptions(prescription_id),
    finding_type        VARCHAR(50) NOT NULL
                        CHECK (finding_type IN (
                            'DRUG_INTERACTION',
                            'ALLERGY_CONFLICT',
                            'DUPLICATE_THERAPY',
                            'DOSE_OUT_OF_RANGE',
                            'RENAL_ADJUSTMENT',
                            'HEPATIC_ADJUSTMENT',
                            'UNKNOWN_MEDICATION',
                            'SCREENING_INCOMPLETE'
                        )),
    severity            VARCHAR(20) NOT NULL
                        CHECK (severity IN ('LOW', 'MODERATE', 'HIGH', 'CRITICAL')),
    related_medication  VARCHAR(200),
    related_lab         VARCHAR(100),
    rule_id             VARCHAR(50),
    description         TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_findings_rx ON safety_findings(prescription_id);
CREATE INDEX idx_findings_type ON safety_findings(finding_type);
CREATE INDEX idx_findings_severity ON safety_findings(severity);

COMMENT ON TABLE safety_findings IS 'Structured safety findings produced by deterministic engine. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- PHARMACIST REVIEWS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pharmacist_reviews (
    review_id           VARCHAR(32) PRIMARY KEY,
    prescription_id     VARCHAR(32) NOT NULL REFERENCES prescriptions(prescription_id),
    pharmacist_id       VARCHAR(50) NOT NULL,
    decision            VARCHAR(30) NOT NULL
                        CHECK (decision IN ('APPROVE', 'REJECT', 'REQUEST_CLARIFICATION')),
    justification       TEXT,
    reviewed_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    callback_token      VARCHAR(100),
    workflow_execution_id VARCHAR(100)
);

CREATE INDEX idx_reviews_rx ON pharmacist_reviews(prescription_id);
CREATE INDEX idx_reviews_pharmacist ON pharmacist_reviews(pharmacist_id);

COMMENT ON TABLE pharmacist_reviews IS 'Human-in-the-loop pharmacist decisions. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- AUDIT LOGS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    audit_id            VARCHAR(32) PRIMARY KEY,
    prescription_id     VARCHAR(32),
    patient_id          VARCHAR(32),
    event_type          VARCHAR(80) NOT NULL,
    previous_status     VARCHAR(30),
    new_status          VARCHAR(30),
    actor               VARCHAR(80) NOT NULL,
    reason              TEXT,
    details             JSONB,
    workflow_execution_id VARCHAR(100),
    timestamp           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_rx ON audit_logs(prescription_id);
CREATE INDEX idx_audit_patient ON audit_logs(patient_id);
CREATE INDEX idx_audit_event ON audit_logs(event_type);
CREATE INDEX idx_audit_ts ON audit_logs(timestamp DESC);

COMMENT ON TABLE audit_logs IS 'Immutable audit trail of all safety and approval events. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- CLINICAL RULES METADATA (optional tracking of loaded rule set version)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinical_rules_versions (
    version_id          VARCHAR(32) PRIMARY KEY,
    version_label       VARCHAR(50) NOT NULL,
    source              VARCHAR(200) NOT NULL,
    effective_date      DATE NOT NULL,
    review_status       VARCHAR(30) NOT NULL DEFAULT 'demo',
    rule_count          INTEGER,
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes               TEXT
);

COMMENT ON TABLE clinical_rules_versions IS 'Tracks which synthetic rule set version is active. DEMO ONLY.';

-- -----------------------------------------------------------------------------
-- HELPER: Updated_at trigger function
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patients_updated
    BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_active_meds_updated
    BEFORE UPDATE ON active_medications
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_prescriptions_updated
    BEFORE UPDATE ON prescriptions
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
