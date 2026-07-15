# Narrow Global Gitignore Skills Negation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop scratch content inside `.claude/skills/**` (tuning workspaces, eval results, nested `.claude/`, logs) from leaking into `git status` via the global gitignore's blanket skills negation, without losing tracked skill support files.

**Architecture:** Append a "RE-IGNORE RULES" section to the global git ignore source file (`dot_config/exact_git/ignore`) with patterns that re-exclude known scratch shapes under `.claude/skills/**` (gitignore is last-match-wins, so this works after the existing negation section). Apply via chezmoi. Then remove the now-redundant local workaround in the `linPEAS-flake` repo (a directory outside this chezmoi source tree, at `/home/rvenutolo/Projects/Personal/linPEAS-flake`).

**Tech Stack:** git, gitignore pattern syntax, chezmoi (`exact_` prefix — file managed exactly, but this is a leaf file not a directory so `exact_` here applies to the parent `dot_config/exact_git/` dir).

## Global Constraints

- Spec: `.claude/specs/2026-07-15-gitignore-skills-scratch-design.md` (this repo, gitignored — do not try to `git add` it; it's a working doc, stays uncommitted).
- Convention: skill scratch directories are named `*-workspace/` or `scratch/`.
- Patterns must be scoped under `.claude/skills/` only — must not affect `results/`, `scratch/`, etc. elsewhere in a repo.
- Repo-local `.gitignore` negations must still be able to override the global rule for any future skill that legitimately needs to track a `results/`-named directory (this is inherent to gitignore precedence — no extra work needed, just don't break it).
- No force-adding gitignored files (user's global CLAUDE.md rule).
- Commit message convention: Angular style `type: subject`, imperative, ≤72 char subject. Use `chore:` for both commits in this plan.
- Final step: commit to `main` and push (user explicitly requested, in this chat — not a standing repo default, so no extra confirmation needed for this push).

---

### Task 1: Add re-ignore rules to global gitignore and verify

**Files:**
- Modify: `/home/rvenutolo/.local/share/chezmoi/dot_config/exact_git/ignore` (append at end of file)

**Interfaces:**
- Consumes: nothing (leaf task)
- Produces: global ignore file (materializes to `~/.config/git/ignore`) with new re-ignore section; verified against real linPEAS-flake scratch paths in Task 2.

- [ ] **Step 1: Append the re-ignore section to the source file**

Append this exact block to the end of `/home/rvenutolo/.local/share/chezmoi/dot_config/exact_git/ignore`:

```gitignore

### RE-IGNORE RULES

## Claude Code skill scratch
**/.claude/skills/**/*-workspace/
**/.claude/skills/**/.claude/
**/.claude/skills/**/scratch/
**/.claude/skills/**/results/
**/.claude/skills/**/*.log
**/.claude/skills/**/*.tmp
**/.claude/skills/**/*.bak
```

Preserve a single blank line before the `### RE-IGNORE RULES` heading, consistent with the blank-line separation used between existing sections in the file.

- [ ] **Step 2: Apply via chezmoi and confirm the diff is exactly the appended block**

Run: `chezmoi diff`
Expected: diff shows only the new lines added at the end of `~/.config/git/ignore`, nothing else changed.

Run: `chezmoi apply`
Expected: exits 0, no output (or a confirmation line depending on chezmoi verbosity settings).

- [ ] **Step 3: Confirm the materialized file matches source**

Run: `diff <(tail -n 10 ~/.config/git/ignore) <(tail -n 10 /home/rvenutolo/.local/share/chezmoi/dot_config/exact_git/ignore)`
Expected: no output (files match).

- [ ] **Step 4: Commit the chezmoi source change**

```bash
cd /home/rvenutolo/.local/share/chezmoi
git add dot_config/exact_git/ignore
git commit -m "chore: re-ignore skill scratch dirs under global .claude/skills negation"
```

---

### Task 2: Verify against linPEAS-flake scratch and remove local workaround

**Files:**
- Modify (external repo, not chezmoi-managed): `/home/rvenutolo/Projects/Personal/linPEAS-flake/.claude/skills/.gitignore` (delete)

**Interfaces:**
- Consumes: global ignore rules from Task 1, already applied to `~/.config/git/ignore`.
- Produces: linPEAS-flake repo with no local `.claude/skills/.gitignore`, scratch confirmed still ignored via global rules only.

- [ ] **Step 1: Confirm each known scratch path is now matched by a global rule, not the local file**

Run, from `/home/rvenutolo/Projects/Personal/linPEAS-flake`:

```bash
cd /home/rvenutolo/Projects/Personal/linPEAS-flake
git check-ignore --verbose .claude/skills/docs-correctness-audit-workspace/
git check-ignore --verbose .claude/skills/docs-correctness-audit/.claude/
git check-ignore --verbose .claude/skills/docs-correctness-audit/evals/seeded-defects/results/
```

Expected: all three print a match against `/home/rvenutolo/.config/git/ignore` (the global file), e.g.:
```
/home/rvenutolo/.config/git/ignore:<N>:**/.claude/skills/**/*-workspace/	.claude/skills/docs-correctness-audit-workspace/
```
(Line numbers will vary — confirm the *source* is `~/.config/git/ignore`, not `.claude/skills/.gitignore`.)

- [ ] **Step 2: Remove the now-redundant local workaround**

```bash
cd /home/rvenutolo/Projects/Personal/linPEAS-flake
git rm .claude/skills/.gitignore
```

- [ ] **Step 3: Re-verify scratch is still ignored after removal**

```bash
cd /home/rvenutolo/Projects/Personal/linPEAS-flake
git status --short --ignored -- .claude/skills
```

Expected: `docs-correctness-audit-workspace/`, `docs-correctness-audit/.claude/`, and `docs-correctness-audit/evals/seeded-defects/results/` all appear prefixed `!!` (ignored). No untracked (`??`) entries for these paths.

- [ ] **Step 4: Commit the removal**

```bash
cd /home/rvenutolo/Projects/Personal/linPEAS-flake
git commit -m "chore: drop local skills gitignore, superseded by global re-ignore rules"
```

---

### Task 3: Push chezmoi repo to main

**Files:**
- None (git operation only)

**Interfaces:**
- Consumes: commit from Task 1.
- Produces: pushed `main` branch on the chezmoi remote.

- [ ] **Step 1: Confirm branch and clean status**

Run: `cd /home/rvenutolo/.local/share/chezmoi && git status --short && git branch --show-current`
Expected: empty status (clean), branch is `main`.

- [ ] **Step 2: Push**

```bash
cd /home/rvenutolo/.local/share/chezmoi
git push origin main
```

Expected: push succeeds, no rejection (branch was up to date before Task 1's commit per session's initial git status).

Note: linPEAS-flake (Task 2) is a separate repo outside this chezmoi source tree — the user's push request applies to the chezmoi repo (`main` mentioned matches this repo's branch). If linPEAS-flake also needs pushing, confirm its remote/branch separately before pushing there; do not assume.
