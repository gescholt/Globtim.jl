# Remove test/Manifest.toml to prevent version conflicts
# The test environment should use the parent project's resolved dependencies

test_manifest = joinpath(@__DIR__, "..", "test", "Manifest.toml")

if isfile(test_manifest)
    rm(test_manifest)
    println("Removed test/Manifest.toml")
else
    println("No test/Manifest.toml to remove")
end
