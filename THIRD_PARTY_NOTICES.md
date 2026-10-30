# Third-party notices

marketharness is an original work licensed under MIT (see `LICENSE`). This
file credits the external components it builds on.

## OpenCode

marketharness is a distribution **for** OpenCode — it makes zero source
changes to OpenCode. At install time it fetches the pinned npm package
**`opencode-ai@1.19.3`** (OpenCode CLI, MIT license) into its own isolated
npm prefix (`~/.local/share/marketharness/opencode`); the package is not
redistributed in this repository, and no OpenCode code is modified, bundled,
or rebranded at the source level. Identity (name, theme, logo, agents,
commands) is delivered entirely by configuration rendered from `profile/`.

- Project: https://opencode.ai — https://github.com/sst/opencode
- License: MIT (as declared by the `opencode-ai` package)
- Pinned version: `1.19.3` (capabilities of this distribution are verified
  against this tag only; see `docs/SPEC.md` §1)

OpenCode is a separate project with its own license and maintainers. Your
existing OpenCode installation (config, data, credentials, sessions, binary)
is never read or written by marketharness.

## Qloo (optional external runtime: `@qloo/qloo-harness`)

The rendered config may register an `mcp.qloo` entry that runs the external
**`qloo` CLI** (`qloo mcp` — the canonical stdio server of the official Qloo
Hackathon Kit). marketharness neither bundles nor installs it: it is an
optional runtime you install yourself with
`npm install --global @qloo/qloo-harness` (Node >= 22.19).

- Package: `@qloo/qloo-harness` — https://www.npmjs.com/package/@qloo/qloo-harness
- Source: https://github.com/qloo/agentic-qloo (package under `apps/qloo-harness`)
- Kit docs: https://github.com/qloo/qloo-hackathon-kit
- License: MIT (as declared by the package)

No code from the harness or the kit is copied into this repository. The entry
is wired into the render **only** when the CLI resolves on `PATH` **and** a
credential exists — the harness's own private configuration
(`qloo setup --qloo`) or `QLOO_API_KEY` in the environment of the process that
starts `qloo mcp`. The key is never written to a config file, a workspace
file, or a repository (the installer fails if a credential-looking string
appears in the staged config). Without the CLI or a credential the entry is
removed from the config entirely, and the agents state explicitly that no
Qloo research was performed.

The separate `mcp.qloo-docs` entry points at the credential-free Qloo
documentation server `https://docs.qloo.com/mcp` — reference only, no
credential, `execute-request` denied by the profile config. The Qloo API, that
service, and Qloo's results are third-party components with their own terms,
quota, and licensing.

## Social platforms

The shipped connector (`connectors/mock-social/`) is a local mock: it touches
no external platform, ships no platform SDK, and stores no credentials.
A future real connector (LinkedIn organization posts are the documented
reference in `docs/SPEC.md`) plugs into the same contract and must respect
the target platform's terms of service, API policies, and branding rules;
platform names mentioned in docs belong to their respective owners.
