---
name: fix-pr-comments
description: Evaluate and fix unresolved review comments for a PR
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(jq *), Bash(cat *), Read, Edit, Write
---

## What this skill does

Fetch the unresolved review threads on the current PR (or one the user names) and, for each, verify against the actual code whether the reviewer's claim is accurate, what change is being requested, and whether it's worth making — surfacing cases where the PR author already pushed back, the comment is on stale code, or the reviewer is wrong.

Present that assessment so the user can pick which to address. Then make only the minimal change each chosen comment asks for, one at a time, without resolving threads or committing.

The goal is to shift verification cost off the user: they review your recommendations and the resulting diff, not the reviewer comments themselves.

## Workflow

### 1. Identify the PR

If the user supplied `owner/repo#N`, pass `--repo owner/repo` to every `gh` command.

Otherwise detect the PR for the current branch:

```bash
gh pr view --json number,url,headRefName,baseRefName,author
```

Capture `author.login` — you'll use it for pushback detection in step 3.

If no PR exists for the current branch, stop and tell the user.

**Cross-repo PRs:** if the PR's repo doesn't match the current working directory, check `~/Documents/projects/` for a clone on the PR's branch and work from there. If no local checkout exists, tell the user where to clone or which directory to switch to — do not try to verify comments against the wrong repo.

### 2. Fetch unresolved threads

Write this query to `$TMPDIR/pr_query.graphql` using the Write tool (bash heredocs mangle `!` in GraphQL type markers):

```graphql
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          isOutdated
          comments(first: 20) {
            nodes {
              author { login }
              body
              path
              line
              startLine
              originalLine
              diffHunk
            }
          }
        }
      }
    }
  }
}
```

Execute and filter to unresolved in one pipeline:

```bash
gh api graphql \
  -F owner='{owner}' \
  -F repo='{repo}' \
  -F pr={number} \
  -f query="$(cat $TMPDIR/pr_query.graphql)" \
  2>/dev/null | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]' > $TMPDIR/pr-{number}-unresolved.json
```

If there are no unresolved threads, report that and stop.

### 3. Verify each thread against the code

Apply the `epistemic-classification` skill to this step — every claim in the assessment must be labeled Verified, Inferred, or Guess. The user is going to skim; labels are what make spot-checking cheap.

For every unresolved thread, determine:

- **Interpretation.** One sentence: what change is being requested? If the comment is a question with no implied change, say so.
- **Accuracy.** Read the cited file at the cited lines. Does the code actually do what the reviewer claims? Cite `file:line`.
- **Staleness.** If `isOutdated: true`, or `line` is null while `originalLine` is set, the diff has moved past the cited location. Flag it — the code under discussion may no longer exist.
- **Author pushback.** Scan the thread for replies by the PR author (the login captured in step 1). If they've rejected, deferred, or explained away the suggestion, flag it and recommend skipping.
- **Suggestion blocks.** If the comment contains a ` ```suggestion ` block, note it — the requested change is literally that block's contents.
- **Worth.** Given all of the above, is the change worth making? A reviewer being technically right about a non-issue is not worth a change.

### 4. Present the assessment

```
## Unresolved comments (N total)

1. **file.ts:42** — @reviewer: "quoted or summarized comment"
   - Interpretation: [one sentence]
   - Accuracy: [V|I|G] [finding, citing file:line]
   - Flags: [stale | author-pushback | reviewer-wrong | suggestion-block | none]
   - Recommendation: [apply | skip] — [one-sentence reason]

2. ...

## Not checked
- [anything you couldn't verify, and why]
```

Then wait. The user picks which to apply (all / specific numbers / none).

### 5. Apply chosen changes

For each comment the user picks:

1. Read the file at the relevant lines.
2. State the change in one line.
3. Make it with Edit.
4. Pause before the next, unless the user said batch them.

**Rules:**
- Only change what the comment specifically asks for. No adjacent refactors, no docstrings, no "while I'm here" improvements.
- For comments containing a ` ```suggestion ` block, apply that block verbatim unless you have a verified reason not to.
- If a comment is unclear or requires a design call you can't make, skip it and say why.
- Do not resolve or dismiss review threads — that's the reviewer's confirmation step after they verify your changes.
- Do not commit or push. The user reviews the diff and decides next steps.

## Gotchas

- **Always use `gh`, never WebFetch for GitHub URLs.** Enterprise GitHub blocks unauthenticated requests; `gh` is always authenticated.
- **GraphQL escaping:** inline queries with `-F query=...` mangle `!` in type markers (`Int!`, `String!`). Write the query to a file with the Write tool and pass it via `-f query="$(cat ...)"`.
- **Filter inline:** pipe through `jq` in the same command — don't write the full GraphQL response to disk. Threads with long histories balloon fast.
- **PR-scope temp filenames:** use `pr-{number}-unresolved.json` so concurrent runs against different PRs don't clobber each other.
