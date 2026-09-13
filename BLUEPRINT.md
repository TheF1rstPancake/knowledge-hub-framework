# Knowledge-Hub Blueprint — replicate this setup in any organization

> **Audience: a coding agent (Claude Code / Codex / Cursor) plus the human bootstrapping it.**
> A portable, org-agnostic recipe for the "hub" pattern: one repo that becomes the shared brain
> and config layer for an org's agent-assisted development, installed at **user scope** so it
> loads in *every* repo on the machine — not just when you're `cd`'d into it.
>
> Read §1-§2 to decide what you're taking. Then follow **§10 Bootstrap recipe**. Everywhere you
> see `{{PLACEHOLDER}}`, substitute the org-specific value (collected in **§11**).
>
> **Reading this to leave Amschel behind?** §2 is the whole answer: about 700 lines of shell, one
> templated `CLAUDE.md`, and an empty skills directory you fill yourself. Everything else here is
> Amschel's output, not Amschel's framework, and you should leave it.

---

## 1. The core idea

Most teams put conventions in a per-repo `CLAUDE.md`. That breaks the moment you have **more than
one repo**: the agent forgets your conventions every time it crosses a repo boundary, findings
scatter, skills get copy-pasted and drift.

The hub fixes this with one move: **a single repo symlinks its `CLAUDE.md` and its skills into the
agent's user-scope config directory.** Because that directory is user scope, the content loads in
*every* session on the machine regardless of working directory. Each product repo's own
`CLAUDE.md` then layers *on top* for stack-specific detail.

```
~/.claude/CLAUDE.md      <- symlink -> hub/CLAUDE.md     (org-wide: mission, conventions, where things live)
~/.claude/skills/*       <- symlinks -> hub/.agents/skills/*
<product-repo>/CLAUDE.md <- real file in each repo       (stack: build, test, auth, schema)
```

The hub is **not a monorepo**. Product repos stay independent clones with their own PR flows. The
hub holds only the cross-cutting layer: conventions, skills, durable findings, shared scripts, MCP
config.

**Why this is worth copying:** edit the convention once in the hub, re-run one script, and every
repo's agent picks it up. Knowledge written in one repo's session is findable from any other. A new
teammate clones the hub, runs one script, and inherits the org's accumulated agent context.

**Skills are vendor-neutral by construction.** The canonical source is `.agents/skills/`, and
`.claude/skills/` is a symlink to it. `AGENTS.md` is a symlink to `CLAUDE.md`. One installer
(`bootstrap-agent.sh --agent claude|codex|cursor|all`) fans the same sources out to each client's
user-scope directory. Never add a skill under a single vendor's directory — that's how you end up
maintaining three copies.

---

## 2. The transport decision: what's framework, what's ballast

This is the section that matters if you're standing this up somewhere new. The instinct is to copy
the hub and delete things; the correct move is the reverse — copy a short list and start empty.

### Take it (the engine, ~700 lines of shell)

| File | Why |
|---|---|
| `scripts/bootstrap-agent.sh` | The multi-client installer. Thin dispatcher; near-fully portable. |
| `scripts/bootstrap-claude.sh` | The install engine: manifest-tracked symlinks + surgical env-var merge. |
| `scripts/ship.sh` | One-command hub contribution. One org string in it. |
| `scripts/{{org}}-repos.sh` | Resolves sibling repos **by git remote, not by path convention**. |
| `.claude/hooks/gh-stack-guard.sh` | The enforcement pattern (§9). Generic apart from one skill name. |
| `.claude/autonomous-gate/` | Optional. The autonomy pattern (§9). |

### Take it (the doctrine — worth more than the code, and it's just prose)

- The six-tier memory table and its **routing tests** (§3). The tiers are obvious; knowing what
  goes in which one is the part teams get wrong.
- The **publishing-constraint layer** (§4). Probably the single most reusable idea here.
- The **hub-vs-handbook precedence ladder** and the handbook test (§5). This is what stops
  `CLAUDE.md` from growing into a 2,000-line dumping ground.
- The **findings convention** (§6) and the **scratch recovery hook** (§7).

### Write your own skills — don't port them

**The framework is the layout, not the skills.** Skills encode *your* procedures against *your*
tools, so they are the one part every adopter should author fresh — including a second team inside
the same company, whose tracker, review culture and deploy path differ from yours.

That isn't only a purity argument. Measured against the Amschel originals, the five meta-skills
carry 18, 19, 11, 53 and 41 hardcoded org references each. Renaming them is a `sed`; making them
*true* is an hour of reading, and the result is worse than an hour spent writing what you actually
do. A ported skill that describes a tracker you don't use is worse than no skill: the agent follows
it confidently and produces the wrong artifact.

What the framework does supply is the **slot** and the **conventions** (§10 step 4): where skills
live, how they're named, how the installer fans them out, and what makes a `description` fire. Fill
it with a starter roster that mirrors the memory tiers in §3 — those five names are the useful part,
not their contents:

| Skill | Its job |
|---|---|
| `{{org}}-finding` | Write a finding: naming, frontmatter, promotion, routing follow-ups to the tracker. |
| `{{org}}-ops-log` | Record shipped work on a surface that notifies nobody. |
| `{{org}}-artifact` | Publish a self-contained interactive page. |
| `{{org}}-roadmap` | Your issue label taxonomy and triage moves. |
| `{{org}}-pr` | PR discipline: branch naming, the CI-green gate, stacks, how to answer review. |

Write each one the third time you've done the task by hand — not before. A skill authored from
imagination encodes a procedure nobody follows.

**The exception worth knowing:** a skill with no org coupling at all does transport. In the Amschel
set, `engineering-design-doc` (0 org references) and `implementation-plan` (2) are pure writing
guidance and can be lifted verbatim. If you have access to a mature hub, grep its skills for your
org's name and take whatever comes back clean.

### Leave it

- **The findings corpus.** 242 files at last count. That's the framework's *output*, not the
  framework. A new hub starts empty and that is correct.
- **Every skill.** The 5 meta-skills for the reason above, and the 23 domain ones (supplier, RFQ,
  extraction, credit-app, Intercom) because they mean nothing elsewhere.
- **`install-agent-mcp.sh` and `.agents/mcp/servers.json`.** Read them as a *shape* (portable
  definitions in JSON, client mechanics in shell, credentials fetched at launch and never on disk),
  then write your own. The five named servers are pure Amschel.
- **`itt-pdf-filler/`** (54 tracked files of a one-off PDF tool), **`agents/`**, **`mcp/`**,
  **`docs/`** apart from this file, **`users/`**, and the untracked `_site/` left over from the
  GitHub Pages attempt that was removed 2026-09-02.

### The copy manifest

From a hub checkout (or a clone of it), into a fresh `{{HUB_NAME}}`:

```bash
SRC=/path/to/amschel-workspace          # or a fresh clone of the hub
DST=/path/to/{{HUB_NAME}}

mkdir -p "$DST"/{scripts,.agents/skills,docs/findings,users,.claude/hooks}
cd "$DST" && git init && ln -s CLAUDE.md AGENTS.md && ln -s ../.agents/skills .claude/skills

# engine
cp "$SRC"/scripts/{bootstrap-agent.sh,bootstrap-claude.sh,ship.sh,amschel-repos.sh} scripts/
mv scripts/amschel-repos.sh scripts/{{org}}-repos.sh
cp "$SRC"/.claude/hooks/gh-stack-guard.sh .claude/hooks/
cp -R "$SRC"/.claude/autonomous-gate .claude/            # optional, see §9
chmod +x scripts/*.sh .claude/hooks/*.sh

# skills: NONE. The directory ships empty on purpose — you author these (see above).
# The one exception: a skill that greps clean for your org's name has no coupling
# and can be lifted verbatim.
grep -ril amschel "$SRC"/.agents/skills --include=SKILL.md -L | sed 's|.*/skills/||'

cp "$SRC"/docs/HUB-BLUEPRINT.md docs/          # bring the recipe along
```

Then run the rename pass in §12, write `CLAUDE.md` (§10 step 2), and install (§10 step 6).

---

## 3. The six tiers of memory (keep these distinct)

There are six places knowledge can live. They are not interchangeable, and collapsing any two is
the most common way this pattern fails.

| Tier | Location | Scope | Lifespan | Who reads it |
|---|---|---|---|---|
| **Conventions** | `hub/CLAUDE.md` -> user scope | Every repo, every session | Until edited | Every agent, always (auto-loaded) |
| **Skills** | `hub/.agents/skills/*` -> user scope | Every repo | Until edited | The agent, when a task matches the trigger |
| **Findings** | `hub/docs/findings/` (team), `users/<h>/findings/` (personal) | The org / the person | Permanent, decays gracefully | Humans + agents, by search |
| **Ops log** | Tracker issues + descriptions (Linear, Jira, GH Issues) | The team | Days | Humans, for "what got done" |
| **Artifacts** | A separate published-pages repo | The team | Until superseded | Humans, by URL |
| **Agent memory** | The agent's own per-project memory dir | Per-repo, this user | Session-spanning working state | The main agent only, auto-loaded |

The routing tests, which are the actually transferable part:

- **Conventions** = "how we always work here." Stable, prescriptive, short. If it needs an example
  to be understood, it's probably a skill.
- **Skills** = "the procedure for doing X." Triggered, step-by-step, reusable. The `description`
  frontmatter is load-bearing — it's the only thing the agent sees when deciding whether to invoke,
  so pack it with trigger phrases.
- **Findings** = "this non-obvious thing we *learned*." The default home for discovery. Don't wait
  to be asked.
- **Ops log** = "this is what we *got done*." Findings deliberately don't answer this, and a lot of
  real work never lands as source code, so it was invisible in the tracker until this tier existed.
- **Artifacts** = "markdown can't carry this." Storyboards, charts over a query result, UI mockups,
  clickable demos of a feature that doesn't exist yet.
- **Agent memory** = the agent's private scratchpad of *your* recurring preferences and corrections.
  Never put collaborative knowledge here — it's per-repo and shared with nobody.

> Findings beat memory for anything a teammate would want. Memory beats findings for "the user
> always wants X" preferences the agent should self-apply. Findings and ops-log entries are
> complementary, not alternatives — work that produced durable knowledge *and* a shipped artifact
> gets both, cross-linked.

**One rule that looks trivial and isn't:** when citing a finding to a human, always give the
**full absolute path** with the hub env var resolved. The reader is almost always sitting in a
product-repo checkout where a hub-relative `docs/findings/...` path doesn't resolve, so their editor
can't open it. This applies to subagent output too — expand any relative paths a subagent hands back.

---

## 4. The publishing-constraint layer

**Decide, up front and in writing, what the agent may never publish under a human's name.** Not as
a vibe — as an enumerated list with explicit carve-outs. Without it you eventually discover the
agent has been agreeing with reviewers, closing threads, and editing PR descriptions in a voice
your colleagues believed was yours.

The Amschel version is "RULE 0" at the top of `CLAUDE.md`, and the shape generalizes:

1. **A named, absolute rule with no "unless it seems helpful" exception.** Put it first in
   `CLAUDE.md`, before the mission. Agents weight early, emphatic instructions heavily.
2. **An enumerated deny list**, not a principle. "Don't be presumptuous" is unenforceable. "Do not
   post a PR comment, reply to a review thread, submit a review, re-request review, add reviewers or
   labels, edit a PR title or body after opening, or react to a comment" is enforceable.
3. **One or two explicit carve-outs**, so the rule doesn't block the actual work. At Amschel:
   *opening* a PR is allowed, because it's the deliverable being asked for — its title and body are
   the agent's to draft. Everything after that belongs to the human.
4. **A carve-out for surfaces that notify nobody.** The tracker (§3's ops log) is written directly,
   without a confirmation gate, because an issue or a description interrupts no one. The same
   document forbids project *status updates*, which fire into Slack. The distinction is
   "does this land on someone's screen unbidden," not "is this a write."
5. **The behavior that replaces the forbidden one.** For review feedback: incorporate all of it,
   resolve each thread as you address it, and **say nothing on the thread** — the diff is the answer,
   and the report goes in chat instead. Give the agent the alternative or it will improvise one.
6. **A stated bar for skipping feedback**, so "I disagree" doesn't become a loophole. At Amschel the
   bar is *obviously contradictory* — conflicts with another instruction, with the codebase's own
   conventions, or with something measured. A comment being skipped stays open, and the reasoning
   goes in chat for the human to decide.
7. **Read-only is always fine.** Say so explicitly, or the agent over-applies the rule and stops
   being able to check CI.
8. **State that this rule outranks everything, including any team playbook** (§5). It's a personal
   constraint on what an agent may publish, not a competing norm.

---

## 5. Governance: hub vs. handbook, and the precedence ladder

The failure mode a live hub hits around month three: `CLAUDE.md` becomes the place every convention
goes, because it's the file that always loads. It grows without bound, mixes "how our org works"
with "how this one person works," and nobody can tell which lines are settled team agreement.

The fix is a **second repo** — a handbook — and a rule about which one wins.

- **The hub is yours.** Discovery notes, skills, scripts, per-user space, one-off plans.
- **The handbook is the team's.** Operating norms, versioned like code, written to be executed by a
  stateless reader. It is not vendored into the hub and not a submodule: a copy would duplicate, and
  a pinned SHA would go stale silently. Read the live checkout, resolved by env var like any sibling.
- **Where they overlap, the handbook wins.**

**The handbook test** — both halves required for a norm to graduate out of the hub:

1. **Aligned by merge.** A PR is a proposal; merging is what makes it settled.
2. **Reused.** More than one person or agent relies on it, more than once.

So: how we file a bug -> handbook. What we learned about a vendor's sitemap -> stays a finding. A
skill only you run -> stays in the hub until a second party depends on it.

**The precedence ladder**, stated explicitly in `CLAUDE.md` so an agent can resolve conflicts
without asking:

1. A **merged handbook playbook** outranks the hub's `CLAUDE.md` and any hub skill on the same
   subject. Merged means aligned — follow it, don't relitigate it in chat.
2. Where a hub convention and a playbook cover the same ground, the fix is to make the hub's copy a
   **pointer** to the playbook, not to keep both. Flag the overlap; don't quietly rewrite.
3. **The publishing constraint (§4) is never overridden.** It's stricter than any team norm.
4. A **per-repo `CLAUDE.md` / `STYLE.md` / `ARCHITECTURE.md`** still owns that repo's code
   conventions. The handbook defers to them by design.

Two details worth copying. Give the handbook a **map** — a registry of every substrate (where a kind
of record lives) and the playbook that governs it — so "where does this go?" has one lookup, and a
blank cell reads as a *named gap* rather than an invitation to improvise. And keep the local checkout
**read-only**: contribute by PR, never commit to it directly.

---

## 6. Findings convention

Durable learnings -> a new file. **Filename:** `YYYY-MM-DD-short-slug.md`. The date in the filename
*is* the staleness signal — old findings get superseded, never maintained.

```markdown
---
date: YYYY-MM-DD
author: <handle>            # git email local-part
issue: N                    # optional — tracker item this is evidence for
supersedes: OLD-SLUG.md     # optional
status: active              # active | superseded | promoted
---

# One-line summary

Short narrative: what you observed, why it matters. A reader should know within three
sentences whether to keep reading.

## Detail
Evidence, examples, specific IDs/URLs, commands you ran, `file.py:line` references.

## Implication
What this changes about how we operate. A fix direction, a rule, a hypothesis to test.

## Related
Links to the issue, the finding this supersedes, the PR where a fix landed.
```

Drop sections that don't apply. A three-paragraph finding is fine; a 3,000-word one is fine if the
material warrants it. What's not fine is padding with empty headers.

**Two tiers.** Personal drafts in `users/<handle>/findings/`, promoted team knowledge in
`docs/findings/`. Most findings start personal; promote with `git mv` (preserves attribution) and
flip `status: active` -> `promoted`. Ship a finding to the hub the moment it's written (§8).

**Write one when** you hit a vendor quirk, an approach that worked unexpectedly well or badly, a
dead end worth not revisiting, a failure signature with its root cause, or a measurement.

**Don't** for anything derivable from `grep` / `git blame`, anything already in `CLAUDE.md`, a task
summary the commit already carries, or ephemeral in-progress state (that's a plan).

**Route follow-up work to the tracker.** Findings routinely surface work you're not doing right now.
Written into the finding and nowhere else, that work is invisible — nobody reads a findings directory
looking for a to-do list. If a finding names actionable, unowned work, file it before you finish,
label it (`from-finding` at Amschel) so the set stays auditable, assign it to a **named human** (not
"me", which resolves to whichever identity holds the token), and cross-link both ways. Audit that
label on a cadence; an honest cancel beats a ticket nobody will pick up.

**Never delete a superseded finding.** It has archival value, especially for the next person who
retreads the same investigation.

---

## 7. Scratch convention

Exploratory artifacts (CSVs, query output, one-off scripts, debug data) ->
`users/<handle>/scratch/YYYY-MM-DD-slug/` with a three-line `README.md`:

```
2026-06-05-vendor-classification/
  README.md      <- what was I doing, what's in here, what's the takeaway
  data.csv
  query.sql
```

The README is the recovery hook. Without it, in six months it's orphaned files. Scratch is
gitignored by default; the per-day README is what makes it survivable if you *do* commit it. Raw data
never goes in a finding body — it goes here, and the finding links to it.

---

## 8. Shipping changes to the hub (`ship.sh`)

Hub `main` is protected (PR required) but has no required reviewers or checks, so clean PRs
auto-merge in seconds. `ship.sh` wraps push -> PR -> enable-auto-merge -> wait -> sync, and handles
the GitHub race where auto-merge fires before mergeability is computed (retries five times, ~2s
apart).

```bash
git checkout -b <handle>/<short-slug>
# edits
git add -A && git commit
scripts/ship.sh            # pushes, opens PR, enables auto-merge, waits ~30s, syncs main
```

Conflicts or failing checks leave the PR open with a link printed. It refuses to run from `main`.

**Ship after:** writing a finding, editing `CLAUDE.md`, changing a skill (then re-run the bootstrap
to refresh symlinks), adding reference data, or touching a workflow.
**Don't ship:** mid-session personal plans, anything under `scratch/`, or product-repo changes
(those use the product repo's own flow).

Friction here is what kills the knowledge layer. One command is the whole point.

---

## 9. Enforcement: when a prose rule isn't enough

A convention in `CLAUDE.md` is a request. Some rules need to be a wall. The hub has two examples,
and both patterns are worth copying.

### A `PreToolUse` hook that denies with guidance

`gh-stack-guard.sh` blocks `gh pr create --base <feature-branch>`, which layers PR diffs correctly
but creates no stack metadata, so the stack tooling can't restack after review feedback. Its own
header comment states the rationale better than any argument for the pattern could:

> *This exists because the prose rule was in context and got ignored anyway.*

The design details that make it good, and that generalize:

- **Fast path first.** It runs on every Bash call, so it pattern-matches the command and `exit 0`s
  before doing any real work.
- **It requires a real invocation**, not a mention. A commit message or doc that quotes
  `gh pr create --base ...` isn't a violation, so it checks for `gh` at a command position.
- **It denies with the fix**, not a refusal — the deny reason contains the three commands to run
  instead and points at the skill with the full flow.
- **It has a documented escape hatch** (`STACK_EXEMPT=1` as a command prefix) for the legitimate
  case, so nobody has to disable it.

Register it in user-scope settings with an env-var fallback so it works before the hub is installed:
`if [ -x "${{{HUB_ENV_VAR}}:-<absolute fallback>}/.claude/hooks/gh-stack-guard.sh" ]; then ... fi`.

### A `Stop` hook that keeps an armed session working

`autonomous-gate/` is optional and more opinionated. Sessions stall not on permission prompts but
because the model voluntarily ends its turn — "looks done" is the only stop signal it has, which
makes the human the verification loop. The gate replaces that with a machine-readable one: an
**armed** session keeps going until the work is built *and* written up as a finding, or until the
agent escalates a genuine decision.

- Arm with a slash command, disarm with another. Marker files in a state dir, keyed so the hook and
  the command compute the same key.
- Markers: `.armed` (block "looks done" stops), `.done` (release), `.escalate` (release), `.blocks`
  (a consecutive-block counter as a runaway backstop, default cap 40).
- **The release is wired into the finding skill** — writing a finding touches `.done`. That's the
  coupling that makes "built and written up" the actual completion criterion.
- **It fails open.** Any unexpected state -> `exit 0`. A gate that can wedge a session shut is worse
  than no gate.

The general lesson: if a rule has been ignored once with the prose in context, it wants to be a hook.

---

## 10. Bootstrap recipe (agent: follow these steps)

Substitute every `{{PLACEHOLDER}}` from §11.

### Step 1 — Create the hub repo skeleton

Run the copy manifest in §2. It creates the tree, the two symlinks (`AGENTS.md` -> `CLAUDE.md` and
`.claude/skills` -> `../.agents/skills`), and drops in the engine and the seven skills.

### Step 2 — Write `CLAUDE.md`

This is the heart. Order matters — the publishing constraint goes first, because early emphatic
instructions carry the most weight:

```markdown
# {{ORG}}

## RULE 0 — <the publishing constraint>
<enumerated deny list, the carve-outs, the replacement behavior — see §4>

## What this repo is
The {{ORG}} hub — the shared knowledge and config layer for all {{ORG}} work.
Installed at user scope by scripts/bootstrap-agent.sh, so it loads in EVERY session.
Resolve the hub by ${{{HUB_ENV_VAR}}} — never by filesystem guessing, never by directory name.
This is not the code (product repos are independent) and not the handbook (see below).

## {{HANDBOOK_REPO}} — the company operating model
Standards live there, not here. Read its map first. Precedence ladder — see §5.

## Mission
{{ONE_PARAGRAPH_MISSION}}
Current state: <what exists vs. what doesn't. Stops the agent wiring up flows that assume
unbuilt systems.>

## The repos
- **{{REPO_1}}** — {{stack + purpose}}. Has its own CLAUDE.md; defer to it.

## Reporting learnings
Durable learnings -> docs/findings/ (the finding skill). Cite them by ABSOLUTE path.
Interactive pages -> the artifacts repo. Exploratory data -> scratch/ with a README hook.
Tactical progress -> the tracker, as issues and descriptions, never status updates.
Memory vs. findings vs. ops log — the routing tests from §3.

## Committing to the hub
git checkout -b {handle}/{slug} && git add -A && git commit && scripts/ship.sh
```

Keep it prescriptive and short, and push anything that needs a worked example down into a skill.

### Step 3 — De-org the engine

Run the rename pass in §12. The engine is shell and its org coupling is genuinely just strings —
env-var names, the manifest filename, a GitHub URL, one skill name in the stack guard's deny
message. Verify with the residue grep at the end of §12; it should come back empty.

### Step 4 — Author the starter skills

Each skill is a directory under `.agents/skills/<name>/` with one `SKILL.md`:

```markdown
---
name: {{org}}-finding
description: Use when writing down a durable learning... Triggers on phrases like write a
  finding, document this, capture the learning, new finding, write it down.
---

# {{ORG}} findings workflow

<step-by-step procedure>
```

Three rules, all learned the hard way:

- **`name:` must equal the directory name.** A mismatch doesn't error — the skill just silently
  never loads. This is the single most common way a new skill appears broken.
- **The `description` is the only thing the agent sees when deciding whether to invoke.** It must
  carry trigger phrases, not a summary. Write the phrases a person would actually type.
- **Keep procedure, not prose.** A skill is the steps; the reasoning belongs in a finding.

Add domain skills as they earn their place — a workflow you've run three times by hand is a skill,
and one you've never run by hand is a guess. Prefix them with your org slug so they can't collide
with another hub's on a shared machine (see §3's tier table for which five to write first).

### Step 5 — Register MCP servers (optional)

Keep portable server definitions in `.agents/mcp/servers.json` and client registration mechanics in
`scripts/install-agent-mcp.sh`, additive over only the entries you own. For anything needing
credentials, use a **stdio wrapper script that fetches the secret at launch** so no token is ever
stored in MCP config or on disk; the usual failure is an expired SSO session, so document the
re-login command. Don't copy Amschel's servers — copy the shape.

### Step 6 — Install into user scope

```bash
scripts/bootstrap-claude.sh --dry-run              # preview every symlink and env change
scripts/bootstrap-agent.sh --agent all             # claude + codex + cursor
scripts/bootstrap-agent.sh --agent claude --status # verify manifest + link state
scripts/bootstrap-agent.sh --agent all --with-mcp  # also register MCP servers
```

`--dry-run` lives on the engine script, not the dispatcher — the dispatcher takes only `--agent`,
`--with-mcp`, `--status` and `--uninstall`, and exits 2 on anything else.

After this, conventions and skills load in **every** repo on the machine. Re-run after editing
skills or `CLAUDE.md`. `--uninstall` reverses exactly what was added (manifest-tracked) and never
touches a pre-existing non-symlink file.

### Step 7 — Wire product repos and the handbook

Clone them wherever you like — `{{org}}-repos.sh` resolves each one **by git remote**, not by path
convention, so a checkout in `~/dev` works as well as one beside the hub. Bootstrap pins each
location into an env var (`{{ORG}}_BACKEND`, `{{ORG}}_APP`, ...) so skills never search at runtime
and nobody edits a skill file to fix a path. `--clone` fetches what's missing; `--refresh`
fast-forwards read-only repos (the handbook) when clean and on their default branch, which is how
stale playbooks get current. Product repos are never auto-updated.

Set `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (bootstrap does this) so `/add-dir` pulls a
sibling repo's `CLAUDE.md` into the session — one session can span repos with full context.

### Step 8 — Create the sibling repos

Two, both optional but both load-bearing once the hub is live: the **handbook** (§5) and an
**artifacts** repo for published interactive pages (§3). For artifacts, the constraint that makes
them work is that each page is **one self-contained `index.html`** with CSS, JS, images and fonts
inline — no remote assets, data snapshotted in. **The hub itself does not publish.** There's no
rendered site for `docs/`, which is exactly why findings are cited by absolute path.

---

## 11. Fill-in-the-blanks checklist

| Placeholder | Meaning | Example |
|---|---|---|
| `{{ORG}}` | Organization / product name | `Acme` |
| `{{org}}` | Lowercase slug for skill and script names | `acme` |
| `{{ORG_UPPER}}` | Uppercase prefix for sibling-repo env vars | `ACME` |
| `{{HUB_NAME}}` | Hub repo directory + GitHub repo name | `acme-workspace` |
| `{{HUB_ENV_VAR}}` | Env var resolving the hub path | `ACME_HUB` |
| `{{GITHUB_ORG}}` | GitHub org slug (for `ship.sh`'s message) | `acme-ai` |
| `{{HANDBOOK_REPO}}` | The operating-model repo, if you have one | `acme-os` |
| `{{ONE_PARAGRAPH_MISSION}}` | What the org is building, 3-5 sentences | — |
| `{{REPO_n}}` | Each product repo + its stack/purpose | `api` (Python/FastAPI) |
| `{{handle}}` convention | How a user handle is derived | git email local-part |
| Tracker + label | Where the ops log lives, and the finding label | Linear, `from-finding` |

---

## 12. The engine scripts: contracts and the rename pass

**Source is deliberately not inlined here.** The previous version of this blueprint pasted a
`bootstrap.sh` that no longer exists — it was later split into `bootstrap-agent.sh` +
`bootstrap-claude.sh`, and the inlined copy silently became wrong. Copy the live files (§2) and use
this section as the contract they must keep.

### `bootstrap-claude.sh` — the install engine

Two properties are the whole value, and neither is obvious enough to reinvent:

- **Manifest-tracked installs.** Every symlink and env key it creates is recorded in
  `~/.claude/.{{org}}-hub-manifest`, so `--uninstall` removes *exactly* what it added — no orphaned
  symlinks, no guessing. It refuses to clobber any pre-existing non-symlink file, and backs up a
  real `CLAUDE.md` to `.{{org}}-bak` before linking over it.
- **Surgical env-var merge with ownership tracking.** `install_env_key` merges one key into
  `settings.json` without disturbing others. If the key pre-exists independently it is left alone
  *and never removed on uninstall*. A conflicting value is left alone with a warning. Ownership
  survives re-runs. Anything less careful eats a hand-edited settings file.

Modes: default install/refresh (idempotent), `--dry-run`, `--status`, `--uninstall`, `--with-repos`.

### `bootstrap-agent.sh` — the multi-client dispatcher

Deliberately thin: portable sources stay in `.agents/`, client configuration belongs to the
installer. Claude delegates to `bootstrap-claude.sh`; Codex and Cursor get plain symlink fan-out to
`~/.agents/skills` plus their own directory. Skipping a destination that exists as a real directory
is the correct behavior, not an error. Adding a fourth client should mean adding one `case` arm.

### `ship.sh` — one org string

The only org-specific line is the final message's GitHub URL.

### Rename pass

`sed -i ''` below is BSD/macOS syntax; on GNU it is `sed -i` with no argument. **Exclude this
blueprint** — it contains the recipe, so a blind pass rewrites its own instructions — and exclude
`__pycache__`, since `sed` on a matching binary corrupts it.

```bash
cd /path/to/{{HUB_NAME}}
grep -rl 'amschel\|AMSCHEL\|Amschel' scripts .claude .agents \
     --exclude-dir=__pycache__ --exclude='*.pyc' \
  | xargs sed -i '' \
      -e 's/AMSCHEL_HUB/{{HUB_ENV_VAR}}/g' \
      -e 's/AMSCHEL_/{{ORG_UPPER}}_/g' \
      -e 's/amschel-ai\/amschel-workspace/{{GITHUB_ORG}}\/{{HUB_NAME}}/g' \
      -e 's/amschel-workspace/{{HUB_NAME}}/g' \
      -e 's/amschel/{{org}}/g' \
      -e 's/Amschel/{{ORG}}/g'

# must come back empty (the blueprint keeps its Amschel examples on purpose)
grep -rn 'amschel\|Amschel\|AMSCHEL' . --exclude-dir=.git --exclude=HUB-BLUEPRINT.md
```

Verified end to end against a throwaway `acme-workspace`: the manifest copies clean, the pass
leaves no residue, and the seven skills land under the new prefix.

Then hand-check the residue that a `sed` can't fix: `install-agent-mcp.sh`'s five server names,
`{{org}}-repos.sh`'s repo list and remotes, the tracker project and label names in
`{{org}}-finding` and `{{org}}-ops-log`, the reviewer checklist in `{{org}}-pr`, and the
`ORCA_PANE_KEY` coupling in the autonomous gate (that's a specific terminal multiplexer; fall back
to the session id, or drop it).

---

## 13. Directory layout (target state)

```
{{HUB_NAME}}/
|-- CLAUDE.md                 # org conventions -> symlinked to user scope
|-- AGENTS.md                 # symlink -> CLAUDE.md (portable-agent convention)
|-- README.md                 # human onboarding
|-- .mcp.json                 # project-scoped MCP servers
|-- .agents/                  # VENDOR-NEUTRAL SOURCE
|   |-- skills/<name>/SKILL.md
|   `-- mcp/servers.json
|-- .claude/
|   |-- skills -> ../.agents/skills    # compatibility symlink
|   |-- hooks/gh-stack-guard.sh        # enforcement (§9)
|   `-- autonomous-gate/               # optional autonomy gate (§9)
|-- .github/workflows/        # hub-level automation
|-- scripts/
|   |-- bootstrap-agent.sh    # multi-client installer
|   |-- bootstrap-claude.sh   # the install engine
|   |-- install-agent-mcp.sh  # client MCP registration
|   |-- {{org}}-repos.sh      # sibling resolution by git remote
|   `-- ship.sh               # one-command hub PR
|-- docs/
|   |-- findings/             # TEAM knowledge — dated, permanent
|   `-- HUB-BLUEPRINT.md      # this file
`-- users/<handle>/
    |-- findings/             # personal drafts (promote via git mv)
    |-- scratch/              # dated subdirs w/ README recovery hooks
    `-- plans/
```

---

## 14. The principles, distilled

1. **Install at user scope, not per-repo.** One script symlinks `CLAUDE.md` + skills into the
   agent's config so conventions ride along everywhere. Per-repo `CLAUDE.md` layers on top.
2. **Keep the source vendor-neutral.** `.agents/skills/` is canonical; vendor directories are
   symlinks. One skill, three clients, no drift.
3. **Separate the six memory tiers and never collapse them.** The routing tests matter more than
   the tiers.
4. **Decide what the agent may never publish, and write it first.** Enumerated, with carve-outs.
5. **Write findings eagerly, structure them lightly.** Dated filenames are the decay signal. Don't
   maintain old findings — supersede them. Cite them by absolute path.
6. **Route unowned follow-up work to the tracker.** A recommendation living only in a finding is
   invisible.
7. **One-command shipping.** Friction is what makes a knowledge layer go stale.
8. **When a prose rule gets ignored with the prose in context, make it a hook.** Deny with the fix
   and an escape hatch, and fail open.
9. **Norms graduate to the handbook; learnings stay in the hub.** Aligned by merge *and* reused.
10. **The hub is a working surface, not a monorepo.** Product code stays in independent repos with
    their own flows.

---

## 15. What this can't ship

Two honest caveats, because a recipe that hides them sets up the next person to think they've
failed.

**The cadence isn't in the files.** The Amschel hub accumulated 242 findings in five months, 105 of
them in the last five weeks. No framework produces that. What the framework *can* supply is the two
things that produced it: shipping costs one command, and the standing instruction is "don't wait to
be asked." The rest is habit, and it takes a few weeks to form.

**Don't harden the template.** Of those 242 findings, 91 have no frontmatter at all. That looks like
a compliance problem and isn't — it's evidence the light-structure principle was real rather than
aspirational. Findings die under bureaucracy. A stricter schema, a required template, or a lint check
on the frontmatter will produce fewer findings, not better ones. If you tighten one thing, tighten
the *filename* (the date and a specific slug are what make the corpus navigable) and leave the body
alone.
