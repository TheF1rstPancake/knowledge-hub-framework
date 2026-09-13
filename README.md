# Knowledge-Hub Framework — starter kit

A portable version of the "hub" pattern: **one repo that becomes the shared brain and config
layer for an org's agent-assisted development**, installed at user scope so it loads in *every*
repo on the machine rather than only when you're `cd`'d into it.

Extracted from a hub that ran for five months and accumulated 242 findings, 30 skills and a
working PR/enforcement discipline. This kit is the part that was actually *framework*: ~700 lines
of engine, the conventions, and an empty skills directory you fill yourself. The findings and the
skills were that org's output — you don't want them, you want the shape that produced them.

**Read `BLUEPRINT.md` for the full reasoning.** This README is just how to run the thing.

---

## Quickstart

```bash
./instantiate.sh --org Acme --github-org acme-ai --owner "Jane Doe" \
    --app-repo app.acme.com --handbook-repo acme-os --reviewer "Sam"

# then
$EDITOR CLAUDE.md              # fill the 7 TODO sections — they are prompts, not prose
git init && git add -A && git commit -m "initial hub"
gh repo create acme-ai/acme-workspace --private --source=. --push
scripts/bootstrap-agent.sh --agent claude
```

`./instantiate.sh --help` lists every flag. `--dry-run` shows what would change. Anything you
don't supply stays a visible `{{PLACEHOLDER}}` and is reported at the end, so nothing goes
silently blank.

After bootstrap, your conventions and skills load in every repo on the machine. Re-run bootstrap
after editing `CLAUDE.md` or any skill. `--uninstall` reverses exactly what it added.

---

## What's in here

```
├── CLAUDE.md.template     -> becomes CLAUDE.md. The heart. 7 TODOs to fill.
├── BLUEPRINT.md           -> the full recipe and reasoning. Moves to docs/.
├── instantiate.sh         -> substitutes placeholders, renames, symlinks
├── scripts/
│   ├── bootstrap-agent.sh     multi-client installer (claude|codex|cursor|all)
│   ├── bootstrap-claude.sh    the install engine: manifest-tracked, reversible
│   ├── ORGSLUG-repos.sh       resolves sibling repos BY GIT REMOTE, not by path
│   └── ship.sh                one-command hub PR: push, PR, auto-merge, sync
├── .claude/
│   ├── hooks/gh-stack-guard.sh    a PreToolUse hook that denies WITH the fix
│   └── autonomous-gate/           optional: a Stop hook that keeps work going
└── .agents/skills/        EMPTY BY DESIGN — the slot, plus README.md on how to fill it
```

`ORGSLUG` in `scripts/ORGSLUG-repos.sh` is a bare token rather than `{{org}}` because it appears in
a **filename**, where braces are a shell-globbing footgun. `instantiate.sh` renames it.

---

## Skills are yours to write

**`.agents/skills/` ships empty on purpose.** Skills encode your procedures against your tools, so
they're the one part every adopter should author fresh — including a second team inside the same
company, whose tracker, review culture and deploy path differ from yours.

This isn't only a purity argument. The hub this came from had 30 skills; its five *framework*
skills carried 18, 19, 11, 53 and 41 hardcoded org references each. Renaming those is a `sed`;
making them true is an hour, and the result is worse than an hour spent writing what you actually
do. A skill that describes a tracker you don't use is worse than no skill — the agent follows it
confidently and produces the wrong artifact.

**`.agents/skills/README.md` is the part that replaces them**: the anatomy, the three rules that
matter (chief among them that `name:` must equal the directory name or the skill silently never
loads), a starter roster of five mirroring the memory tiers, and how to grep an existing hub for
skills clean enough to lift verbatim.

Two places in the kit assume skills you haven't written yet, by design:

- `gh-stack-guard.sh`'s deny message points at a `<org>-pr` skill for the full stacking flow.
- `CLAUDE.md`'s findings section has a comment marking where to name your `<org>-finding` skill.

Both work fine before those skills exist — the hook still blocks, the convention still loads. They
just get better once you write them.

---

## The five ideas worth understanding before you customize

Full versions in `BLUEPRINT.md`; these are the ones people get wrong.

1. **Install at user scope, not per-repo.** The whole point. Per-repo `CLAUDE.md` breaks the
   moment you have two repos — the agent forgets your conventions at every boundary.

2. **Six memory tiers, and the routing tests matter more than the tiers.** Conventions / skills /
   findings / ops log / artifacts / agent-memory. Findings beat memory for anything a teammate
   would want; memory beats findings for "the user always wants X." Collapsing any two is the
   most common way this pattern fails.

3. **Decide what the agent may never publish, and write it first.** Enumerated, with explicit
   carve-outs, before the mission. Without it you eventually find the agent has been agreeing
   with reviewers in a voice your colleagues believed was yours. The distinction that makes it
   workable is *"does this land on someone's screen unbidden"* — not *"is this a write."*

4. **Norms graduate to a handbook; learnings stay in the hub.** Around month three `CLAUDE.md`
   becomes the place every convention goes and grows without bound. The fix is a second repo and
   a precedence ladder. The test for graduating: *aligned by merge* **and** *reused by more than
   one party*.

5. **When a prose rule gets ignored with the prose in context, make it a hook.** `gh-stack-guard.sh`
   exists for exactly that reason. Deny *with the fix*, keep a documented escape hatch, and fail
   open.

---

## Two things this kit can't give you

**The cadence isn't in the files.** The original accumulated 242 findings in five months, 105 of
them in the last five weeks. No framework produces that. What it *can* supply is the two things
that did: shipping costs one command, and the standing instruction is "don't wait to be asked."
The rest is habit and takes a few weeks.

**Don't harden the finding template.** Of those 242 findings, 91 had no frontmatter at all. That
looks like a compliance problem and isn't — it's evidence the light-structure rule was
load-bearing. Findings die under bureaucracy. A stricter schema or a frontmatter lint check
produces *fewer* findings, not better ones. If you tighten one thing, tighten the filename — the
date and a specific slug are what make the corpus navigable — and leave the body alone.

---

## Requirements

`bash`, `git`, `jq`, and the [GitHub CLI](https://cli.github.com) (`gh`, authenticated).
`instantiate.sh` handles both BSD/macOS and GNU `sed`. The autonomous gate additionally assumes a
terminal multiplexer for its session key and falls back to the agent's session id without one.
