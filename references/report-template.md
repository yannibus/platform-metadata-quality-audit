# Metadata Quality Report — {{OBJECT_LABEL}} ({{OBJECT_API_NAME}})

Generated: {{DATE}}
Org: {{ORG_ALIAS}}
Reference language: {{ORG_LANGUAGE}}
Records in object: {{TOTAL_RECORDS}}
Proposals file (source of truth for deploy): `{{JSON_PATH}}`

## Summary

| Metric | Count |
|--------|-------|
| Total fields audited | {{TOTAL_FIELDS}} |
| Missing descriptions | {{MISSING_COUNT}} |
| Poor quality descriptions | {{POOR_COUNT}} |
| Adequate (improvable) | {{ADEQUATE_COUNT}} |
| Good (no change) | {{GOOD_COUNT}} |
| Managed (read-only) | {{MANAGED_COUNT}} |
| Unused fields (0 % fill rate) | {{UNUSED_COUNT}} |

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

| # | Field API Name | Label | Type | Fill rate | Attribute | Current | Proposed | Status |
|---|---------------|-------|------|-----------|-----------|---------|----------|--------|
| {{ITEM_ID}} | {{FIELD_API}} | {{FIELD_LABEL}} | {{FIELD_TYPE}} | {{FILL_RATE}} | {{ATTRIBUTE}} | {{CURRENT}} | {{PROPOSED}} | {{STATUS}} |

_`#` matches the `id` of the item in the JSON proposals file. Pipes in values are escaped as `\|`._

### Unused Fields (0 % Fill Rate)

_Candidates for cleanup rather than documentation._

| Field API Name | Label | Type |
|---------------|-------|------|
| {{FIELD_API}} | {{FIELD_LABEL}} | {{FIELD_TYPE}} |

### Managed Package Fields (Read-Only)

| Field API Name | Label | Namespace |
|---------------|-------|-----------|
| {{FIELD_API}} | {{FIELD_LABEL}} | {{NAMESPACE}} |

### Fields With Good Metadata (No Changes)

| Field API Name | Label | Type | Description |
|---------------|-------|------|-------------|
| {{FIELD_API}} | {{FIELD_LABEL}} | {{FIELD_TYPE}} | {{FIELD_DESC}} |

---

## Sample Records (Context)

_The following records were sampled to understand field usage and inform description proposals. Personal or sensitive values are masked (`Jo***`) and long values are truncated to 60 characters._

| {{FIELD_HEADERS}} |
|{{SEPARATOR}}|
| {{RECORD_VALUES}} |

---

## How to Use This Report

1. **Review** the "Proposed" values above
2. **Edit the JSON proposals file** (`{{JSON_PATH}}`) to adjust a value (`proposed`) or skip a line (`apply: false`). Edits to this markdown are not applied.
3. **Return** to the assistant and say **"go"** or **"apply"** to deploy all approved changes
4. Or say **"regenerate"** to re-run the analysis

> Only JSON items with `apply: true` and a non-empty `proposed` value are deployed.
