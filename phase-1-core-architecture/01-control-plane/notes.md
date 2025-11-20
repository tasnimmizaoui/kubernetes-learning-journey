# Control Plane Components

## Key Concepts

**API Server**: Gateway for all cluster operations. Only component that talks to etcd.

**etcd**: Key-value store using Raft consensus. Stores all cluster state.

**Scheduler**: Assigns pods to nodes via filtering (eliminate unsuitable nodes) and scoring (rank remaining nodes).

**Controller Manager**: Runs reconciliation loops. Watch → Compare → Act pattern.

## Observations

- API requests processed in ~10ms
- Controllers use watch (not polling) for efficiency
- Reconciliation happens in seconds when state changes
