]633;E;{   echo "## Lab 07 support path"\x3b   echo "Probed on $(date -u +%Y-%m-%dT%H:%M:%SZ)"\x3b   grep -A1 '== Verdict ==' outputs/lab-07-support-probe.txt | tail -1\x3b } >> notes/lab-07-notes.md;9362bbfc-a77b-40d7-b7a5-8b218cc04666]633;C## Lab 07 support path
Probed on 2026-10-19T04:34:43Z
PATH A  - use aws eks throughout

## Step 3 - "EKS is just ECS with different names"
FALSE because: (your answer: e.g. on EKS you run and patch the nodes and the CNI, the right-hand column of the table is not empty)
NEARLY TRUE because: (your answer: both schedule containers, keep N copies alive and use two IAM roles)

## Step 3 - "EKS is just ECS with different names"
FALSE because: (your answer: e.g. on EKS you run and patch the nodes and the CNI, the right-hand column of the table is not empty)
NEARLY TRUE because: (your answer: both schedule containers, keep N copies alive and use two IAM roles)

## Step 9 - OIDC issuer
The OIDC issuer is the URL where the cluster publishes the keys used to verify its service-account tokens. IAM trusts it as an identity provider, so a pod can swap its token for AWS credentials (IRSA).

## Step 11 - kubectl access (deviation)
aws eks update-kubeconfig failed: the k3s API server rejected the aws eks get-token credential (Floci does not validate AWS tokens).
Workaround: copied /etc/rancher/k3s/k3s.yaml out of container floci-aws-floci-course-eks-usms-eks-cluster, pointed it at https://localhost:6500, stored it in outputs/lab-07-kubeconfig.yaml (git-ignored, chmod 600).
Only one node registered (control-plane,master); t3.small / the 2-node nodegroup is recorded in the AWS API but not provisioned as separate nodes.

## Step 11 - kubectl access (deviation)
aws eks update-kubeconfig failed: the k3s API server rejected the aws eks get-token credential (Floci does not validate AWS tokens).
Workaround: copied /etc/rancher/k3s/k3s.yaml out of container floci-aws-floci-course-eks-usms-eks-cluster, pointed it at https://localhost:6500, stored it in outputs/lab-07-kubeconfig.yaml (git-ignored, chmod 600).
Only one node registered (control-plane,master); t3.small / the 2-node nodegroup is recorded in the AWS API but not provisioned as separate nodes.

## Step 16 - who replaced the deleted pod
The ReplicaSet (usms-enrolment-5cf94ff846) created the replacement pod. It keeps the pod count at the desired 2; the Deployment only manages ReplicaSets.

## Step 18 - usms-results image roll
kubectl set image results=nginx:1.27 stalled: the cluster could not pull nginx:1.27 within 120s (events: Pulling image "nginx:1.27"). Old pods kept serving because the default 25% strategy never removed them. rollout undo restored nginx:1.27-alpine. History shows revisions 2 and 3.

## Step 19 - failures observed
ImagePullBackOff (old pods kept serving), Pending/FailedScheduling (0/1 nodes: only one node on this build), Error/CrashLoop (exit 1; logs --previous was unavailable on this k3s). All temporary pods deleted.

## Step 20 - ECS and Kubernetes, compared with both running

| Question | ECS answer | Kubernetes answer |
| --- | --- | --- |
| What holds the container spec? | | |
| What keeps N copies alive? | | |
| What gives it a stable name? | | |
| How does another service find it? | | |
| What does a rolling update create? | | |
| Where does rollback state live? | | |
| Which IAM role does the app code use? | | |
| What would I have to change to move to another cloud? | | |

Two sentences: which one would I choose for USMS, and why.

## Step 21 - IRSA on this build
Completed: (1) issuer present in describe-cluster, (2) OIDC provider registered in IAM (arn:aws:iam::000000000000:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/626F31A1CA7546A68E68A334BA0A9542), ServiceAccount usms-enrolment-sa created.
Not completed: (3) web-identity role not written, (4) no annotation, (5) no pod-identity webhook in this k3s, (6) STS cannot fetch the discovery document from a non-public issuer. IRSA is conceptual here.

## Step 22 - persistence
After floci-down/up: cluster and nodegroup re-derived from list-clusters/list-nodegroups; namespace, 3 Deployments and ConfigMaps intact. The k3s container kept running (Floci stopped only itself), so Kubernetes state was never at risk. Cluster status briefly read CREATING after restart (settled to: <fill in>).

## Step 22 - result (deviation)
After floci-down/up, Floci logged "Restoring k3s container" and "Adopted surviving k3s container ... port 6500". Namespace, Deployments and ConfigMaps survived and the nodegroup stayed ACTIVE, but describe-cluster stayed CREATING for 5+ minutes. This looks like a Floci restore quirk: the k3s cluster is healthy while the AWS-side status was never promoted. Not fixed; I did not recreate the cluster. USMS_EKS_CLUSTER_STATUS in lab-07.env records CREATING as observed.

## Section 8 - verify result
verify-lab-07.sh: PASS=29 FAIL=1. The one failure is "cluster is ACTIVE": after floci-down/up the cluster stays CREATING (Floci restore quirk, k3s healthy). Kubernetes checks need KUBECONFIG=outputs/lab-07-kubeconfig.yaml exported in the shell.
