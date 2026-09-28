/**
 * =============================================================================
 * DETERMINISTIC CLINICAL SAFETY ENGINE
 * Autonomous Clinical Drug-Interaction & Dosage Safety Net
 * =============================================================================
 *
 * DEMO / SYNTHETIC ONLY — NOT FOR CLINICAL USE
 *
 * This Code Node performs purely deterministic checks against a versioned
 * clinical rules dataset. It NEVER asks an AI model whether something is safe.
 *
 * Input (from previous n8n nodes, expected in $input / items):
 *   - prescription: { prescription_id, patient_id, drug_name, dose, dose_unit, frequency, route }
 *   - patient: { patient_id, weight_kg, sex, date_of_birth, ... }
 *   - active_medications: array of active meds
 *   - allergies: array of allergies
 *   - labs: array of clinical labs (creatinine, eGFR, ALT, AST, bilirubin, ...)
 *   - rules: the full clinical_rules_demo_v1.json object
 *
 * Output: structured safety screening result (see section 7 of the brief)
 *
 * Architecture invariant:
 *   Deterministic rules → safety findings → AI explanation → human approval → audit
 * =============================================================================
 */

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function normalizeDrugName(name, normalizationMap) {
  if (!name || typeof name !== 'string') return null;
  const key = name.trim().toLowerCase();
  return normalizationMap[key] || name.trim().toUpperCase().replace(/\s+/g, '_');
}

function getLatestLab(labs, testName) {
  if (!Array.isArray(labs) || labs.length === 0) return null;
  const matches = labs
    .filter(l => l.test_name && l.test_name.toLowerCase() === testName.toLowerCase())
    .sort((a, b) => new Date(b.collected_at) - new Date(a.collected_at));
  return matches.length > 0 ? matches[0] : null;
}

function severityRank(sev) {
  const order = { LOW: 1, MODERATE: 2, HIGH: 3, CRITICAL: 4 };
  return order[sev] || 0;
}

function maxSeverity(findings) {
  if (!findings || findings.length === 0) return null;
  return findings.reduce((max, f) =>
    severityRank(f.severity) > severityRank(max) ? f.severity : max,
    'LOW'
  );
}

function makeFinding(type, severity, related, ruleId, description) {
  return {
    type,
    severity,
    related_drug: related || null,
    rule_id: ruleId || null,
    description
  };
}

// ---------------------------------------------------------------------------
// Main engine
// ---------------------------------------------------------------------------

function runSafetyEngine(input) {
  const {
    prescription,
    patient,
    active_medications = [],
    allergies = [],
    labs = [],
    rules
  } = input;

  // --- Guard: required inputs ---
  if (!prescription || !prescription.prescription_id || !prescription.patient_id) {
    return {
      prescription_id: prescription?.prescription_id || null,
      patient_id: prescription?.patient_id || null,
      screening_status: 'INCOMPLETE',
      requires_pharmacist_review: true,
      risk_level: 'HIGH',
      findings: [
        makeFinding(
          'SCREENING_INCOMPLETE',
          'HIGH',
          null,
          null,
          'Required prescription identifiers missing. Prescription held pending pharmacist review.'
        )
      ],
      engine_version: '1.0',
      rules_version: rules?.metadata?.version || 'unknown',
      screened_at: new Date().toISOString()
    };
  }

  if (!rules || !rules.rules || !Array.isArray(rules.rules)) {
    return {
      prescription_id: prescription.prescription_id,
      patient_id: prescription.patient_id,
      screening_status: 'INCOMPLETE',
      requires_pharmacist_review: true,
      risk_level: 'HIGH',
      findings: [
        makeFinding(
          'SCREENING_INCOMPLETE',
          'HIGH',
          null,
          null,
          'Clinical rules dataset could not be loaded. Prescription held pending pharmacist review.'
        )
      ],
      engine_version: '1.0',
      rules_version: 'unavailable',
      screened_at: new Date().toISOString()
    };
  }

  if (!patient) {
    return {
      prescription_id: prescription.prescription_id,
      patient_id: prescription.patient_id,
      screening_status: 'INCOMPLETE',
      requires_pharmacist_review: true,
      risk_level: 'HIGH',
      findings: [
        makeFinding(
          'SCREENING_INCOMPLETE',
          'HIGH',
          null,
          null,
          'Patient record could not be retrieved. Prescription held pending pharmacist review.'
        )
      ],
      engine_version: '1.0',
      rules_version: rules.metadata?.version || 'unknown',
      screened_at: new Date().toISOString()
    };
  }

  const findings = [];
  const normMap = rules.normalization_map || {};
  const drugClasses = rules.drug_classes || {};
  const allRules = rules.rules;

  // Normalize new prescription drug
  const newDrugNorm = normalizeDrugName(prescription.drug_name, normMap);
  if (!newDrugNorm) {
    findings.push(
      makeFinding(
        'UNKNOWN_MEDICATION',
        'HIGH',
        prescription.drug_name,
        null,
        `Unable to normalize medication name: "${prescription.drug_name}". Requires pharmacist review.`
      )
    );
  }

  const newDrugClass = drugClasses[newDrugNorm] || null;

  // =========================================================================
  // A. DRUG-DRUG INTERACTIONS
  // =========================================================================
  const activeNorms = (active_medications || [])
    .filter(m => m.status === 'active' || !m.status)
    .map(m => ({
      ...m,
      normalized: m.normalized_drug_name || normalizeDrugName(m.drug_name, normMap)
    }));

  for (const med of activeNorms) {
    if (!med.normalized || !newDrugNorm) continue;

    // Check both orderings of the pair
    const interactionRules = allRules.filter(
      r =>
        r.rule_type === 'drug_interaction' &&
        ((r.drug_a === newDrugNorm && r.drug_b === med.normalized) ||
          (r.drug_b === newDrugNorm && r.drug_a === med.normalized))
    );

    for (const rule of interactionRules) {
      findings.push(
        makeFinding(
          'DRUG_INTERACTION',
          rule.severity,
          med.drug_name || med.normalized,
          rule.rule_id,
          rule.risk_description
        )
      );
    }
  }

  // =========================================================================
  // B. ALLERGY CONFLICTS
  // =========================================================================
  const activeAllergies = (allergies || []).filter(
    a => a.status === 'active' || !a.status
  );

  for (const allergy of activeAllergies) {
    const allergenClass = allergy.allergen_class;
    if (!allergenClass) continue;

    const allergyRules = allRules.filter(
      r =>
        r.rule_type === 'allergy_conflict' &&
        r.allergen_class &&
        r.allergen_class.toLowerCase() === allergenClass.toLowerCase()
    );

    for (const rule of allergyRules) {
      const conflicting = rule.conflicting_drugs || [];
      if (newDrugNorm && conflicting.includes(newDrugNorm)) {
        findings.push(
          makeFinding(
            'ALLERGY_CONFLICT',
            rule.severity,
            allergy.allergen,
            rule.rule_id,
            `${rule.risk_description} Documented allergen: ${allergy.allergen} (${allergy.severity || 'unknown severity'}).`
          )
        );
      }
    }

    // Also check direct allergen name match (simple exact)
    if (
      newDrugNorm &&
      allergy.allergen &&
      allergy.allergen.toUpperCase().includes(newDrugNorm)
    ) {
      findings.push(
        makeFinding(
          'ALLERGY_CONFLICT',
          allergy.severity === 'life-threatening' ? 'CRITICAL' : 'HIGH',
          allergy.allergen,
          null,
          `Direct allergen match detected for "${allergy.allergen}". Synthetic demo check.`
        )
      );
    }
  }

  // =========================================================================
  // C. DUPLICATE THERAPY
  // =========================================================================
  // Exact same normalized drug already active
  for (const med of activeNorms) {
    if (med.normalized && newDrugNorm && med.normalized === newDrugNorm) {
      findings.push(
        makeFinding(
          'DUPLICATE_THERAPY',
          'MODERATE',
          med.drug_name,
          null,
          `Exact medication already active on profile: ${med.drug_name} ${med.dose}${med.dose_unit} ${med.frequency}.`
        )
      );
    }
  }

  // Same therapeutic class
  if (newDrugClass) {
    const classRules = allRules.filter(
      r => r.rule_type === 'duplicate_therapy' && r.drug_class === newDrugClass
    );
    for (const rule of classRules) {
      const sameClassMeds = activeNorms.filter(
        m => drugClasses[m.normalized] === newDrugClass
      );
      if (sameClassMeds.length > 0) {
        findings.push(
          makeFinding(
            'DUPLICATE_THERAPY',
            rule.severity,
            sameClassMeds.map(m => m.drug_name).join(', '),
            rule.rule_id,
            `${rule.risk_description} Existing: ${sameClassMeds.map(m => m.drug_name).join(', ')}.`
          )
        );
      }
    }
  }

  // =========================================================================
  // D. DOSE VALIDATION
  // =========================================================================
  if (newDrugNorm && prescription.dose != null) {
    const doseRules = allRules.filter(
      r => r.rule_type === 'dose_range' && r.drug === newDrugNorm
    );
    for (const rule of doseRules) {
      const prescribed = Number(prescription.dose);
      const unitMatch =
        !rule.dose_unit ||
        (prescription.dose_unit &&
          prescription.dose_unit.toLowerCase() === rule.dose_unit.toLowerCase());

      if (!unitMatch) {
        // Unit mismatch itself is a review trigger
        findings.push(
          makeFinding(
            'DOSE_OUT_OF_RANGE',
            'MODERATE',
            newDrugNorm,
            rule.rule_id,
            `Dose unit mismatch: prescribed ${prescription.dose_unit}, rule expects ${rule.dose_unit}. Requires pharmacist review.`
          )
        );
        continue;
      }

      if (prescribed < rule.min_dose || prescribed > rule.max_dose) {
        findings.push(
          makeFinding(
            'DOSE_OUT_OF_RANGE',
            rule.severity,
            newDrugNorm,
            rule.rule_id,
            `${rule.risk_description} Prescribed: ${prescribed} ${prescription.dose_unit}. Configured demo range: ${rule.min_dose}–${rule.max_dose} ${rule.dose_unit}.`
          )
        );
      }
    }
  }

  // =========================================================================
  // E. RENAL CONSIDERATIONS
  // =========================================================================
  const egfrLab = getLatestLab(labs, 'eGFR');
  const creatinineLab = getLatestLab(labs, 'creatinine');

  if (newDrugNorm) {
    const renalRules = allRules.filter(
      r => r.rule_type === 'renal_adjustment' && r.drug === newDrugNorm
    );
    for (const rule of renalRules) {
      if (egfrLab && egfrLab.value != null) {
        const egfr = Number(egfrLab.value);
        if (egfr < rule.egfr_threshold_ml_min) {
          findings.push(
            makeFinding(
              'RENAL_ADJUSTMENT',
              rule.severity,
              newDrugNorm,
              rule.rule_id,
              `${rule.risk_description} Patient eGFR: ${egfr} ${egfrLab.unit} (collected ${egfrLab.collected_at}). Threshold: ${rule.egfr_threshold_ml_min}.`
            )
          );
        }
      } else {
        // Missing renal data for a drug that has renal rules → hold for review
        findings.push(
          makeFinding(
            'SCREENING_INCOMPLETE',
            'MODERATE',
            newDrugNorm,
            rule.rule_id,
            `Renal function data (eGFR) unavailable for a medication with renal adjustment rules. Prescription held pending pharmacist review.`
          )
        );
      }
    }
  }

  // =========================================================================
  // F. HEPATIC CONSIDERATIONS
  // =========================================================================
  if (newDrugNorm) {
    const hepaticRules = allRules.filter(
      r => r.rule_type === 'hepatic_adjustment' && r.drug === newDrugNorm
    );
    for (const rule of hepaticRules) {
      const markerLab = getLatestLab(labs, rule.lab_marker || 'ALT');
      if (markerLab && markerLab.value != null && markerLab.reference_high != null) {
        const value = Number(markerLab.value);
        const refHigh = Number(markerLab.reference_high);
        const threshold = refHigh * (rule.threshold_multiplier || 3);
        if (value > threshold) {
          findings.push(
            makeFinding(
              'HEPATIC_ADJUSTMENT',
              rule.severity,
              newDrugNorm,
              rule.rule_id,
              `${rule.risk_description} Patient ${rule.lab_marker}: ${value} ${markerLab.unit} (ref high ${refHigh}). Threshold used: ${threshold}.`
            )
          );
        }
      }
    }
  }

  // =========================================================================
  // Final decision
  // =========================================================================
  const hasFindings = findings.length > 0;
  const risk = hasFindings ? maxSeverity(findings) : null;

  return {
    prescription_id: prescription.prescription_id,
    patient_id: prescription.patient_id,
    normalized_drug: newDrugNorm,
    screening_status: hasFindings ? 'FLAGGED' : 'CLEAR',
    requires_pharmacist_review: hasFindings,
    risk_level: risk,
    findings,
    patient_context_summary: {
      weight_kg: patient.weight_kg || null,
      sex: patient.sex || null,
      latest_egfr: egfrLab
        ? { value: egfrLab.value, unit: egfrLab.unit, collected_at: egfrLab.collected_at }
        : null,
      latest_creatinine: creatinineLab
        ? {
            value: creatinineLab.value,
            unit: creatinineLab.unit,
            collected_at: creatinineLab.collected_at
          }
        : null,
      active_medication_count: activeNorms.length,
      active_allergy_count: activeAllergies.length
    },
    engine_version: '1.0',
    rules_version: rules.metadata?.version || 'unknown',
    rules_source: rules.metadata?.source || 'unknown',
    screened_at: new Date().toISOString()
  };
}

// ---------------------------------------------------------------------------
// n8n Code Node entry point
// ---------------------------------------------------------------------------
// Expects a single item with json containing the assembled context.
// Adjust field paths to match how you merge data in the workflow.

const items = $input.all();
const results = [];

for (const item of items) {
  const data = item.json;

  // Support both flat and nested shapes
  const input = {
    prescription: data.prescription || data,
    patient: data.patient || data.patient_record,
    active_medications: data.active_medications || data.medications || [],
    allergies: data.allergies || [],
    labs: data.labs || data.clinical_labs || [],
    rules: data.rules || data.clinical_rules
  };

  const result = runSafetyEngine(input);
  results.push({ json: result });
}

return results;
