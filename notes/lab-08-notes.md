
## Step 3 - Ten times the traffic
First I would raise replicas (dimension 1) with an HPA, because it is the cheapest and fastest change, after checking that the pods are really CPU-bound and that the 50m request is realistic. Between steps I would watch for Pending pods and "Insufficient cpu" events, because those show the nodes are full. If they are, I would raise the node group's desiredSize (dimension 3) or install an autoscaler to do it. Only if a single pod or node shape were the bottleneck would I resize pods (dimension 2, which restarts them) or create a new, larger node group (dimension 4).

## Step 6 - QoS experiment
Before: Burstable. After raising requests to equal limits (200m/128Mi): Guaranteed. After restoring 50m/32Mi requests: Burstable again.
The pod was replaced, not adjusted, because requests and limits are part of the pod template, so changing them creates a new ReplicaSet and a rolling update. A running pod cannot be resized in place. This is dimension 2 from Step 3, and it is why VerticalPodAutoscaler is used far less than HPA.
I would want Guaranteed for a latency-sensitive or critical workload that must be evicted last under node pressure and needs predictable CPU.

## Step 10 - node group scaling (Conceptual on this build)
- describe-nodegroup works: min 2 / max 4 / desired 2, t3.small, labels workload=usms tier=app.
- update-nodegroup-config failed with UnknownOperationException
  (POST /clusters/usms-eks-cluster/node-groups/usms-eks-nodes/update-config).
  This Floci build does not implement the operation, so desiredSize stayed at 2.
- On real AWS this call returns an asynchronous Update object (InProgress); the
  Auto Scaling group then launches a third EC2 instance, which joins as Ready
  within minutes. Only then would Pending pods from Step 9 schedule.
- Raising replicas (HPA, Kubernetes API) and raising desiredSize (EKS API) are
  different operations. Nothing links them without a Cluster Autoscaler or Karpenter.

## Step 11 - nodeSelector (observed)
- Node group labels (workload=usms, tier=app) did not reach the node; applied by hand with kubectl label.
- This cluster has ONE node (k3s control-plane), so all pods share it.
- workload=nonexistent: new pod Pending, event "0/1 nodes are available: 1 node(s)
  didn't match Pod's node affinity/selector". Old pods kept serving (maxUnavailable: 0).
- Restored workload=usms; rollout completed. nodeSelector added to manifests/lab-07/20-enrolment.yaml.
- Cluster Autoscaler / Karpenter: named and compared, not installed (need IRSA and an ASG, unavailable here).

## Step 12 - PodDisruptionBudgets (observed)
- usms-gateway-pdb minAvailable 1 -> ALLOWED DISRUPTIONS 0; usms-enrolment-pdb maxUnavailable 1 -> 1.
- First eviction attempt: NotFound (Git Bash rewrote the /api path). Redone with MSYS_NO_PATHCONV=1.
- Eviction API on this build: BOTH the gateway (ALLOWED DISRUPTIONS 0) and an enrolment pod
  (ALLOWED DISRUPTIONS 1) returned "Forbidden: unknown" and both pods survived. Identical results
  for a pod the PDB blocks and one it allows mean the PDB is not what produced the error: this
  build rejects the eviction subresource itself. So the PDB-refuses-eviction behaviour was NOT
  observed here. On stock Kubernetes the gateway would return TooManyRequests and enrolment
  would be evicted and replaced.
- kubectl delete pod: deleted and replaced with no PDB objection (PDB not consulted).
- drain --dry-run=client lists every pod; one-node cluster, so a real drain was NOT run.


## Step 17 - Practical 2 and Practical 4, compared with both running

### Scaling

| Question | ECS + Application Auto Scaling | Kubernetes + HPA |
| --- | --- | --- |
| What integer is written? | | |
| Who writes it? | | |
| Where does that thing run? | | |
| Where does the metric come from? | | |
| What does "50% CPU" mean - 50% of what? | | |
| How is scale-in slowed down? | | |
| What happens if there is no capacity for the new instance/pod? | | |
| What creates the alarms, if anything? | | |

### Exposure

| Question | ECS + ALB (Lab 05) | Kubernetes + Ingress (Step 16) |
| --- | --- | --- |
| How many AWS objects did I create by hand? | | |
| What is the target type, and why? | | |
| How are targets registered and deregistered? | | |
| How are competing routing rules disambiguated? | | |
| What would I change to move this to another cloud? | | |
| What is the cost of exposing ten services? | | |

### Two paragraphs, in prose

1. If the AWS control plane has a bad afternoon, what happens to each of the two
   scaling arrangements, and which of them can I still debug?

2. For USMS specifically - one small team, one region, quiet for eight months and
   very busy for two - which would I choose, and what is the strongest argument
   AGAINST my own choice?
