# Skill Anonymizer
[![GitHub release](https://img.shields.io/github/v/release/wan-huiyan/skill-anonymizer)](https://github.com/wan-huiyan/skill-anonymizer/releases) [![Claude Code](https://img.shields.io/badge/Claude_Code-skill-orange)](https://claude.com/claude-code) [![license](https://img.shields.io/github/license/wan-huiyan/skill-anonymizer)](LICENSE) [![last commit](https://img.shields.io/github/last-commit/wan-huiyan/skill-anonymizer)](https://github.com/wan-huiyan/skill-anonymizer/commits)

Scan Claude Code skills for client-specific data and anonymize them for safe public sharing. Handles current file content and git history cleaning via `git-filter-repo`.

## Why This Exists

Skills built during client engagements absorb specific details: brand names, GCP project IDs, exact revenue figures, p-values from specific analyses. The methodology and patterns are valuable to share; the client-specific numbers are confidential. This skill systematically finds and removes identifying information while preserving instructional value.

## Quick Start

```
You: "I want to publish my campaign-analysis skill. Check it for client data first."

Claude: Runs three-category sensitivity scan:

=== Sensitivity Scan: campaign-analysis ===

DIRECT IDENTIFIERS (must remove):
  SKILL.md:327 — "acme-prod-123.analytics" (GCP project ID)
  SKILL.md:338 — "BrandX" (client brand name, 4 occurrences)

QUASI-IDENTIFIERS (should anonymize):
  SKILL.md:635 — "p from 0.047 to 0.096" (exact p-values from engagement)
  SKILL.md:164 — "£64K (+36%)" (exact amount, percentage is OK to keep)

CONTEXTUAL (your call):
  SKILL.md:190 — "a mid-size retailer" (narrows the industry)

Total: 12 direct, 8 quasi, 2 contextual
```

## Installation

**Claude Code:**
```bash
git clone https://github.com/wan-huiyan/skill-anonymizer.git ~/.claude/skills/skill-anonymizer
```

**Cursor (2.4+):**
```bash
mkdir -p .cursor/rules
# Copy SKILL.md content into .cursor/rules/skill-anonymizer.mdc with alwaysApply: true
```

## What You Get

- **Three-category scan**: Direct identifiers (must remove), Quasi-identifiers (anonymize with relative terms), Contextual (judge case by case)
- **Smart replacement rules**: preserves instructional value while removing specifics (e.g., "p worsened ~2x" instead of exact values)
- **Git history cleaning**: `git-filter-repo` workflow that rewrites blobs AND commit messages
- **Post-push verification**: confirms zero leaks in the published repo

## How It Works

| Step | What it does |
|------|-------------|
| **1. Scan** | Reads SKILL.md + references/, categorizes sensitive data into A/B/C |
| **2. Rules** | Creates replacement mapping preserving instructional value |
| **3. Apply** | Applies replacements to current files, reviews diff with user |
| **4. History** | Cleans git history via `git-filter-repo` (local-only or fresh clone) |
| **5. Verify** | Searches entire history for leaks, checks GitHub API post-push |

## What It Catches

**Category A — Direct Identifiers** (always remove):
- Company/brand names, GCP/AWS project IDs, dataset paths
- Email addresses, domain names, API keys

**Category B — Quasi-Identifiers** (anonymize with relative terms):
- Exact currency amounts (£297K -> "a moderate uplift")
- Exact p-values from specific analyses (p=0.039 -> "p < 0.05")
- Exact dates from engagements, correlation values

**Category C — Contextual** (judge case by case):
- Industry-specific details that narrow to a single company
- Geographic specifics, team sizes, revenue ranges

## Limitations

- Requires `git-filter-repo` (Python package) for history cleaning
- Cannot detect sensitive data in binary files (images, PDFs)
- Contextual identifiers require human judgment — the skill surfaces them but can't decide for you
- Force-push after history rewriting is destructive — always confirm with user

## Dependencies

- **git-filter-repo** (`pip install git-filter-repo`) — for history rewriting. Optional if you only need current-file scanning.
- **gh CLI** — for post-push verification. Optional.
- No other external packages required.

## Related Skills

- [data-provenance-verifier](https://github.com/wan-huiyan/data-provenance-verifier) — Verify data files are genuine before publishing
- [publish-skill](https://github.com/wan-huiyan/publish-skill) — Publish skills to GitHub (runs anonymizer as a pre-step)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-31 | Initial release. Three-category scan, replacement rules, git-filter-repo workflow. Tested with planted client data and history cleaning scenarios. |

## License

MIT
