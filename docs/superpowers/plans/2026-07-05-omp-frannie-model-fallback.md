# OMP Frannie Model & Fallback Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure OMP on frannie with agent-specific model selections, per-agent overrides, and provider-diverse retry fallback chains across four providers.

**Architecture:** Add an `omp` configuration block to frannie's `home-manager.users.scotttrinh` section, using the existing `modules/home/omp/default.nix` module. The module generates `~/.omp/agent/config.yml` and `models.yml` via sops templates.

**Tech Stack:** Nix flakes, home-manager, sops-nix, omp home-manager module

## Global Constraints

- **Host:** frannie (darwin/aarch64, user scotttrinh)
- **Spec:** `docs/superpowers/specs/2026-07-05-omp-frannie-model-fallback-design.md`
- **Module:** `modules/home/omp/default.nix` — already auto-imported via `modules/home/default.nix`
- **Verified provider IDs** (from `omp models` catalog):
  - `openai-codex` — OpenAI models (NOT `openai`)
  - `anthropic` — Claude models
  - `zai` — Z.ai GLM models (NOT `zai-coding-plan`)
  - `google-antigravity` — Google Gemini via antigravity OAuth (NOT `google`; catalog is outdated but model slugs confirmed via `agy models`)
- **Verified model slugs:**
  - `openai-codex/gpt-5.5` (272K ctx, 128K max-out)
  - `anthropic/claude-opus-4-8` (1M ctx, 128K max-out) — hyphenated `4-8`
  - `anthropic/claude-sonnet-5` (1M ctx, 128K max-out)
  - `anthropic/claude-haiku-4-5` (200K ctx, 64K max-out) — hyphenated `4-5`
  - `zai/glm-5.2` (1M ctx, 131K max-out)
  - `google-antigravity/gemini-3.5-flash` (confirmed via agy CLI; omp catalog outdated)
  - `google-antigravity/gemini-3.1-flash-lite` (confirmed via agy CLI; omp catalog outdated)
- **Credentials:** Only Z.ai uses a static credential (existing sops secret `codex_zai_coding_plan_api_key`). OpenAI, Anthropic, and Google use OAuth/env — no sops secrets needed. Google uses `google-antigravity` OAuth via imperative `/login google-antigravity`.
- **No context promotion** — disabled, rely on auto-compaction
- **Fallback revert policy** — leave unset (null), runtime default is `cooldown-expiry`

---

### Task 1: Verify Provider IDs and Model Selectors

**Status:** ✅ COMPLETE — verified via `omp models` and `agy models`. Selectors confirmed in Global Constraints above.

---

### Task 2: Add OMP Model Role Configuration and Z.ai Credential

**Files:**
- Modify: `configurations/darwin/frannie.nix` — add `omp` block inside `home-manager.users.scotttrinh`

**Interfaces:**
- Consumes: `config.sops.secrets.codex_zai_coding_plan_api_key.path` (existing sops secret)
- Produces: all model roles set, Z.ai credential wired

- [ ] **Step 1: Add the omp block with model roles and Z.ai credential**

In `configurations/darwin/frannie.nix`, inside the `home-manager.users.scotttrinh = { ... }: {` block (after the existing `codex = { ... };` block, before the `sops.secrets` declarations around line 153), add:

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

  # tiny role is not a top-level option — set via raw settings
  settings.modelRoles.tiny = "google-antigravity/gemini-3.1-flash-lite";

  # Z.ai static credential (only provider needing one)
  modelProviders.zai = {
    apiKey = "!cat ${config.sops.secrets.codex_zai_coding_plan_api_key.path}";
  };
};
```

- [ ] **Step 2: Verify Nix evaluation**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.omp.defaultModel 2>&1 | head -5
```
Expected: `"openai-codex/gpt-5.5"`

- [ ] **Step 3: Commit**

```bash
git add configurations/darwin/frannie.nix
git commit -m "feat: add omp model role configuration for frannie"
```

---

### Task 3: Add Fallback Chains, Agent Overrides, and Context Promotion

**Files:**
- Modify: `configurations/darwin/frannie.nix` — extend the `omp` block from Task 2

**Interfaces:**
- Produces: `config.omp.model.fallbackChains`, `config.omp.tasks.agentModelOverrides`, `config.omp.context.promotionEnabled`

- [ ] **Step 1: Add fallback chains, agent overrides, and context promotion**

Extend the `omp` block (add these keys inside the `omp = { ... }` from Task 2, after the `modelProviders` block):

```nix
  # Retry fallback chains — quality-preserved resilience
  model = {
    modelFallback = true;
    fallbackChains = {
      "openai-codex/gpt-5.5"               = [ "anthropic/claude-opus-4-8" "google-antigravity/gemini-3.5-flash" ];
      "anthropic/claude-opus-4-8"          = [ "openai-codex/gpt-5.5" "google-antigravity/gemini-3.5-flash" ];
      "zai/glm-5.2"                        = [ "openai-codex/gpt-5.5" "anthropic/claude-sonnet-5" ];
      "google-antigravity/gemini-3.5-flash" = [ "anthropic/claude-sonnet-5" "openai-codex/gpt-5.5" ];
      "google-antigravity/gemini-3.1-flash-lite" = [ "zai/glm-5.2" "anthropic/claude-haiku-4-5" ];
    };
  };

  # Disable context promotion — rely on compaction
  context.promotionEnabled = false;

  # Per-agent model overrides
  tasks.agentModelOverrides = {
    reviewer  = "openai-codex/gpt-5.5";
    explore   = "zai/glm-5.2";
    sonic     = "zai/glm-5.2";
    librarian = "zai/glm-5.2";
  };
```

- [ ] **Step 2: Verify Nix evaluation of fallback chains**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.omp.model.fallbackChains --json 2>&1 | head -20
```
Expected: JSON object with all five fallback chain keys.

- [ ] **Step 3: Verify context promotion is disabled**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.omp.context.promotionEnabled 2>&1
```
Expected: `false`

- [ ] **Step 4: Commit**

```bash
git add configurations/darwin/frannie.nix
git commit -m "feat: add omp fallback chains and agent overrides for frannie"
```

---

### Task 4: Full Build Verification

**Files:**
- Reference: `configurations/darwin/frannie.nix`

- [ ] **Step 1: Build the darwin configuration**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.omp.enable 2>&1
```
Expected: `true` (confirms full module evaluation succeeds without errors)

If it fails, check:
- Provider validation errors (the module asserts `baseUrl`, `apiKey`, `api` requirements for providers with `models`)
- Model role option type errors (all should be strings)
- Fallback chain type errors (should be `attrsOf (listOf str)`)

- [ ] **Step 2: Verify generated config.yml model roles**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-config.content --json 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)
roles = c['modelRoles']
expected = {
    'default': 'openai-codex/gpt-5.5',
    'plan': 'openai-codex/gpt-5.5',
    'slow': 'anthropic/claude-opus-4-8',
    'task': 'zai/glm-5.2',
    'designer': 'google-antigravity/gemini-3.5-flash',
    'vision': 'google-antigravity/gemini-3.5-flash',
    'commit': 'google-antigravity/gemini-3.1-flash-lite',
    'smol': 'google-antigravity/gemini-3.1-flash-lite',
    'tiny': 'google-antigravity/gemini-3.1-flash-lite',
}
for role, model in expected.items():
    assert roles.get(role) == model, f'{role}: expected {model}, got {roles.get(role)}'
print('All model roles verified ✓')
"
```
Expected: `All model roles verified ✓`

- [ ] **Step 3: Verify fallback chains and context promotion**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-config.content --json 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)
chains = c['retry']['fallbackChains']
assert c['retry']['modelFallback'] == True, 'modelFallback not enabled'
assert c['contextPromotion']['enabled'] == False, 'contextPromotion not disabled'
assert chains['openai-codex/gpt-5.5'] == ['anthropic/claude-opus-4-8', 'google-antigravity/gemini-3.5-flash']
assert chains['zai/glm-5.2'] == ['openai-codex/gpt-5.5', 'anthropic/claude-sonnet-5']
assert len(chains) == 5, f'expected 5 chains, got {len(chains)}'
overrides = c['task']['agentModelOverrides']
assert overrides['reviewer'] == 'openai-codex/gpt-5.5'
assert overrides['explore'] == 'zai/glm-5.2'
print('Fallback chains, context promotion, and agent overrides verified ✓')
"
```
Expected: `Fallback chains, context promotion, and agent overrides verified ✓`

- [ ] **Step 4: Verify Z.ai credential in models.yml**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-models.content --json 2>&1 | python3 -c "
import json, sys
m = json.load(sys.stdin)
zai = m['providers']['zai']
assert zai['apiKey'].startswith('!cat'), f\"zai apiKey should start with !cat, got: {zai['apiKey']}\"
print('Z.ai credential wired correctly ✓')
"
```
Expected: `Z.ai credential wired correctly ✓`

- [ ] **Step 5: Final commit if any fixes were needed**

If Steps 1-4 required any fixes, commit them:
```bash
git add configurations/darwin/frannie.nix
git commit -m "fix: correct omp configuration after build verification"
```

If no fixes were needed, this step is a no-op.
