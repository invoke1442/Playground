# openai.yaml fields

`agents/openai.yaml` is product-specific metadata for Codex skill lists and invocation UI.

## Example

```yaml
interface:
  display_name: "Optional user-facing name"
  short_description: "Optional user-facing description"
  icon_small: "./assets/small-400px.png"
  icon_large: "./assets/large-logo.svg"
  brand_color: "#3B82F6"
  default_prompt: "Use $skill-name to handle this task."

dependencies:
  tools:
    - type: "mcp"
      value: "github"
      description: "GitHub MCP server"
      transport: "streamable_http"
      url: "https://api.githubcopilot.com/mcp/"

policy:
  allow_implicit_invocation: true
```

## Constraints

- Quote all string values.
- Keep keys unquoted.
- `interface.display_name`: human-facing title shown in UI skill lists and chips.
- `interface.short_description`: human-facing short UI blurb, 25-64 characters.
- `interface.icon_small` and `interface.icon_large`: paths relative to the skill directory.
- `interface.brand_color`: hex color for UI accents.
- `interface.default_prompt`: short example prompt that explicitly mentions the skill as `$skill-name`.
- `dependencies.tools[].type`: dependency category. Only `mcp` is supported for now.
- `policy.allow_implicit_invocation`: when false, the skill is not injected by default but can still be invoked explicitly.
