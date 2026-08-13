# Handoff — what remains, and how to do it

Both replication packages are complete and verified. Everything left is version
control and the arXiv posting, which decision **D-9** put outside the build
scope. This document is the procedure.

**Paper A is published.** Its `main` carries the 405-file package, the guide is
live, and the three URLs the manuscript prints all resolve. **Paper B has not
been pushed**, and neither paper is on arXiv. The procedure below is what was
actually run for Paper A, so it can be followed as-is for Paper B.

---

## State at handoff

| | Paper A | Paper B |
|---|---|---|
| Directory | `bayesmokken-scalability-replication` | `bayesmokken-clustered-polytomous-replication` |
| Files git will commit | **405** | **412** |
| — of which `docs/_book` | 39 | 37 |
| Rows in `release-files.csv` | 405 | 412 |
| Size (excl. `docs/_book`) | 42.4 MB | 34.4 MB |
| Exhibits reproduce | **16 / 16** | **16 / 16** |
| Ledger byte-identical | yes, `d128c692…` | yes, `6a42e735…` |
| Manuscript predicates | **62 / 62** | **69 / 69** |
| Semantic checks | **20 / 20** | **21 / 21** |
| Receipt chain | **114 / 114** | **30 / 30** |
| Disclosure findings | **0** | **0** |
| Oracle lane | **6 / 6** | **13 / 13** |
| Negative controls | **16 / 16** | **19 / 19** |
| Cold start | **15 / 15** | **15 / 15** |

Manuscripts, after the Step 12.1/12.2 URL edits:

| | Paper A | Paper B |
|---|---|---|
| Pages | **55** (unchanged) | **49** (unchanged) |
| Number checks | **63 / 63** | **69 / 69** |
| arXiv preflight | **34 / 34** | **42 / 42** |
| Overfull boxes | 0 | 0 |
| PDF text vs before | identical apart from the URLs | identical apart from the URLs |

---

## 1. Create the two repositories

```bash
gh repo create joonho112/bayesmokken-scalability-replication --public \
  --description 'Replication package for "A Calibrated Bayesian Bootstrap Confidence Interval for Mokken'"'"'s Scale-Level Scalability Coefficient" JoonHo Lee (2026)'

gh repo create joonho112/bayesmokken-clustered-polytomous-replication --public \
  --description 'Replication package for "Cluster-Aware Uncertainty for Polytomous Mokken Scalability: A Calibrated Hierarchical Bayesian Bootstrap" JoonHo Lee (2026)'
```

The names are not free choices — **both manuscripts now print them**, at three
sites each. If you rename a repository, the manuscripts must change with it.

Suggested topics: `reproducibility`, `replication-package`,
`mokken-scale-analysis`, `bayesian-bootstrap`, `psychometrics`.

## 2. Initialise and commit

From each package root:

```bash
git init -b main
git config user.name  "joonho112"          # repo-local, so a global change cannot
git config user.email "jlee296@ua.edu"     # silently reattribute the commit
git remote add origin https://github.com/joonho112/<repo-name>.git

# If the repository was created on the web it already has an "Initial commit"
# holding a stub README. Build on it rather than force-pushing over it:
git fetch origin main
git reset origin/main        # HEAD moves to that commit; the working tree is untouched

git add -A
git commit -m "Replication package v1.0.0"
git push -u origin main
```

Check the identity actually recorded, before pushing:

```bash
git log -1 --format='%an <%ae> / %cn <%ce>'
```

Before committing, check what `git add -A` will take:

```bash
git status --short | head -40
du -sh .
```

Expect exactly **405** and **412** files — the same counts as each package's
`provenance/release-files.csv`, which is the check worth making before you
commit. `.gitignore` already excludes the Quarto cache,
`.Rhistory`, `.DS_Store` and the verification scratch directories.

::: note
`docs/_book/` **is** committed — it is the rendered guide that GitHub Pages
serves. It is about 4 MB per package.
:::

`.gitattributes` marks `.gz`, `.rds`, `.pdf`, `.png` as binary and `.tex`,
`.csv`, `.tsv` as `-text`. **Do not remove those lines.** A CRLF rewrite would
silently break every byte-parity gate, and the floats are compared with `cmp`.

## 3. GitHub Pages

Quarto writes the site to `docs/_book/`, and Pages can serve only a branch root
or `/docs` — never a nested subdirectory. Pointing it at `main` / `/docs` would
publish the `.qmd` sources instead of the site.

So the built site goes to its own **`gh-pages`** branch. That leaves `main`
exactly as verified: no re-render, no `output-dir` change, no file moved, and
`release-files.csv` still describes `main` exactly.

```bash
TMP=$(mktemp -d)/ghp
git worktree add -q --detach "$TMP"
cd "$TMP"
git checkout -q --orphan gh-pages
git rm -rq --cached .
find . -mindepth 1 -maxdepth 1 -not -name '.git' -exec rm -rf {} +
cp -a <package-root>/docs/_book/. .
touch .nojekyll                 # without it Jekyll drops any _-prefixed path
git add -A
git commit -m "Publish the replication guide"
git push -u origin gh-pages
cd - && git worktree remove --force "$TMP"
```

Pushing a `gh-pages` branch enables Pages automatically. Confirm the source:

```bash
gh api repos/joonho112/<repo-name>/pages --jq '.html_url, .status, .source'
```

The published URLs are already declared in `config.yml` and linked from both
READMEs:

- <https://joonho112.github.io/bayesmokken-scalability-replication/>
- <https://joonho112.github.io/bayesmokken-clustered-polytomous-replication/>

::: note
To update the site later, re-render `docs/` on `main` and repeat the block
above. The orphan checkout replaces the branch contents wholesale, so a deleted
page never lingers.
:::

## 4. Verify after pushing

```bash
# both URLs the manuscripts print must resolve
curl -sSI https://github.com/joonho112/bayesmokken-scalability-replication          | head -1
curl -sSI https://github.com/joonho112/bayesmokken-clustered-polytomous-replication | head -1
curl -sSI https://github.com/joonho112/bayesmokken                                  | head -1

# and the guides
curl -sSI https://joonho112.github.io/bayesmokken-scalability-replication/          | head -1
```

Then, once each site is live, re-run the guide link check against the deployed
pages if you want the external links verified too — the shipped checker
deliberately does not fetch them, so that the gate never depends on the network.

## 5. arXiv posting

The blocker recorded in both manuscript READMEs — *"push
`joonho112/bayesmokken-replication` public"* — is now resolved differently from
how it was written: **two repositories, and the manuscripts name them.** Update
those checklists when you post.

Remaining per-paper items, unchanged from the manuscript READMEs:

| Item | Paper A | Paper B |
|---|---|---|
| replication archive live | after step 1–2 | after step 1–2 |
| funding sentence still true on the day | confirm | confirm |
| primary category | `stat.ME`, cross-list `stat.AP` | same |
| abstract as plain text in the arXiv form | yes | yes |
| generative-AI declaration | decide; this build omits it | decide |
| **cite the companion by arXiv id** | — | **Paper B names the companion article three times without a citation.** If Paper A is posted first, cite its identifier. |

After posting, fill in `arxiv_id` in each package's `config.yml` and replace the
`TODO(author)` line in each README and `CITATION.cff`.

## 6. If you change anything before pushing

Re-run the gate that owns it, then the rehearsal:

```bash
bash verification/cold_start_rehearsal.sh
```

And if you touched a manuscript:

```bash
cd <manuscript dir> && make && make check
```

Both must stay at 55 and 49 pages.

---

## What was deliberately not done

- **No repository was created and nothing was pushed.** D-9.
- **No arXiv submission.**
- **No `bayesmokken` package changes.** It is public at 0.9.0 and pinned, not
  vendored.
- **Paper B's `manuscript-clustered-v3-arXiv`** — the directory exists but is
  empty; v2 is canonical for this work.

## Where the record is

`log/log-replication-packages/` holds the master plan and thirteen phase logs.
The findings worth knowing before you touch anything are S-11 (the
data-generating source code was initially missing), S-19 (what severance should
mean), S-22 (a banner claim that was not checkable as first written), and S-23
(a gate that took 226 seconds on one file).
