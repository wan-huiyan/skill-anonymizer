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
  history while preserving commit structure).
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

## Step 5: Post-Push Verification

After force-pushing, verify on GitHub:
```bash
gh api repos/owner/repo/contents/SKILL.md --jq '.content' | base64 -d | grep -c -i "sensitive_term"
# Must be 0
```

Note: GitHub may cache old commit data briefly. The reflog on GitHub is eventually
garbage-collected, but for highly sensitive data, consider contacting GitHub support
to purge cached objects.

## Key Principle

The methodology is the asset; the specific numbers are the liability. A skill that says
"removing a contaminated covariate improved p by ~2x" is just as instructional as one
that says "removing the correlated covariate improved p from 0.142 to 0.060" — but only
the first is safe to publish.
