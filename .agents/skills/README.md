# Skills

**This directory ships empty on purpose.** Skills encode *your* procedures against *your* tools,
so they're the one part of this framework every adopter should author fresh — including a second
team inside the same company, whose tracker, review culture and deploy path differ.

What the framework gives you is the slot: this directory is the **vendor-neutral source**,
`../.claude/skills` symlinks to it, and `scripts/bootstrap-agent.sh` fans it out to every client's
user-scope config. Drop a directory in here, re-run bootstrap, and it loads in every repo on the
machine.

## Anatomy

One directory per skill, containing at minimum a `SKILL.md`:

```
{{org}}-finding/
├── SKILL.md              # required: frontmatter + the procedure
├── README.md             # optional: notes for humans maintaining it
└── helper.py             # optional: tooling the skill invokes
```

```markdown
---
name: {{org}}-finding
description: Use when writing down a durable learning, observation, or investigation result —
  anything future-you or another agent would want to know. Triggers on phrases like write a
  finding, document this, capture the learning, new finding, write it down.
---

# {{ORG}} findings workflow

<the procedure, as steps>
```

## Three rules, all learned the hard way

1. **`name:` must equal the directory name.** A mismatch doesn't error — the skill just silently
   never loads. This is the most common reason a new skill appears broken.
2. **The `description` is the only thing the agent sees when deciding whether to invoke.** Pack it
   with trigger phrases a person would actually type, not a tidy summary. This field is doing
   retrieval, not documentation.
3. **Keep procedure, not prose.** A skill is the steps. The reasoning behind them belongs in a
   finding; the standing rules belong in `CLAUDE.md`.

## Two more worth knowing

- **Prefix with your org slug** (`acme-finding`, not `finding`) so your skills can't collide with
  another hub's on a shared machine. Unprefixed names are first-come, last-bootstrap-wins.
- **Write a skill the third time you've done the task by hand** — not before. A skill authored
  from imagination encodes a procedure nobody follows.

## A starter roster

These five mirror the memory tiers in `BLUEPRINT.md` §3, which is what makes them the natural
first five. The *names* are the useful part here; the contents are yours.

| Skill | Its job |
|---|---|
| `{{org}}-finding` | Write a finding: naming, frontmatter, promotion, routing follow-ups to the tracker. |
| `{{org}}-ops-log` | Record shipped work on a surface that notifies nobody. |
| `{{org}}-artifact` | Publish a self-contained interactive page. |
| `{{org}}-roadmap` | Your issue label taxonomy and triage moves. |
| `{{org}}-pr` | PR discipline: branch naming, the CI-green gate, stacks, how to answer review. |

Then add domain skills as they earn their place.

## Lifting a skill from an existing hub

A skill with no coupling to its origin org does transport. Grep a mature hub's skills for that
org's name and take whatever comes back clean:

```bash
grep -ril <origin-org> /path/to/their-hub/.agents/skills --include=SKILL.md -L
```

In practice this returns pure writing/technique skills (how to structure a design doc, how to lay
out an implementation plan) and nothing that touches a tracker, a deploy, or a repo.
