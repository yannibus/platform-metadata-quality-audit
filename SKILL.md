---
name: platform-metadata-quality-audit
description: "Use this skill when users want to audit, review, or improve the quality of Salesforce object and field metadata. Trigger when users mention metadata quality, missing descriptions, metadata audit, documentation of objects/fields, enriching metadata, or when they provide one or more object API names and ask to check/improve their metadata. Also use when users say things like 'audit my metadata', 'check descriptions on Account', 'improve metadata quality for X object', 'document my fields'. Works with both standard and custom objects."
metadata:
  version: "1.0"
  minApiVersion: "60.0"
---

## When to Use This Skill

Use this skill when you need to:
- Audit metadata quality (descriptions, help text, labels) on one or more Salesforce objects
- Identify fields and objects missing descriptions or with poor-quality descriptions
- Generate enriched descriptions for objects and fields based on actual data usage
- Produce a local markdown report of proposed metadata improvements
- Deploy metadata description updates after user approval

## Specification

## 1. Overview and Purpose

This skill audits and improves the documentation quality of Salesforce object and field metadata. It reads object/field metadata attributes, samples real records for context, then produces a structured markdown report with proposed improvements. On user approval, it deploys the changes via Salesforce CLI.

**Scope of audited attributes:**

| Level | Attributes |
|-------|-----------|
| Object | `description`, `label`, `pluralLabel` |
| Field (standard & custom) | `description`, `inlineHelpText`, `label` |

---

## 2. Input

The user provides one or more Salesforce object API names (standard or custom).

**Examples:**
- `Account`
- `My_Custom_Object__c`
- `Account, Contact, Opportunity`
- `Case My_Custom_Object__c`

Parse any comma-separated, space-separated, or line-separated list.

---

## 3. Workflow

### Phase 1 — Retrieve Metadata

For each object API name provided:

1. **Retrieve object metadata** using `sf project retrieve start` with the metadata type `CustomObject` (for custom) or by reading from the project source if already retrieved.
2. **Retrieve field metadata** — all fields (standard + custom) for the object.
3. **Parse the following attributes** for each field:
   - `label`
   - `fullName` (API name)
   - `type` (field data type)
   - `description` (may be empty)
   - `inlineHelpText` (may be empty)
   - `required`
   - `unique`
   - `externalId`
   - `formula` (if formula field)
   - `referenceTo` (if relationship field)
   - `relationshipName`

4. **Parse object-level attributes:**
   - `label`
   - `pluralLabel`
   - `description` (may be empty)

### Phase 2 — Sample Records

For each object:

1. Run a SOQL query picking **5 records** using a subset of populatable fields:
   ```
   SELECT <fields> FROM <Object> ORDER BY LastModifiedDate DESC LIMIT 5
   ```
2. Use these records to understand:
   - Which fields are actually populated (not always null)
   - What kind of data the fields contain (to inform description writing)
   - Business context and patterns

### Phase 3 — Analyze & Propose

For each object and its fields, evaluate quality:

**Quality criteria for descriptions:**
| Criterion | Bad | Good |
|-----------|-----|------|
| Present | Empty / null | Has content |
| Specific | "This field stores data" | "Stores the customer's preferred shipping address for order fulfillment" |
| Business context | "Text field" | "Internal project code assigned by the PMO during intake" |
| Length | > 200 chars or < 10 chars | 20–150 chars, concise and informative |

**For each item (object or field), classify as:**
- `MISSING` — no description at all
- `POOR` — description exists but is generic/unhelpful
- `ADEQUATE` — description is acceptable, minor improvements possible
- `GOOD` — no change needed

**Generate proposals for items classified as MISSING or POOR.** Optionally propose improvements for ADEQUATE items.

**Rules for writing proposals:**
- Use field labels, not API names, in description text
- Reference business context gleaned from record sampling
- For formula fields: describe what they compute and why
- For relationship fields: describe the business relationship, not just "Lookup to X"
- For picklist fields: mention key values if they reveal purpose
- Keep descriptions under 150 characters for fields, under 250 for objects
- Write in the same language as existing metadata (default: English)

### Phase 4 — Generate Markdown Report

Generate a local markdown file at:
```
./metadata-quality-report-<ObjectName>.md
```

**Report structure:**

```markdown
# Metadata Quality Report — <Object Label> (<API Name>)

Generated: <date>

## Summary

| Metric | Count |
|--------|-------|
| Total fields audited | X |
| Missing descriptions | X |
| Poor quality descriptions | X |
| Adequate (improvable) | X |
| Good (no change) | X |

## Object-Level Metadata

| Attribute | Current Value | Proposed Value | Status |
|-----------|--------------|----------------|--------|
| description | ... | ... | MISSING/POOR/ADEQUATE/GOOD |
| label | ... | — | GOOD |
| pluralLabel | ... | — | GOOD |

## Field Metadata

### Fields Requiring Updates

| # | Field API Name | Label | Type | Attribute | Current | Proposed | Status |
|---|---------------|-------|------|-----------|---------|----------|--------|
| 1 | My_Field__c | My Field | Text | description | (empty) | "..." | MISSING |
| 2 | My_Field__c | My Field | Text | inlineHelpText | (empty) | "..." | MISSING |

### Fields With Good Metadata (No Changes)

| Field API Name | Label | Type | Description |
|---------------|-------|------|-------------|
| ... | ... | ... | ... |

## Sample Records (Context)

<First 5 records used for analysis, formatted as a table>
```

**Tell the user the report file path** and invite them to:
1. Review and edit the markdown directly
2. Come back and say "go" or "apply" to deploy
3. Or say "regenerate" to re-run the analysis

### Phase 5 — Apply Changes (on user "go")

When the user confirms:

1. **Read the markdown report** (the user may have edited it)
2. **Parse the "Proposed" column** for all rows where a change is indicated
3. **For custom objects:** Update the `.object-meta.xml` file with the new `<description>`
4. **For custom fields:** Update each `.field-meta.xml` with `<description>` and/or `<inlineHelpText>`
5. **For standard objects/fields:** Use `sf project retrieve start` to get current source, then modify and deploy back with `sf project deploy start`
6. **Deploy** using:
   ```bash
   sf project deploy start --source-dir <path> --target-org <org>
   ```
7. **Report deployment result** to the user

---

## 4. CLI Commands Reference

### Retrieve object + fields metadata
```bash
sf project retrieve start --metadata CustomObject:<ObjectName> --target-org <alias>
```

### For standard objects (retrieve all fields)
```bash
sf project retrieve start --metadata CustomObject:<ObjectName> CustomField:<ObjectName>.* --target-org <alias>
```

### SOQL query for record sampling
```bash
sf data query --query "SELECT <fields> FROM <Object> ORDER BY LastModifiedDate DESC LIMIT 5" --target-org <alias> --json
```

### Deploy updated metadata
```bash
sf project deploy start --source-dir <path> --target-org <alias>
```

---

## 5. Constraints & Edge Cases

### Standard Objects
- Standard object descriptions and standard field descriptions CAN be set via metadata API
- Retrieve first, modify the XML, then deploy back

### Large Objects
- If an object has > 100 fields, focus on custom fields first, then standard fields that are actually used (populated in sample records)
- Warn the user that the report will be large

### Multi-Object Runs
- Generate one report file per object
- Process objects sequentially

### Language
- Detect the language of existing descriptions and match it
- If no existing descriptions, default to English unless the user specifies otherwise

### Field Types Needing Special Description Guidance
| Field Type | Description Should Include |
|-----------|---------------------------|
| Formula | What it calculates and from which fields |
| Rollup Summary | What it aggregates (SUM/COUNT/MIN/MAX) and from where |
| Lookup / Master-Detail | The business relationship, not just the target object |
| Picklist | The business purpose; optionally mention key values |
| Encrypted / External ID | Security or integration context |

---

## 6. Verification Checklist

Before generating the report, verify:
- [ ] All objects provided are accessible in the target org
- [ ] Metadata retrieve was successful
- [ ] SOQL query returned records (if not, note "no records found" in report)
- [ ] Proposed descriptions are specific and business-contextual
- [ ] No API names used in description text (use labels)
- [ ] Report markdown is well-formed and readable

Before deploying, verify:
- [ ] User explicitly said "go", "apply", "deploy", or equivalent
- [ ] The report file was re-read (user may have edited it)
- [ ] XML modifications are syntactically valid
- [ ] Deploy command targets the correct org

---

## Reference File Index

| File | When to read |
|------|-------------|
| `references/report-template.md` | Template for the generated markdown report |
| `references/description-examples.md` | Examples of good vs bad descriptions for various field types |
