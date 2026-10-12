# Head in the Claudes

A generalised library of skills and workflows I use with Claude to develop software better and faster.

Each top-level folder is a **domain**, packaged as a Claude Code plugin. Each domain holds one or more **skills**.

## Domains and skills

| Domain | Skill | What it does |
| --- | --- | --- |
| [system-design](system-design/) | [system-design-specialist](system-design/skills/system-design-specialist/) | Name a technology and get a candid assessment: advantages, limitations, tradeoffs, and a 1–5 rating per dimension. |
| [devsecops](devsecops/) | [repo-devsecops](devsecops/skills/repo-devsecops/) | Pick a security level from 1 to 5 and get an npm repo on GitHub hardened in a single pull request: Dependabot, secret scanning, dependency review, install-script allowlists, Socket, trusted publishing and more. |
| [product](product/) | [idea-proposal](product/skills/idea-proposal/) | A fun little skill i used in personal projects. Run `/idea-proposal <idea>` and get an HTML proposal deck built from your repo and a short plain-language interview: features, benefits, tradeoffs, sample code changes, infrastructure options and a blunt verdict. |

## Install

### As a Claude Code plugin

```
/plugin marketplace add alexgrossidev/HeadInTheClaudes
/plugin install system-design@head-in-the-claudes
/plugin install devsecops@head-in-the-claudes
/plugin install product@head-in-the-claudes
```

### As local skills (for hacking on them)

Clone the repo and symlink every skill into `~/.claude/skills`:

```sh
git clone https://github.com/alexgrossidev/HeadInTheClaudes.git
cd HeadInTheClaudes
link-local.sh                     # symlinks every skill into ~/.claude/skills
```

Edits in the repo are live straight away. Re-run the script after adding a skill. If a skill with the same name already exists in `~/.claude/skills` as a real folder, the script skips it; pass `--force` to replace it.

### In claude.ai

Zip a skill folder (for example `system-design/skills/system-design-specialist/`) and upload it under Settings → Capabilities → Skills.

## Layout

```
.claude-plugin/marketplace.json   # lists each domain as a plugin
<domain>/
  .claude-plugin/plugin.json
  skills/<skill>/
    SKILL.md                      # what Claude reads
    README.md                     # user guide
    examples/                     # real prompt → real output
link-local.sh                     # symlinks every skill into ~/.claude/skills
```

To add a skill, create `<domain>/skills/<skill-name>/SKILL.md` with `name: <skill-name>` in its frontmatter. To add a domain, also add a `.claude-plugin/plugin.json` and list the domain in `.claude-plugin/marketplace.json`.

## License

[MIT](LICENSE)
