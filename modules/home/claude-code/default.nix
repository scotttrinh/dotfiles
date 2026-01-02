
{ flake, config, ... }:
{
  sops.secrets.zai_api_key = {
    key = "ZAI_API_KEY";
    mode = "0400";
  };

  # sops templates for injecting secrets into config files
  sops.templates."claude-settings".content = ''
    {
      "env": {
        "ANTHROPIC_AUTH_TOKEN": "${config.sops.placeholder.zai_api_key}",
        "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
        "API_TIMEOUT_MS": "3000000"
      },
      "model": "opus"
    }
  '';
  sops.templates."claude-settings".path = "/Users/scotttrinh/.claude/settings.json";
}
