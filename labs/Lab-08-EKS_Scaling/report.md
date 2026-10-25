# Lab 08 Report: EKS Scaling and Service Exposure

**Course project:** University Student Management System (USMS)
**Role:** Junior Cloud Engineer, College of Science and Technology
**Environment:** Floci (local AWS emulator) with a k3s-based Kubernetes cluster, using the AWS CLI and kubectl

---

## 1. Aim / Objective

To scale the USMS workloads on Amazon EKS (Kubernetes) and expose them to users, by:

- scaling pods manually, through manifests, and automatically with a HorizontalPodAutoscaler (HPA)
- understanding resource requests, limits and QoS classes
- scaling the node group from the AWS side using the AWS CLI
- restricting pod placement with a node selector and protecting availability with PodDisruptionBudgets (PDBs)
- climbing the service exposure ladder: ClusterIP, port-forward, NodePort, LoadBalancer and Ingress
- verifying that scaling and exposure configuration survives a restart

---

## 2. Introduction

Amazon Elastic Kubernetes Service (EKS) is AWS's managed Kubernetes service. It runs the Kubernetes control plane for you, while the application runs on worker nodes grouped into managed node groups. Its key features include automatic workload scaling through the HorizontalPodAutoscaler, node scaling through node group settings or tools such as Cluster Autoscaler and Karpenter, and several ways of exposing applications (Services, load balancers and Ingress). It matters in cloud computing because applications must grow when demand rises and shrink when it falls, without downtime or wasted cost. Typical applications include web portals, APIs and microservices that face uneven traffic, such as a university system that is quiet for most of the year and very busy during enrolment and results periods.

---

## 3. Use Case

- **Student portal at peak times:** the `usms-enrolment` service receives far more requests during enrolment week. An HPA adds pods automatically and removes them once the rush is over.
- **Safe maintenance:** PodDisruptionBudgets keep enough pods running while nodes are drained for upgrades.
- **Exposing services:** a LoadBalancer Service or an Ingress gives students one public entry point, routing `/enrolment` and `/results` to the correct backend.

---

## 4. System Architecture / Design

![alt text](<aws-architecture-diagram (3).png>)

```
                        Students (internet)
                               |
                  Ingress  (usms-portal-ingress)
             /enrolment        /results         /
                 |                |              |
          usms-enrolment     usms-results    usms-gateway  <-- LoadBalancer Service
            (ClusterIP)       (ClusterIP)     (ClusterIP    (+ usms-results-np
                 |                |           + NodePort)      NodePort 30080)
                 v                v              v
        +----------------+  +-------------+  +-----------+
        | enrolment pods |  | results pods|  | gateway   |
        |  2 to 8 (HPA)  |  |     2       |  |   pod     |
        +----------------+  +-------------+  +-----------+
                 ^
                 |  reads CPU every 15s
        HorizontalPodAutoscaler  <--- metrics-server <--- kubelet
        (min 2, max 8, 50% of 50m request)

   PodDisruptionBudgets: gateway minAvailable 1, enrolment maxUnavailable 1

   Infrastructure layer:  EKS node group usms-eks-nodes
                          (AWS CLI: min / max / desired size)
   Load generator:        usms-loadgen (3 pods) ---> gateway ---> enrolment
```

**Data flow:** a request enters through the Ingress or LoadBalancer, reaches the gateway, and is forwarded to the enrolment or results pods. The HPA watches enrolment CPU through metrics-server and changes the replica count.

---

## 5. Implementation Procedure

| Step | What was done |
|------|---------------|
| 1 | Started Floci, sourced the config files from earlier labs, set the namespace to `usms`, and checked that enrolment has a CPU request and that the cluster has the `_lb_ports_` tag. |
| 2 | Recorded a baseline of Deployments, endpoints, Service types and nodes. |
| 3 | Studied the four dimensions of scaling and wrote a plan for ten times the traffic. |
| 4 | Scaled `usms-enrolment` from 2 to 5 pods with `kubectl scale`, confirmed traffic spread, then scaled back to 2. |
| 5 | Created configuration drift (cluster 6, file 2), watched `kubectl apply` undo it, and used `kubectl diff` as the safe habit. |
| 6 | Read QoS classes, inspected the scheduler's CPU arithmetic, and changed `usms-gateway` to Guaranteed and back. |
| 7 | Checked the metrics API and confirmed `kubectl top` returns data. |
| 8 | Created `usms-enrolment-hpa` (autoscaling/v2, min 2, max 8, CPU 50%, fast scale-up, slow scale-down). |
| 9 | Wrote `hpa-watch.sh`, ran the `usms-loadgen` load generator, watched replicas rise, then removed the load. |
| 10 | Read the node group from AWS and tried to raise it to min 2, max 6, desired 3. |
| 11 | Labelled nodes, added a `nodeSelector`, proved enforcement with a wrong value, then restored it. |
| 12 | Created PDBs for the gateway and enrolment, compared eviction with delete, and ran a drain dry run. |
| 13 | Confirmed the ClusterIP is unreachable from the laptop and used `port-forward` to tunnel to it. |
| 14 | Created the pinned NodePort Service `usms-results-np` (30080). |
| 15 | Promoted `usms-gateway` to a LoadBalancer Service with AWS annotations. |
| 16 | Created `usms-portal-ingress` with three path rules and tested the routes in-cluster. |
| 17 | Inspected both ECS and EKS stacks and created the comparison notes. |
| 18 | Recorded configuration, stopped and restarted Floci, and compared before and after. |
| 19 | Wrote `configs/lab-08.env`, the verify script and the cleanup script. |

---

## 6. Results and Evidence

### 6.1 CLI / SDK Output

#### Environment and baseline (Steps 1 and 2)

Environment started and configs sourced:

![Environment started](../../screenshots/lab8/image.png)
![Configs sourced](../../screenshots/lab8/image-1.png)
![Context and namespace](../../screenshots/lab8/image-2.png)

The two checks (CPU request and `_lb_ports_` tag):

![Two checks](../../screenshots/lab8/image-3.png)

Baseline snapshot, with all Services as ClusterIP and no external address:

![Baseline](../../screenshots/lab8/image-4.png)

#### Manual scaling (Step 4)

Scaling `usms-enrolment` up to 5 replicas:

![Watcher and scale up](../../screenshots/lab8/image-5.png)
![Scale up result](../../screenshots/lab8/image-6.png)
![Endpoints grew](../../screenshots/lab8/image-7.png)

Traffic spreading across the pods through the gateway:

![Traffic spread](../../screenshots/lab8/image-8.png)

Scaling back down to 2:

![Scale down](../../screenshots/lab8/image-9.png)

#### Configuration drift (Step 5)

Cluster set to 6 replicas while the file says 2:

![Drift created](../../screenshots/lab8/image-10.png)

`kubectl apply` silently reset the replicas to 2:

![Apply undid the scaling](../../screenshots/lab8/image-11.png)

Using `kubectl diff` before applying a change to 3, then restoring 2:

![Diff and apply](../../screenshots/lab8/image-12.png)
![Baseline restored](../../screenshots/lab8/image-13.png)

#### Requests, limits and QoS (Step 6)

QoS classes of all pods (Burstable) and the scheduler's CPU allocation on the node:

![QoS classes](../../screenshots/lab8/image-14.png)
![Scheduler arithmetic](../../screenshots/lab8/image-15.png)

The HPA denominator (50% of a 50m request is about 25m per pod):

![HPA denominator](../../screenshots/lab8/image-16.png)

Gateway pod before the change, as Guaranteed, and back to Burstable:

![Before](../../screenshots/lab8/image-17.png)
![Guaranteed](../../screenshots/lab8/image-18.png)
![Back to Burstable](../../screenshots/lab8/image-19.png)

#### Metrics pipeline (Step 7)

Metrics API check and `kubectl top` output:

![Metrics API check](../../screenshots/lab8/image-20.png)
![kubectl top](../../screenshots/lab8/image-21.png)

#### HorizontalPodAutoscaler (Step 8)

HPA manifest applied and verified:

![HPA manifest applied](../../screenshots/lab8/image-22.png)
![HPA verified](../../screenshots/lab8/image-23.png)

#### Load test (Step 9)

Watcher script created and running in a second terminal:

![Watcher script](../../screenshots/lab8/image-24.png)
![Watcher running](../../screenshots/lab8/image-25.png)

Load generator deployed:

![Load generator deployed](../../screenshots/lab8/image-26.png)

Load removed, replicas held for the stabilisation window, and the HPA events:

![Load removed](../../screenshots/lab8/image-27.png)
![Replicas held then reduced](../../screenshots/lab8/image-28.png)
![HPA events](../../screenshots/lab8/image-29.png)

#### Node group scaling (Step 10)

Node group configuration before the change:

![Node group before](../../screenshots/lab8/image-30.png)

The update command was rejected by this Floci build (`UnknownOperationException`). Read-back from AWS and Kubernetes:

![Node group after and Kubernetes nodes](../../screenshots/lab8/image-31.png)

#### Node selector (Step 11)

Label check, labelling the nodes, and applying the selector:

![Label check](../../screenshots/lab8/image-32.png)
![Nodes labelled](../../screenshots/lab8/image-33.png)
![nodeSelector applied](../../screenshots/lab8/image-34.png)

Enforcement proven with a non-existent label (new pod Pending) and then restored:

![Selector enforced](../../screenshots/lab8/image-35.png)
![Restored](../../screenshots/lab8/image-36.png)

#### PodDisruptionBudgets (Step 12)

PDBs created:

![PDBs created](../../screenshots/lab8/image-37.png)

Eviction blocked by the PDB, while `kubectl delete pod` is not blocked:

![Eviction blocked](../../screenshots/lab8/image-38.png)
![Delete not blocked](../../screenshots/lab8/image-39.png)

Drain dry run only (no node was changed):

![Drain dry run](../../screenshots/lab8/image-40.png)

#### Exposure ladder (Steps 13 to 16)

ClusterIP is not reachable from the laptop:

![ClusterIP not reachable](../../screenshots/lab8/image-41.png)

Port-forward tunnel and the three routes answering:

![Port-forward running](../../screenshots/lab8/image-42.png)
![Routes answered](../../screenshots/lab8/image-43.png)

NodePort Service `usms-results-np`, reached from inside the cluster, and the node loop (one node):

![NodePort Service](../../screenshots/lab8/image-44.png)
![Reached from inside](../../screenshots/lab8/image-45.png)
![Node loop](../../screenshots/lab8/image-46.png)

NodePort from the laptop, and the port-forward fallback:

![Host test](../../screenshots/lab8/image-47.png)
![Port-forward fallback](../../screenshots/lab8/image-48.png)

LoadBalancer Service, address watch and reach tests:

![LoadBalancer applied](../../screenshots/lab8/image-49.png)
![Watching for an address](../../screenshots/lab8/image-50.png)
![Reach test 1](../../screenshots/lab8/image-51.png)
![Reach test 2](../../screenshots/lab8/image-52.png)
![Reach test 3](../../screenshots/lab8/image-53.png)

One-line summary of the ladder on `usms-gateway`:

![Ladder line](../../screenshots/lab8/image-54.png)

Ingress controller check, manifest, and in-cluster route tests:

![Controller check](../../screenshots/lab8/image-55.png)
![Ingress manifest](../../screenshots/lab8/image-56.png)
![Ingress applied](../../screenshots/lab8/image-57.png)
![In-cluster route test 1](../../screenshots/lab8/image-58.png)
![In-cluster route test 2](../../screenshots/lab8/image-59.png)

#### ECS and EKS comparison (Step 17)

Both stacks inspected and the notes template created:

![Both systems](../../screenshots/lab8/image-61.png)
![Notes template](../../screenshots/lab8/image-60.png)

#### Persistence test (Step 18)

State recorded, Floci stopped and restarted, and the before and after diff:

![Before restart](../../screenshots/lab8/image-62.png)
![Stop and start](../../screenshots/lab8/image-63.png)
![After restart and diff](../../screenshots/lab8/image-64.png)

#### Config file and scripts (Step 19)

Node group state, `configs/lab-08.env` created and verified, and the verify and cleanup scripts:

![Node group state](../../screenshots/lab8/image-65.png)
![Config file created](../../screenshots/lab8/image-66.png)
![Config verified](../../screenshots/lab8/image-67.png)
![Verify and cleanup scripts](../../screenshots/lab8/image-68.png)

### 6.2 AWS Management Console Verification

Floci is a local emulator and has no AWS Management Console. Resource creation was therefore verified by reading the resources back with the AWS CLI and `kubectl`, which is the same information the console would show.

| Evidence | One-line explanation |
|----------|----------------------|
| ![](../../screenshots/lab8/image-23.png) | `kubectl get hpa` confirms `usms-enrolment-hpa` exists with min 2, max 8 and a 50% CPU target. |
| ![](../../screenshots/lab8/image-31.png) | `aws eks describe-nodegroup` and `kubectl get nodes` show the node group configuration from both the AWS and Kubernetes sides. |
| ![](../../screenshots/lab8/image-37.png) | `kubectl get pdb` confirms both budgets exist and shows their allowed disruptions. |
| ![](../../screenshots/lab8/image-44.png) | The NodePort Service `usms-results-np` is listed with the pinned port 30080. |
| ![](../../screenshots/lab8/image-54.png) | One line showing `usms-gateway` as a LoadBalancer with a ClusterIP and a NodePort. |
| ![](../../screenshots/lab8/image-57.png) | `kubectl get ingress` confirms `usms-portal-ingress` is stored with its path rules. |
| ![](../../screenshots/lab8/image-64.png) | The after-restart diff shows the configuration persisted. |
| ![](../../screenshots/lab8/image-67.png) | `configs/lab-08.env` is populated with live values. |

---

## 7. Analysis and Discussion

**What was achieved.** The USMS workloads were scaled by hand, by manifest and automatically. The HPA raised `usms-enrolment` replicas under load and kept them for the 300-second stabilisation window before reducing them. A node selector, two PDBs, and every rung of the exposure ladder were created and tested. Configuration persisted across a Floci restart.

**Did results match expectations?** Most did. The HPA behaviour, QoS changes, node selector enforcement, PDB behaviour and persistence matched the lab guide. The two exposure results that depend on the emulator (LoadBalancer address and Ingress address) are recorded exactly as observed in the screenshots.

**Errors encountered and how they were resolved.**

| Problem | Cause | Resolution |
|---------|-------|------------|
| `update-nodegroup-config` failed with `UnknownOperationException` | This Floci build does not implement the endpoint | The command was correct; the failure was recorded as an emulator limitation and the node group was read back instead |
| NodePort 30080 not reachable from the laptop | Node containers do not publish the port | Used `kubectl port-forward` to prove the Service works |
| Heredocs merged lines when pasted | Terminal paste behaviour | Pasted large blocks on their own and checked files with `cat` before applying |
| Only one node | Local cluster size | The "every node answers" test ran once and was noted honestly |

**Observations.**

- `kubectl scale` writes only the replica count, so it can be silently overwritten by `kubectl apply`.
- Changing resource values replaces the pod, which is why vertical scaling is disruptive.
- The HPA scales out quickly and in slowly, which protects users from capacity being removed too early.
- A PDB governs evictions but not `kubectl delete pod`.
- Each exposure rung keeps the rung below it.

---

## 8. Reflection

**What did I learn?** Scaling has four separate dimensions (pods, pod size, nodes, node size). The HPA uses the CPU request as its denominator, so changing requests changes what "50%" means. Manual changes cause drift, so the repository should always describe the cluster.

**Challenges.** The emulator did not support node group updates, host ports were not reachable, and pasted commands sometimes merged. Working around these meant using `port-forward`, in-cluster tests, and checking files before applying them.

**Real-world application.** In production I would install metrics-server, run the HPA on key services, add Cluster Autoscaler or Karpenter so Pending pods trigger new nodes, use PDBs for safe upgrades, and expose services through an Ingress backed by the AWS Load Balancer Controller so that many services share one load balancer.

**What I would explore next.** Cluster Autoscaler and Karpenter with IRSA, the VerticalPodAutoscaler, scaling on custom metrics such as queue depth, and cost comparison between ECS on Fargate and EKS.

---

## 9. Conclusion

The objectives of this practical were achieved. I scaled the USMS enrolment service manually and automatically, tested resource classes, node placement and disruption budgets, and exposed the application through every rung of the ladder from ClusterIP to Ingress. The only limits were emulator-related (node group update, host ports and controller-dependent addresses), and each was recorded honestly with an explanation of what real AWS would do.

Key concepts learned were the four dimensions of scaling, how the HPA calculates replicas, why QoS and requests matter, and how Kubernetes objects map onto the load balancer and target group commands used in Lab 5. Skills developed include writing and applying manifests, reading autoscaler behaviour, diagnosing Pending pods and drift, and verifying persistence. EKS scaling and exposure is important because it lets a small team keep USMS responsive during very busy periods without paying for idle capacity during quiet ones.

---

## 10. Appendix

- Manifests: `manifests/lab-08/` (`10-hpa-enrolment.yaml`, `20-loadgen.yaml`, `30-pdb-gateway.yaml`, `40-service-nodeport.yaml`, `50-service-loadbalancer.yaml`, `60-ingress.yaml`)
- Updated manifest: `manifests/lab-07/20-enrolment.yaml` (node selector added)
- Scripts: `scripts/utilities/hpa-watch.sh`, `scripts/utilities/verify-lab-08.sh`, `scripts/cleanup/lab-08-cleanup.sh`
- Config file: `configs/lab-08.env`
- Notes: `notes/lab-08-notes.md`
- Output files: `outputs/lab-08-baseline.txt`, `outputs/lab-08-nodegroup-before.json`, `outputs/lab-08-nodegroup-after.json`, `outputs/lab-08-before-restart.txt`, `outputs/lab-08-after-restart.txt`

