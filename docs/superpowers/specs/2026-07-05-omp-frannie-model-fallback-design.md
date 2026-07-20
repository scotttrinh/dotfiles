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

| Provider | ID | Auth | Primary Use |
|----------|----|------|-------------|
| OpenAI | `openai-codex` | OAuth / env | Heavy work: default, plan, reviewer |
| Anthropic | `anthropic` | OAuth / env | Deep reasoning: slow, fallback peer |
| z.ai | `zai` | Static key (sops) | Parallel subagents: task, explore, sonic, librarian |
| Google | `google-antigravity` | OAuth (`/login`) | Multimodal + utility: designer, vision, smol, commit, tiny |

Only z.ai uses a static credential (`codex_zai_coding_plan_api_key` in sops).
OpenAI, Anthropic, and Google authenticate via OAuth or environment variables.

### Model catalog (verified via `omp models` and `agy models`)

| Selector | Family tier | Context | Notes |
|----------|-------------|---------|-------|
| `openai-codex/gpt-5.5` | OpenAI GPT SOTA | 272K | No `-codex` model suffix; provider is `openai-codex` |
| `anthropic/claude-opus-4-8` | Anthropic Opus | 1M | Hyphenated version: `4-8` |
| `anthropic/claude-sonnet-5` | Anthropic Sonnet | 1M | |
| `anthropic/claude-haiku-4-5` | Anthropic Haiku | 200K | Hyphenated version: `4-5` |
| `zai/glm-5.2` | Z.ai GLM SOTA | 1M | Provider is `zai`, not `zai-coding-plan` |
| `google-antigravity/gemini-3.5-flash` | Gemini SOTA | ~1M | omp catalog outdated; confirmed via `agy models` |
| `google-antigravity/gemini-3.1-flash-lite` | Gemini budget | ~1M | Cheaper tier |

## Model Role Assignments

Each OMP role is pinned to a specific provider/model:

| Role | Model | Provider | Rationale |
|------|-------|----------|-----------|
| `default` | `openai-codex/gpt-5.5` | OpenAI | SOTA coding model, strong agentic tool use |
| `plan` | `openai-codex/gpt-5.5` | OpenAI | Same as default — consistent planning without model-switch friction |
| `slow` | `anthropic/claude-opus-4-8` | Anthropic | Best deep reasoning; complementary to GPT-5.5 for hard debugging |
| `task` | `zai/glm-5.2` | z.ai | Cheap parallel fan-out; main session supervises quality |
| `designer` | `google-antigravity/gemini-3.5-flash` | Google | SOTA Gemini — strong multimodal for UI/UX work |
| `vision` | `google-antigravity/gemini-3.5-flash` | Google | SOTA Gemini — best image understanding for screenshots/diagrams |
| `commit` | `google-antigravity/gemini-3.1-flash-lite` | Google | Budget tier — fast, cheap commit messages |
| `smol` | `google-antigravity/gemini-3.1-flash-lite` | Google | Budget tier — lightweight tasks, quick lookups |
| `tiny` | `google-antigravity/gemini-3.1-flash-lite` | Google | Budget tier — background: session titles, memory, classification |

### Per-Agent Model Overrides

Subagents that deviate from the default `task` role:

| Agent | Model | Rationale |
|-------|-------|-----------|
| `reviewer` | `openai-codex/gpt-5.5` | Quality-critical code review needs SOTA reasoning |
| `explore` | `zai/glm-5.2` | Read-only scout — cheap is fine |
| `sonic` | `zai/glm-5.2` | Mechanical updates — cheap is fine |
| `librarian` | `zai/glm-5.2` | Library research — cheap is fine |

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
    "openai-codex/gpt-5.5":
      - "anthropic/claude-opus-4-8"
      - "google-antigravity/gemini-3.5-flash"
    "anthropic/claude-opus-4-8":
      - "openai-codex/gpt-5.5"
      - "google-antigravity/gemini-3.5-flash"
    "zai/glm-5.2":
      - "openai-codex/gpt-5.5"
      - "anthropic/claude-sonnet-5"
    "google-antigravity/gemini-3.5-flash":
      - "anthropic/claude-sonnet-5"
      - "openai-codex/gpt-5.5"
    "google-antigravity/gemini-3.1-flash-lite":
      - "zai/glm-5.2"
      - "anthropic/claude-haiku-4-5"
  # Leave fallbackRevertPolicy unset → runtime default (cooldown-expiry)
```

### Chain rationale

- **GPT-5.5 ↔ Claude Opus 4-8:** Two SOTA models back each other up.
  Gemini 3.5 Flash (Gemini SOTA) is the third diverse provider.
- **GLM-5.2:** Steps up to GPT-5.5 (stronger, different provider), then
  Claude Sonnet 5 (second diverse provider).
- **Gemini 3.5 Flash:** Falls to Claude Sonnet 5 (strong multimodal peer), then
  GPT-5.5.
- **Gemini 3.1 Flash Lite:** Falls to GLM-5.2 (cheap peer, different provider),
  then Claude Haiku 4-5 (budget-tier Anthropic).

### Revert policy

Leave `fallbackRevertPolicy` unset (null) → runtime applies `cooldown-expiry`,
which reverts to the primary model once its rate-limit cooldown expires. This
avoids thrashing (every-turn reversion) and wasteful persistence (session-wide
fallback).

## Context Promotion

**Disabled.** Rely on auto-compaction for context-window overflow rather than
cross-provider model switching. Avoids mid-session quality shifts and the
complexity of defining promotion targets across heterogeneous providers.

## Nix Configuration

Implemented in `configurations/darwin/frannie.nix` under `home-manager.users.scotttrinh`:

```nix
omp = {
  enable = true;

  # Model roles
  defaultModel  = "openai-codex/gpt-5.5";
  planModel     = "openai-codex/gpt-5.5";
  slowModel     = "anthropic/claude-opus-4-8";
  taskModel     = "zai/glm-5.2";
  designerModel = "google-antigravity/gemini-3.5-flash";
  visionModel   = "google-antigravity/gemini-3.5-flash";
  commitModel   = "google-antigravity/gemini-3.1-flash-lite";
  smolModel     = "google-antigravity/gemini-3.1-flash-lite";

  # tiny role (not a top-level option — via raw settings)
  settings.modelRoles.tiny = "google-antigravity/gemini-3.1-flash-lite";

  # Retry fallback chains (quality-preserved resilience)
  model = {
    modelFallback = true;
    fallbackChains = {
      "openai-codex/gpt-5.5"                = [ "anthropic/claude-opus-4-8" "google-antigravity/gemini-3.5-flash" ];
      "anthropic/claude-opus-4-8"           = [ "openai-codex/gpt-5.5" "google-antigravity/gemini-3.5-flash" ];
      "zai/glm-5.2"                         = [ "openai-codex/gpt-5.5" "anthropic/claude-sonnet-5" ];
      "google-antigravity/gemini-3.5-flash" = [ "anthropic/claude-sonnet-5" "openai-codex/gpt-5.5" ];
      "google-antigravity/gemini-3.1-flash-lite" = [ "zai/glm-5.2" "anthropic/claude-haiku-4-5" ];
    };
  };

  # Context promotion disabled
  context.promotionEnabled = false;

  # Per-agent overrides
  tasks.agentModelOverrides = {
    reviewer  = "openai-codex/gpt-5.5";
    explore   = "zai/glm-5.2";
    sonic     = "zai/glm-5.2";
    librarian = "zai/glm-5.2";
  };

  # Z.ai static credential (only provider needing one)
  modelProviders.zai = {
    apiKey = "!cat ${config.sops.secrets.codex_zai_coding_plan_api_key.path}";
  };
};
```

## Verification

All selectors verified via `omp models` (OpenAI, Anthropic, z.ai) and `agy models`
(Google — omp bundled catalog is outdated). Full `nix eval` verification passed
for all 9 model roles, 5 fallback chains, context promotion disabled, 4 agent
overrides, and Z.ai credential wiring.
