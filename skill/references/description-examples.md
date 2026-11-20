# Description Quality Examples

## Object Descriptions

### Bad Examples

| Description | Why It's Bad |
|-------------|-------------|
| "This object stores data" | Generic, no business context |
| "Custom object for tracking" | Vague, could apply to anything |
| "Contains fields for Account info" | Describes structure, not purpose |
| (empty) | Missing entirely |

### Good Examples

| Object | Description |
|--------|-------------|
| Vehicle__c | "Tracks company fleet vehicles including make, model, mileage, and maintenance schedules. Used by the Operations team for fleet management and compliance reporting." |
| Project_Task__c | "Represents individual work items within a project. Links to Project and assigned team member. Tracks effort, status, and deadlines for sprint planning." |
| Invoice__c | "Records billing events sent to customers. Tied to an Opportunity after close-won. Finance uses this for revenue recognition and AR aging." |

---

## Field Descriptions

### Bad Examples

| Field | Description | Why It's Bad |
|-------|-------------|-------------|
| Status__c | "Status" | Just repeats the label |
| Amount__c | "Number field" | Describes type, not purpose |
| Email__c | "The email" | Too short, no context |
| Start_Date__c | "This is the start date field which stores the date when something starts" | Redundant, overly verbose |

### Good Examples

| Field | Type | Description |
|-------|------|-------------|
| Status__c | Picklist | "Current lifecycle stage of the application (Draft, Submitted, Under Review, Approved, Rejected). Drives workflow rules for reviewer assignment." |
| Annual_Revenue__c | Currency | "Self-reported annual revenue provided during onboarding. Used for customer segmentation and tier assignment." |
| Primary_Contact__c | Lookup(Contact) | "The main point of contact for this account, typically the person who signed the contract. Notifications and renewal reminders go to this contact." |
| Days_Since_Last_Activity__c | Formula(Number) | "Calculates business days since the last completed activity on this record. Triggers at-risk alerts when exceeding 30 days." |
| Total_Line_Items__c | Rollup Summary | "Counts all active line items on this order. Used by the fulfillment dashboard to prioritize complex orders." |

---

## inlineHelpText Examples

### Bad Examples

| Help Text | Why It's Bad |
|-----------|-------------|
| "Enter the value" | Obvious, adds no value |
| "Required field" | The UI already shows this |
| "Please fill in" | No guidance on what to enter |

### Good Examples

| Field | Help Text |
|-------|-----------|
| Billing_Frequency__c | "How often this customer is invoiced. Monthly is default; select Quarterly only for enterprise contracts over $50k/year." |
| External_ID__c | "The unique identifier from the ERP system (format: ERP-XXXXX). Do not edit manually — synced nightly via integration." |
| Priority__c | "Set to Critical only for production-down scenarios. High = same-day response, Medium = 24h, Low = best effort." |

---

## Language Matching

When existing metadata is in a non-English language, match that language:

| Existing Label (FR) | Proposed Description (FR) |
|--------------------|-----------------------------|
| "Statut" | "Étape actuelle du cycle de vie du dossier. Détermine les règles d'attribution automatique." |
| "Montant annuel" | "Chiffre d'affaires annuel déclaré par le client lors de l'onboarding. Utilisé pour la segmentation." |
