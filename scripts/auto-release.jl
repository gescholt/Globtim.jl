#!/usr/bin/env julia
"""
Automated release management for Globtim.jl
Handles version bumping, changelog generation, and release creation.
"""

using Pkg, TOML, Dates, JSON

# Configuration
const PROJECT_FILE = "Project.toml"
const CHANGELOG_FILE = "CHANGELOG.md"
const RELEASE_NOTES_FILE = "RELEASE_NOTES.md"

"""
Parse semantic version string
"""
function parse_semver(version_str)
    parts = split(version_str, ".")
    if length(parts) != 3
        error("Invalid semantic version: $version_str")
    end
    return (parse(Int, parts[1]), parse(Int, parts[2]), parse(Int, parts[3]))
end

"""
Format semantic version tuple to string
"""
function format_semver(major, minor, patch)
    return "$major.$minor.$patch"
end

"""
Bump version according to type
"""
function bump_version(current_version, bump_type)
    major, minor, patch = parse_semver(current_version)
    
    if bump_type == "major"
        return format_semver(major + 1, 0, 0)
    elseif bump_type == "minor"
        return format_semver(major, minor + 1, 0)
    elseif bump_type == "patch"
        return format_semver(major, minor, patch + 1)
    else
        error("Invalid bump type: $bump_type. Use 'major', 'minor', or 'patch'")
    end
end

"""
Get current version from Project.toml
"""
function get_current_version()
    project = TOML.parsefile(PROJECT_FILE)
    return project["version"]
end

"""
Update version in Project.toml
"""
function update_project_version(new_version)
    project = TOML.parsefile(PROJECT_FILE)
    project["version"] = new_version
    
    open(PROJECT_FILE, "w") do f
        TOML.print(f, project)
    end
    
    println("✅ Updated Project.toml version to $new_version")
end

"""
Get git commits since last tag
"""
function get_commits_since_last_tag()
    try
        # Get the last tag
        last_tag = strip(read(`git describe --tags --abbrev=0`, String))
        println("📋 Last tag: $last_tag")
        
        # Get commits since last tag
        commits = strip(read(`git log $last_tag..HEAD --oneline`, String))
        
        if isempty(commits)
            return String[]
        end
        
        return split(commits, '\n')
    catch
        # If no tags exist, get all commits
        println("📋 No previous tags found, getting all commits")
        commits = strip(read(`git log --oneline`, String))
        return isempty(commits) ? String[] : split(commits, '\n')
    end
end

"""
Categorize commits by type
"""
function categorize_commits(commits)
    features = String[]
    fixes = String[]
    breaking = String[]
    other = String[]
    
    for commit in commits
        commit_lower = lowercase(commit)
        
        if contains(commit_lower, "feat:") || contains(commit_lower, "feature:")
            push!(features, commit)
        elseif contains(commit_lower, "fix:") || contains(commit_lower, "bug:")
            push!(fixes, commit)
        elseif contains(commit_lower, "breaking:") || contains(commit_lower, "!:")
            push!(breaking, commit)
        else
            push!(other, commit)
        end
    end
    
    return (features=features, fixes=fixes, breaking=breaking, other=other)
end

"""
Generate changelog entry
"""
function generate_changelog_entry(version, commits)
    categorized = categorize_commits(commits)
    
    entry = """
## [$version] - $(Dates.format(now(), "yyyy-mm-dd"))

"""
    
    if !isempty(categorized.breaking)
        entry *= "### ⚠️ BREAKING CHANGES\n"
        for commit in categorized.breaking
            entry *= "- $commit\n"
        end
        entry *= "\n"
    end
    
    if !isempty(categorized.features)
        entry *= "### ✨ New Features\n"
        for commit in categorized.features
            entry *= "- $commit\n"
        end
        entry *= "\n"
    end
    
    if !isempty(categorized.fixes)
        entry *= "### 🐛 Bug Fixes\n"
        for commit in categorized.fixes
            entry *= "- $commit\n"
        end
        entry *= "\n"
    end
    
    if !isempty(categorized.other)
        entry *= "### 🔧 Other Changes\n"
        for commit in categorized.other
            entry *= "- $commit\n"
        end
        entry *= "\n"
    end
    
    return entry
end

"""
Update CHANGELOG.md
"""
function update_changelog(version, commits)
    changelog_entry = generate_changelog_entry(version, commits)
    
    if isfile(CHANGELOG_FILE)
        # Read existing changelog
        existing_content = read(CHANGELOG_FILE, String)
        
        # Find where to insert new entry (after # Changelog header)
        lines = split(existing_content, '\n')
        header_index = findfirst(line -> startswith(line, "# Changelog"), lines)
        
        if header_index !== nothing
            # Insert new entry after header
            new_lines = vcat(
                lines[1:header_index],
                "",
                split(changelog_entry, '\n'),
                lines[header_index+1:end]
            )
            new_content = join(new_lines, '\n')
        else
            # Prepend to existing content
            new_content = "# Changelog\n\n" * changelog_entry * existing_content
        end
    else
        # Create new changelog
        new_content = "# Changelog\n\n" * changelog_entry
    end
    
    write(CHANGELOG_FILE, new_content)
    println("✅ Updated $CHANGELOG_FILE")
end

"""
Generate release notes
"""
function generate_release_notes(version, commits)
    categorized = categorize_commits(commits)
    
    notes = """# Release Notes - Globtim.jl v$version

Released on $(Dates.format(now(), "yyyy-mm-dd"))

## What's New

"""
    
    if !isempty(categorized.features)
        notes *= "### ✨ New Features\n"
        for commit in categorized.features
            notes *= "- $commit\n"
        end
        notes *= "\n"
    end
    
    if !isempty(categorized.fixes)
        notes *= "### 🐛 Bug Fixes\n"
        for commit in categorized.fixes
            notes *= "- $commit\n"
        end
        notes *= "\n"
    end
    
    if !isempty(categorized.breaking)
        notes *= "### ⚠️ Breaking Changes\n"
        for commit in categorized.breaking
            notes *= "- $commit\n"
        end
        notes *= "\n"
    end
    
    notes *= """
## Installation

```julia
using Pkg
Pkg.add("Globtim")
```

## Documentation

- [Stable Documentation](https://gescholt.github.io/Globtim.jl/stable/)
- [Development Documentation](https://gescholt.github.io/Globtim.jl/dev/)

## Full Changelog

See [CHANGELOG.md](CHANGELOG.md) for the complete list of changes.
"""
    
    write(RELEASE_NOTES_FILE, notes)
    println("✅ Generated $RELEASE_NOTES_FILE")
    
    return notes
end

"""
Create git tag and push
"""
function create_git_tag(version)
    tag_name = "v$version"
    
    # Create annotated tag
    run(`git tag -a $tag_name -m "Release $tag_name"`)
    println("✅ Created git tag $tag_name")
    
    # Push tag (if in CI environment)
    if haskey(ENV, "CI")
        run(`git push origin $tag_name`)
        println("✅ Pushed tag to origin")
    else
        println("ℹ️  Run 'git push origin $tag_name' to push the tag")
    end
end

"""
Create GitLab release via API
"""
function create_gitlab_release(version, release_notes)
    if !haskey(ENV, "GITLAB_PRIVATE_TOKEN") || !haskey(ENV, "GITLAB_PROJECT_ID")
        println("⚠️  GitLab API credentials not found, skipping release creation")
        return
    end
    
    tag_name = "v$version"
    
    # Prepare release data
    release_data = Dict(
        "name" => "Globtim.jl $version",
        "tag_name" => tag_name,
        "description" => release_notes,
        "assets" => Dict(
            "links" => [
                Dict(
                    "name" => "Documentation",
                    "url" => "https://gescholt.github.io/Globtim.jl/stable/"
                ),
                Dict(
                    "name" => "Changelog",
                    "url" => "https://github.com/gescholt/Globtim.jl/blob/main/CHANGELOG.md"
                )
            ]
        )
    )
    
    # Save release data for GitLab CI
    open("gitlab_release.json", "w") do f
        JSON.print(f, release_data, 2)
    end
    
    println("✅ Prepared GitLab release data")
end

"""
Main release function
"""
function main()
    # Parse command line arguments
    bump_type = get(ARGS, 1, "patch")
    
    if !(bump_type in ["major", "minor", "patch"])
        println("Usage: julia auto-release.jl [major|minor|patch]")
        println("Default: patch")
        exit(1)
    end
    
    println("🚀 Globtim.jl Automated Release")
    println("=" ^ 40)
    
    # Get current version and calculate new version
    current_version = get_current_version()
    new_version = bump_version(current_version, bump_type)
    
    println("📦 Current version: $current_version")
    println("📦 New version: $new_version")
    println("📦 Bump type: $bump_type")
    
    # Get commits for changelog
    commits = get_commits_since_last_tag()
    println("📋 Found $(length(commits)) commits since last release")
    
    if isempty(commits)
        println("⚠️  No new commits found. Are you sure you want to release?")
        if !haskey(ENV, "CI")
            print("Continue? (y/N): ")
            response = readline()
            if lowercase(strip(response)) != "y"
                println("❌ Release cancelled")
                exit(0)
            end
        end
    end
    
    # Update version in Project.toml
    update_project_version(new_version)
    
    # Update changelog
    update_changelog(new_version, commits)
    
    # Generate release notes
    release_notes = generate_release_notes(new_version, commits)
    
    # Create git tag
    create_git_tag(new_version)
    
    # Prepare GitLab release
    create_gitlab_release(new_version, release_notes)
    
    println("\n✅ Release $new_version prepared successfully!")
    println("📋 Next steps:")
    println("   1. Review the generated files")
    println("   2. Commit changes: git add . && git commit -m 'Release $new_version'")
    println("   3. Push changes: git push")
    println("   4. The GitLab CI will create the release automatically")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
