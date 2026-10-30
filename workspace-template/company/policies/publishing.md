# Publishing policy — {{company}}

Starter rules. These are enforced by the connector confirm flow and the
`delete` deny permission; agent prompts restate them but the config is the
enforcement.

1. **Approval is mandatory.** No post or reply is published without explicit
   user confirmation that binds account + project + full text + attachments +
   target comment. The confirmation is the connector's confirm token, valid
   only for the exact payload it was issued for.
2. **Any change = new approval.** One word, one attachment, a different target
   comment — anything changed after approval invalidates the confirm token.
   Re-prepare and re-confirm.
3. **Deleting content is forbidden.** The `delete` permission is `deny` in the
   profile config; never attempt it through any connector.
4. **Only `marketagents-publish` executes.** All other commands and skills
   stop at drafts. `prepare` elsewhere is allowed; `execute` is not.
5. **No blind retries.** On an uncertain outcome, check `status <action_id>`
   first. The action log deduplicates on `action_id`.
6. **Approved claims only.** Published text contains only claims from
   `knowledge/approved-claims.md` or explicitly cited sources.
7. **Credentials never in the workspace.** Accounts carry an `auth_ref`
   pointing at connector-private storage — never tokens or passwords in YAML.
