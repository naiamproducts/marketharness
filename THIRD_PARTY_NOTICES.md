# Third-party notices

marketagents is an original work licensed under MIT (see `LICENSE`). This
file credits the external components it builds on.

## OpenCode

marketagents is a distribution **for** OpenCode — it makes zero source
changes to OpenCode. At install time it fetches the pinned npm package
**`opencode-ai@1.19.3`** (OpenCode CLI, MIT license) into its own isolated
npm prefix (`~/.local/share/marketagents/opencode`); the package is not
redistributed in this repository, and no OpenCode code is modified, bundled,
or rebranded at the source level. Identity (name, theme, logo, agents,
commands) is delivered entirely by configuration rendered from `profile/`.

- Project: https://opencode.ai — https://github.com/sst/opencode
- License: MIT (as declared by the `opencode-ai` package)
- Pinned version: `1.19.3` (capabilities of this distribution are verified
  against this tag only; see `docs/SPEC.md` §1)

OpenCode is a separate project with its own license and maintainers. Your
existing OpenCode installation (config, data, credentials, sessions, binary)
is never read or written by marketagents.

## Qloo (optional MCP server)

The rendered config may register an `mcp.qloo` entry that runs the external
**`qloo` CLI** (`qloo mcp`) with `QLOO_API_KEY` from the environment. The
qloo CLI and the Qloo API are third-party components with their own terms,
licensing, and credentials; marketagents does not bundle them. The entry is
wired into the render **only** when both the credential and the CLI are
present — otherwise it is removed from the config entirely, and the agents
state explicitly that no Qloo research was performed.

## Social platforms

The shipped connector (`connectors/mock-social/`) is a local mock: it touches
no external platform, ships no platform SDK, and stores no credentials.
A future real connector (LinkedIn organization posts are the documented
reference in `docs/SPEC.md`) plugs into the same contract and must respect
the target platform's terms of service, API policies, and branding rules;
platform names mentioned in docs belong to their respective owners.
