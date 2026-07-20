# OMP Terra-to-Luna Cutover for Frannie

**Date:** 2026-07-14
**Host:** frannie (darwin/aarch64, scotttrinh)
**Configuration:** `configurations/darwin/frannie.nix`

## Goal

Remove every configured use of GPT-5.6 Terra from OMP on frannie. Replace the
workloads that currently select Terra with GPT-5.6 Luna at explicit `xhigh`
reasoning effort, preserving provider-diverse retry behavior.

## Evidence

Artificial Analysis places GPT-5.6 Sol and Luna ahead of Terra across the
Intelligence-versus-Cost-per-Task frontier. Luna `xhigh` scores about 49 on the
Artificial Analysis Intelligence Index at about $0.15 per task. It matches
Terra `high` intelligence at substantially lower cost and exceeds lower-effort
Terra configurations.

Source: [How GPT-5.6 Sol, Terra, Luna compare on intelligence vs cost](https://artificialanalysis.ai/articles/gpt-5-6-intelligence-vs-cost-across-sol-terra-luna), published 2026-07-13.

The installed OMP 16.5.0 catalog supports `low`, `medium`, `high`, `xhigh`, and
`max` for GPT-5.6 Luna. OMP role values and retry fallback entries accept
`provider/model:effort` selectors. An explicit selector effort takes precedence
over an agent definition's default effort.

## Current Terra Usage

All relevant Terra selectors are in `configurations/darwin/frannie.nix`:

1. the general-purpose `taskModel` role;
2. the `librarian` per-agent model override;
3. a Terra-keyed retry fallback chain;
4. Terra fallback targets for Z.ai GLM-5.2 and Gemini 3.5 Flash.

The unrelated Doom Emacs `terra` module comment is not a model selector and is
out of scope.

## Approved Mapping

| Purpose | Current selector | New selector |
|---------|------------------|--------------|
| General-purpose task subagents | `openai-codex/gpt-5.6-terra` | `openai-codex/gpt-5.6-luna:xhigh` |
| Librarian subagent | `openai-codex/gpt-5.6-terra` | `openai-codex/gpt-5.6-luna:xhigh` |
| Z.ai fallback target | `openai-codex/gpt-5.6-terra` | `openai-codex/gpt-5.6-luna:xhigh` |
| Gemini fallback target | `openai-codex/gpt-5.6-terra` | `openai-codex/gpt-5.6-luna:xhigh` |

The Terra-keyed fallback chain is removed because Terra is no longer a primary
or fallback selector. The existing base Luna fallback chain remains:

```nix
"openai-codex/gpt-5.6-luna" = [
  "zai/glm-5.2"
  "anthropic/claude-haiku-4-5"
];
```

OMP matches model-keyed fallback chains by base selector, so this chain also
covers an active `openai-codex/gpt-5.6-luna:xhigh` role.

## Scope

Only `configurations/darwin/frannie.nix` changes. The OMP Home Manager module
already types model roles and fallback entries as selector strings, so it needs
no schema change. Existing Sol, Luna, Anthropic, Z.ai, and Gemini assignments
outside the former Terra positions remain unchanged.

## Verification

1. Evaluate the frannie Darwin/Home Manager configuration.
2. Inspect the evaluated/generated OMP configuration and confirm:
   - task and librarian resolve to `openai-codex/gpt-5.6-luna:xhigh`;
   - former Terra fallback targets resolve to the same selector;
   - no `gpt-5.6-terra` selector remains.
3. Run OMP against the evaluated configuration in a non-interactive smoke check
   and confirm the selected model reports explicit `xhigh` reasoning.
