# Issue #49 Phase 1 TDD Implementation Breakdown

**Epic**: Dagger.jl Adaptive Domain Optimization
**Phase**: Phase 1 - Foundation (Already 95% Complete)
**Approach**: Test-Driven Development (TDD)
**Status**: Foundation exists, enhancement needed

---

## Executive Summary

**Good News**: Issues #45-48 already completed the Phase 1 foundation! We have:
- ✅ Dagger.jl HPC compatibility validated (Issue #47)
- ✅ Test-first framework with 230+ tests (Issue #46)
- ✅ Basic job tracking and registry system
- ✅ Hook orchestrator integration (Issue #48)
- ✅ Visualization framework with interactive displays

**What's Missing for True Phase 1 Completion**:
1. **Intelligent Job Scheduling** (resource-aware distribution)
2. **Experiment Dependency Management** (multi-phase workflows)
3. **Dynamic Resource Allocation** (adaptive CPU/memory)
4. **Automatic Job Recovery** (failure detection & retry)

---

## Phase 1 Enhancement: TDD Breakdown

### Step 1: Intelligent Job Scheduling (3-5 days)

**TDD Cycle 1.1: Basic Job Priority System**
```
Test → Implement → Refactor
```

**Tests to Write First** (`test/specialized_tests/dagger_integration/test_intelligent_scheduling.jl`):
```julia
@testset "Job Priority System" begin
    # Test: Jobs can be assigned priority levels
    job1 = create_dagger_job("low_priority", "test.jl", priority=:low)
    job2 = create_dagger_job("high_priority", "test.jl", priority=:high)

    @test job1.priority == :low
    @test job2.priority == :high
    @test job2.priority_score > job1.priority_score
end

@testset "Priority Queue Management" begin
    # Test: Jobs are queued by priority
    scheduler = create_job_scheduler()

    enqueue_job!(scheduler, create_dagger_job("job_a", "a.jl", priority=:low))
    enqueue_job!(scheduler, create_dagger_job("job_b", "b.jl", priority=:high))
    enqueue_job!(scheduler, create_dagger_job("job_c", "c.jl", priority=:medium))

    next_job = dequeue_job!(scheduler)
    @test next_job.experiment_name == "job_b"  # High priority first
end
```

**Implementation** (`src/DaggerJobScheduler.jl` - create new module):
```julia
module DaggerJobScheduler

export JobPriority, JobScheduler, create_job_scheduler
export enqueue_job!, dequeue_job!, schedule_next_jobs

@enum JobPriority low=1 medium=5 high=10 critical=20

mutable struct JobScheduler
    queue::PriorityQueue{DaggerJobTracker, Int}
    running_jobs::Dict{String, DaggerJobTracker}
    max_concurrent_jobs::Int
    resource_monitor::ResourceMonitor
end

function create_job_scheduler(max_concurrent=4)
    JobScheduler(
        PriorityQueue{DaggerJobTracker, Int}(),
        Dict{String, DaggerJobTracker}(),
        max_concurrent,
        ResourceMonitor()
    )
end

function enqueue_job!(scheduler::JobScheduler, job::DaggerJobTracker)
    priority_score = Int(job.priority)
    enqueue!(scheduler.queue, job, priority_score)
end

# ... rest of implementation
end
```

**Refactor**: Extract priority calculation logic if complex

---

**TDD Cycle 1.2: Resource-Aware Scheduling**

**Tests to Write First**:
```julia
@testset "Resource-Aware Scheduling" begin
    # Test: Scheduler checks available resources
    scheduler = create_job_scheduler()

    # Mock high-memory job
    heavy_job = create_dagger_job("heavy", "heavy.jl",
                                  required_memory_gb=16.0,
                                  required_cpus=8)

    # Check if resources available
    can_schedule = check_resource_availability(scheduler, heavy_job)
    @test can_schedule isa Bool

    # Test resource reservation
    if can_schedule
        reserve_resources!(scheduler, heavy_job)
        @test scheduler.resource_monitor.reserved_memory >= 16.0
        @test scheduler.resource_monitor.reserved_cpus >= 8
    end
end

@testset "Resource Monitoring" begin
    # Test: System resources are monitored
    monitor = ResourceMonitor()

    resources = get_system_resources(monitor)
    @test haskey(resources, "available_memory_gb")
    @test haskey(resources, "available_cpus")
    @test haskey(resources, "total_memory_gb")
    @test resources["available_memory_gb"] > 0.0
end
```

**Implementation** (`src/DaggerResourceMonitor.jl` - create new module):
```julia
module DaggerResourceMonitor

using Sys: total_memory, cpu_info

export ResourceMonitor, get_system_resources, check_resource_availability
export reserve_resources!, release_resources!

mutable struct ResourceMonitor
    total_memory_gb::Float64
    available_memory_gb::Float64
    reserved_memory_gb::Float64
    total_cpus::Int
    available_cpus::Int
    reserved_cpus::Int

    function ResourceMonitor()
        total_mem = total_memory() / 1024^3  # Convert to GB
        total_cpus = length(cpu_info())
        new(total_mem, total_mem, 0.0, total_cpus, total_cpus, 0)
    end
end

function get_system_resources(monitor::ResourceMonitor)
    # Update with current usage
    update_resource_usage!(monitor)

    return Dict(
        "total_memory_gb" => monitor.total_memory_gb,
        "available_memory_gb" => monitor.available_memory_gb,
        "reserved_memory_gb" => monitor.reserved_memory_gb,
        "total_cpus" => monitor.total_cpus,
        "available_cpus" => monitor.available_cpus,
        "reserved_cpus" => monitor.reserved_cpus
    )
end

# ... rest of implementation
end
```

---

**TDD Cycle 1.3: Adaptive Job Distribution**

**Tests to Write First**:
```julia
@testset "Adaptive Job Distribution" begin
    # Test: Jobs distributed based on worker load
    scheduler = create_job_scheduler()

    # Create 10 jobs
    jobs = [create_dagger_job("job_$i", "test.jl") for i in 1:10]
    for job in jobs
        enqueue_job!(scheduler, job)
    end

    # Schedule jobs adaptively
    scheduled = schedule_next_jobs(scheduler)

    @test length(scheduled) <= scheduler.max_concurrent_jobs
    @test all(job -> job.status == :scheduled, scheduled)
end

@testset "Worker Load Balancing" begin
    # Test: Jobs distributed to least-loaded workers
    scheduler = create_job_scheduler()

    # Mock worker loads
    set_worker_load!(scheduler, 2, 0.8)  # Worker 2 is 80% loaded
    set_worker_load!(scheduler, 3, 0.2)  # Worker 3 is 20% loaded

    job = create_dagger_job("test", "test.jl")
    assigned_worker = assign_worker(scheduler, job)

    @test assigned_worker == 3  # Assign to less-loaded worker
end
```

**Implementation**: Extend `DaggerJobScheduler.jl` with load balancing logic

---

### Step 2: Experiment Dependency Management (3-5 days)

**TDD Cycle 2.1: Job Dependency Graph**

**Tests to Write First** (`test/specialized_tests/dagger_integration/test_dependency_management.jl`):
```julia
@testset "Job Dependency Declaration" begin
    # Test: Jobs can declare dependencies
    job_a = create_dagger_job("data_prep", "prep.jl")
    job_b = create_dagger_job("analysis", "analyze.jl",
                              depends_on=[job_a.job_id])
    job_c = create_dagger_job("visualization", "viz.jl",
                              depends_on=[job_b.job_id])

    @test length(job_b.dependencies) == 1
    @test job_a.job_id in job_b.dependencies
    @test length(job_c.dependencies) == 1
    @test job_b.job_id in job_c.dependencies
end

@testset "Dependency Graph Validation" begin
    # Test: Detect circular dependencies
    graph = DependencyGraph()

    job_a = create_dagger_job("a", "a.jl")
    job_b = create_dagger_job("b", "b.jl", depends_on=[job_a.job_id])
    job_c = create_dagger_job("c", "c.jl", depends_on=[job_b.job_id])

    add_job!(graph, job_a)
    add_job!(graph, job_b)
    add_job!(graph, job_c)

    @test is_valid_dag(graph) == true

    # Try to create circular dependency
    @test_throws DependencyError add_dependency!(graph, job_a.job_id, job_c.job_id)
end

@testset "Dependency Resolution" begin
    # Test: Only schedule jobs when dependencies complete
    scheduler = create_job_scheduler()

    job_a = create_dagger_job("a", "a.jl")
    job_b = create_dagger_job("b", "b.jl", depends_on=[job_a.job_id])

    enqueue_job!(scheduler, job_a)
    enqueue_job!(scheduler, job_b)

    # Schedule first batch
    scheduled = schedule_next_jobs(scheduler)
    @test job_a in scheduled
    @test job_b ∉ scheduled  # Not ready yet

    # Complete job_a
    mark_job_completed!(scheduler, job_a.job_id)

    # Schedule second batch
    scheduled = schedule_next_jobs(scheduler)
    @test job_b in scheduled  # Now ready
end
```

**Implementation** (`src/DaggerDependencyGraph.jl` - create new module):
```julia
module DaggerDependencyGraph

export DependencyGraph, add_job!, add_dependency!
export is_valid_dag, get_ready_jobs, mark_completed!

struct DependencyError <: Exception
    message::String
end

mutable struct DependencyGraph
    jobs::Dict{String, DaggerJobTracker}
    dependencies::Dict{String, Set{String}}  # job_id => set of dependency job_ids
    dependents::Dict{String, Set{String}}    # job_id => set of jobs waiting on this
    completed::Set{String}

    function DependencyGraph()
        new(
            Dict{String, DaggerJobTracker}(),
            Dict{String, Set{String}}(),
            Dict{String, Set{String}}(),
            Set{String}()
        )
    end
end

function add_job!(graph::DependencyGraph, job::DaggerJobTracker)
    graph.jobs[job.job_id] = job
    graph.dependencies[job.job_id] = Set(job.dependencies)

    # Update dependents
    for dep_id in job.dependencies
        if !haskey(graph.dependents, dep_id)
            graph.dependents[dep_id] = Set{String}()
        end
        push!(graph.dependents[dep_id], job.job_id)
    end
end

function is_valid_dag(graph::DependencyGraph)::Bool
    # Check for cycles using DFS
    visited = Set{String}()
    in_stack = Set{String}()

    function has_cycle(job_id::String)::Bool
        if job_id in in_stack
            return true  # Cycle detected
        end
        if job_id in visited
            return false
        end

        push!(visited, job_id)
        push!(in_stack, job_id)

        for dep_id in get(graph.dependencies, job_id, Set{String}())
            if has_cycle(dep_id)
                return true
            end
        end

        pop!(in_stack, job_id)
        return false
    end

    for job_id in keys(graph.jobs)
        if has_cycle(job_id)
            return false
        end
    end

    return true
end

function get_ready_jobs(graph::DependencyGraph)::Vector{DaggerJobTracker}
    ready = DaggerJobTracker[]

    for (job_id, job) in graph.jobs
        if job.status == :pending
            # Check if all dependencies completed
            deps = get(graph.dependencies, job_id, Set{String}())
            if all(dep_id -> dep_id in graph.completed, deps)
                push!(ready, job)
            end
        end
    end

    return ready
end

# ... rest of implementation
end
```

---

### Step 3: Dynamic Resource Allocation (2-3 days)

**TDD Cycle 3.1: Adaptive Memory Allocation**

**Tests to Write First** (`test/specialized_tests/dagger_integration/test_dynamic_resources.jl`):
```julia
@testset "Dynamic Memory Allocation" begin
    # Test: Jobs can request minimum and preferred memory
    job = create_dagger_job("adaptive", "test.jl",
                           min_memory_gb=4.0,
                           preferred_memory_gb=16.0)

    @test job.resource_requirements.min_memory_gb == 4.0
    @test job.resource_requirements.preferred_memory_gb == 16.0

    # Test allocation based on availability
    scheduler = create_job_scheduler()
    allocated = allocate_resources(scheduler, job)

    @test allocated.memory_gb >= job.resource_requirements.min_memory_gb
    @test allocated.memory_gb <= job.resource_requirements.preferred_memory_gb
end

@testset "Resource Scaling" begin
    # Test: Resources scale based on system load
    scheduler = create_job_scheduler()

    # Low system load - give preferred resources
    set_system_load!(scheduler, 0.2)
    job = create_dagger_job("test", "test.jl",
                           min_memory_gb=4.0,
                           preferred_memory_gb=16.0)
    allocated = allocate_resources(scheduler, job)
    @test allocated.memory_gb ≈ 16.0 atol=1.0

    # High system load - give minimum resources
    set_system_load!(scheduler, 0.9)
    allocated = allocate_resources(scheduler, job)
    @test allocated.memory_gb ≈ 4.0 atol=1.0
end
```

**Implementation**: Extend `DaggerResourceMonitor.jl` with adaptive allocation

---

### Step 4: Automatic Job Recovery (2-3 days)

**TDD Cycle 4.1: Failure Detection**

**Tests to Write First** (`test/specialized_tests/dagger_integration/test_job_recovery.jl`):
```julia
@testset "Job Failure Detection" begin
    # Test: Failed jobs are detected
    job = create_dagger_job("failing_job", "fail.jl")
    job.status = :running

    # Simulate failure
    mark_job_failed!(job, "Out of memory")

    @test job.status == :failed
    @test job.failure_reason == "Out of memory"
    @test job.retry_count == 0
end

@testset "Automatic Retry Logic" begin
    # Test: Failed jobs are automatically retried
    recovery_manager = RecoveryManager(max_retries=3)

    job = create_dagger_job("retry_test", "test.jl")
    mark_job_failed!(job, "Temporary network error")

    should_retry = check_retry_eligibility(recovery_manager, job)
    @test should_retry == true

    # Retry job
    retry_job!(recovery_manager, job)
    @test job.status == :pending
    @test job.retry_count == 1

    # Fail again twice more
    for i in 2:3
        mark_job_failed!(job, "Still failing")
        retry_job!(recovery_manager, job)
        @test job.retry_count == i
    end

    # Fourth failure - no more retries
    mark_job_failed!(job, "Permanent failure")
    should_retry = check_retry_eligibility(recovery_manager, job)
    @test should_retry == false
    @test job.status == :failed
end

@testset "Exponential Backoff" begin
    # Test: Retry delays increase exponentially
    recovery_manager = RecoveryManager(
        max_retries=3,
        base_delay_seconds=10.0,
        backoff_multiplier=2.0
    )

    delays = [calculate_retry_delay(recovery_manager, i) for i in 1:3]

    @test delays[1] ≈ 10.0
    @test delays[2] ≈ 20.0
    @test delays[3] ≈ 40.0
end
```

**Implementation** (`src/DaggerJobRecovery.jl` - create new module):
```julia
module DaggerJobRecovery

export RecoveryManager, mark_job_failed!, retry_job!
export check_retry_eligibility, calculate_retry_delay

mutable struct RecoveryManager
    max_retries::Int
    base_delay_seconds::Float64
    backoff_multiplier::Float64
    retry_history::Dict{String, Vector{DateTime}}

    function RecoveryManager(;
        max_retries=3,
        base_delay_seconds=10.0,
        backoff_multiplier=2.0
    )
        new(max_retries, base_delay_seconds, backoff_multiplier, Dict{String, Vector{DateTime}}())
    end
end

function mark_job_failed!(job::DaggerJobTracker, reason::String)
    job.status = :failed
    job.failure_reason = reason
    job.failed_at = now()
end

function check_retry_eligibility(manager::RecoveryManager, job::DaggerJobTracker)::Bool
    return job.retry_count < manager.max_retries
end

function calculate_retry_delay(manager::RecoveryManager, retry_attempt::Int)::Float64
    return manager.base_delay_seconds * (manager.backoff_multiplier ^ (retry_attempt - 1))
end

# ... rest of implementation
end
```

---

## Implementation Timeline

| Step | Feature | Duration | Tests | Implementation |
|------|---------|----------|-------|----------------|
| 1.1 | Job Priority System | 1 day | 2 test sets, ~20 tests | `DaggerJobScheduler.jl` |
| 1.2 | Resource-Aware Scheduling | 2 days | 3 test sets, ~30 tests | `DaggerResourceMonitor.jl` |
| 1.3 | Adaptive Distribution | 1-2 days | 2 test sets, ~20 tests | Extend scheduler |
| 2.1 | Dependency Graph | 2 days | 4 test sets, ~40 tests | `DaggerDependencyGraph.jl` |
| 2.2 | Dependency Resolution | 1-2 days | 2 test sets, ~20 tests | Integrate with scheduler |
| 3.1 | Dynamic Resources | 2-3 days | 3 test sets, ~30 tests | Extend resource monitor |
| 4.1 | Job Recovery | 2-3 days | 4 test sets, ~35 tests | `DaggerJobRecovery.jl` |

**Total Duration**: 11-17 days (2-3.5 weeks)

---

## TDD Workflow for Each Feature

```
┌─────────────────────────────────────────┐
│ 1. Write Failing Tests                 │
│    - Define expected behavior           │
│    - Test edge cases                    │
│    - Run tests (should fail)            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 2. Implement Minimum Code              │
│    - Make tests pass                    │
│    - No extra features                  │
│    - Run tests (should pass)            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 3. Refactor                             │
│    - Clean up code                      │
│    - Extract common patterns            │
│    - Run tests (still pass)             │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 4. Integration Tests                    │
│    - Test with existing system          │
│    - Verify zero regression             │
│    - Document usage                     │
└─────────────────────────────────────────┘
```

---

## Success Criteria for Phase 1 Enhancement

### Functional Requirements
- ✅ Job priority system with 4 levels (low, medium, high, critical)
- ✅ Resource-aware scheduling (memory + CPU)
- ✅ Dependency management with DAG validation
- ✅ Automatic retry with exponential backoff
- ✅ Zero regression on existing pipeline

### Test Coverage Requirements
- ✅ Minimum 95% code coverage on new modules
- ✅ All edge cases tested (circular deps, resource exhaustion, etc.)
- ✅ Integration tests with existing Dagger pipeline
- ✅ Performance tests (no >5% overhead)

### Performance Requirements
- ✅ Job scheduling latency: <100ms
- ✅ Dependency resolution: <50ms for graphs with <1000 nodes
- ✅ Resource monitoring overhead: <2% CPU usage
- ✅ Recovery detection: <5 seconds

---

## Next Steps

1. **Immediate**: Start with Step 1.1 (Job Priority System)
   - Create `test/specialized_tests/dagger_integration/test_intelligent_scheduling.jl`
   - Write priority tests first
   - Run tests (watch them fail)
   - Implement `DaggerJobScheduler.jl`
   - Run tests (watch them pass)

2. **After Step 1**: Move to Step 2 (Dependency Management)
3. **After Step 2**: Add Step 3 (Dynamic Resources)
4. **After Step 3**: Finish with Step 4 (Recovery)

5. **Final**: Integration test with actual Lotka-Volterra experiments

---

## Related Issues

- **Foundation**: #45 (Integration), #46 (Testing), #47 (HPC), #48 (Hooks)
- **Next Phase**: #49 Phase 2 (Mathematical Intelligence)
- **Epic**: #137 (Automation & Monitoring)

---

**Document Status**: Ready for implementation
**Last Updated**: 2025-10-06
**Author**: GlobTim Team via Claude Code
