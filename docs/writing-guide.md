# Technical writing guide

Write so a reader can understand what the software provides, choose an approach, and
implement it. Lead with the capability or action and explain the result the reader can
expect.

This guide adapts the plain language, concrete explanation and revision discipline of the
Morlencir Empire's [general writing guide](Morlencir-Empire/docs/writing/repository.md) and
[reference-manual guide](Morlencir-Empire/docs/writing/morlencir-reference-manual.md) for
software documentation. Apply it alongside each repository's technical conventions.

## Lead with what the software does

This is the central rule. Describe what the project is, what it does, and what it enables
the user or implementer to do. Define a feature through its behavior and purpose.

| Before | After |
|---|---|
| There is no user database to maintain and no password form. | People sign in with their existing directory accounts. IdentityServer reads their profiles and groups to build tokens for the application. |
| The server is not responsible for application sessions. | The application manages its session and starts a new sign-in when it needs fresh tokens. |
| Discovery loading is not a sign-in. | Verify the deployment by completing browser sign-in and redeeming the authorization code. |
| The portable providers do not use the Windows wrapper. | The portable providers use `System.DirectoryServices.Protocols` on Windows and Linux. |

Remove descriptions of what the software is not, lacks or does not do unless the distinction
is essential to an implementation decision. A departure from an expected protocol or
framework behavior merits an explicit statement: unsupported refresh tokens, for example,
change how a client obtains fresh tokens. Put that statement beside the supported procedure
and explain its consequence.

Warnings and failure conditions must remain precise. A callback check that matches only
hostnames needs that qualification; readers may otherwise assume exact URI matching.
Document the limit where the reader configures callbacks. A brief overview should lead with
the sign-in capability.

## State behavior precisely

Name the component, its action and the result. Use concrete verbs: reads, checks, redirects,
stores, rejects. Explain which setting controls the behavior and what the reader should
observe.

Replace praise with evidence. “Reliable key management” becomes “Persisted keys let the
server redeem an unexpired authorization code after a restart.” Remove intensifiers and
significance flags such as “remarkably,” “simply,” and “it is worth noting” when they add
only emphasis. Preserve qualifiers that describe real uncertainty or a tested limit.

Use familiar words and exact technical names. Define a specialist term when the reader
first needs it. Expand compressed phrases such as “reader identity/keytab lifecycle” into
the account, file and renewal steps involved.

## Start with useful content

Open a page with the task it supports or the behavior it explains. Follow with prerequisites
and scope when those affect the reader's choice. A heading usually provides enough
orientation for its section; begin the text with the explanation or instruction.

Each paragraph should develop one point. Split a sentence when its clauses describe
different actors or require the reader to reconstruct a sequence. End with the resulting
behavior or next action. Cut a closing sentence that merely repeats the paragraph.

## Ground explanations in implementation

Use examples that help the reader act: a configuration value, a request and response, a
command with expected output, or a symptom with its cause and remedy. Place the example
where the reader needs it. Keep names, ports and paths consistent across connected steps.

Explain why an instruction matters when the consequence helps the reader make a decision.
“Keep token keys outside the application folder so updates preserve them” supplies both
the action and its purpose.

## Give each page a purpose

Keep the full explanation of a subject in one reference page. Deployment guides should
carry the steps and context needed for their platform and link to that reference for detail.
Use ordinary Markdown links with descriptive labels.

Repeat a requirement where a reader needs it to carry out a procedure safely. Keep that
reminder short. Complete reference tables and explicit error conditions serve readers who
arrive at a single section through search. Match detail to the task and likely entry point.

Distinguish introductions, procedures, references and validation records. A validation
record preserves the date, environment, results and limits of the actual test. Keep its
claims tied to the evidence, including checks that remain unperformed.

## Format for use

Use numbered steps for sequences, bullets for independent items, and tables for settings
or comparisons. Use prose to explain causes and relationships. Keep all members of a list
when each carries useful information; revise lists padded for rhythm.

Use code formatting for identifiers, paths, settings and literal output. Reserve bold for
labels or warnings that help scanning. Prefer full stops and commas; use a colon for a
following explanation and parentheses for a short aside. Keep punctuation varied and
sentences easy to read.

Preserve command syntax, configuration keys, literal errors and published link targets
during prose edits. If a heading changes, update its incoming links.

## Review the whole passage

Make separate passes for positive framing, sentence clarity and repetition. Searches for
“not,” “no,” “without,” “rather than,” and “instead of” locate candidates for review. Judge
each occurrence by whether it conveys a consequential distinction.

After each edit, reread the complete sentence and its neighbors. Check that modifiers have
clear owners, pronouns have clear antecedents, and the edit has preserved the technical
meaning. Then read the whole page for repeated explanations and gaps between steps.

Finish by checking links and anchors, code examples, and any technical claims affected by
the rewrite. Match verification to the change: prose edits need documentation checks;
changes to commands or behavior need the corresponding technical validation.
