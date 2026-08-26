"""
    ExperimentLedger

Per-run provenance records and the append-only experiment ledger.

Purpose: stay honest about which experiments produced outputs, which runs
iterate on which, and never lose or hallucinate a run. Every run emits a
self-describing `ledger_record.json` into its output directory — the
distributed source of truth, traveling with the artifacts through rsync/git.
The git-tracked union of all records is `experiments/ledger.jsonl`, appended
opportunistically here and reconciled by `infra/tools/ledger_collect.jl`.
Invariants (existence, staleness against `experiments/invalidations.toml`,
supersession lineage, claims linkage) are checked by
`infra/tools/ledger_check.jl`.

A record is a fact keyed by `run_id`; the ledger is the union of facts, so
two machines appending independently never conflict — collection dedupes by
`run_id`. The git SHA is stored bare (`git rev-parse HEAD`, not a describe
string) because the staleness check feeds it to `git merge-base
--is-ancestor`.
"""
module ExperimentLedger

using JSON3
using SHA
using Dates

export emit_ledger_record

"""
Walk up from `start` to the enclosing git repository root, or `nothing`.
"""
function find_repo_root(start::AbstractString)
    dir = abspath(start)
    while true
        isdir(joinpath(dir, ".git")) && return dir
        parent = dirname(dir)
        parent == dir && return nothing
        dir = parent
    end
end

sha256_file(path::AbstractString) = open(io -> bytes2hex(sha256(io)), path)

# Repo-relative path when inside the repo, absolute otherwise (an outdir
# outside the repo must not be stored as an ../.. escape chain).
function _rel_to_root(path::AbstractString, repo_root::Union{AbstractString,Nothing})
    repo_root === nothing && return abspath(path)
    r = relpath(abspath(path), repo_root)
    return startswith(r, "..") ? abspath(path) : r
end

function _git_state(repo_root::Union{AbstractString,Nothing})
    repo_root === nothing && return ("unknown", false)
    sha = try
        readchomp(`git -C $repo_root rev-parse HEAD`)
    catch
        "unknown"
    end
    dirty = try
        !isempty(readchomp(`git -C $repo_root status --porcelain --untracked-files=no`))
    catch
        false
    end
    return (sha, dirty)
end

_sanitize_slug(s::AbstractString) = replace(s, r"[^A-Za-z0-9_.-]" => "-")

"""
    emit_ledger_record(; slug, outdir, kwargs...) -> run_id

Write `<outdir>/ledger_record.json` describing one experiment run, and append
the same record as one line to `<repo_root>/experiments/ledger.jsonl` when the
enclosing repo can be located (cluster clones without the ledger file still get
the in-dir record; `ledger_collect.jl` picks it up after results sync).

# Keyword arguments
- `slug`: experiment identity that successive runs iterate on (e.g.
  `"daisy7d_capture"`). Sanitized to `[A-Za-z0-9_.-]`.
- `outdir`: the run's output directory (must exist).
- `headline`: small Dict of the few numbers one would cite from this run
  (values must be JSON-safe; non-finite floats are stored as `nothing`).
- `artifacts`: paths relative to `outdir` to record with sha256; default:
  every regular file directly in `outdir` (excluding the record itself).
- `config_path`: path of the config that produced the run, if any (hashed).
- `supersedes`: run_ids of earlier runs this one replaces.
- `bead`: bd issue id this run belongs to.
- `status`: `"completed"` (default), `"failed"`, or `"interrupted"`.
- `job_id`: scheduler job id; defaults to `ENV["SLURM_JOB_ID"]` when set.
- `manual`: `true` for hand-written / backfilled records (two-tier trust).
- `append_to_ledger`: pass `false` to write only the in-dir record (tests,
  scratch experiments that must not enter the central ledger). Defaults to
  the env switch `GLOBTIM_LEDGER_APPEND` (unset/1 = append) — cluster jobs
  export `GLOBTIM_LEDGER_APPEND=0` so the tracked ledger.jsonl never gets
  dirtied on the clone (which would block its ff-only pulls); their in-dir
  records reach the ledger through ledger_collect.jl after results sync.
"""
function emit_ledger_record(;
    slug::AbstractString,
    outdir::AbstractString,
    headline::AbstractDict = Dict{String,Any}(),
    artifacts::Union{Vector{String},Nothing} = nothing,
    config_path::Union{AbstractString,Nothing} = nothing,
    supersedes::Vector{String} = String[],
    bead::Union{AbstractString,Nothing} = nothing,
    status::AbstractString = "completed",
    job_id = get(ENV, "SLURM_JOB_ID", nothing),
    manual::Bool = false,
    append_to_ledger::Bool = get(ENV, "GLOBTIM_LEDGER_APPEND", "1") != "0",
)
    isdir(outdir) || error("emit_ledger_record: outdir does not exist: $outdir")
    slug_s = _sanitize_slug(slug)
    repo_root = find_repo_root(outdir)
    repo_root === nothing && (repo_root = find_repo_root(pwd()))
    code_sha, dirty = _git_state(repo_root)

    stamp = Dates.format(Dates.now(), "yyyymmddTHHMMSS")
    run_id = job_id === nothing ? "$(stamp)_$(slug_s)" : "$(stamp)_$(slug_s)_job$(job_id)"

    if artifacts === nothing
        artifacts = sort(
            filter(
                f -> f != "ledger_record.json" && isfile(joinpath(outdir, f)),
                readdir(outdir),
            ),
        )
    end
    artifact_records = map(artifacts) do rel
        p = joinpath(outdir, rel)
        isfile(p) || error("emit_ledger_record: artifact not found: $p")
        Dict{String,Any}("path" => rel, "sha256" => sha256_file(p), "bytes" => filesize(p))
    end

    headline_safe = Dict{String,Any}(
        string(k) => (v isa AbstractFloat && !isfinite(v) ? nothing : v) for
        (k, v) in headline
    )

    rel_outdir = _rel_to_root(outdir, repo_root)

    record = Dict{String,Any}(
        "run_id" => run_id,
        "slug" => slug_s,
        "status" => status,
        "manual" => manual,
        "timestamp" => Dates.format(Dates.now(), Dates.ISODateTimeFormat),
        "host" => gethostname(),
        "job_id" => job_id,
        "code_sha" => code_sha,
        "dirty" => dirty,
        "outdir" => rel_outdir,
        "artifacts" => artifact_records,
        "headline" => headline_safe,
        "supersedes" => supersedes,
        "bead" => bead,
    )
    if config_path !== nothing
        isfile(config_path) ||
            error("emit_ledger_record: config_path not found: $config_path")
        record["config_path"] = _rel_to_root(config_path, repo_root)
        record["config_sha256"] = sha256_file(config_path)
    end

    open(joinpath(outdir, "ledger_record.json"), "w") do io
        JSON3.pretty(io, record)
    end

    # Opportunistic append to the central ledger (single write of one line —
    # atomic enough under O_APPEND for concurrent local runs). Cluster clones
    # rely on ledger_collect.jl after results sync instead.
    if append_to_ledger && repo_root !== nothing
        ledger = joinpath(repo_root, "experiments", "ledger.jsonl")
        if isdir(dirname(ledger))
            open(ledger, "a") do io
                write(io, JSON3.write(record) * "\n")
            end
        else
            @debug "ExperimentLedger: no experiments/ dir at $repo_root; in-dir record only"
        end
    else
        @debug "ExperimentLedger: repo root not found; in-dir record only"
    end

    return run_id
end

end # module ExperimentLedger
