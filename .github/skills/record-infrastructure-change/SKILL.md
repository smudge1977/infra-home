---
name: record-infrastructure-change
description: 'Use when recording an infrastructure change, deployment, maintenance operation, retrospective change ticket, or updating change issue labels and due dates in Forgejo for infra-home. Create and update change issues through the API using tea, not BrowserOS neo.'
---

# Record an infrastructure change

## Required conventions

- Record changes in `Home/infra-home` on `https://git.keithmarston.me.uk`.
- Use the authenticated Forgejo REST API, preferably `tea api`. Do not use
  BrowserOS neo or browser forms to create, edit, label, date, or close issues.
- Every change issue must have `change` and the affected system's label.
  For massage-brighton changes, the exact labels are `change` and
  `massage-brighton`. Add all relevant system labels for a multi-system change.
- Set the issue **due date to the date of the change**, not the date the issue
  was created, documented, reviewed, or closed. Record the date in the body too.
  For planned work use the agreed change date, then correct it to the actual
  deployment date if the change moves. If no date is known, ask before writing
  the record; do not silently substitute today.
- A check-mode preview, prepared playbook, failed run, or proposed change is
  not a completed deployment. Close only after evidence of completion and
  verification, or an explicit user confirmation of completion.
- Recording a change does not authorize deploying it. Never execute deployment
  or maintenance commands merely to complete the ticket.
- Preserve existing body content, labels, assignees, milestone and state unless
  the requested update requires a change. Do not automatically add `backlog`
  to a completed change; that label denotes unscheduled work, not change type.

## 1. Establish the record and evidence

1. Determine affected systems, summary, planned/actual change date, deployment
   status, verification outcome, rollback procedure and owner where known.
2. Read an explicitly linked issue first. Otherwise search existing issues in
   **all states**, including closed records, before creating anything. Match
   system, scope and date; a similar title alone is not enough. Paginate list
   results until exhausted when necessary.
3. Use deployment output, dated operator confirmation or logs as evidence.
   Repository preparation/commit dates and issue creation dates do not prove
   deployment. If the date is inferred from history, disclose the basis; ask
   if it remains ambiguous. Never invent test results or rollback success.
4. Link implementation, deployment notes and follow-up issues where useful.
   Keep secrets, private log dumps and unnecessary personal data out of issues.

## 2. Authenticate without exposing credentials

The verified client is `tea` with login `git.keithmarston.me.uk`. It obtains
credentials from its local configuration; never print or commit that file,
extract the token into chat, use debug/HTTP tracing, or put credentials in URLs.

```sh
command -v tea
command -v jq
tea login list
tea api --help
tea api --login git.keithmarston.me.uk repos/Home/infra-home/issues/25
```

The final command is a read-only example; substitute the requested issue number.
If authentication is unavailable, stop and ask the user to configure `tea` in
their terminal, then resume through the API. Do not request tokens in chat or
switch to browser automation. An already configured secure API client is an
acceptable alternative. Never send credentials to a different host.

## 3. Resolve labels and the API schema

```sh
tea api --login git.keithmarston.me.uk 'repos/Home/infra-home/labels?limit=100&page=1'
```

Paginate if needed. Resolve exact names to repository-local numeric IDs; never
reuse IDs from examples or another repository. Create missing required labels
with `POST repos/Home/infra-home/labels`, supplying `name`, six-digit hex `color`
(without `#`) and `description`. Existing labels must not be renamed/recolored.
Use `0075ca` for a new `change` label; use the existing system color where known
(massage-brighton was created as `5319e7`). If creation reports a conflict,
re-read labels and resolve the existing ID rather than retrying blindly.

Use the instance's `/swagger.v1.json` schema or `tea api --help` when uncertain.
The verified API supports:

| Purpose | Method and endpoint | JSON fields |
|---|---|---|
| Read issue | `GET repos/Home/infra-home/issues/{number}` | None |
| List/search issues | `GET repos/Home/infra-home/issues?state=all&limit=50&page=1` | None |
| Create label | `POST repos/Home/infra-home/labels` | `name`, `color`, `description` |
| Create issue | `POST repos/Home/infra-home/issues` | `title`, `body`, `labels` (numeric IDs), `due_date`, `closed` |
| Add labels, preserving others | `POST repos/Home/infra-home/issues/{number}/labels` | `labels` (numeric IDs) |
| Edit issue | `PATCH repos/Home/infra-home/issues/{number}` | Only changed fields: e.g. `body`, `due_date`, `state` |

`tea api` prefixes `/api/v1/` automatically for these relative endpoints.
Use `-X` explicitly for writes. `-f key=value` sends strings; `-F` sends typed
arrays/booleans. For full issue bodies, build JSON with `jq --arg`/`--rawfile`
and pipe to `tea api ... -d @-`; do not hand-escape multiline JSON.

## 4. Write the change issue

For new records, use the following body structure, omitting unavailable details
or marking them unknown rather than inventing them:

```markdown
## Summary
What changed and why; affected system/service and scope.

## Change date
YYYY-MM-DD — planned or actual; evidence/source and timezone if relevant.

## Implementation
Actions taken or planned; links to playbook, configuration and deployment notes.
State explicitly if only a check-mode run or partial deployment occurred.

## Validation and outcome
Checks actually performed and results, service impact and remaining problems.
For planned work distinguish acceptance checks from completed checks.

## Rollback
Restore/revert steps and rollback trigger; whether rollback was needed.

## Owner and follow-up
Responsible operator if known; related issues and outstanding work.
```

1. Send `due_date` as an RFC3339 timestamp using `YYYY-MM-DDT00:00:00Z`
   for the intended calendar date. Forgejo may normalize this to end of day;
   compare the returned **calendar date**, not the literal timestamp.
2. Create new issues with both required labels and the date in the initial
   request. Set `closed: true` only for confirmed completed retrospective work;
   otherwise leave the issue open.
3. For an existing issue, add missing labels with **POST**, not PUT (which
   replaces the label set), then PATCH only fields that need changing.
   A metadata correction must not reopen an already closed change.
4. Capture the issue number/URL from the response. If a write times out or
   returns an uncertain result, read/search before retrying to avoid duplicate
   issues, comments or labels. Do not retry authentication/permission errors
   without fixing their cause.

## 5. Verify and report

GET the issue again after all writes. Verify title/identity, preserved content,
`change` and system labels, due-date calendar day, and intended open/closed state.
Report its link, labels, change date and state concisely. If any write failed,
report which updates succeeded and which remain; do not claim full completion.

Reference example: issue #25, “Deploy PHP-FPM slow-request logging on
massage-brighton”, is closed with labels `change`, `massage-brighton`, and due
date **2026-11-08**. The date came from the deployment conversation: on
2026-11-09 the operator confirmed logging had been deployed for a day. It is
not the issue's creation date (2026-11-09). Do not reuse this date for other work.