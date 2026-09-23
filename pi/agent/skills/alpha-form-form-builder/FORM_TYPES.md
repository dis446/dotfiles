# Form Types — webform, wizard

Reference for Step 1 (INTENT): what each Form.io form type is, what it can do, when to choose it, and the phrasing signals that distinguish them. A form's type is set at creation but can be changed later via the form's display setting, so a wrong guess is recoverable — still, get it right up front.

## Webform (single-page form)

The standard form type: every field is presented on one page, completed and submitted in a single view.

**Capabilities.** The full component library, conditional fields, calculated values, validation — everything the renderer supports, on one page.

**When to choose.** Shorter forms the user can finish in one sitting — contact forms, feedback forms, quick surveys, sign-up forms. When in doubt between webform and wizard, a webform is the simpler default for anything under roughly a dozen fields.

## Wizard (multi-page form)

A multi-step form that breaks many fields into bite-size pages. Each page is a Panel layout component at the form's root; users navigate with header tabs and Cancel / Previous / Next buttons.

**Capabilities.** Everything a webform does, plus per-page navigation, conditional pages (a page whose visibility depends on earlier answers), and per-page validation before advancing.

**When to choose.** Long or complex forms where one page would overwhelm — multi-section intake forms, registrations with distinct stages, applications with branching sections. If the user describes stages, steps, or sections, they want a wizard.

**Nested wizard workflows (child wizards).** A wizard can embed another wizard — a **child wizard** — for hierarchical flows: build the child wizard as its own standard wizard form, then in the parent wizard add a Panel to the target page, place a Nested Form component inside it, and link it to the child wizard. Like any Nested Form, the component should set `reference: false` so the child wizard acts as a nested interface saved inline with the parent — not a separate child submission; the canonical guidance lives in `alpha-form-schema`'s `../alpha-form-schema/references/form/data-components.md` (Form component section), which the SCHEMA step loads. The Panel keeps the child wizard's pages rendered as sub-navigation beneath the parent's navigation instead of colliding with it. Use nested wizards when a complex workflow has sub-sections that deserve their own step-by-step navigation; use Tab components instead when step-by-step navigation is not needed. Creating the child wizard is its own SCHEMA → SAVE pass through this skill's pipeline (each wizard is a separate form in the project); the parent links to the saved child.

> **No PDF form type in this deployment.** The alpha CE fork has no hosted PDF server and no document upload/hosting path, so PDF forms cannot be built end to end. This skill presents only webform and wizard. (A future CE PDF server would make the pdf option a re-add, not a skill edit.)

## Phrasing signals — how INTENT distinguishes the types

| The user says … | Signal for | Confidence |
| --- | --- | --- |
| "multi-page form", "multi-step", "wizard", "steps", "stages", "sections", "one page per topic" | wizard | Unambiguous — infer and confirm |
| "form", "survey", "contact form", "questionnaire" with no size or layout cues | webform | Default — confirm, offer wizard if the field list turns out long |
| A long field list (roughly a dozen or more fields, or distinct topical groups) with no type named | wizard candidate | Ambiguous — ask |
