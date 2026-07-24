# platform-metadata-quality-audit

An **Agentforce Vibes / Salesforce DX Einstein** skill that audits and improves the documentation quality of Salesforce **object and field metadata** — then deploys the approved changes via the Salesforce CLI.

It reads object/field metadata, samples real records for context, classifies every description as `MISSING` / `POOR` / `ADEQUATE` / `GOOD`, and produces a reviewable Markdown report of proposed improvements. Nothing is deployed until you say so.

## What it does

- **Audits** descriptions, help text, and labels on one or more objects (standard *and* custom).
- **Samples** 5 real records per object to ground the proposed descriptions in actual usage.
- **Classifies** every attribute against explicit quality criteria (present / specific / business context / length).
- **Proposes** enriched, business-contextual descriptions — using labels, not API names.
- **Reports** everything to a local Markdown file you can edit before applying.
- **Deploys** the approved changes with `sf project deploy start`, only after explicit confirmation.

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

1. **Retrieve** object + field metadata (`sf project retrieve start`).
2. **Sample** records (`SELECT … ORDER BY LastModifiedDate DESC LIMIT 5`).
3. **Analyze & propose** — classify each item, generate proposals for `MISSING` / `POOR`.
4. **Generate report** at `./metadata-quality-report-<ObjectName>.md`.
5. **Apply on approval** — re-read the (possibly edited) report, update the XML, deploy.

You stay in control: review the report, edit any proposal inline, then say **"go"** / **"apply"** to deploy — or **"regenerate"** to re-run.

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

- Detects the language of existing metadata and matches it (defaults to English).
- Standard object/field descriptions are supported — retrieve, modify, deploy back.
- For objects with 100+ fields, custom fields and actually-populated fields are prioritized.

---

*Skill authored for use with Agentforce Vibes / the Salesforce DX Einstein GPT extension.*
