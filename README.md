# apply-factory

**A form-filling and learning extension for [career-ops](https://github.com/santifer/career-ops).**

Career-ops evaluates jobs and generates answers. This extension takes those answers and actually types them into the form via [Kimi Webbridge](https://kimi.com/), then learns from anything you fix manually — so next time those fields auto-fill.

Adds LinkedIn coverage too, since career-ops doesn't handle it.

## Contents

- [What it adds](#what-it-adds)
- [How it works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Install](#install)
- [Daily workflow](#daily-workflow)
- [Commands reference](#commands-reference)
- [The knowledge base](#the-knowledge-base)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Roadmap](#roadmap)

## What it adds

Six new modes to career-ops:

| Command | What it does |
|---|---|
| `/career-ops fill <slug>` | Types Section G answers into the form via Kimi Webbridge |
| `/career-ops learn <slug>` | Ingests the pre-submit form snapshot into the knowledge base |
| `/career-ops linkedin "<query>"` | Searches LinkedIn (three modes: full scrape, URL-only, or paste URLs) |
| `/career-ops linkedin-easy <slug>` | Handles LinkedIn's multi-step Easy Apply modal |
| `/career-ops kb-review` | Reviews entries the KB learned once but hasn't confirmed |
| `/career-ops briefing` | Daily overview: what's new, ready-to-apply, needs attention |

## How it works

```
1. /career-ops <url>         → career-ops evaluates, writes report + Section G
2. /career-ops fill <slug>   → this extension emits a Kimi Webbridge prompt
                               → you paste into Kimi on the job page
                               → Kimi fills known fields, pauses
                               → you review, correct anything wrong
                               → tell Kimi "snapshot"
                               → YOU click Submit
3. /career-ops learn <slug>  → snapshot → KB + report Section G updated
```

The extension never submits forms itself. You always click Submit. Kimi's job is to type; yours is to review and approve.

Everything career-ops already does — scoring, tailoring, cover letter generation, Section G drafting — runs unchanged. This extension only kicks in when you invoke one of its commands.

## Prerequisites

- A working [career-ops](https://github.com/santifer/career-ops) checkout
- Python 3.10+ with `pip`
- An AI coding CLI: [opencode](https://opencode.ai), [Claude Code](https://claude.com/claude-code), [Codex](https://openai.com/index/introducing-codex), or [Kimi](https://kimi.com/) — whichever you already use with career-ops
- [Kimi Webbridge](https://kimi.com/) browser extension for the form-fill step
- (Optional) An LLM backend for KB intent normalization — shells out to `opencode run` by default; see [Configuration](#configuration)

## Install

Two options — pick one.

### One-command install

```bash
# From inside your career-ops checkout:
curl -sL https://raw.githubusercontent.com/<your-user>/apply-factory/main/install.sh | bash -s -- .
```

*(Replace `<your-user>` with your GitHub username after forking.)*

### Manual install

```bash
# 1. Clone this repo somewhere
git clone https://github.com/<your-user>/apply-factory.git /tmp/apply-factory

# 2. Copy the 6 mode files into career-ops/modes/
cp /tmp/apply-factory/modes/*.md /path/to/career-ops/modes/

# 3. Copy the extension folder into career-ops/extensions/
mkdir -p /path/to/career-ops/extensions
cp -r /tmp/apply-factory/extensions/apply-factory /path/to/career-ops/extensions/

# 4. Set up Python + initialize the KB
cd /path/to/career-ops/extensions/apply-factory
pip install pyyaml
python3 orchestrator.py init

# 5. Verify
python3 orchestrator.py briefing
```

If step 5 prints an empty briefing (no errors), you're set.

### If you already extracted the zip inside `career-ops/extensions/`

Use `finish-install.sh` instead — it auto-locates career-ops from wherever the extension folder ended up:

```bash
bash career-ops/extensions/apply-factory/finish-install.sh
```

## Daily workflow

Typical order per application:

```bash
# 1. Morning check
/career-ops briefing
#   → shows new LinkedIn jobs, reports ready to apply, unconfirmed KB entries

# 2. Discover jobs
/career-ops linkedin "Senior Backend Engineer"
#   → past-24h + Easy Apply by default
#   → or use `linkedin url "<query>"` if you'd rather browse manually
#   → or use `linkedin add <url>` to paste specific URLs

# 3. Evaluate the interesting ones (career-ops native)
/career-ops https://boards.greenhouse.io/acme/jobs/12345
#   → writes reports/acme-senior-backend.md with Section G

# 4. Fill the form
/career-ops fill acme-senior-backend
#   → prints a Kimi Webbridge prompt
#   → open the job URL in your browser, launch Kimi, paste the prompt
#   → Kimi fills known fields, pauses
#   → you review, fix anything wrong
#   → tell Kimi "snapshot", it writes snapshots/<slug>.json
#   → YOU click Submit yourself

# 5. Learn from what you filled
/career-ops learn acme-senior-backend
#   → KB gains new question→answer pairs
#   → Section G in the report is rewritten with your final answers

# 6. Weekly KB hygiene
/career-ops kb-review
#   → surfaces recently-learned entries so you can approve/correct/delete
#   → catches misclassified intents before they poison future applications
```

## Commands reference

### `/career-ops fill <slug>`

Emits a Kimi Webbridge prompt to fill the form using Section G answers + KB.

Flags (passed to underlying `orchestrator.py`):
- `--prompt generic|easy-apply` — which Kimi template to emit

### `/career-ops learn <slug>`

Ingests the pre-submit snapshot at `snapshots/<slug>.json` into the KB and rewrites Section G in the report with the final answers.

### `/career-ops linkedin`

Three tiers depending on how much you want automated:

```bash
# Full scrape (Kimi does everything, ~2-5 min at human speed)
/career-ops linkedin "Senior Backend Engineer"
/career-ops linkedin "Senior Backend Engineer" --date-posted past-week --experience mid-senior

# URL only (you browse yourself, then paste URLs back)
/career-ops linkedin url "Senior Backend Engineer" --location Bangalore
# → prints https://www.linkedin.com/jobs/search/?... open in browser

# Manual add (paste specific URLs)
/career-ops linkedin add https://www.linkedin.com/jobs/view/12345 https://www.linkedin.com/jobs/view/67890
# → tries to fetch company/role from LinkedIn's og: tags
# → if that fails: --company "X" --role "Y" --jd-file /tmp/jd.txt
```

Flags for search:
- `--date-posted past-24h|past-week|past-month|any` (default: past-24h)
- `--experience entry|associate|mid-senior|director|any` (default: any)
- `--remote onsite|remote|hybrid|any` (default: any)
- `--all` — include non-Easy-Apply jobs (default: EA only)
- `--max N` — cap results (default 25, max 50)

### `/career-ops linkedin-easy <slug>`

Same as `fill` but uses the LinkedIn Easy Apply prompt template — walks the modal's 2-4 step wizard, tracks per-step state, snapshots at the Review step.

### `/career-ops kb-review`

Shows KB entries with `seen_count == 1` (learned once, never reinforced). For each, options are:

- `python3 orchestrator.py kb-approve <intent_key>` — mark confirmed
- `python3 orchestrator.py kb set <intent_key> "<value>"` — correct
- `python3 orchestrator.py kb-delete <intent_key>` — remove

### `/career-ops briefing`

Read-only dashboard:

- New LinkedIn inbox jobs from the last 24 hours
- Reports with a Section G but not yet applied (ready for `fill`)
- Count of unconfirmed KB entries
- KB size and recent learning event count

### Full `orchestrator.py` reference

```bash
python3 orchestrator.py --help
```

Subcommands: `init`, `fill`, `learn`, `kb`, `kb-review`, `kb-approve`, `kb-delete`, `linkedin-search`, `linkedin-url`, `linkedin-add`, `linkedin-ingest`, `briefing`.

## The knowledge base

The KB is a SQLite database at `extensions/apply-factory/kb.sqlite`.

### What gets stored

Every form field you fill (via Kimi's prefill + your corrections) is normalized to a canonical `intent_key` (snake_case) and stored as:

```
{intent_key, answer, answer_type, confidence, source, seen_count}
```

Example: the question "Are you an Indian Citizen?" gets `intent_key = citizen_of_india`, answer = "Yes". The next form that asks anything semantically equivalent ("Nationality: are you a citizen of India?", "Indian passport holder?") maps to the same `intent_key` and auto-fills from your stored answer.

### Learning events

Three event types tracked in `learning_events` (audit table):

- **new** — first time we've seen this intent
- **reinforced** — Kimi pre-filled correctly, you didn't change it
- **corrected** — Kimi pre-filled from KB, you changed the value; KB updates to your new answer

Corrections always win. Career-ops's report Section G is rewritten from the snapshot after each `learn`, so it stays in sync with what actually got submitted.

### What doesn't get stored

Job-specific answers (`why_company`, `why_this_role`, `additional_notes`, cover letters) are on the skip-list — they'd poison future applications with company-specific text. See `SKIP_INTENTS` in `learner/learn.py` if you need to add more.

## Configuration

`extensions/apply-factory/config.yaml`:

```yaml
paths:
  kb_db: "kb.sqlite"                           # local to apply-factory
  profile: "../../config/profile.yml"          # career-ops's profile
  reports_dir: "../../reports"                 # where Section G lives
  output_dir: "../../output"                   # where CVs live
  pipeline_tsv: "../../data/pipeline.tsv"      # career-ops's tracker

llm:
  backend: "opencode"                          # or "kimi" | "anthropic"
  model: "kimi-k2"
  temperature: 0.1

kimi_webbridge:
  never_auto_submit: true                      # do not change
  checkpoint_timeout_sec: 900
```

Switch LLM backend via env var:

```bash
export APPLY_LLM_BACKEND=kimi         # requires MOONSHOT_API_KEY
export APPLY_LLM_BACKEND=anthropic    # requires ANTHROPIC_API_KEY
export APPLY_LLM_BACKEND=opencode     # default; shells to `opencode run --stdin`
```

Backends are defined in `lib/llm.py` — add your own by editing the `call()` function.

## Troubleshooting

### `no Section G in reports/<slug>.md`

You either haven't run `/career-ops apply <url>` on this job yet (which is what generates Section G), or your Section G heading format doesn't match the parser's regex.

The parser expects one of:
- `## Section G`
- `## G.`
- `## G — ...`
- `## Application Responses`

If your career-ops config uses a different heading, edit `SECTION_G_HEADING` at the top of `lib/report_parser.py`.

### Kimi Webbridge fills nothing / wrong fields

Kimi's DOM matching uses semantic label match against `answers.json`. If it's leaving fields blank:

1. Check `extensions/apply-factory/artifacts/<slug>/answers.json` — is the answer even there?
2. If not, Section G was empty or the parser missed it (see above).
3. If yes, the label on the page probably doesn't match any question in the answers. That's fine — you'll fill it manually and `learn` will pick it up.

### LinkedIn search returns 0 results

LinkedIn A/B-tests its CSS class names weekly. The selectors in `prompts/kimi_linkedin_search.md` may be stale.

Open a LinkedIn search page in DevTools, find the current class names for job cards, title, company, location. Update the JavaScript block in `kimi_linkedin_search.md`.

### `pip install pyyaml` fails with `externally-managed-environment`

Debian/Ubuntu PEP 668 protection. Three options:

```bash
pip install --user pyyaml
# OR
pip install --break-system-packages pyyaml
# OR
python3 -m venv .venv && .venv/bin/pip install pyyaml
```

### LinkedIn OpenGraph metadata fetch returns nothing

LinkedIn sometimes serves a login wall to unauthenticated `og:` tag fetches, sometimes doesn't. Pass `--company "X" --role "Y"` explicitly:

```bash
/career-ops linkedin add <url> --company "Acme Corp" --role "Senior Backend Engineer"
```

### The wrong intent_key got learned

Common: LLM classified "How many hours per WEEK?" as `hours_per_day`. Fix:

```bash
python3 orchestrator.py kb-delete hours_per_day
```

Then rerun `/career-ops learn <slug>` — the LLM will invent a new key (`hours_per_week`) or you can preseed one with `kb set hours_per_week 40`.

## Uninstall

```bash
cd /path/to/career-ops
rm modes/{fill,learn,linkedin,linkedin-easy,kb-review,briefing}.md
rm -rf extensions/apply-factory
```

Your career-ops is now exactly as it was. `data/pipeline.tsv`, `reports/`, `output/`, `config/profile.yml` — none of those were touched.

## Roadmap

- [ ] Direct writes to `data/pipeline.tsv` on `linkedin-ingest` (currently stages to `data/linkedin-inbox.json`)
- [ ] Better LinkedIn scraper — likely swap Kimi-driven DOM walking for a real HTTP scraper (see [related discussion](#related-work))
- [ ] `kb-review` UI that batch-confirms/deletes rather than one-at-a-time
- [ ] Handle Workday's multi-page applications (career-ops handles Workday's ATS, but Workday's form flow is quirky)
- [ ] Naukri and Indeed coverage (same pattern as LinkedIn)
- [ ] Optional Section G preservation before `learn` overwrites (keep an audit trail)

## Related work

- [career-ops](https://github.com/santifer/career-ops) — the parent project this extends
- [Kimi Webbridge](https://kimi.com/) — the browser agent used for form-filling

## Contributing

Issues and PRs welcome. If you find a case where the Section G parser or the LinkedIn scraper breaks, please paste a redacted example — regex fixes are usually one line and land quickly.

## License

MIT

## Acknowledgments

Built on top of [santifer/career-ops](https://github.com/santifer/career-ops), which does the actual heavy lifting of job evaluation, resume tailoring, and Section G generation. This extension is a thin layer on top that adds actual form typing and a persistent knowledge base for common answers.
