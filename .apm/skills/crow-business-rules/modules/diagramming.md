# Diagramming

Diagrams are authored as Mermaid source in `business-rules-data.json` and
pre-rendered to inline SVG by `scripts/render-business-rules.ps1`. The published
HTML contains no diagram runtime and loads nothing at view time.

## When to draw a diagram

Draw a diagram only when it explains rule interaction better than prose:

- `flowchart` for decision order and branching between rules;
- `stateDiagram-v2` for lifecycle and allowed transitions;
- `sequenceDiagram` for cross-service rule enforcement;
- `classDiagram` or `erDiagram` for the data model that rules constrain.

Keep each diagram to one question. Several small diagrams are easier to read
and to re-render than one large one.

## Required content

- Reference the rules the diagram depicts in `rule_refs`; every reference must
  resolve to a rule in the same file.
- Write a `description` that states what the diagram shows. It becomes the
  accessible description of the figure, so a reader who cannot see the diagram
  still gets the information.
- Name nodes with the rule identifier when the node represents one rule, for
  example `Reject: BR-0001`.

## Security constraints

The validator rejects a diagram when its source contains any of the following:

- init directives (`%%{ ... }%%`);
- a `click` statement, at the start of a line or after a `;` separator;
- `href`, `call`, or `callback` followed by binding syntax (`(`, `=`, `:`, or a
  quote);
- raw HTML, including line-break tags and entities written as markup;
- a line that starts a Markdown code fence (three or more backticks, optionally
  indented by up to three spaces);
- absolute URLs of any scheme, `javascript:` and `data:` URLs, and style imports.

### UML annotations and stereotypes

Mermaid's own guillemet annotations are syntax, not markup, and are accepted:
`<<interface>>`, `<<abstract>>`, and `<<enumeration>>` in `classDiagram`, and
`<<fork>>`, `<<join>>`, and `<<choice>>` in `stateDiagram-v2`. A custom
stereotype is accepted when it starts with a letter and contains only letters,
digits, spaces, underscores, and hyphens, for example `<<Fee service>>`.

The allowance is narrow on purpose. The grammar admits no `<`, `>`, `/`, `=`,
`:`, or quote character, so it cannot express a tag, an attribute, a URL, or a
scheme, and every other check still reads the original source. `<<script>>`,
`<<img src=x>>`, and `<<interface>> <b>Shape</b>` are all still rejected.

### Residual restrictions

The checks are scoped to directives, bindings, and URL syntax, so ordinary label
text such as `Call centre`, `Data: pending`, or `Script review` is accepted.
Two residual restrictions remain, and both are deliberate:

- a `;` inside a label followed by `click` is read as a statement separator and
  rejected, because `;` really does separate Mermaid statements;
- a label that puts a colon, `=`, `(`, or a quote directly after the words
  `href`, `call`, or `callback` (for example `Call: escalate`) is rejected.

Reword the label rather than weakening the check; the checks fail closed.

Rendering uses the pinned `assets/mermaid-config.json`, which sets
`securityLevel: strict`, disables HTML labels, and fixes the theme, so a diagram
cannot opt into a weaker configuration.

## Rendering pipeline

1. The renderer writes each diagram to a temporary directory under the system
   temporary path and invokes a preinstalled Mermaid CLI (`mmdc`). It never
   invokes `npx` or downloads a package.
2. The rendered SVG is checked as markup rather than as raw document text: it is
   split into tags, attributes, and text runs before any check runs, so label
   text such as `Data: pending` stays inert while active contexts still fail
   closed. Script, `foreignObject`, `image`, embedded, and animated elements,
   event handler attributes, `javascript:`/`data:` and other active schemes in
   `href`/`xlink:href`/`src`/`style`/`url()` contexts, references that are not
   same-document, DOCTYPE and entity declarations, and markup that cannot be
   parsed are rejected. The tokenizer follows browser rules: comment terminators
   (`-->`, `--!>`, and the abrupt `<!-->`); an `=` that only introduces a value
   after an attribute name; a quote that only opens a quoted value directly
   after that `=`; an unquoted value that ends only at whitespace or `>`, so an
   internal `=` or quote cannot re-open quoted mode and swallow the elements
   after the tag; and `script` and `style` as raw-text elements that a trailing
   solidus does not self-close, because HTML has no self-closing `script` or
   `style`. A raw-text end-tag name ends at whitespace, at `/`, or at `>`, and
   the end tag then runs on to its `>`, so the browser-valid `</style/>` and
   `</style foo>` forms close the element and the markup after them is checked
   as live markup instead of being read as inert CSS or script text; whitespace
   directly after `</` is not an end tag at all. An unterminated end tag is
   malformed rather than a reason to read on to a later one, and a `<` inside
   style content, which valid CSS never needs, is rejected as a defence in
   depth. An element cannot therefore be hidden inside a comment, behind an
   unquoted attribute value, or after `<style/>` or `</style/>`. Unsafe content
   is rejected, never stripped or repaired.
3. Identifiers inside each SVG are rewritten with a deterministic per-diagram
   prefix so several inlined diagrams cannot collide.
4. The SVG receives `role="img"` and is labelled by the figure caption and
   description.
5. Any failure stops the run before either document is published, so an existing
   Markdown and HTML pair is left unchanged.

Supply `-MermaidCliPath` when `mmdc` is not on `PATH`. PATH discovery looks for
an executable, so npm's Windows shim layout (`mmdc.ps1` beside `mmdc.cmd`) is
handled. If the CLI is unavailable, report the missing prerequisite; do not
remove the diagrams to make the run succeed unless the report user asks for
that.

## Markdown output

The Markdown report keeps the Mermaid source in a fenced `mermaid` block so it
renders on platforms that support Mermaid and stays reviewable in a diff. The
HTML report carries the pre-rendered SVG instead.

The fence is fixed at three backticks, so diagram source that starts a code fence
of its own is rejected instead of being re-fenced at run time. Reword or indent
such a label; the published document contract stays reviewable rather than
depending on run-time input.
