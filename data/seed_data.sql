-- =============================================================================
-- SYNTHETIC SEED DATA
-- DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE
-- =============================================================================

-- Clear existing demo data (order matters for FKs)
TRUNCATE TABLE audit_logs, pharmacist_reviews, safety_findings, prescriptions,
               clinical_labs, allergies, active_medications, patients,
               clinical_rules_versions CASCADE;

-- -----------------------------------------------------------------------------
-- PATIENTS
-- -----------------------------------------------------------------------------
INSERT INTO patients (patient_id, first_name, last_name, date_of_birth, sex, weight_kg, height_cm) VALUES
('PT-1001', 'Alex',   'Rivera',  '1978-03-15', 'male',   82.5, 178.0),
('PT-1002', 'Jordan', 'Chen',    '1965-11-02', 'female', 68.0, 162.0),
('PT-1003', 'Sam',    'Patel',   '1990-07-22', 'male',   95.0, 185.0),
('PT-1004', 'Taylor', 'Nguyen',  '1952-01-30', 'female', 55.5, 155.0),
('PT-1005', 'Morgan', 'Brooks',  '1985-09-08', 'other',  74.0, 170.0);

-- -----------------------------------------------------------------------------
-- ACTIVE MEDICATIONS
-- -----------------------------------------------------------------------------
INSERT INTO active_medications (
    medication_id, patient_id, drug_name, normalized_drug_name, drug_class,
    dose, dose_unit, frequency, route, start_date, status
) VALUES
-- PT-1001: on warfarin + lisinopril (interaction test target)
('MED-2001', 'PT-1001', 'Warfarin',      'WARFARIN',      'Anticoagulant', 5.0,  'mg', 'daily',     'oral', '2024-01-10', 'active'),
('MED-2002', 'PT-1001', 'Lisinopril',    'LISINOPRIL',    'ACE Inhibitor', 10.0, 'mg', 'daily',     'oral', '2023-06-01', 'active'),
('MED-2003', 'PT-1001', 'Metformin',     'METFORMIN',     'Biguanide',     500.0,'mg', 'twice daily','oral', '2023-03-15', 'active'),

-- PT-1002: on simvastatin (interaction + renal test)
('MED-2004', 'PT-1002', 'Simvastatin',   'SIMVASTATIN',   'Statin',        20.0, 'mg', 'daily',     'oral', '2022-11-20', 'active'),
('MED-2005', 'PT-1002', 'Amlodipine',    'AMLODIPINE',    'CCB',           5.0,  'mg', 'daily',     'oral', '2023-02-01', 'active'),

-- PT-1003: penicillin allergy target + no major interactions
('MED-2006', 'PT-1003', 'Atorvastatin',  'ATORVASTATIN',  'Statin',        40.0, 'mg', 'daily',     'oral', '2024-05-01', 'active'),
('MED-2007', 'PT-1003', 'Omeprazole',    'OMEPRAZOLE',    'PPI',           20.0, 'mg', 'daily',     'oral', '2024-01-15', 'active'),

-- PT-1004: elderly, reduced renal function, on digoxin
('MED-2008', 'PT-1004', 'Digoxin',       'DIGOXIN',       'Cardiac Glycoside', 0.125, 'mg', 'daily', 'oral', '2021-08-10', 'active'),
('MED-2009', 'PT-1004', 'Furosemide',    'FUROSEMIDE',    'Loop Diuretic', 40.0, 'mg', 'daily',     'oral', '2022-04-01', 'active'),

-- PT-1005: clean baseline for CLEAR path
('MED-2010', 'PT-1005', 'Levothyroxine', 'LEVOTHYROXINE', 'Thyroid Hormone', 75.0, 'mcg', 'daily',  'oral', '2020-12-01', 'active');

-- -----------------------------------------------------------------------------
-- ALLERGIES
-- -----------------------------------------------------------------------------
INSERT INTO allergies (allergy_id, patient_id, allergen, allergen_class, reaction, severity, status) VALUES
('ALG-3001', 'PT-1003', 'Penicillin',     'Beta-lactam antibiotic', 'Anaphylaxis',     'life-threatening', 'active'),
('ALG-3002', 'PT-1002', 'Sulfa drugs',    'Sulfonamide',            'Rash / hives',    'moderate',         'active'),
('ALG-3003', 'PT-1004', 'Codeine',        'Opioid',                 'Nausea / vomiting','mild',             'active'),
('ALG-3004', 'PT-1001', 'None recorded',  NULL,                     NULL,              'mild',             'active');

-- -----------------------------------------------------------------------------
-- CLINICAL LABS (renal + hepatic)
-- -----------------------------------------------------------------------------
INSERT INTO clinical_labs (
    lab_id, patient_id, test_name, value, unit, reference_low, reference_high, collected_at, status
) VALUES
-- PT-1001 normal renal/hepatic
('LAB-4001', 'PT-1001', 'creatinine', 1.0,  'mg/dL', 0.7, 1.3,  '2025-09-01 08:00:00+00', 'final'),
('LAB-4002', 'PT-1001', 'eGFR',       88.0, 'mL/min/1.73m2', 60, 120, '2025-09-01 08:00:00+00', 'final'),
('LAB-4003', 'PT-1001', 'ALT',        22.0, 'U/L',  7, 56,  '2025-09-01 08:00:00+00', 'final'),
('LAB-4004', 'PT-1001', 'AST',        25.0, 'U/L', 10, 40,  '2025-09-01 08:00:00+00', 'final'),

-- PT-1002 mild renal impairment
('LAB-4005', 'PT-1002', 'creatinine', 1.6,  'mg/dL', 0.6, 1.1,  '2025-09-10 09:30:00+00', 'final'),
('LAB-4006', 'PT-1002', 'eGFR',       42.0, 'mL/min/1.73m2', 60, 120, '2025-09-10 09:30:00+00', 'final'),
('LAB-4007', 'PT-1002', 'ALT',        35.0, 'U/L',  7, 56,  '2025-09-10 09:30:00+00', 'final'),

-- PT-1003 normal
('LAB-4008', 'PT-1003', 'creatinine', 0.9,  'mg/dL', 0.7, 1.3,  '2025-08-20 07:45:00+00', 'final'),
('LAB-4009', 'PT-1003', 'eGFR',       105.0,'mL/min/1.73m2', 60, 120, '2025-08-20 07:45:00+00', 'final'),
('LAB-4010', 'PT-1003', 'bilirubin',  0.8,  'mg/dL', 0.1, 1.2,  '2025-08-20 07:45:00+00', 'final'),

-- PT-1004 significant renal impairment (elderly)
('LAB-4011', 'PT-1004', 'creatinine', 2.1,  'mg/dL', 0.6, 1.1,  '2025-09-15 10:00:00+00', 'final'),
('LAB-4012', 'PT-1004', 'eGFR',       28.0, 'mL/min/1.73m2', 60, 120, '2025-09-15 10:00:00+00', 'final'),
('LAB-4013', 'PT-1004', 'ALT',        18.0, 'U/L',  7, 56,  '2025-09-15 10:00:00+00', 'final'),
('LAB-4014', 'PT-1004', 'AST',        22.0, 'U/L', 10, 40,  '2025-09-15 10:00:00+00', 'final'),

-- PT-1005 normal
('LAB-4015', 'PT-1005', 'creatinine', 0.85, 'mg/dL', 0.7, 1.3,  '2025-09-05 08:15:00+00', 'final'),
('LAB-4016', 'PT-1005', 'eGFR',       98.0, 'mL/min/1.73m2', 60, 120, '2025-09-05 08:15:00+00', 'final'),
('LAB-4017', 'PT-1005', 'ALT',        19.0, 'U/L',  7, 56,  '2025-09-05 08:15:00+00', 'final');

-- -----------------------------------------------------------------------------
-- RULE VERSION TRACKING
-- -----------------------------------------------------------------------------
INSERT INTO clinical_rules_versions (version_id, version_label, source, effective_date, review_status, rule_count, notes)
VALUES (
    'RULESET-DEMO-1.0',
    '1.0',
    'Synthetic demonstration rules — NOT FOR CLINICAL USE',
    '2025-01-01',
    'demo',
    18,
    'Portfolio prototype rule set. Replace with validated clinical knowledge base before any real-world use.'
);
