## What changed

Describe the change in 3-6 concise bullets.

## Why

What problem does this solve? What regression or gap does it address?

## Scope

- [ ] Bug fix
- [ ] Feature
- [ ] Refactor
- [ ] Docs
- [ ] Tests
- [ ] Platform-specific change (Linux/Windows)

## Validation

List exactly how this was tested.

### Automated

- [ ] `make test`
- [ ] relevant unit tests added/updated

### Manual

Provide reproducible manual steps and observed result.

## Risk and rollback

- Risk level: Low / Medium / High
- If high or medium, what is the rollback plan?

## ABI/low-level checklist (required for Win64 call-site changes)

- [ ] Stack is 16-byte aligned at every `call`
- [ ] Required shadow space is reserved
- [ ] Non-volatile registers are preserved
- [ ] Call arguments are passed per ABI contract

## Docs and TODO updates

- [ ] Updated relevant docs (`README`, status, roadmap, architecture, or contributing)
- [ ] Added TODO notes for deferred follow-up work

## Related issue

`Closes #...` or `Related #...`
