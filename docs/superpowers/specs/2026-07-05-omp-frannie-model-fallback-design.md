# OMP Model & Fallback Configuration for Frannie

**Date:** 2026-07-05
**Host:** frannie (darwin/aarch64, scotttrinh)
**Module:** `modules/home/omp/default.nix` → `configurations/darwin/frannie.nix`

## Goal

Configure OMP on frannie with agent-specific model selections and provider-diverse
fallback chains. The primary workflow is a superpowers flow (brainstorm → spec →
plan → implement with parallel subagents), with occasional lighter native OMP
plan-mode loops.

## Providers

Four providers, each with distinct cost/capability profiles:

| Provider | Primary Use | Credential |
|----------|-------------|------------|
| OpenAI (`openai`) | Heavy work: default, plan, reviewer | API key / OAuth |
| Anthropic (`anthropic`) | Deep reasoning: slow, fallback peer | API key / OAuth |
| z.ai (`zai-coding-plan`) | Parallel subagents: task, explore, sonic, librarian | `codex_zai_coding_plan_api_key` (sops) |
| Google (`google`) | Multimodal + utility: designer, vision, smol, commit, tiny | `GEMINI_API_KEY` |

## Model Role Assignments

Each OMP role is pinned to a specific provider/model:

| Role | Model | Provider | Rationale |
|------|-------|----------|-----------|
| `default` | `gpt-5.5-codex` | OpenAI | Top-tier coding model, codex-optimized, strong agentic tool use |
| `plan` | `gpt-5.5-codex` | OpenAI | Same as default — consistent planning without model-switch friction |
| `slow` | `claude-opus` | Anthropic | Best deep reasoning; complementary to GPT-5.5-Codex for hard debugging |
| `task` | `glm-5.2` | z.ai | Cheap parallel fan-out; main session supervises quality |
| `designer` | `gemini-3.5-pro` | Google | Strong multimodal for UI/UX work |
| `vision` | `gemini-3.5-pro` | Google | Best image understanding for screenshots/diagrams |
| `commit` | `gemini-3.5-flash` | Google | Fast, cheap commit messages |
| `smol` | `gemini-3.5-flash` | Google | Lightweight tasks, quick lookups |
| `tiny` | `gemini-3.5-flash` | Google | Background: session titles, memory, auto-thinking classification |

### Per-Agent Model Overrides

Subagents that deviate from the default `task` role:

| Agent | Model | Rationale |
|-------|-------|-----------|
| `reviewer` | `gpt-5.5-codex` (OpenAI) | Quality-critical code review needs strong reasoning |
| `explore` | `glm-5.2` (z.ai) | Read-only scout — cheap is fine |
| `sonic` | `glm-5.2` (z.ai) | Mechanical updates — cheap is fine |
| `librarian` | `glm-5.2` (z.ai) | Library research — cheap is fine |

All other agents (Tester, task, plan, designer) inherit their role default or
agent frontmatter model.

## Retry Fallback Chains

Strategy: **quality-preserved resilience**. Each primary model falls to the
closest-capability model on a different provider. Provider diversity ensures a
single outage doesn't take down any role.

```yaml
retry:
  enabled: true
  modelFallback: true
  fallbackChains:
    "openai/gpt-5.5-codex":
      - "anthropic/claude-opus"
      - "google/gemini-3.5-pro"
    "anthropic/claude-opus":
      - "openai/gpt-5.5-codex"
      - "google/gemini-3.5-pro"
    "zai-coding-plan/glm-5.2":
      - "openai/gpt-5.5-codex"
      - "anthropic/claude-sonnet"
    "google/gemini-3.5-pro":
      - "anthropic/claude-sonnet"
      - "openai/gpt-5.5-codex"
    "google/gemini-3.5-flash":
      - "zai-coding-plan/glm-5.2"
      - "openai/gpt-5.4"
  # Leave fallbackRevertPolicy unset → runtime default (cooldown-expiry)
```

### Chain rationale

- **GPT-5.5-Codex ↔ Claude Opus:** Two top-tier models back each other up.
  Gemini Pro is the third diverse provider.
- **GLM-5.2:** Steps up to GPT-5.5-Codex (stronger, different provider), then
  Claude Sonnet (second diverse provider).
- **Gemini Pro:** Falls to Claude Sonnet (strong multimodal peer), then OpenAI.
- **Gemini Flash:** Falls to GLM-5.2 (cheap peer, different provider), then
  GPT-5.4 (reliable fallback).

### Revert policy

Leave `fallbackRevertPolicy` unset (null) → runtime applies `cooldown-expiry`,
which reverts to the primary model once its rate-limit cooldown expires. This
avoids thrashing (every-turn reversion) and wasteful persistence (session-wide
fallback).

## Context Promotion

**Disabled.** Rely on auto-compaction for context-window overflow rather than
cross-provider model switching. Avoids mid-session quality shifts and the
complexity of defining promotion targets across heterogeneous providers.

## Nix Configuration Structure

The configuration will be added to `configurations/darwin/frannie.nix` under the
`home-manager.users.scotttrinh` block, using the `omp` module options:

```
omp = {
  enable = true;

  # Model roles
  defaultModel = "openai/gpt-5.5-codex";
  planModel    = "openai/gpt-5.5-codex";
  slowModel    = "anthropic/claude-opus";   # exact canonical ID TBD
  taskModel    = "zai-coding-plan/glm-5.2";
  designerModel = "google/gemini-3.5-pro";  # exact ID TBD
  visionModel  = "google/gemini-3.5-pro";
  commitModel  = "google/gemini-3.5-flash";
  smolModel    = "google/gemini-3.5-flash";

  # tiny role (not top-level option — via settings)
  settings.modelRoles.tiny = "google/gemini-3.5-flash";

  # Retry fallback chains
  model = {
    modelFallback = true;
    fallbackChains = { ... };  # as specified above
  };

  # Context promotion disabled
  context.promotionEnabled = false;

  # Per-agent overrides
  tasks.agentModelOverrides = {
    reviewer = "openai/gpt-5.5-codex";
    explore  = "zai-coding-plan/glm-5.2";
    sonic    = "zai-coding-plan/glm-5.2";
    librarian = "zai-coding-plan/glm-5.2";
  };

  # Provider credentials (wired from sops secrets)
  modelProviders = { ... };
};
```

## Open Items

1. **Exact model IDs:** Confirm canonical model identifiers for Claude Opus,
   Claude Sonnet, Gemini Pro, and Gemini Flash against the omp bundled catalog
   (`omp models` output). The spec uses family names; implementation must use
   exact `provider/modelId` selectors.
2. **Provider credentials:** Add `GEMINI_API_KEY` to sops secrets. Confirm
   OpenAI and Anthropic keys are available to omp (not just to claudeCode/codex).
   z.ai key is already wired.
3. **OMP package:** Confirm the `omp` package derivation exists or needs to be
   added to `packages/`.
