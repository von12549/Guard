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

## Host environment safety

- Treat User, Machine and Process `PATH`, all persistent User/Machine environment variables, registry
  environment keys, and all PowerShell profile files as immutable host-owned state.
- Never persist a process environment, run `setx`, call `SetEnvironmentVariable` for User or Machine,
  write registry environment keys, or create/edit a PowerShell profile as part of Guard development,
  tests, installation, launch or cleanup.
- Every child process that receives an isolated `DOTNET_CLI_HOME` must also receive
  `DOTNET_ADD_GLOBAL_TOOLS_TO_PATH=0` in that same child-process environment.
- Environment-safety evidence must contain only hashes, existence flags and equality results. Never
  print or store PATH contents.
- If any captured environment or PowerShell profile value drifts, stop immediately, preserve only
  non-secret hash/equality evidence, report `BLOCKED — HOST SAFETY INCIDENT`, and do not auto-repair.
