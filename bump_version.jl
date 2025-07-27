#!/usr/bin/env julia

# Simple version bumping script for Globtim.jl
# Usage: julia bump_version.jl [patch|minor|major]

using TOML

# Read current version
project = TOML.parsefile("Project.toml")
current_version = VersionNumber(project["version"])

# Parse command line argument
bump_type = length(ARGS) > 0 ? ARGS[1] : "patch"

# Calculate new version
if bump_type == "patch"
    new_version = VersionNumber(
        current_version.major,
        current_version.minor,
        current_version.patch + 1,
    )
elseif bump_type == "minor"
    new_version = VersionNumber(current_version.major, current_version.minor + 1, 0)
elseif bump_type == "major"
    new_version = VersionNumber(current_version.major + 1, 0, 0)
else
    error("Invalid bump type. Use 'patch', 'minor', or 'major'")
end

# Update Project.toml
project["version"] = string(new_version)

# Write back to file
open("Project.toml", "w") do io
    TOML.print(io, project)
end

println("Version bumped from $current_version to $new_version")
println("\nNext steps:")
println(
    "1. Commit the version change: git add Project.toml && git commit -m \"Bump version to v$new_version\"",
)
println("2. Push to main branch: git push origin main")
println(
    "3. The GitHub Actions will automatically sync to github-release branch and create a release",
)
