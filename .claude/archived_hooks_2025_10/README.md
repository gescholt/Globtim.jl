# Archived Hooks - October 2025

This directory contains Claude Code hooks archived during the October 2025 repository cleanup.

## Archived Hooks

### git-auto-commit-push.md

**Reason for archiving**: Anti-pattern for version control

**Issues identified**:
1. **Auto-commits create messy history** - Commits are created automatically without meaningful, thoughtful messages
2. **Auto-pushes bypass code review** - Changes are pushed without testing or review
3. **Risk of pushing broken code** - No verification before pushing to remote
4. **Risk of pushing sensitive data** - Could accidentally push tokens, credentials, or private data
5. **Goes against Git best practices** - Version control should be deliberate and intentional

**Why this pattern is problematic**:
- Git history becomes polluted with automated, generic commit messages
- Defeats the purpose of version control (careful tracking of changes)
- Can push code that breaks CI/CD pipelines
- Makes it difficult to revert or understand changes later
- Removes user agency and control over their commits

**Better approach**:
- Manual commits with thoughtful, descriptive messages
- Review changes before committing (git diff)
- Run tests locally before pushing
- Use git hooks that PROMPT rather than AUTO-EXECUTE

## Alternative Approaches

If you want commit assistance (not automation), consider:

1. **Pre-commit hook that PROMPTS**:
   - Shows what will be committed
   - Asks for confirmation
   - Suggests commit message based on changes
   - Allows user to edit or cancel

2. **Post-completion reminder**:
   - At end of session, reminds user to commit
   - Lists files changed
   - Does NOT commit automatically

3. **Commit template generation**:
   - Generates suggested commit message
   - User reviews and edits
   - User manually executes commit

## Restoration Warning

**DO NOT restore this hook without significant modifications.**

If you must have auto-commit functionality:
- Remove auto-push (never push without user confirmation)
- Add explicit user confirmation before committing
- Run tests before any commit
- Create meaningful commit messages based on actual changes
- Add safeguards against committing sensitive data

## Related Documentation

See `docs/repository_cleanup_2025_10.md` for the complete rationale and alternative approaches.

---

**Archived Date**: 2025-10-20
**Archived By**: Claude Code
**Audit Report**: `docs/repository_cleanup_2025_10.md`
**Status**: Not recommended for restoration
