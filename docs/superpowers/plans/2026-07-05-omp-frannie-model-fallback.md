# OMP Frannie Model & Fallback Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure OMP on frannie with agent-specific model selections, per-agent overrides, and provider-diverse retry fallback chains across four providers.

**Architecture:** Add an `omp` configuration block to frannie's `home-manager.users.scotttrinh` section, using the existing `modules/home/omp/default.nix` module. Wire provider credentials from sops secrets. The module generates `~/.omp/agent/config.yml` and `models.yml` via sops templates.

**Tech Stack:** Nix flakes, home-manager, sops-nix, omp home-manager module

## Global Constraints

- **Host:** frannie (darwin/aarch64, user scotttrinh)
- **Spec:** `docs/superpowers/specs/2026-07-05-omp-frannie-model-fallback-design.md`
- **Module:** `modules/home/omp/default.nix` — already auto-imported via `modules/home/default.nix`
- **Provider IDs must be verified** against the omp catalog before finalizing. The spec uses `openai`, `anthropic`, `zai-coding-plan`, `google` as provider IDs — confirm these match what omp's bundled catalog uses.
- **Model slugs** (confirmed by user): `gpt-5.5`, `claude-opus-4.8`, `claude-sonnet-5`, `claude-haiku-4.5`, `glm-5.2`, `gemini-3.5-flash`, `gemini-3.1-flash-lite`
- **No context promotion** — disabled, rely on auto-compaction
- **Fallback revert policy** — leave unset (null), runtime default is `cooldown-expiry`

---

### Task 1: Verify Provider IDs and Model Selectors

**Files:**
- Reference: `modules/home/omp/default.nix` (option definitions)
- Reference: `omp://models.md` and `omp://providers.md`

**Interfaces:**
- Produces: confirmed `provider/modelId` selectors for all roles and fallback chains

This task verifies the exact selectors before implementation. No file changes.

- [ ] **Step 1: Check available omp providers and models**

Run:
```bash
omp models 2>/dev/null || echo "omp not installed — check bundled catalog in source"
```

If omp is installed, look for the four providers (`openai`, `anthropic`, `zai-coding-plan`, `google`) and verify the model slugs exist. If omp is not installed, verify against the omp docs:

- `openai/gpt-5.5` — the OpenAI provider uses `gpt-5.5` (no `-codex` suffix)
- `anthropic/claude-opus-4.8`, `anthropic/claude-sonnet-5`, `anthropic/claude-haiku-4.5`
- `zai-coding-plan/glm-5.2` — verify provider ID is `zai-coding-plan` (not `zai` or `zhipu-coding-plan`)
- `google/gemini-3.5-flash`, `google/gemini-3.1-flash-lite`

- [ ] **Step 2: Document confirmed selectors**

Record the verified `provider/modelId` selectors. If any differ from the spec, note the correction for Task 3.

---

### Task 2: Add Google API Key to Sops Secrets

**Files:**
- Modify: `secrets.yaml` — add `GEMINI_API_KEY_FRANNIE`
- Modify: `configurations/darwin/frannie.nix` — add sops secret declaration

**Interfaces:**
- Produces: `config.sops.secrets.gemini_api_key.path` available for provider wiring in Task 4

- [ ] **Step 1: Add Gemini API key to secrets.yaml**

The user must provide the actual key value. Add a new key to `secrets.yaml`:

```yaml
GEMINI_API_KEY_FRANNIE: <user-provided-key>
```

Run:
```bash
sops secrets.yaml
```
Add the key entry, save, and close the editor.

- [ ] **Step 2: Add sops secret declaration to frannie.nix**

In `configurations/darwin/frannie.nix`, inside the `home-manager.users.scotttrinh` block, alongside the existing `sops.secrets` declarations (around line 153-162), add:

```nix
sops.secrets.gemini_api_key = {
  key = "GEMINI_API_KEY_FRANNIE";
  mode = "0400";
};
```

- [ ] **Step 3: Verify OpenAI and Anthropic key availability**

Check whether omp can authenticate with OpenAI and Anthropic. The existing frannie config has `claude_code_api_key` (shared between claudeCode and codex z.ai). For omp:

- **OpenAI:** May need `OPENAI_API_KEY` env var or an omp-specific key in sops. Check if the user has one.
- **Anthropic:** May need `ANTHROPIC_API_KEY` or OAuth. The claudeCode config uses z.ai proxy, not direct Anthropic.

If direct keys are needed, add them to secrets.yaml and declare sops secrets following the same pattern.

- [ ] **Step 4: Commit**

```bash
git add secrets.yaml configurations/darwin/frannie.nix
git commit -m "feat: add Gemini API key sops secret for omp"
```

---

### Task 3: Add OMP Model Role Configuration

**Files:**
- Modify: `configurations/darwin/frannie.nix:34-163` — add `omp` block inside `home-manager.users.scotttrinh`

**Interfaces:**
- Produces: `config.omp.defaultModel` through `config.omp.smolModel` and `config.omp.settings.modelRoles.tiny` all set

- [ ] **Step 1: Add the omp enable and model role block**

In `configurations/darwin/frannie.nix`, inside the `home-manager.users.scotttrinh = { ... }: {` block (after the existing `codex = { ... };` block, before the `sops.secrets` declarations), add:

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

  # tiny role is not a top-level option — set via raw settings
  settings.modelRoles.tiny = "google/gemini-3.1-flash-lite";
};
```

Use the corrected selectors from Task 1 if any differed.

- [ ] **Step 2: Verify Nix evaluation**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.omp.defaultModel 2>&1 | head -5
```
Expected: `"openai/gpt-5.5"`

- [ ] **Step 3: Commit**

```bash
git add configurations/darwin/frannie.nix
git commit -m "feat: add omp model role configuration for frannie"
```

---

### Task 4: Add Fallback Chains, Agent Overrides, and Context Promotion

**Files:**
- Modify: `configurations/darwin/frannie.nix` — extend the `omp` block from Task 3

**Interfaces:**
- Produces: `config.omp.model.fallbackChains`, `config.omp.tasks.agentModelOverrides`, `config.omp.context.promotionEnabled`

- [ ] **Step 1: Add fallback chains, agent overrides, and context promotion**

Extend the `omp` block (add these keys inside the `omp = { ... }` from Task 3):

```nix
  # Retry fallback chains — quality-preserved resilience
  model = {
    modelFallback = true;
    fallbackChains = {
      "openai/gpt-5.5"                = [ "anthropic/claude-opus-4.8" "google/gemini-3.5-flash" ];
      "anthropic/claude-opus-4.8"     = [ "openai/gpt-5.5" "google/gemini-3.5-flash" ];
      "zai-coding-plan/glm-5.2"       = [ "openai/gpt-5.5" "anthropic/claude-sonnet-5" ];
      "google/gemini-3.5-flash"       = [ "anthropic/claude-sonnet-5" "openai/gpt-5.5" ];
      "google/gemini-3.1-flash-lite"  = [ "zai-coding-plan/glm-5.2" "anthropic/claude-haiku-4.5" ];
    };
  };

  # Disable context promotion — rely on compaction
  context.promotionEnabled = false;

  # Per-agent model overrides
  tasks.agentModelOverrides = {
    reviewer  = "openai/gpt-5.5";
    explore   = "zai-coding-plan/glm-5.2";
    sonic     = "zai-coding-plan/glm-5.2";
    librarian = "zai-coding-plan/glm-5.2";
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

### Task 5: Wire Provider Credentials

**Files:**
- Modify: `configurations/darwin/frannie.nix` — add `modelProviders` to the `omp` block

**Interfaces:**
- Consumes: `config.sops.secrets.codex_zai_coding_plan_api_key.path` (existing)
- Consumes: `config.sops.secrets.gemini_api_key.path` (from Task 2)
- Produces: provider API keys wired into generated `models.yml`

The omp module generates `~/.omp/agent/models.yml` from `modelProviders`. Provider `apiKey` values use env-var-name-or-literal semantics, or `!command` prefix for shell-resolved secrets. For sops secrets (which are files on disk), use `!cat <path>`.

- [ ] **Step 1: Add provider credentials for z.ai and Google**

Add `modelProviders` to the `omp` block:

```nix
  modelProviders = {
    # z.ai coding plan — key already in sops
    zai-coding-plan = {
      apiKey = "!cat ${config.sops.secrets.codex_zai_coding_plan_api_key.path}";
    };

    # Google Gemini
    google = {
      apiKey = "!cat ${config.sops.secrets.gemini_api_key.path}";
    };
  };
```

Note: `openai` and `anthropic` providers use built-in catalog credentials (env vars `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` or omp OAuth). If direct API keys are needed (from Task 2 Step 3), add them here too:

```nix
    # OpenAI — if a direct key is needed
    openai = {
      apiKey = "!cat ${config.sops.secrets.openai_api_key.path}";
    };

    # Anthropic — if a direct key is needed
    anthropic = {
      apiKey = "!cat ${config.sops.secrets.anthropic_api_key.path}";
    };
```

Only add `openai` and `anthropic` entries if the verification in Task 2 Step 3 showed that env vars or OAuth are insufficient.

- [ ] **Step 2: Verify Nix evaluation includes providers**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.omp.modelProviders --apply 'x: builtins.attrNames x' 2>&1
```
Expected: `[ "google" "zai-coding-plan" ]` (plus `openai`/`anthropic` if added)

- [ ] **Step 3: Verify generated models.yml has API keys**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-models.content --json 2>&1 | nix run nixpkgs#jq -- -r '.providers["zai-coding-plan"].apiKey' 2>/dev/null || echo "manual check needed"
```
Expected: The apiKey field contains the `!cat /...` command referencing the sops secret path.

- [ ] **Step 4: Commit**

```bash
git add configurations/darwin/frannie.nix
git commit -m "feat: wire omp provider credentials from sops secrets"
```

---

### Task 6: Full Build Verification

**Files:**
- Reference: `configurations/darwin/frannie.nix`

- [ ] **Step 1: Build the darwin configuration**

Run:
```bash
nix build .#darwinConfigurations.frannie.system --dry-run 2>&1 | tail -20
```
Expected: build succeeds without evaluation errors.

If it fails, check:
- Provider validation errors (the module asserts `baseUrl`, `apiKey`, `api` requirements)
- Model role option type errors (all should be strings)
- Fallback chain type errors (should be `attrsOf (listOf str)`)

- [ ] **Step 2: Verify generated config.yml structure**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-config.content --json 2>&1 | python3 -m json.tool | grep -E '(modelRoles|fallbackChains|modelFallback|contextPromotion|agentModelOverrides)' | head -20
```
Expected: all model roles, fallback chains, modelFallback=true, contextPromotion.enabled=false, agentModelOverrides present.

- [ ] **Step 3: Verify model role assignments**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-config.content --json 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)
roles = c['modelRoles']
assert roles['default'] == 'openai/gpt-5.5', f\"default: {roles['default']}\"
assert roles['slow'] == 'anthropic/claude-opus-4.8', f\"slow: {roles['slow']}\"
assert roles['task'] == 'zai-coding-plan/glm-5.2', f\"task: {roles['task']}\"
assert roles['tiny'] == 'google/gemini-3.1-flash-lite', f\"tiny: {roles['tiny']}\"
print('All model roles verified ✓')
"
```
Expected: `All model roles verified ✓`

- [ ] **Step 4: Verify fallback chains**

Run:
```bash
nix eval .#darwinConfigurations.frannie.config.home-manager.users.scotttrinh.sops.templates.omp-config.content --json 2>&1 | python3 -c "
import json, sys
c = json.load(sys.stdin)
chains = c['retry']['fallbackChains']
assert 'openai/gpt-5.5' in chains, 'missing openai/gpt-5.5 chain'
assert chains['openai/gpt-5.5'] == ['anthropic/claude-opus-4.8', 'google/gemini-3.5-flash']
assert chains['zai-coding-plan/glm-5.2'] == ['openai/gpt-5.5', 'anthropic/claude-sonnet-5']
assert c['retry']['modelFallback'] == True
print('All fallback chains verified ✓')
"
```
Expected: `All fallback chains verified ✓`

- [ ] **Step 5: Final commit if any fixes were needed**

If Steps 1-4 required any fixes, commit them:
```bash
git add configurations/darwin/frannie.nix
git commit -m "fix: correct omp configuration after build verification"
```

If no fixes were needed, this step is a no-op.
