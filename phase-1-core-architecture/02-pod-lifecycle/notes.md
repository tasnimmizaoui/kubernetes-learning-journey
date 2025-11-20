# Pod Lifecycle

## Init Containers
- Run sequentially before main containers
- Must complete successfully
- Use for: setup, waiting for dependencies, config generation

## Lifecycle Hooks

**postStart**: Runs after container starts (not guaranteed before ENTRYPOINT)
**preStop**: Runs before termination, blocks until complete

## Multi-container Patterns
- Sidecar: Helper containers (logging, monitoring)
- Shared volumes: emptyDir for container communication

## Pod Phases
Pending → Init:0/N → Init:1/N → PodInitializing → Running → Terminating

## Observed Behavior
- Init containers: sequential execution with clear timing
- postStart: Creates files immediately after container start
- preStop: 5-second delay observed during graceful shutdown
- Restart policies: Always/OnFailure/Never control restart behavior
