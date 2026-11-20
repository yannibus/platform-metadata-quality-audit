# platform-metadata-quality-audit

Audit and improve the documentation quality (descriptions, help text, labels) of Salesforce **object and field metadata**. Two ways to use it, same rules:

| Stream | For | How |
|--------|-----|-----|
| [`skill/`](skill/) | Vibe coders | An agent skill (Claude Code, Agentforce Vibes, any `SKILL.md`-compatible agent) driving the Salesforce CLI. |
| [`admin-app/`](admin-app/) | Org admins | A Lightning Web Component installed in the org: pick an object and a sample size (max 100), review the analysis, edit and apply the recommendations. Generation runs on a Prompt Template. Setup guide: [`admin-app/README.md`](admin-app/README.md). |

`skill/SKILL.md` is the reference for the quality criteria, scope and safeguards; the `admin-app/` stream follows them.

Design: [`docs/superpowers/specs/2026-11-19-lwc-admin-design.md`](docs/superpowers/specs/2026-11-19-lwc-admin-design.md) · Plan: [`docs/superpowers/plans/2026-11-19-lwc-admin-audit.md`](docs/superpowers/plans/2026-11-19-lwc-admin-audit.md)
