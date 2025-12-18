# glab Command Syntax Corrections

**Date:** 2025-10-05
**Status:** ✅ Complete

## Problem

Two common syntax errors were identified when using `glab` (GitLab CLI):

### Error 1: Using `-m` flag with `glab issue close`
```bash
❌ glab issue close 135 -m "message"
ERROR: unknown shorthand flag: 'm' in -m
```

**Root cause:** Confusion with `git commit -m` syntax. The `glab issue close` command does NOT support a `-m` or `--message` flag.

### Error 2: Using `glab issue note` command
```bash
❌ glab issue note 135 "message"
ERROR: accepts 1 arg(s), received 2
```

**Root cause:**
1. Wrong command - should be `glab issue comment`, not `glab issue note`
2. Missing `--message` flag - message cannot be a positional argument

## Correct Syntax

### Close Issue with Comment

**CORRECT approach - two separate commands:**
```bash
# Step 1: Close the issue
glab issue close 135

# Step 2: Add completion comment
glab issue comment 135 --message "Implementation complete with 66 passing tests."
```

**Why separate?** The `glab issue close` command intentionally does not support adding a message. This design forces you to use the `comment` command, which properly records the comment in the issue timeline.

## Common Mistakes from Other Tools

| Incorrect (from git/gh) | Correct (glab) |
|------------------------|----------------|
| `git commit -m "msg"` | `glab issue comment <id> --message "msg"` |
| `gh issue close 135 --comment "msg"` | `glab issue close 135` then `glab issue comment 135 --message "msg"` |
| `glab issue note 135 "msg"` | `glab issue comment 135 --message "msg"` |
| `glab issue comment 135 "msg"` | `glab issue comment 135 --message "msg"` |

## Updated Documentation

The following files have been updated to include these corrections:

### 1. Agent Configuration
**File:** `.claude/agents/project-task-updater.md`

**Changes:**
- Added common mistakes #17-20 with specific error examples
- Updated command examples to emphasize correct syntax
- Added inline comments warning about the `-m` flag habit

**Lines updated:**
- Line 58-62: Added warnings to close/comment examples
- Line 271-274: Added specific mistakes to avoid

### 2. Quick Reference
**File:** `tools/gitlab/QUICK_REFERENCE.md`

**Changes:**
- Expanded "Common Mistakes" section with all four error patterns
- Added inline comments explaining each error
- Made correct syntax examples more prominent

**Lines updated:**
- Line 104-118: Expanded DON'T/DO examples

## Key Takeaways

1. **No `-m` flag:** `glab issue close` does not support message flags (unlike `git commit`)
2. **Use `comment`, not `note`:** The command is `glab issue comment`, not `glab issue note`
3. **Always use `--message`:** Message text must use the `--message` flag, not positional argument
4. **Two-step process:** Closing with a comment requires two separate commands

## Prevention

These corrections have been added to:
- ✅ Agent configuration templates
- ✅ Quick reference guides
- ✅ Common mistakes documentation
- ✅ Workflow examples

Future invocations of the `project-task-updater` agent will follow the correct syntax.

## Testing

Verified the correct syntax works:
```bash
# Successfully closed issue #135
cd /Users/ghscholt/GlobalOptim/globtimcore
glab issue close 135                    # ✅ Worked
glab issue comment 135 --message "..."  # ✅ Worked
```

## Related Documentation

- [GIT_GITLAB_CONFIGURATION.md](GIT_GITLAB_CONFIGURATION.md) - Git/GitLab configuration protection
- [tools/gitlab/QUICK_REFERENCE.md](../tools/gitlab/QUICK_REFERENCE.md) - Quick command reference
- [.claude/agents/project-task-updater.md](../.claude/agents/project-task-updater.md) - Agent configuration
