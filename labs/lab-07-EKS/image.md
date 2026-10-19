Step 1: Start the environment
![alt text](image.png)
![alt text](image-1.png)
![alt text](image-2.png)

Then verify:
![alt text](image-3.png)

Step 2: Probe your EKS support path

Part B: Create and run the probe script
![alt text](image-4.png)
![alt text](image-5.png)
![alt text](image-6.png)

Steps 3 and 4: trust policies
![alt text](image-7.png)
![alt text](image-8.png)

Then verify:
![alt text](image-9.png)
![alt text](image-10.png)

Step 5: permissions policies
Block 1, the cluster policy:
![alt text](image-11.png)

Block 2, the node policy:
![alt text](image-12.png)

Block 3, validate and verify:
![alt text](image-13.png)

Step 6: cluster role and cluster security group
Part 1, the role:
![alt text](image-14.png)

Part 2, the permissions policy, attached to the role:
![alt text](image-15.png)

Part 3, the security group in Lab 2's VPC:
![alt text](image-16.png)

Verify:
![alt text](image-17.png)

Step 7: node role, and Lab 1's policy attached to it
Part 1, the role and its own policy:
![alt text](image-18.png)

Part 2, attach Lab 1's policy unchanged:
![alt text](image-19.png)

Verify:
![alt text](image-20.png)

Step 8: create the cluster
Part 1, build the request body. This heredoc is unquoted (<< EOF) on purpose, so don't add quotes:
![alt text](image-21.png)
![alt text](image-22.png)

Part 2, assume the developer role. This puts temporary credentials into your shell:
![alt text](image-23.png)

Part 3, create the cluster (Path A):
![alt text](image-24.png)

Part 4, restore your normal identity. This is not optional:
![alt text](image-25.png)

Step 9: wait for ACTIVE
![alt text](image-26.png)

Then record the full cluster details:
![alt text](image-27.png)

Then confirm the tag directly:
![alt text](image-28.png)

Your turn (Step 9)

Print the Kubernetes version and the OIDC issuer URL side by side in one command:
![alt text](image-29.png)

Step 10: managed node group
Part 1, the request body. The heredoc is unquoted again, on purpose:
![alt text](image-30.png)

Part 2, create it (Path A):
![alt text](image-31.png)

Part 3, wait for ACTIVE:
![alt text](image-32.png)

Verify (one-line query, to avoid paste problems):
![alt text](image-33.png)

Step 11: point kubectl at the cluster
Part 1, write the kubeconfig and switch context:
![alt text](image-34.png)

Part 2, prove you can reach the API server:
![alt text](image-35.png)

verify
![alt text](image-36.png)

Step 12: namespace
![alt text](image-37.png)
![alt text](image-38.png)

Step 13: first microservice, usms-enrolment
Part 1, the shared ConfigMap:
![alt text](image-39.png)

Part 2, the enrolment service (ConfigMap, Deployment and Service in one file). This is the longest paste in the lab, so paste it on its own:
![alt text](image-40.png)

Before applying, you can check the file saved correctly (earlier long pastes displayed oddly):
![alt text](image-41.png)

Verify:
![alt text](image-42.png)

Part 3, prove it serves:
![alt text](image-43.png)

Step 14: usms-results
![alt text](image-44.png)

Then apply it:
![alt text](image-45.png)

Verify (one line, so the backslash continuation can't break):
![alt text](image-46.png)

Step 15: the gateway
![alt text](image-47.png)

Then apply it:
![alt text](image-48.png)

verify
![alt text](image-49.png)

Step 16: service discovery
Part 1, resolve the names:
![alt text](image-50.png)

Part 2, go through the gateway:
![alt text](image-51.png)

Part 3, show that traffic is spread across pods:
![alt text](image-52.png)

Step 16 "Your turn": delete a pod
![alt text](image-53.png)

Copy one pod name, then:
A replacement should appear within seconds. Then re-run the Part 3 tally. The new pod name should show up and no request should fail. To see who created the replacement:
![alt text](image-54.png)
![alt text](image-55.png)

Step 17: ConfigMaps and Secrets
Part 1, create the Secret manifest.
![alt text](image-56.png)

Part 2, base64 is not a lock:
![alt text](image-57.png)

Part 3, consume it in the enrolment Deployment:
![alt text](image-58.png)

Verify:
![alt text](image-59.png)

Step 18: roll out a change, then roll it back

Part 1, change the ConfigMap:
![alt text](image-60.png)

Part 2, observe that nothing happened:
![alt text](image-61.png)

Part 3, trigger the rollout. Skip the annotate command, which the lab itself says may not roll, and go to the supported one:
![alt text](image-62.png)

Part 4, history, then rollback:
![alt text](image-63.png)
![alt text](image-64.png)

Part 5, restore the known state:
![alt text](image-65.png)

Your turn. Change the image tag of usms-results, then roll back, and count the revisions:
![alt text](image-66.png)
![alt text](image-67.png)

Step 19: break pods on purpose
Failure 1: bad image.
![alt text](image-68.png)
![alt text](image-69.png)

Failure 2: unschedulable pod.
![alt text](image-70.png)

Failure 3: crash loop.
![alt text](image-71.png)

At the end, confirm everything is back to normal:
![alt text](image-72.png)

Step 20: ECS vs Kubernetes comparison
Both platforms are running, so check the claims now:
![alt text](image-73.png)

Step 21: IRSA
![alt text](image-74.png)

Part 2 applies. Run it:
![alt text](image-75.png)

Part 3, the ServiceAccount:
![alt text](image-76.png)

Verify:
![alt text](image-77.png)

Step 22: persistence across a restart

Part 1, record the truth before the restart:
![alt text](image-78.png)

Part 2, restart Floci:
![alt text](image-79.png)

Part 3, read back, re-deriving from the API:
![alt text](image-80.png)
![alt text](image-81.png)
![alt text](image-82.png)

Step 23: write configs/lab-07.env
![alt text](image-83.png)

Then verify:
![alt text](image-84.png)