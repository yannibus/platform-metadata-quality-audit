---
name: platform-metadata-quality-audit
description: "Use this skill when users want to audit, review, or improve the quality of Salesforce object and field metadata. Trigger when users mention metadata quality, missing descriptions, metadata audit, documentation of objects/fields, enriching metadata, or when they provide one or more object API names and ask to check/improve their metadata. Also use when users say things like 'audit my metadata', 'check descriptions on Account', 'improve metadata quality for X object', 'document my fields'. Works with both standard and custom objects. Do not use for translations of labels/help text into other languages (use the sf-metadata-translator agent)."
metadata:
  version: "1.5"
  minApiVersion: "60.0"
---

## When to Use This Skill

Use this skill when you need to:
- Audit metadata quality (descriptions, help text, labels) on one or more Salesforce objects
- Identify fields and objects missing descriptions or with poor-quality descriptions
- Measure which fields are actually used (fill rate) to prioritize documentation
- Generate enriched descriptions for objects and fields based on actual data usage
- Produce a local report of proposed metadata improvements
- Deploy metadata description updates after user approval

Not in scope: translating labels, help text or picklist values into other languages. Point the user to the `sf-metadata-translator` agent for that. Descriptions themselves are not translatable through the Metadata API (verified on API 67.0), so they are always written in the org's reference language.

## Specification

## 1. Overview and Purpose

This skill audits and improves the documentation quality of Salesforce object and field metadata. It reads metadata attributes through the describe and Tooling APIs, measures field fill rates, samples real records for context, then produces a reviewable markdown report plus a JSON proposals file. On user approval, it deploys the changes via Salesforce CLI.

**Scope of audited attributes:**

| Level | Attributes |
|-------|-----------|
| Object | `description`, `label`, `pluralLabel` |
| Field (standard & custom) | `description`, `inlineHelpText`, `label` |

---

## 2. Input

- **Target org** (SF CLI alias). Required: never fall back to the default org silently. Ask if missing.
- **One or more object API names**, standard or custom.
- **Sample size** (optional): number of recent records to sample for business context, **from 1 to 100, default 5**. Ask the user if they want to change it. Clamp any value above 100 to 100 and below 1 to 1, and say so.

**Examples:**
- `Account`
- `My_Custom_Object__c`
- `Account, Contact, Opportunity`
- `Case My_Custom_Object__c`

Parse any comma-separated, space-separated, or line-separated list.

---

## 3. Workflow

### Phase 0 — Org context

```bash
sf org display --target-org <alias> --json 2>/dev/null
sf data query --target-org <alias> --json --query "SELECT LanguageLocaleKey FROM Organization" 2>/dev/null
```

- `LanguageLocaleKey` is the org's reference language. Write proposals in that language unless existing descriptions are clearly in another language, or the user asks otherwise.
- **Check the running user's language** (the user the CLI is authenticated as, from `sf org display`):
  ```bash
  sf data query --target-org <alias> --json --query "SELECT LanguageLocaleKey FROM User WHERE Username = '<username>'" 2>/dev/null
  ```
  If it differs from the org's `LanguageLocaleKey`, **stop before Phase 1** and tell the user why:
  - `sf sobject describe` returns labels (and possibly help text) **translated into the running user's language**, so the audit would read translations instead of the reference values;
  - `sf project retrieve start` can also return translated values (observed: `inlineHelpText` in French for an `en_US` org). Redeploying such a file in Phase 5 would **overwrite the reference-language text** with the translation.

  Offer two options and wait for the user's choice:
  1. **(recommended)** temporarily switch the running user to the org language, then restore it at the end of the run, after explicit consent:
     ```bash
     sf data update record --sobject User --where "Username='<username>'" --values "LanguageLocaleKey=<org language>" --target-org <alias>
     ```
     Record the original value and restore it at the end, even if a later phase fails.
  2. re-authenticate the CLI with another user whose language matches the org language.

  Descriptions read through the Tooling API are not affected (they are not translatable), but labels and help text are. Never continue silently with a mismatch.
- The CLI prints plugin warnings on stderr: always redirect `2>/dev/null` before parsing JSON, and check `.result.success` (not only `.status`).

### Phase 1 — Read metadata (no retrieve needed)

The audit is read-only and does **not** require an SFDX project or a metadata retrieve.

1. **Field list, labels, types, help text and properties** from describe:
   ```bash
   sf sobject describe --sobject <Object> --target-org <alias> --json 2>/dev/null
   ```
   Per field: `name`, `label`, `type`, `length`, `inlineHelpText`, `nillable` (→ required), `unique`, `externalId`, `calculated` + `calculatedFormula`, `referenceTo`, `relationshipName`, `picklistValues`, `custom`.
   Object level: `label`, `labelPlural`, `custom`.
2. **Descriptions** (not exposed by describe) from the Tooling API:
   ```bash
   sf data query --use-tooling-api --target-org <alias> --json 2>/dev/null \
     --query "SELECT QualifiedApiName, Description FROM EntityDefinition WHERE QualifiedApiName = '<Object>'"
   sf data query --use-tooling-api --target-org <alias> --json 2>/dev/null \
     --query "SELECT QualifiedApiName, Description FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = '<Object>'"
   ```
   This works for standard and custom objects and fields.
3. **Field-level security caveat:** describe only returns fields visible to the running user. If the field count looks low, say so in the report and recommend running with a user that has View All Fields or an admin profile.
4. **Classify ownership:**
   - Fields with a namespace prefix (`ns__Field__c`) belong to a managed package and are **read-only**. List them as `MANAGED` and make no proposal.
   - Standard fields (`custom: false`): only `description` and `inlineHelpText` can be proposed. Never propose a new label for a standard field or standard object (see Phase 3).

### Phase 2 — Measure usage and sample records

1. **Fill rate.** One aggregate query per batch of fields:
   ```sql
   SELECT COUNT(Id) total, COUNT(Field1__c) f1, COUNT(Field2__c) f2, ... FROM <Object>
   ```
   - Keep at most 50 `COUNT()` aggregates per query, and split into several queries beyond that.
   - Long text area, rich text, encrypted and some compound fields cannot be counted. Mark them `n/a`.
   - Use the percentage (`f / total`) in the report. It drives prioritization: a 0 % field may be obsolete, which is worth flagging rather than documenting.
   - If the object has more than 2 million records and the query times out, fall back to the sample only and say so.
2. **Sample records** for business context (size = the sample size chosen in the input, default 5, max 100):
   ```bash
   sf data query --target-org <alias> --json 2>/dev/null \
     --query "SELECT <fields> FROM <Object> ORDER BY LastModifiedDate DESC LIMIT <sampleSize>"
   ```
   Use them to understand what the fields contain and the business patterns. A larger sample (up to 100) gives a more reliable picture of how fields are really used, at the cost of a bigger query:
   - select only the fields being analyzed, in batches of at most 40 columns, rather than every field of the object;
   - skip compound and encrypted fields in the sample;
   - read the rows to understand the data but **do not copy them into the report**: show at most 3 masked example values per field.
3. **Protect personal data.** Before writing sample values to the report, mask fields that look personal or sensitive:
   - types `email`, `phone`, encrypted fields;
   - names matching `(?i)(email|phone|mobile|ssn|iban|birth|address|salary|passport|tax)`.

   Show the first 2 characters followed by `***`. Truncate other values to 60 characters. The sample is context, not an export.

### Phase 3 — Analyze & Propose

**Quality criteria for descriptions:**
| Criterion | Bad | Good |
|-----------|-----|------|
| Present | Empty / null | Has content |
| Specific | "This field stores data" | "Stores the customer's preferred shipping address for order fulfillment" |
| Business context | "Text field" | "Internal project code assigned by the PMO during intake" |
| Length | > 300 chars or < 20 chars | 20–300 chars, structured (see below) |
| Findable | Repeats the label | Names the business meaning, values, usage and synonyms that people and search agents use |

**For each attribute, classify as:**
- `MISSING`: empty.
- `POOR`: exists but is generic or unhelpful.
- `ADEQUATE`: acceptable, with minor improvements possible.
- `GOOD`: no change needed.
- `MANAGED`: managed-package component, not editable.

**Generate proposals for `MISSING` and `POOR`.** Optionally propose improvements for `ADEQUATE` items.

**Two readers.** Proposals are read by (1) admins and end users and (2) AI search and analysis agents (Agentforce Coworker, other agents) that find fields by meaning. Write plain text, no markdown, with the business vocabulary people use in their questions. Never invent: omit a segment rather than guess.

**Description format** — labelled segments, in this order, only those that apply, 300 characters maximum (20 minimum). If too long, drop from the end: *Also called*, *Filled by*, then shorten *Values*. Keep the twin sentence (below) in any case.
- `What:` the business meaning, never a repetition of the label. For formulas, what they compute.
- `Values:` up to 8 key picklist values, or the unit, format or range for numbers, currencies, dates, codes. Never state only the data type — omit the segment instead.
- `Used for:` the questions, filters, reports or processes the field serves.
- `Filled by:` who or what populates it (user, integration, automation, formula, system), only when type, fill rate or sample show it.
- `Also called:` business synonyms people would search for, only when derivable from the label, API name, values or sample.
- Example: `What: Sales stage of the opportunity in the pipeline. Values: Prospecting, Qualification, Proposal, Closed Won, Closed Lost. Used for: filtering open versus closed deals, forecast category, win-rate reports. Filled by: the opportunity owner.`

**Help text** is for the person typing the value, not for agents: under 150 characters, imperative and plain — what to enter, with a format or example when useful. No technical term, no segment labels, never a repetition of the label.

**Rules for writing proposals:**
- Use field labels, not API names, in description text.
- Reference business context gleaned from fill rates and record sampling.
- For formula fields: describe what they compute and why.
- For relationship fields: describe the business relationship, not just "Lookup to X".
- For relationship and external-ID/key fields: add the segment `Join key: links to <related object label>.` after `What:`. This is what lets search assistants (Agentforce Coworker, agents) discover how objects connect.
- **Twin fields**: before writing proposals, compare the fields of the object and flag *twins* — two fields with the same normalized label, or the same API-name base (`Industry` / `Industry__c`), where at least one is custom. The description of each twin **must name the other** and say how to choose ("Use this field when …; for …, use <other label> (<API name>) instead"). Base the distinction only on labels, types, descriptions and fill rates; if it cannot be inferred, write "Not to be confused with <other label> (<API name>): check which one your process fills" rather than inventing a business rule. Twins can be outside the batch you are analysing: always compare against the whole field list.
- For picklist fields: mention key values if they reveal purpose.
- Keep field descriptions at 300 characters or less, help text under 150, and object descriptions under 250 (hard Salesforce limits: 1000 for field descriptions, 510 for help text).
- Write in the language determined in Phase 0.

**Rules for labels** (custom objects and custom fields only):
- Propose a new label only when the current one is clearly defective:
  - it is the API name or a technical token (`Cust_Ref`, `Field1`, `fld_status`);
  - it is an unexplained abbreviation;
  - it duplicates another field's label on the same object;
  - it is inconsistent with the object's naming (mixed languages, capitalization).
- Max 40 characters for field labels, 80 for object labels.
- Warn that renaming a label is user-visible and may affect reports, list views and existing translations (the `sf-metadata-translator` agent can re-audit translations afterwards).
- Never propose label changes on standard objects or standard fields.

**Large objects:** if an object has more than 100 fields, process custom fields first, then standard fields with a fill rate above 0 %, and warn the user that the report will be large.

### Phase 4 — Generate the report and the proposals file

Write both files to a working directory, by default `./metadata-audit/<alias>/` relative to the current directory. Tell the user the path.

1. `metadata-quality-report-<Object>.md`: the human-readable report. Follow `references/report-template.md`.
2. `metadata-quality-proposals-<Object>.json`: **the source of truth for Phase 5**. The markdown is for review only, so table formatting (pipes, line breaks inside cells) can never break the deployment.
   ```json
   {
     "org": "<alias>", "object": "<Object>", "objectIsCustom": true,
     "language": "en_US", "generated": "<ISO date>",
     "items": [
       { "id": 1, "level": "field", "field": "Region__c", "fieldIsCustom": true,
         "attribute": "description", "current": null,
         "proposed": "Sales region that owns the account, used for territory reports.",
         "status": "MISSING", "fillRate": 0.82, "apply": true }
     ]
   }
   ```
   `level` is `object` or `field`, and `attribute` is `description`, `inlineHelpText`, `label` or `pluralLabel`.
   In the markdown, escape `|` as `\|` and replace line breaks with a space.

Invite the user to:
1. Review the markdown report.
2. Edit proposals **in the JSON file**: change `proposed`, or set `apply: false` to skip a line.
3. Say "go" or "apply" to deploy, or "regenerate" to re-run the analysis.

### Phase 5 — Apply Changes (on user "go")

1. **Re-check the running user's language** (Phase 0): it must still match the org language, otherwise stop. Then **re-read the JSON file** (the user may have edited it). Keep only `apply: true` items with a non-empty `proposed`. Re-check lengths and drop any `MANAGED` item.
2. **Prepare a minimal SFDX project** in the working directory if none exists (`sfdx-project.json` with `packageDirectories: [{"path": "force-app", "default": true}]`).
3. **Retrieve the current source** right before editing, into a directory **separate** from the package directory:
   ```bash
   sf project retrieve start --metadata CustomObject:<Object> --target-org <alias> --output-dir <work>/retrieved --json 2>/dev/null
   ```
   - `CustomObject:<Object>` returns the object and **all** its fields, standard ones included.
   - Do **not** use `CustomField:<Object>.*`: the wildcard is not supported for child types. The command reports success but returns no field files.
   - If `--output-dir` is the same folder as a package directory, the retrieve fails without writing files.
   - If a retrieve fails with `fetch failed` (transient), retry once.
4. **Edit only what is approved:**
   - **Custom object:** set `<description>`, `<label>` and `<pluralLabel>` in `<Object>.object-meta.xml`.
   - **Fields:** set `<description>`, `<inlineHelpText>` and `<label>` (custom fields only) in `fields/<Field>.field-meta.xml`.
   - **Standard fields:** the retrieved file only carries a few properties (no label, no description). Add `<description>` / `<inlineHelpText>` after `<fullName>` and leave everything else untouched.
   - **Standard object:** add `<description>` right after the root element.
   - XML-escape values (`&`, `<`, `>`, `'` → `&apos;`). Validate each file with `xmllint --noout`.
5. **Deploy only the modified files.** Never deploy the whole retrieved standard object folder, which would push every standard field, list view and setting back to the org:
   ```bash
   sf project deploy start --source-dir <file1> --source-dir <file2> ... --target-org <alias> --json 2>/dev/null
   ```
   For more than 20 files, run a `--dry-run` first and then the real deploy.
6. **Verify** by re-running the Phase 1 Tooling and describe queries, and compare each deployed value with the JSON. Report deployed / skipped / failed counts with exact error messages.

> Status of standard-component writes (tested on API 67.0): adding a `description` to a standard object (Account) and a `description` or `inlineHelpText` to a standard field (Account.Industry) **passes `--dry-run` validation**. Persistence after a real deploy has not been confirmed yet. Always run step 6 and report any value that did not stick.

---

## 4. CLI Commands Reference

```bash
# Org language
sf data query --target-org <alias> --json --query "SELECT LanguageLocaleKey FROM Organization"

# Fields, labels, help text, types (read)
sf sobject describe --sobject <Object> --target-org <alias> --json

# Descriptions (read)
sf data query --use-tooling-api --target-org <alias> --json --query "SELECT QualifiedApiName, Description FROM FieldDefinition WHERE EntityDefinition.QualifiedApiName = '<Object>'"

# Fill rate
sf data query --target-org <alias> --json --query "SELECT COUNT(Id) total, COUNT(Field__c) f1 FROM <Object>"

# Retrieve before editing (object + all fields)
sf project retrieve start --metadata CustomObject:<Object> --target-org <alias> --output-dir <work>/retrieved --json

# Deploy only modified files
sf project deploy start --source-dir <file> [--source-dir <file> ...] --target-org <alias> --json
```

---

## 5. Constraints & Edge Cases

### Managed packages
Namespaced objects and fields cannot be modified. Report them as `MANAGED`, with no proposal.

### Multi-Object Runs
Generate one report file and one JSON file per object. Process objects sequentially.

### Language
Write proposals in the org's reference language (`LanguageLocaleKey`) unless existing descriptions are consistently in another language or the user specifies otherwise. Descriptions cannot be translated: to translate labels and help text, use the `sf-metadata-translator` agent after this audit.

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
- [ ] The target org was explicitly named
- [ ] The running user's language matches the org language (or the user chose to switch it temporarily)
- [ ] All objects provided are accessible (describe succeeded)
- [ ] Descriptions were read through the Tooling API
- [ ] Fill rates were computed (or marked `n/a` with the reason)
- [ ] The sample size is between 1 and 100 (default 5) and was announced to the user
- [ ] Sample values in the report are masked or truncated, and limited to 3 examples per field
- [ ] Managed components are flagged `MANAGED`, with no proposal
- [ ] No label proposal on standard objects or fields
- [ ] Proposed descriptions are specific and business-contextual, and use labels, not API names
- [ ] The JSON proposals file is written and valid (`jq . file.json`)

Before deploying, verify:
- [ ] User explicitly said "go", "apply", "deploy", or equivalent
- [ ] The running user's language still matches the org language
- [ ] If the user's language was switched temporarily, it is restored at the end of the run
- [ ] The JSON file was re-read (user may have edited it)
- [ ] Source was freshly retrieved, into a directory separate from the package directory
- [ ] Only modified files are deployed
- [ ] XML files pass `xmllint --noout`
- [ ] The deploy command targets the correct org
- [ ] Post-deploy verification compared every value with the JSON

---

## Reference File Index

| File | When to read |
|------|-------------|
| `references/report-template.md` | Template for the generated markdown report |
| `references/description-examples.md` | Examples of good vs bad descriptions for various field types |

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.5 | 2026-11-20 | Proposals written for two readers (humans and AI search/analysis agents such as Agentforce Coworker): labelled description segments (What / Values / Used for / Filled by / Also called / Join key), 300-character descriptions, short human help text |
| 1.4 | 2026-11-19 | Join-key wording for relationship/external-ID fields; twin-field detection (standard/custom pairs) with a mandatory "use this one, not that one" sentence, so search assistants pick the right field |
| 1.3 | 2026-11-19 | Configurable sample size, from 1 to 100 records (default 5, unchanged behavior); guidance for large samples (batches of 40 columns, at most 3 masked examples per field in the report) |
| 1.2 | 2026-10-09 | Running-user language check in Phase 0 and Phase 5: describe and retrieve return values in the user's language, so a mismatch with the org language could make the audit read translations and make the deploy overwrite reference-language text. Stops and offers a temporary, restored language switch |
| 1.1 | 2026-10-09 | Read via describe + Tooling API (no retrieve for the audit); fill-rate measurement; PII masking in samples; JSON proposals file as the source of truth for deploy; label rules; managed-package handling; deploy only modified files; documented retrieve pitfalls (`CustomField:X.*` wildcard, output-dir); default language = org language; pointer to `sf-metadata-translator` for translations |
| 1.0 | — | Initial version |
