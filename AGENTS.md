# Repository agent instructions

## AI attribution

- Every commit created with AI assistance must end with a `Co-Authored-By` trailer. Leave one blank
  line between the commit body and the trailer, and identify the tool or model that actually produced
  the change.
- For Codex-authored work, use:

  `Co-Authored-By: Codex <codex@openai.com>`

- For Claude Opus 5.5-authored work, use:

  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

- Do not attribute work to an AI tool that was not used. If multiple tools materially contributed,
  add one trailer for each contributor.
- Every pull request created or updated with AI assistance must end its description with a
  `Generated with` footer that identifies the tool actually used. Leave one blank line before the
  footer.
- For Codex-generated pull requests, use:

  `Generated with [Codex](https://openai.com/codex/)`

- For Claude Code-generated pull requests, use:

  `Generated with [Claude Code](https://claude.com/claude-code)`
