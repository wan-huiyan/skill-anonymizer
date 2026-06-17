---
name: skill-anonymizer
description: |
  Scan Claude Code skills for client-specific or sensitive data and anonymize them for
  safe public sharing. Use this skill whenever publishing a skill to GitHub, sharing a
  skill with others, or when the user says "anonymize skill", "clean skill for sharing",
  "remove client data from skill", "prepare skill for publishing", or "check skill for
  sensitive data". Also trigger proactively before running publish-skill — skills derived
  from client work almost always contain identifying information that needs cleaning.
  Handles both the current file content AND git history (using git-filter-repo to rewrite
  history while preserving commit structure). A known-term grep is necessary-NOT-sufficient:
  open-vocabulary identifiers (private skill/codenames) evade it — pair it with a SEMANTIC scan,
  and verify on the LIVE full-repo artifact (every file, including ones you didn't touch).
  Bundled `scripts/leak_scan.sh` runs the whole-repo audit — currency in FORMAT STRINGS (`£{...}`,
  `£%{...}`) that a `£[0-9]` regex misses, raw client figures as bare integers (symbol stripped),
  git history + tags + stale branches + GitHub release source-archives — and can be wired as a
  pre-push hook so a leak is blocked before it leaves the machine.
author: Claude Code
version: 1.2.0
date: 2026-06-17
---

# Skill Anonymizer

Skills built during client engagements absorb specific details: brand names, GCP project
IDs, exact revenue figures, p-values from specific analyses. These details make the skill
more concrete and useful locally, but they become a data leak when the skill is published
to a public GitHub repo. The methodology and patterns are valuable to share; the
client-specific numbers are confidential.

This skill systematically finds and removes identifying information while preserving the
skill's instructional value.

## When This Applies

- Before publishing any skill to GitHub (especially via `publish-skill`)
- When a skill was built during a client engagement
- When the user wants to share a skill with colleagues
- After updating a published skill with findings from a specific project

## Step 1: Scan for Sensitive Data

Read the skill's SKILL.md and all files in references/. Search for these categories:

### Category A: Direct Identifiers (always remove)
- **Company/brand names** — client names, competitor names mentioned by name
- **GCP/AWS/Azure project IDs** — `project-name-12345`, `acme-prod-123`, etc.
- **Dataset paths** — `company.dataset.table`, S3 bucket names
- **Email addresses** — `user@company.com`
- **Domain names** — `company.com`, internal URLs
- **API keys or tokens** — even placeholder-looking ones

### Category B: Quasi-Identifiers (anonymize with relative terms)
- **Exact currency amounts** — £297K, $1.2M, €45K
  - Replace with relative terms: "a significant uplift", "~30% improvement"
  - Or use illustrative generic amounts: "e.g., $50K-200K depending on scale"
- **Exact p-values from specific analyses** — p=0.039, p=0.114
  - Replace with ranges: "p < 0.05", "p worsened ~3x"
- **Exact dates from specific engagements** — "the Feb 27 - Mar 2 campaign"
  - Replace with generic: "a 4-day campaign window"
- **Correlation values from specific datasets** — r=0.885 for a specific metric
  - Keep if they illustrate a general pattern; remove the variable name if identifying

### Category C: Contextual Identifiers (judge case by case)
- **Industry-specific details** that narrow to a single company
- **Geographic specifics** — "London-based footwear retailer" → "a retailer"
- **Exact team sizes, revenue ranges** that identify the client
- **Specific product categories** if they're identifying

### Numeric & format-string evasions a `£[0-9]` grep misses (run `scripts/leak_scan.sh`)

A naive `grep '£[0-9]' SKILL.md` is the audit that let a real leak ship publicly for ~2 months
(S2026-06-17). Three blind spots, all caught by the bundled scanner:

- **Currency in FORMAT STRINGS.** `print(f"...£{x}")`, a Plotly `hovertemplate: '£%{y}'`, or
  `'£' + n` in a JS code template — the `£` isn't followed by a digit, so `£[0-9]` skips it. Grep the
  **bare symbol** (`grep -rnI -e '£' -e '€' -e '¥'`), never `£[0-9]`.
- **Raw integers with the symbol stripped.** You anonymize `£250,000` in the prose but a JS mockup
  still has `effect: 175000` / `ciLow: -176000` — the headline figure as a bare integer. Hunt the
  **digits of every known client figure** independently of the currency symbol.
- **Wrong file scope.** The leak is rarely only in `SKILL.md` — it's in `README.md`, `docs/`,
  `references/`, demo HTML, and code templates. Scan the **whole repo** (and skip binary files: `-I`).

The bundled scanner encodes all three plus the history / refs / release checks (Step 4a/5):
```bash
~/.claude/skills/skill-anonymizer/scripts/leak_scan.sh <repo> \
  -t known_terms.txt -n "250000 175000 90000" --remote owner/repo
# exit non-zero = candidate leaks. Still grep-class — pair with the semantic name scan below.
```

### A known-term grep is necessary, NOT sufficient — add a semantic scan

A grep/regex sweep only catches identifiers you can **enumerate in advance** (the brand names,
project IDs, `/Users/<name>` paths, `sk-` keys you already know). It is blind to **open-vocabulary
identifiers** — most dangerously, **private skill names / internal codenames** that look like
ordinary kebab-case but encode client work:

- a hardcoded list in a script, e.g. `TARGETS = {"baked-payload-stale-after-merge",
  "ssot-registry-lockstep-pins-upstream", "gha-auto-deploy-never-ran-skipped-mask"}` — real private
  trap-lessons, invisible to any fixed-token grep because you'd never think to grep for them;
- a comment that re-introduces telemetry while *abstracting* the name, e.g. "the single most
  name-invoked skill (~81 hits)" — the count + superlative is still private data even with the name gone.

So **pair the known-term grep with a SEMANTIC pass**: read every file (or fan out independent LLM
scanners) and ask *"is any token here a private/client identifier — a name, codename, count, or
inventory that reveals specific private work rather than generic methodology?"* The LLM recognizes a
client-shaped name a token list can't enumerate. In one real publish, a comprehensive grep came back
clean while a 3-scanner fan-out caught 3 such leaks. Also drop, don't ship, project-coupled scripts
that hardcode the user's private catalog (`recompute_with_overrides`-style override sets) — genericize
to an illustrative placeholder set with a "replace with your own" disclaimer.

Present findings to the user:

```
=== Sensitivity Scan: my-skill ===

DIRECT IDENTIFIERS (must remove):
  SKILL.md:327 — "acme-prod-123.analytics" (GCP project ID)
  SKILL.md:338 — "BrandX" (client brand name, 4 occurrences)

QUASI-IDENTIFIERS (should anonymize):
  SKILL.md:635 — "p from 0.047 to 0.096" (exact p-values from engagement)
  SKILL.md:164 — "£64K (+36%)" (exact amount, percentage is OK to keep)

CONTEXTUAL (your call):
  SKILL.md:190 — "a mid-size retailer" (narrows the industry)
  references/code_templates.md — clean, no identifiers found

Total: 12 direct, 8 quasi, 2 contextual
```

## Step 2: Create Replacement Rules

Build a replacement mapping. The goal is to preserve the instructional value while
removing identifying specifics:

**Good replacements:**
- `"BrandX"` → `"the retailer"` or `"the client"`
- `"acme-prod-123"` → `"your-project-id"`
- `"£176K"` → `"a moderate uplift"` or `"~$150K (illustrative)"`
- `"p=0.039"` → `"p < 0.05"`
- `"the paid metric had r=0.885"` → `"the paid channel metric had high correlation (r > 0.8)"`

**Bad replacements (lose instructional value):**
- `"p worsened from 0.047 to 0.096"` → `"p worsened"` (loses the magnitude)
  - Better: `"p worsened ~2x (from significant to non-significant)"`
- `"removing a correlated covariate increased effect by 36%"` → `"removing a covariate helped"`
  - Better: `"removing the contaminated covariate increased the effect estimate by ~30-40%"`

Save the replacement rules to a file for git-filter-repo:

```
# replacements.txt (for git-filter-repo --replace-text)
client_brand==>the client
project-id-12345==>your-project-id
£176K==>a moderate uplift
```

## Step 3: Apply to Current Files

Apply replacements to SKILL.md and all reference files. Review the diff with the user
before committing.

## Step 4: Clean Git History (if published repo)

If the skill is in a git repo (especially a public one), the old commits still contain
the sensitive data. Use `git-filter-repo` to rewrite history.

**For local-only repos** (never pushed), you can run in-place with `--force`:
```bash
cd /path/to/skill-dir
python3 -m git_filter_repo --replace-text /tmp/replacements.txt --replace-message /tmp/msg_replacements.txt --force
```

**For published repos**, clone fresh first to avoid accidental half-cleaned force-pushes:

```bash
# Install if needed
python3 -m pip install git-filter-repo

# Clone fresh (git-filter-repo requires a fresh clone)
git clone <repo-url> /tmp/skill-clean
cd /tmp/skill-clean

# Also create message replacements for commit messages
cat > /tmp/msg_replacements.txt << 'EOF'
ClientName==>client
BrandName==>the brand
EOF

# Rewrite all blobs AND commit messages
python3 -m git_filter_repo \
  --replace-text /tmp/replacements.txt \
  --replace-message /tmp/msg_replacements.txt \
  --force

# Verify: search entire history for leaks
git log --all -p --format="%B" | grep -c -i "pattern1\|pattern2"
# Must be 0

# Re-add remote and force push
git remote add origin <repo-url>
git push --force origin main
```

This preserves all commits (authorship, timestamps, messages) while cleaning the content.
The user should confirm the force push since it rewrites public history.

### Step 4a: a history rewrite is incomplete until you also purge refs, tags, and releases

`git-filter-repo` / an orphan-rewrite only fix what `main` reaches. These ALSO serve the old
(leaky) commits and must be cleaned, or the scrub is theatre (all bit the S2026-06-17 incident):

- **Stale merged branches** — every un-deleted feature branch keeps its pre-scrub commits
  reachable. `git ls-remote origin`, then `git push origin --delete <branch>` for each merged one.
- **Old tags** — a tag pinned to a pre-scrub commit is a permanent handle to the leak.
  `git push origin --delete refs/tags/vX`; re-create only on the clean commit.
- **GitHub releases** — a release's **source archives (`.zip`/`.tar.gz`) are generated from its
  tag's commit**, so a release on a leaky tag serves the leak as a download even after main is
  rewritten. `gh release delete vX --yes`, then recreate on the clean tag.

**Orphan-rewrite (nuke-all alternative to git-filter-repo)** when you want a single clean root and
don't need to preserve commit history (the README version table preserves the human changelog):
```bash
git checkout --orphan clean && git add -A && git commit -m "..."   # sanitized tree only
git branch -D main && git branch -m main && git push --force origin main
# then delete every stale branch / tag / release as above; re-tag + re-release on the clean commit
```
Past public exposure (forks, clones, GitHub's direct-SHA cache for ~90d) cannot be undone — the
rewrite stops *further* exposure. For highly sensitive data, also contact GitHub support to purge.

## Step 4b: GitHub issues / PRs / comments — editing does NOT remove the leak

A leak isn't only in files and commits. If you filed a public **issue, PR, or comment** that
contains a client name / identifier, **`gh issue edit` (or editing in the UI) does NOT purge it** —
GitHub retains the full **edit history** behind the "edited" pencil, viewable by anyone. The
anonymized edit only changes the *current* view.

For a real identifier leak in a freshly-created public issue/PR with no replies or cross-refs worth
keeping, **delete and re-file the clean version** instead of editing:
```bash
gh issue delete <N> --yes          # removes the issue AND its edit history
gh issue create --title "..." --body "<anonymized>" --label "..."   # re-file clean → new number
```
Note the renumber in your summary. If the issue already has valuable replies / inbound references,
deletion is lossy — then edit to scrub the live body, and tell the user the edit history still holds
the original (only GitHub support can purge it). Best of all: anonymize **before** filing anything
public — same discipline as never committing the un-anonymized blob. (2026-06-06: filed an issue that
named a client + their PR; editing would have left it in the pencil-history, so deleted #55 and
re-filed clean as #56.)

## Step 5: Post-Push Verification — on the LIVE FULL repo, not just your change set

Verify on the **published artifact**, and scan **every file in the repo — including files you never
edited.** A change-scoped gate (scanning only the files your edit touched) is blind to **pre-existing
leaks**: a leak can sit in a `README.md`, `docs/`, or sibling file that predates your change and that
your staging review never opened. Clone the merged main fresh and grep the whole tree:

```bash
git clone <repo-url> /tmp/verify-clean && cd /tmp/verify-clean
grep -rniE 'known|sensitive|terms|here' . --include='*.md' --include='*.py' --include='*.json' | grep -v '.git/'
# Must be empty — AND remember the grep is necessary-not-sufficient (Step 1): for a public push,
# also eyeball / semantic-scan the README + docs for client-shaped NAMES the grep can't enumerate.
```

In one real publish, staging was grep-clean and the change-scoped leak gate passed, yet the final live
grep over the *whole* merged repo caught a private name in a `README.md` that was never part of the
change — fixed with a follow-up PR. Verify the live artifact, every file, before declaring clean.

**If an agent/subagent did the sanitizing, re-clone and grep YOURSELF — do not trust its self-reported
"clean."** In the S2026-06-17 incident a sanitization subagent reported "0 residual hits" but had left
`£{...}` format-string currency and raw `175000`/`-176000` mockup integers; an independent fresh
re-clone (+ a digits-too grep) caught them. Run the bundled scanner on the fresh clone with the figure
list, and confirm history is clean too:
```bash
git clone <repo-url> /tmp/verify-clean
~/.claude/skills/skill-anonymizer/scripts/leak_scan.sh /tmp/verify-clean \
  -t known_terms.txt -n "250000 175000 90000" --remote owner/repo   # exit 0 required
```

After force-pushing history (Step 4), also confirm a single file via the API:
```bash
gh api repos/owner/repo/contents/SKILL.md --jq '.content' | base64 -d | grep -c -i "sensitive_term"
# Must be 0
```

Note: GitHub may cache old commit data briefly. The reflog on GitHub is eventually
garbage-collected, but for highly sensitive data, consider contacting GitHub support
to purge cached objects.

## Strongest guarantee: gate it, don't just remember it

The audit only protects you if it actually runs. A checklist relies on someone remembering to run
it (the S2026-06-17 leak shipped because the pre-publish audit was either skipped or too shallow).
To make it **non-skippable** for a repo, wire the scanner as a git **pre-push hook** so any push
carrying a known client term/figure is blocked before it leaves the machine:

```bash
# .git/hooks/pre-push  (chmod +x) — or point core.hooksPath at a shared hooks dir for all repos
#!/usr/bin/env bash
~/.claude/skills/skill-anonymizer/scripts/leak_scan.sh . \
  -t .leakterms.txt -n "$(cat .leakfigs 2>/dev/null)" \
  || { echo "pre-push BLOCKED: candidate client-data leak (see above)."; exit 1; }
```

Keep `.leakterms.txt` / `.leakfigs` out of the repo (add to a global gitignore). This catches the
**enumerable** identifiers automatically; the open-vocabulary semantic name-scan (Step 1) still needs
a human/LLM pass before a *first* public publish. Enumerable-auto + semantic-once is the belt-and-braces.

## Key Principle

The methodology is the asset; the specific numbers are the liability. A skill that says
"removing a contaminated covariate improved p by ~2x" is just as instructional as one
that says "removing the correlated covariate improved p from 0.142 to 0.060" — but only
the first is safe to publish.
