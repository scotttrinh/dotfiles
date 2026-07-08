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

### Model catalog

| Slug | Family tier | Notes |
|------|-------------|-------|
| `gpt-5.5` | OpenAI GPT pro | No `-codex` suffix; the current SOTA OpenAI model |
| `claude-opus-4.8` | Anthropic Opus | Current SOTA Claude model |
| `claude-sonnet-5` | Anthropic Sonnet | Mid-tier Claude |
| `claude-haiku-4.5` | Anthropic Haiku | Budget Claude |
| `glm-5.2` | Z.ai GLM | Current SOTA GLM model (coding plan) |
| `gemini-3.5-flash` | Gemini SOTA | The current pro-equivalent in the Gemini family; no separate Pro model exists |
| `gemini-3.1-flash-lite` | Gemini budget | Cheaper tier Gemini model |

## Model Role Assignments

Each OMP role is pinned to a specific provider/model:

| Role | Model | Provider | Rationale |
|------|-------|----------|-----------|
| `default` | `openai/gpt-5.5` | OpenAI | SOTA coding model, strong agentic tool use |
| `plan` | `openai/gpt-5.5` | OpenAI | Same as default — consistent planning without model-switch friction |
| `slow` | `anthropic/claude-opus-4.8` | Anthropic | Best deep reasoning; complementary to GPT-5.5 for hard debugging |
| `task` | `zai-coding-plan/glm-5.2` | z.ai | Cheap parallel fan-out; main session supervises quality |
| `designer` | `google/gemini-3.5-flash` | Google | SOTA Gemini — strong multimodal for UI/UX work |
| `vision` | `google/gemini-3.5-flash` | Google | SOTA Gemini — best image understanding for screenshots/diagrams |
| `commit` | `google/gemini-3.1-flash-lite` | Google | Budget tier — fast, cheap commit messages |
| `smol` | `google/gemini-3.1-flash-lite` | Google | Budget tier — lightweight tasks, quick lookups |
| `tiny` | `google/gemini-3.1-flash-lite` | Google | Budget tier — background: session titles, memory, classification |

### Per-Agent Model Overrides

Subagents that deviate from the default `task` role:

| Agent | Model | Rationale |
|-------|-------|-----------|
| `reviewer` | `openai/gpt-5.5` | Quality-critical code review needs SOTA reasoning |
| `explore` | `zai-coding-plan/glm-5.2` | Read-only scout — cheap is fine |
| `sonic` | `zai-coding-plan/glm-5.2` | Mechanical updates — cheap is fine |
| `librarian` | `zai-coding-plan/glm-5.2` | Library research — cheap is fine |

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
    "openai/gpt-5.5":
      - "anthropic/claude-opus-4.8"
      - "google/gemini-3.5-flash"
    "anthropic/claude-opus-4.8":
      - "openai/gpt-5.5"
      - "google/gemini-3.5-flash"
    "zai-coding-plan/glm-5.2":
      - "openai/gpt-5.5"
      - "anthropic/claude-sonnet-5"
    "google/gemini-3.5-flash":
      - "anthropic/claude-sonnet-5"
      - "openai/gpt-5.5"
    "google/gemini-3.1-flash-lite":
      - "zai-coding-plan/glm-5.2"
      - "anthropic/claude-haiku-4.5"
  # Leave fallbackRevertPolicy unset → runtime default (cooldown-expiry)
```

### Chain rationale

- **GPT-5.5 ↔ Claude Opus 4.8:** Two SOTA models back each other up.
  Gemini 3.5 Flash (Gemini SOTA) is the third diverse provider.
- **GLM-5.2:** Steps up to GPT-5.5 (stronger, different provider), then
  Claude Sonnet 5 (second diverse provider).
- **Gemini 3.5 Flash:** Falls to Claude Sonnet 5 (strong multimodal peer), then
  GPT-5.5.
- **Gemini 3.1 Flash Lite:** Falls to GLM-5.2 (cheap peer, different provider),
  then Claude Haiku 4.5 (budget-tier Anthropic).

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

```nix
omp = {
  enable = true;

  # Model roles
  defaultModel  = "openai/gpt-5.5";
  planModel     = "openai/gpt-5.5";
  slowModel     = "anthropic/claude-opus-4.8";
  taskModel     = "zai-coding-plan/glm-5.2";
  designerModel = "google/gemini-3.5-flash";
  visionModel   = "google/gemini-3.5-flash";
  commitModel   = "google/gemini-3.1-flash-lite";
  smolModel     = "google/gemini-3.1-flash-lite";

  # tiny role (not a top-level option — via raw settings)
  settings.modelRoles.tiny = "google/gemini-3.1-flash-lite";

  # Retry fallback chains (quality-preserved resilience)
  model = {
    modelFallback = true;
    fallbackChains = {
      "openai/gpt-5.5"             = [ "anthropic/claude-opus-4.8" "google/gemini-3.5-flash" ];
      "anthropic/claude-opus-4.8"  = [ "openai/gpt-5.5" "google/gemini-3.5-flash" ];
      "zai-coding-plan/glm-5.2"   = [ "openai/gpt-5.5" "anthropic/claude-sonnet-5" ];
      "google/gemini-3.5-flash"    = [ "anthropic/claude-sonnet-5" "openai/gpt-5.5" ];
      "google/gemini-3.1-flash-lite" = [ "zai-coding-plan/glm-5.2" "anthropic/claude-haiku-4.5" ];
    };
  };

  # Context promotion disabled
  context.promotionEnabled = false;

  # Per-agent overrides
  tasks.agentModelOverrides = {
    reviewer  = "openai/gpt-5.5";
    explore   = "zai-coding-plan/glm-5.2";
    sonic     = "zai-coding-plan/glm-5.2";
    librarian = "zai-coding-plan/glm-5.2";
  };

  # Provider credentials (wired from sops secrets)
  modelProviders = { ... };
};
```

## Open Items

1. **Provider IDs:** Confirm exact provider IDs in the omp catalog for each model
   (e.g., is GPT-5.5 under `openai` or `openai-codex`?). Verify with `omp models`
   before finalizing selectors.
2. **Provider credentials:** Add `GEMINI_API_KEY` to sops secrets. Confirm
   OpenAI and Anthropic keys are available to omp (not just to claudeCode/codex).
   z.ai key is already wired.
3. **OMP package:** Confirm the `omp` package derivation exists or needs to be
   added to `packages/`.
