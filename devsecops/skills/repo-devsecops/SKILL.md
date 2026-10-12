---
name: repo-devsecops
description: Harden an npm repository on GitHub to a security level the user picks (1-5) and deliver every change as a single pull request. Use when the user wants to secure a repo, set up DevSecOps, add supply-chain protection, Dependabot, secret scanning, dependency review, Socket, or asks "make this repo safe".
---

# Repo DevSecOps (npm)

Take an npm repository on GitHub from "nothing configured" to a chosen security level in one pass. The user picks a level from 1 to 5. Levels are cumulative, and the user can add or remove any individual control. Every file change ships as **one pull request**. Repository settings, which cannot live in a PR, are applied only after explicit confirmation.

The goal is speed with no surprises. Never change anything the user hasn't seen in the plan.

## Scope and preconditions

- **npm only.** If the repo has `pnpm-lock.yaml`, `yarn.lock` or `bun.lock*` and no `package-lock.json`, stop and say this skill covers npm only.
- **GitHub only.** CI controls target GitHub Actions. If CI lives elsewhere, still apply the `.npmrc`, Dependabot and settings controls, and list the CI controls as manual steps.
- **Requires:** `git`, `gh` authenticated (`gh auth status`), and a clean working tree. If the tree is dirty, stop and ask the user to commit or stash.
- **Never hard-code versions or SHAs from this file.** Resolve the latest release of every action and tool at run time (see "Pinning actions"). The examples below show shape only.

## Step 1: Detect

Gather the facts before talking to the user. Run these in parallel where possible:

```bash
gh repo view --json nameWithOwner,visibility,viewerPermission,isInOrganization,defaultBranchRef
npm -v; node -v
ls package-lock.json .npmrc .github/dependabot.yml .github/workflows/ SECURITY.md CODEOWNERS .github/CODEOWNERS 2>/dev/null
cat .github/devsecops.yml 2>/dev/null   # previous run of this skill
gh api repos/{owner}/{repo} --jq '.security_and_analysis'
```

From `package.json`, check `private`, `publishConfig`, `workspaces` and `engines`. A package counts as **published** if `private` is not true and either a publish workflow exists or the user confirms it.

Record:

- **visibility:** public, or private. If private, check whether GitHub Advanced Security, Secret Protection or Code Security is available. If `security_and_analysis.advanced_security` is missing or disabled, assume it isn't.
- **admin:** `viewerPermission == ADMIN`. Settings controls need admin. Without it, settings become manual steps for the repo owner.
- **npm major version:** this changes how level 3 works (see 3.1 and 3.2).
- **What already exists:** never duplicate a control. Upgrade it or skip it.
- **Previous run:** if `.github/devsecops.yml` exists, this is an upgrade or change. Start from what it records.

## Step 2: Choose the level and the controls

Show the five levels in one short table, with a "pick this if…" line and the friction for each:

| Level | Name | Pick this if… | Friction |
|---|---|---|---|
| 1 | Baseline | Side project, anything public | None |
| 2 | PR gate | More than one contributor, or real users | Low |
| 3 | Supply-chain hardening | Anything in production | Medium: first install may need script approvals |
| 4 | Behavioural and code | A team, or handling customer data | Medium: Socket account, admin rights |
| 5 | Publisher / high assurance | You publish packages others install | High |

After the user picks a level, show the full control list up to that level as a checklist. Every control is pre-selected by default. Mark controls that don't apply as unavailable and give the reason: a private repo without GHAS, no admin rights, or a package that isn't published. Let the user:

- **Deselect** any control.
- **Add** individual controls from higher levels.
- **Change parameters**, such as the release-age days or the severity threshold.

Use the AskUserQuestion tool with multiSelect when it is available. Otherwise, ask in one message. The user's selection is final. Don't argue for a deselected control more than once; one line on the risk is enough.

## Step 3: Show the plan

Before writing anything, show three buckets:

1. **Pull request:** the files to be added or changed, one line each.
2. **Repository settings:** each `gh api` call, in plain words. These run only after a separate "yes".
3. **Manual steps:** anything needing a third-party account, billing or the web UI.

Get one confirmation for the PR, and one for the settings.

## Step 4: Build the PR

```bash
git switch -c security/devsecops-level-<N>
```

- **One commit per control group,** using conventional messages, for example `ci(security): add dependency review gate`. No WIP commits.
- **Write `.github/devsecops.yml`.** It is the manifest that makes re-runs idempotent:

  ```yaml
  # Managed by the repo-devsecops skill. Edit with care.
  level: 3
  applied: [1.1, 1.2, 1.3, 2.1, 2.3, 3.1, 3.2]
  skipped:
    - id: 2.2
      reason: "user deselected"
  params:
    min-release-age-days: 3
    fail-on-severity: high
  ```

- **Verify locally before pushing:**
  - Run `npm ci` with the new `.npmrc`. It must succeed. If install scripts are now blocked, resolve that through 3.1 before continuing.
  - Parse every YAML file you touched.
  - Run `actionlint` and `zizmor` on `.github/workflows/` if either is available (`uvx zizmor .`). Fix any findings in files you added.
- **Push and open the PR** with `gh pr create`. The PR body uses the template at the end of this file.

## Step 5: Apply the settings (after confirmation)

- **Settings that don't depend on the PR:** run them now. These are Dependabot alerts, secret scanning, private vulnerability reporting and the Actions permission defaults.
- **Settings that depend on the PR's checks existing:** list them in the PR body under "After merge" as copy-paste `gh` commands. Offer to run them once the PR is merged. This covers branch rulesets with required status checks.

Confirm each setting by reading it back with `gh api`. Report any setting that failed because of plan or permissions.

## Pinning actions

Every `uses:` the skill adds is pinned to a full commit SHA, with the version as a comment:

```yaml
- uses: actions/checkout@<40-char-sha> # v6.0.0
```

Resolve the SHA at run time:

```bash
TAG=$(gh api repos/actions/checkout/releases/latest --jq .tag_name)
gh api repos/actions/checkout/commits/$TAG --jq .sha
```

Dependabot's `github-actions` ecosystem (control 1.4) keeps these pins up to date. For reusable workflows such as OSV-Scanner's, pin the `@ref` the same way.

---

## Control catalogue

Each control lists its ID, what it does, how to apply it, and whether it is a **PR** change, a **Setting** or a **Manual** step. Requirements are noted where they apply.

### Level 1: Baseline

**1.1 Dependabot alerts and security updates** (Setting)

```bash
gh api -X PUT repos/{o}/{r}/vulnerability-alerts
gh api -X PUT repos/{o}/{r}/automated-security-fixes
```

**1.2 Secret scanning and push protection** (Setting)

```bash
gh api -X PATCH repos/{o}/{r} \
  -F 'security_and_analysis[secret_scanning][status]=enabled' \
  -F 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

Free on public repos. On private repos it needs GitHub Secret Protection; if that isn't available, fall back to 1.6.

**1.3 Lockfile discipline** (PR)

- `package-lock.json` is committed.
- Every CI install uses `npm ci`, never `npm install`. Rewrite existing workflow steps.

**1.4 Dependabot config** (PR): `.github/dependabot.yml`

```yaml
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule: { interval: weekly }
    groups:
      minor-and-patch: { update-types: [minor, patch] }
  - package-ecosystem: github-actions
    directory: /
    schedule: { interval: weekly }
```

Level 3 adds a `cooldown` block to this file (see 3.3).

**1.5 Security policy** (PR + Setting)

- Add `SECURITY.md` explaining how to report a vulnerability privately.
- For public repos, enable private vulnerability reporting: `gh api -X PUT repos/{o}/{r}/private-vulnerability-reporting`.

**1.6 Secret hygiene check** (PR + one-off scan)

- Make sure `.gitignore` covers `.env*` (except `.env.example`), `*.pem` and `*.key`.
- Run `gitleaks git .` (or `npx` or `docker` if it isn't installed) once over the history.
- **Report findings to the user only.** Never write found secrets into the PR, the commits or the chat. Tell them to rotate every finding, because removing it from history does not undo the leak.

**1.7 npm audit fallback** (PR)

Only when 2.1 is unavailable (a private repo without GHAS). Add a CI job that runs `npm audit --audit-level=high --omit=dev`.

### Level 2: PR gate

**2.1 Dependency review** (PR): `actions/dependency-review-action` on `pull_request`

- `fail-on-severity: high` (user parameter).
- `comment-summary-in-pr: on-failure`. This needs `pull-requests: write` on the job.
- Optional: `allow-licenses` with the user's licence list.

Public repos get this free; private repos need GHAS.

**2.2 OSV-Scanner** (PR)

Two workflows, using Google's reusable workflows from `google/osv-scanner-action`:

- `osv-scanner-reusable-pr.yml` on `pull_request`.
- `osv-scanner-reusable.yml` on a weekly `schedule` and on push to the default branch. New advisories hit unchanged code, so the scheduled scan matters.

Job permissions: `actions: read`, `contents: read`, `security-events: write`. If code scanning isn't available (a private repo without GHAS), set `upload-sarif: false` and rely on `fail-on-vuln`.

**2.3 Pin all actions to SHAs** (PR)

Rewrite every existing `uses:` in the repo to a SHA with a version comment (see "Pinning actions").

**2.4 Least-privilege tokens** (PR + Setting)

- **In every workflow:** set `permissions: {}` (or `contents: read`) at the top level, and grant extra permissions per job only.
- **On every `actions/checkout`:** set `persist-credentials: false`.
- **Repo default:**

  ```bash
  gh api -X PUT repos/{o}/{r}/actions/permissions/workflow \
    -F default_workflow_permissions=read -F can_approve_pull_request_reviews=false
  ```

**2.5 Registry signature check** (PR)

Add `npm audit signatures` after `npm ci` in CI. It verifies registry signatures and provenance attestations.

### Level 3: Supply-chain hardening

**3.1 Install-script allowlist** (PR)

How to do this depends on the npm version:

- **npm 12 or later:** dependency install scripts are blocked by default unless they are listed in `allowScripts` in `package.json`.
- **npm 11.16 or later:** same mechanism, but it only warns by default. Add `strict-allow-scripts=true` to `.npmrc` to enforce it.
- **Older npm:** set `ignore-scripts=true` in `.npmrc`, then run `npm rebuild <pkg>` in CI for each approved package. Recommend upgrading npm.

Steps:

1. Run `npm approve-scripts --allow-scripts-pending` to list the packages that want install scripts.
2. **Show the list to the user** with one line per package on what its script does. Common legitimate ones are esbuild, sharp, prisma, bcrypt and puppeteer.
3. Approve only what the user approves: `npm approve-scripts <pkg>`. These entries are pinned to the version by default. **Never use `--all`.**
4. Pin the npm version in CI so local and CI behaviour match. Use `devEngines` or `packageManager` in `package.json`, or an explicit `npm i -g npm@<major>` step.

**3.2 Release-age cooldown** (PR): `.npmrc`

```
min-release-age=3
```

- Needs npm 11.10 or later. Older versions ignore the line **silently**, so make sure CI's npm version supports it (3.1, step 4).
- The number of days is a user parameter. The default is 3.
- Use `min-release-age-exclude` for the user's own scopes, for example `@myorg/*`.
- **Security fixes:** a patched version newer than the window is blocked too. Document this in the PR body: for an urgent fix, temporarily add the package to `min-release-age-exclude`.

**3.3 Dependabot cooldown** (PR)

Add to the npm entry in `dependabot.yml`:

```yaml
cooldown:
  default-days: 3
  semver-major-days: 14
```

Cooldown never delays security updates.

**3.4 Block non-registry sources** (PR): `.npmrc`

```
allow-git=none
allow-remote=none
```

This is the default in npm 12, so set it explicitly for npm 11. If the project has git or tarball dependencies, list them and let the user choose: `allow-git=root`, or keep blocking.

**3.5 Lockfile integrity** (PR)

CI step:

```bash
npx lockfile-lint --path package-lock.json --type npm --allowed-hosts npm --validate-https --validate-integrity
```

This stops a lockfile from pointing at an unexpected host.

**3.6 Workflow linting** (PR)

Add a zizmor workflow (`zizmorcore/zizmor-action`) on push and pull_request, with top-level `permissions: {}`.

- **SARIF upload** (public repos or GHAS): the job needs `security-events: write`.
- **Otherwise:** run `uvx zizmor --format=github .` with `contents: read`.

### Level 4: Behavioural and code

**4.1 Socket**

- **GitHub App** (Manual): ask the user to install it from socket.dev on this repo. It reviews PRs for malicious or risky package behaviour (install scripts, network access, obfuscation, typosquats). A free tier exists.
- **Socket Firewall in CI** (PR): add `socketdev/action` with `mode: firewall` before install, and change the install to `sfw npm ci`. The free tier needs no account or API key.

**4.2 Static analysis** (Setting or PR)

Enable CodeQL default setup (free on public repos, GHAS on private ones):

```bash
gh api -X PATCH repos/{o}/{r}/code-scanning/default-setup -f state=configured
```

Without GHAS, offer a Semgrep CE workflow instead (PR).

**4.3 CODEOWNERS** (PR)

Require owner review for `.github/`, `package.json`, `package-lock.json` and `.npmrc`. Ask the user for the owner handle(s).

**4.4 Default-branch ruleset** (Setting, after merge)

- Require a PR to merge.
- Require the status checks this PR added.
- Block force pushes and deletion.
- Require CODEOWNERS review.

**Solo maintainer warning:** GitHub doesn't let you approve your own PR. For a single-person repo, require checks but set required approvals to 0, or the owner will lock themselves out.

**4.5 Restrict allowed actions** (Setting)

Allow only GitHub-owned and verified-creator actions, plus an explicit list of the actions this PR adds. Use `PUT repos/{o}/{r}/actions/permissions` and `.../selected-actions`.

### Level 5: Publisher / high assurance

**5.1 Trusted publishing** (PR + Manual; published packages only)

- **PR:** a release workflow that publishes with OIDC (`permissions: id-token: write`), with provenance generated automatically. Delete any `NPM_TOKEN` secret usage. Put the publish job in a GitHub Environment named `npm-publish` with required reviewers.
- **Manual:** the user adds the trusted publisher on npmjs.com, under the package's settings.
- Check at run time which npm version trusted publishing needs.

**5.2 SBOM** (PR)

On release, run `npm sbom --sbom-format cyclonedx > sbom.json` and attach the file to the GitHub release.

**5.3 OpenSSF Scorecard** (PR; public repos)

Weekly `ossf/scorecard-action` with SARIF upload, plus an optional README badge.

**5.4 Runner egress control** (PR)

Add `step-security/harden-runner` as the first step of every job with `egress-policy: audit`. Tell the user to move to `block` with an `allowed-endpoints` list after a week of baseline data. Don't switch to `block` in this PR.

**5.5 Signed commits** (Setting, after merge)

Add "require signed commits" to the 4.4 ruleset. Warn the user to set up commit signing locally first, or their own pushes will be rejected.

**5.6 Account hardening** (Manual)

- Org-wide 2FA requirement.
- npm account 2FA set to "authorization and publishing".
- Review who has publish rights on npm.

---

## PR body template

~~~markdown
## Security hardening: level <N> (<name>)

Generated by the repo-devsecops skill. The manifest is in `.github/devsecops.yml`.

### Added in this PR
| ID | Control | Files | What changes for you |
|----|---------|-------|----------------------|
| ... | ... | ... | ... |

### Skipped
- <ID>: <control> — <reason>

### Repository settings
- Applied: <list, read back and confirmed>
- After merge (run these once the checks below have passed on main):
  ```bash
  <gh api commands>
  ```

### Manual steps
- [ ] <step, with link>

### Friction to expect
- <for example: new install scripts need `npm approve-scripts <pkg>`; packages newer than 3 days won't install>

### Rollback
Revert this PR. Undo the settings with: <commands>
~~~

## Final report to the user

Keep it short:

- The PR link.
- Which settings were applied.
- Remaining manual steps.
- Any finding the user must act on now, such as leaked secrets from 1.6.