# platform-metadata-quality-audit

An agent skill (Claude Code, Agentforce Vibes, or any `SKILL.md`-compatible agent) that audits and improves the documentation quality of Salesforce **object and field metadata** — then deploys the approved changes via the Salesforce CLI.

It reads object/field metadata through the describe and Tooling APIs, measures field fill rates, samples real records for context, classifies every description as `MISSING` / `POOR` / `ADEQUATE` / `GOOD`, and produces a reviewable Markdown report plus a JSON proposals file. Nothing is deployed until you say so.

## What it does

- **Audits** descriptions, help text, and labels on one or more objects (standard *and* custom).
- **Measures** the fill rate of every field to spot unused fields and prioritize documentation.
- **Samples** 5 real records per object (with personal data masked) to ground the proposed descriptions in actual usage.
- **Skips** managed-package components (read-only) and never relabels standard objects or fields.
- **Classifies** every attribute against explicit quality criteria (present / specific / business context / length).
- **Proposes** enriched, business-contextual descriptions — using labels, not API names.
- **Reports** everything to a local Markdown file, with a JSON file that you edit before applying.
- **Deploys** only the modified files with `sf project deploy start`, after explicit confirmation, then verifies every value.

### Attributes audited

| Level | Attributes |
|-------|-----------|
| Object | `description`, `label`, `pluralLabel` |
| Field (standard & custom) | `description`, `inlineHelpText`, `label` |

## Usage

Invoke the skill and provide one or more object API names. Any comma-, space-, or line-separated list works:

```
Account
My_Custom_Object__c
Account, Contact, Opportunity
Case My_Custom_Object__c
```

Typical triggers: *"audit my metadata"*, *"check descriptions on Account"*, *"improve metadata quality for X object"*, *"document my fields"*.

## Workflow

0. **Org context**: reference language.
1. **Read** metadata (`sf sobject describe` + Tooling `EntityDefinition` / `FieldDefinition`). No retrieve needed.
2. **Measure & sample**: fill rates (`COUNT()`), 5 recent records with PII masked.
3. **Analyze & propose**: classify each item and generate proposals for `MISSING` / `POOR`.
4. **Generate** `./metadata-audit/<alias>/metadata-quality-report-<Object>.md` + `metadata-quality-proposals-<Object>.json`.
5. **Apply on approval**: re-read the (possibly edited) JSON, retrieve fresh source, edit XML, deploy only modified files, verify.

You stay in control: review the report, edit any proposal in the JSON file, then say **"go"** / **"apply"** to deploy — or **"regenerate"** to re-run.

## Repository structure

```
.
├── SKILL.md                          # Skill definition + full specification
└── references/
    ├── description-examples.md       # Good vs. bad descriptions per field type
    └── report-template.md            # Template for the generated Markdown report
```

## Requirements

- Salesforce CLI **v2** (`sf`)
- An authenticated org (`sf org display`)
- Minimum API version **60.0**

## Notes

- Writes in the org's reference language by default. Descriptions are not translatable through the Metadata API; for label and help text translations, use a dedicated translation agent.
- Standard object/field descriptions and help text are supported (validated with `--dry-run` on API 67.0). Only the modified files are deployed back.
- Do not use `CustomField:<Object>.*` to retrieve fields: the wildcard returns nothing. `CustomObject:<Object>` returns all fields.
- For objects with 100+ fields, custom fields and actually-populated fields are prioritized.

---

*Version 1.1. See the version history in `SKILL.md`.*
