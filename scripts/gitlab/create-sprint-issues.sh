#!/bin/bash
# Create initial issues for sprint planning

source .env.gitlab

echo "Creating initial sprint issues..."

# Issue templates
create_issue() {
    local title="$1"
    local description="$2"
    local labels="$3"
    local milestone_id="${4:-$CURRENT_MILESTONE_ID}"

    echo "Creating issue: $title"

    # Create JSON payload with jq to ensure proper escaping
    JSON_PAYLOAD=$(jq -n \
      --arg title "$title" \
      --arg desc "$description" \
      --arg labels "$labels" \
      --argjson milestone "$milestone_id" \
      '{title: $title, description: $desc, labels: $labels, milestone_id: $milestone}')

    RESPONSE=$(curl -s -X POST \
      -H "PRIVATE-TOKEN: $GITLAB_PRIVATE_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$JSON_PAYLOAD" \
      "$GITLAB_API_URL/projects/$GITLAB_PROJECT_ID/issues")

    ISSUE_ID=$(echo "$RESPONSE" | jq -r '.iid // empty' 2>/dev/null)
    if [ -n "$ISSUE_ID" ]; then
        echo "  ✅ Created issue #$ISSUE_ID"
    else
        echo "  ❌ Failed to create issue"
        echo "  Response: $RESPONSE"
    fi
}

# Infrastructure Issues
create_issue \
  "Set up GitLab CI/CD pipeline for Julia tests" \
  "## Description
Configure GitLab CI to run Julia tests automatically on push and MR.

## Acceptance Criteria
- [ ] Create .gitlab-ci.yml
- [ ] Configure Julia test runner
- [ ] Add coverage reporting
- [ ] Test on multiple Julia versions (1.9, 1.10)

## Technical Notes
- Use official Julia Docker images
- Cache Julia packages for faster builds
- Generate and upload coverage reports" \
  "type::feature,component::infrastructure,priority::high,status::backlog"

create_issue \
  "Create project boards for sprint management" \
  "## Description
Set up GitLab boards for visualizing sprint progress.

## Boards to Create
1. **Development Board**: Status-based (backlog → done)
2. **Epic Board**: Track progress by epic
3. **Priority Board**: Visualize by priority

## Acceptance Criteria
- [ ] Create Development Board with status columns
- [ ] Configure board settings
- [ ] Add board descriptions
- [ ] Document board usage in wiki" \
  "type::feature,component::project-management,priority::high,status::ready"

# Development Issues
create_issue \
  "Optimize L2 norm computation for large arrays" \
  "## Description
Current L2 norm implementation may be inefficient for large arrays.

## Tasks
- [ ] Benchmark current implementation
- [ ] Implement SIMD optimizations
- [ ] Add multi-threading support
- [ ] Compare with BLAS implementations

## Performance Goals
- 2x speedup for arrays > 1M elements
- Maintain accuracy within 1e-15" \
  "type::feature,epic::julia-optimization,priority::medium,status::backlog"

create_issue \
  "Add comprehensive test suite for core algorithms" \
  "## Description
Expand test coverage for core mathematical operations.

## Test Areas
- [ ] Edge cases (empty arrays, single elements)
- [ ] Numerical stability tests
- [ ] Performance regression tests
- [ ] Property-based testing with PropCheck.jl

## Coverage Target
- Increase coverage from current to >80%" \
  "type::test,epic::test-framework,priority::high,status::backlog"

# Documentation Issues
create_issue \
  "Update README with installation and usage examples" \
  "## Description
Improve documentation for new users.

## Sections to Add/Update
- [ ] Clear installation instructions
- [ ] Basic usage examples
- [ ] API reference links
- [ ] Contributing guidelines
- [ ] Performance benchmarks

## Format
- Use Julia markdown code blocks
- Include output examples
- Add badges (CI status, coverage)" \
  "type::documentation,priority::medium,status::backlog"

echo
echo "Sprint issues created! Next steps:"
echo "1. Review and refine issue descriptions"
echo "2. Assign team members"
echo "3. Set story points/time estimates"
echo "4. Prioritize for sprint planning"
