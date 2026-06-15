# BrainAI Memory for Agents (MCP)

BrainAI exposes each workspace's knowledge base (LightRAG) **and** its Markdown
memory wiki to external AI agents (Cursor, Claude Desktop, Claude Code, and any
MCP client) through the Model Context Protocol.

Memory is **per-workspace** — each workspace ("project") has its own isolated
`raw/`, `wiki/`, `schema/`, and `metadata/` tree. Tools default to the active
workspace and accept an optional `workspace` slug/name to target another.

## Tools

### Read
| Tool | Purpose |
|------|---------|
| `brainai_query` | Natural-language RAG query over the knowledge graph |
| `brainai_search` | Search entities/relations by label and text |
| `brainai_wiki_search` | Full-text search across wiki pages |
| `brainai_wiki_get_page` | Read a wiki page by path or slug |
| `brainai_wiki_review_queue` | List pending review items |
| `brainai_list_workspaces` | List workspaces (projects) and which is active |

### Write
| Tool | Purpose |
|------|---------|
| `brainai_insert` | Insert text into the LightRAG knowledge graph |
| `brainai_create_entity` / `brainai_create_relation` | Add graph nodes/edges |
| `brainai_wiki_append_log` | Append a timestamped fact to the workspace log (low friction) |
| `brainai_wiki_create_note` | Create a reviewable memory page (`concept`, `decision`, `entity`, `question`, `contradiction`, `user`, `synthesis`, `inbox`) |
| `brainai_wiki_record_source` | Preserve a raw source verbatim + create a source page |

Agent-authored wiki pages land in the **review queue** as `needs_review` (or
`auto_accepted` when `auto_accept: true`), so a human stays in the loop before a
note becomes trusted workspace memory. `brainai_wiki_create_note` also accepts an
optional `domain` (`work`, `personal-project`, `hobby-*`, `personal`) recorded in
the page frontmatter.

### Resources

The server also exposes MCP **resources** so agents can read the memory model
without a tool call:

| URI | Contents |
|-----|----------|
| `brainai://memory/schema` | Memory taxonomy (entity types, relation patterns, tagging conventions) |
| `brainai://memory/index` | Index of compiled wiki pages in the active workspace |
| `brainai://memory/page/<path>` | Any individual wiki page (also listed per-page in `resources/list`) |

`brainai_wiki_search` accepts an optional `domain` to filter results. A workspace
can carry a default `domain` (Settings → Workspaces) that `brainai_wiki_create_note`
applies automatically when no `domain` is passed.

## Connecting over stdio (Cursor, Claude Desktop, Claude Code)

Build the standalone server binary:

```bash
cd BrainAI
swift build -c release --product BrainAIMCP
# binary at: .build/release/BrainAIMCP
```

Then register it with your agent. Example MCP config:

```json
{
  "mcpServers": {
    "brainai": {
      "command": "/absolute/path/to/BrainAI/.build/release/BrainAIMCP",
      "env": {
        "BRAINAI_LIGHTRAG_HOST": "localhost",
        "BRAINAI_LIGHTRAG_PORT": "9621"
      }
    }
  }
}
```

- Claude Code: `claude mcp add brainai /absolute/path/to/BrainAIMCP`
- Claude Desktop: add the block above to `claude_desktop_config.json`.
- Cursor: add it to `~/.cursor/mcp.json`.

The binary speaks newline-delimited JSON-RPC over stdin/stdout; diagnostics go to
stderr so stdout stays a clean protocol channel. `BRAINAI_LIGHTRAG_HOST` /
`BRAINAI_LIGHTRAG_PORT` are optional (default `localhost:9621`); the wiki memory
tools work even when LightRAG is offline.

## Connecting over WebSocket (in-app / LAN)

The app can host the same MCP server over WebSocket via `MCPWebSocketServer`
(default port `8765`), so in-app and LAN MCP clients can connect without a
spawned process:

```
ws://<host>:8765
```

Each connection gets its own server loop. Use stdio for local agent tooling and
WebSocket when a long-running app instance should serve memory to other clients.

## Quick check

```bash
printf '%s\n%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | .build/release/BrainAIMCP
```

You should see the server info and the full tool list.
