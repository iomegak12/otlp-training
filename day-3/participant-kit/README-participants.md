# TradeNova Day 3 — Light Kit for Participants

During the session your instructor runs the full lab on a four-node cluster. This kit lets you replay **every Day 3 lab** afterwards on your own laptop, on a single virtual machine.

What's different from the instructor's cluster:

| | Instructor | Light kit |
| --- | --- | --- |
| Virtual machines | 4 (1 control plane + 3 workers) | 1 (does everything) |
| Kafka | 3 brokers, 6 partitions per topic | 1 broker, 3 partitions per topic |
| Applications | 2 replicas each | 1 replica each |
| Gateways | autoscale 2 → 6 | autoscale 2 → 6, but only 3 get a Kafka partition (a nice way to *see* the partition ceiling) |
| Burst in Lab 1 | 1000 traces/s per worker | 300 traces/s per worker |

Everything else — the Collector configurations, the labs, the scripts, the dashboard — is identical.

## What you need

- A laptop with **16 GB RAM** (the VM takes 8 GB; close other heavy programs), 4 CPU cores and 40 GB of free disk.
- Windows 10/11 Pro (Hyper-V) or macOS or Linux.
- About 40 minutes and a good internet connection for the first install.

Install the tools (Windows, in PowerShell):

```powershell
winget install Git.Git Canonical.Multipass Kubernetes.kubectl Helm.Helm
```

On macOS: `brew install multipass kubectl helm`. Run all commands below in **Git Bash** (Windows) or a normal terminal (macOS/Linux).

## Install

1. Unzip the bundle and open a terminal in the `tradenova-day3-k8s` folder.
2. Edit `lab.env`:
   ```bash
   LIGHT_MODE=1
   REGISTRY=<the value your instructor gave you>     # for example docker.io/tradenova-training
   ```
   You do **not** need to build any images; you use the instructor's.
3. Run:
   ```bash
   participant-kit/install-all.sh
   ```
   It creates the VM `tn-solo`, installs k3s, then the whole platform. When it finishes it prints the Grafana and Prometheus addresses.
4. Check:
   ```bash
   scripts/status.sh
   ```
   Give it 5 minutes, then look for traces in **Grafana → Explore → Tempo (shared)**.

## Do the labs

Follow the instructor's demo — every command in it works the same here. The key commands:

| Lab | Start state | Apply the fix |
| --- | --- | --- |
| 1: Operator, auto-instrumentation, scaling | `scripts/reset-labs.sh` | `scripts/apply-lab.sh 1` |
| 2: Persistent queues | `scripts/apply-lab.sh 1` | `scripts/apply-lab.sh 2` |
| 3: Collector health + broken pipelines | `scripts/apply-lab.sh 2` | `labs/lab3-collector-health/fix.sh N` |
| 4: Security and governance | `scripts/apply-lab.sh 3` | `scripts/apply-lab.sh 4` |

Lab scripts live in `labs/<lab>/`. Each one has a comment at the top saying what it does.

## Stop, restart, remove

- Pause: `multipass stop tn-solo` — Resume: `multipass start tn-solo`, wait 3–4 minutes, `scripts/status.sh`.
- If the VM's IP changed after a restart (Windows does this sometimes), run `participant-kit/create-single-vm.sh` again; it keeps the VM and refreshes the connection.
- Back to the start of Day 3: `scripts/reset-labs.sh`.
- Remove everything: `participant-kit/destroy-single-vm.sh`.

## If something doesn't work

| Symptom | Try |
| --- | --- |
| `ImagePullBackOff` | `REGISTRY` in `lab.env` doesn't match the instructor's value. Fix it, then `helm/install-platform.sh`. |
| Pods `Pending`, "Insufficient memory" | Close other programs; or give the VM more memory (`LIGHT_VM_MEMORY=10G`) and recreate it. |
| Grafana doesn't open | Run `scripts/port-forward.sh` and use http://localhost:3000. |
| Anything else | `scripts/status.sh` shows what isn't running; `kubectl describe pod <name> -n <namespace>` shows why. |
