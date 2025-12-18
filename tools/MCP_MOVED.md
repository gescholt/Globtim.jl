# MCP Server Moved ⚠️

The MCP (Model Context Protocol) server has been **moved to a new location**.

## New Location

```
/Users/ghscholt/GlobalOptim/mcp/
```

## Why?

The MCP server operates across multiple repositories:
- globtimcore
- GlobTimRL
- globtimplots
- globtim_results

It made more sense to place it at the GlobalOptim root level rather than buried in `globtimcore/tools/`.

## What Changed?

✨ **New features:**
- Smart package management (5 new tools)
- Lazy loading (15x faster startup: 2s vs 30s)
- Validation tools enabled (previously disabled)
- Better organized structure

📍 **New location:**
```
/Users/ghscholt/GlobalOptim/mcp/
├── server.jl
├── shared/package_manager.jl
├── tools/
│   ├── package_tools.jl
│   └── globtimcore/
├── templates/
└── docs/
```

## Migration

**Old config:**
```json
{
  "mcpServers": {
    "globtim": {
      "command": "julia",
      "args": [
        "--project=/Users/ghscholt/GlobalOptim/globtimcore/tools/mcp",
        "/Users/ghscholt/GlobalOptim/globtimcore/tools/mcp/server.jl"
      ]
    }
  }
}
```

**New config:**
```json
{
  "mcpServers": {
    "globtim": {
      "command": "julia",
      "args": [
        "--project=/Users/ghscholt/GlobalOptim/mcp",
        "/Users/ghscholt/GlobalOptim/mcp/server.jl"
      ]
    }
  }
}
```

## Documentation

See the new location for full documentation:
- `/Users/ghscholt/GlobalOptim/mcp/README.md`
- `/Users/ghscholt/GlobalOptim/mcp/QUICKSTART.md`
- `/Users/ghscholt/GlobalOptim/mcp/IMPROVEMENTS.md`

## Old Files

Old MCP files are archived in:
```
/Users/ghscholt/GlobalOptim/globtimcore/tools/mcp.archived/
```

These can be safely deleted after verifying the new server works.

---

**Migration date:** 2025-10-22
**Status:** Complete ✅
