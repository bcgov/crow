# Attribution and Third-Party Notices

This skill ships only Crow-authored files. Nothing in it is vendored from
another project.

- **Concepts.** The report structure and reconciliation vocabulary were
  informed by publicly available quality-documentation practice, including the
  Apache-2.0 licensed `andrewstellman/quality-playbook`
  (<https://github.com/andrewstellman/quality-playbook>). Ideas were adapted;
  no text, prompts, or code were copied.
- **Mermaid.** Diagrams are rendered by the MIT-licensed Mermaid CLI
  (`@mermaid-js/mermaid-cli`, <https://github.com/mermaid-js/mermaid-cli>),
  which the user installs separately. Mermaid is not bundled, vendored, or
  downloaded at run time; only the pinned configuration in
  [`assets/mermaid-config.json`](assets/mermaid-config.json) is shipped.
- **B.C. Design System.** [`assets/business-rules.css`](assets/business-rules.css)
  follows the published Apache-2.0 B.C. Design System foundations
  (<https://www2.gov.bc.ca/gov/content/digital/design-system/foundations>)
  using original CSS. No design-system package, font, or asset is included, and
  the generated report does not claim to be a design-system component.
- **Report behaviour.** [`assets/business-rules.js`](assets/business-rules.js)
  is compact original vanilla JavaScript written for this skill. No third-party
  JavaScript library is used or required.

All files in this skill are covered by the Crow repository's MIT licence.
