# Metadata Quality Report — {{OBJECT_LABEL}} ({{OBJECT_API_NAME}})

Generated: {{DATE}}
Org: {{ORG_ALIAS}}

## Summary

| Metric | Count |
|--------|-------|
| Total fields audited | {{TOTAL_FIELDS}} |
| Missing descriptions | {{MISSING_COUNT}} |
| Poor quality descriptions | {{POOR_COUNT}} |
| Adequate (improvable) | {{ADEQUATE_COUNT}} |
| Good (no change) | {{GOOD_COUNT}} |

---

## Object-Level Metadata

| Attribute | Current Value | Proposed Value | Status |
|-----------|--------------|----------------|--------|
| description | {{OBJ_DESC_CURRENT}} | {{OBJ_DESC_PROPOSED}} | {{OBJ_DESC_STATUS}} |
| label | {{OBJ_LABEL}} | — | GOOD |
| pluralLabel | {{OBJ_PLURAL_LABEL}} | — | GOOD |

---

## Field Metadata

### Fields Requiring Updates

| # | Field API Name | Label | Type | Attribute | Current | Proposed | Status |
|---|---------------|-------|------|-----------|---------|----------|--------|
| {{ROW_NUM}} | {{FIELD_API}} | {{FIELD_LABEL}} | {{FIELD_TYPE}} | {{ATTRIBUTE}} | {{CURRENT}} | {{PROPOSED}} | {{STATUS}} |

### Fields With Good Metadata (No Changes)

| Field API Name | Label | Type | Description |
|---------------|-------|------|-------------|
| {{FIELD_API}} | {{FIELD_LABEL}} | {{FIELD_TYPE}} | {{FIELD_DESC}} |

---

## Sample Records (Context)

_The following records were sampled to understand field usage and inform description proposals._

| {{FIELD_HEADERS}} |
|{{SEPARATOR}}|
| {{RECORD_VALUES}} |

---

## How to Use This Report

1. **Review** the "Proposed" values above
2. **Edit** this file directly if you want to adjust any proposed description
3. **Return** to the assistant and say **"go"** or **"apply"** to deploy all proposed changes
4. Or say **"regenerate"** to re-run the analysis

> Only rows with a non-empty "Proposed" column will be applied on deploy.
