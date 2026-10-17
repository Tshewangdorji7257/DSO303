Step 1 - Resume the environment and load six env files
![alt text](image.png)
![alt text](image-1.png)
![alt text](image-2.png)

Step 2 - Confirm Labs 02, 03, 04 and 05 are still intact
![alt text](image-3.png)

Step 3 - Probe what this Floci build supports
![alt text](image-4.png)

Step 4 - Create the service-linked role that writes desiredCount

![alt text](image-5.png)
![alt text](image-6.png)

Step 5: register the scalable target.
Part 1: build the resource ID from the API
![alt text](image-7.png)
![alt text](image-8.png)

Part 2: register it
![alt text](image-9.png)

Verify
![alt text](image-10.png)

Part 3: check what registering did to the service
![alt text](image-11.png)

Step 6: change the bounds.

Part 1 raises the max to 12 passing only --max-capacity, and the min should stay at 2.
![alt text](image-12.png)

Part 2: put it back
![alt text](image-13.png)

Then the duplicate check:
![alt text](image-14.png)

Your turn exercise (do it after Part 2 is confirmed)

First, answer in your head without running anything: if you re-register with --min-capacity 5 while the service runs 2 tasks, what happens? Then run it:
![alt text](image-15.png)
![alt text](image-16.png)

Then put it back to 2, and also fix the service count. Re-registering with min 2 will not lower desiredCount on its own, because the floor only pushes the count up.
![alt text](image-17.png)

Step 7, the CPU target tracking policy. 
Part 1 writes the config file, and Part 2 creates the policy.
![alt text](image-18.png)

Part 2: create the policy
![alt text](image-19.png)

Then verify:
![alt text](image-20.png)

Step 8: read the two alarms you didn't create

Part 1, find them:
![alt text](image-21.png)

Then confirm both alarms invoke your Step 7 policy:
![alt text](image-22.png)

Every line should equal your $CPU_POLICY_ARN. You can check by comparing with:
![alt text](image-23.png)

Part 2, prove the naming is derivable:
![alt text](image-24.png)

Step 9: the request-count policy. 
Part 1 gets the ResourceLabel:
![alt text](image-25.png)

Part 2: write the policy configuration
![alt text](image-26.png)

Part 3: create the policy
![alt text](image-27.png)

Verify:
![alt text](image-28.png)
![alt text](image-29.png)

Step 10: the step scaling policy and the alarm that drives it
Part 1: publish the metric
![alt text](image-30.png)

Part 2: write the step configuration (quoted heredoc, because there are no variables)
![alt text](image-31.png)

Part 3: create the policy first, then the alarm that drives it
![alt text](image-32.png)

Check that the ARN is not empty before going on. Then create the alarm:
![alt text](image-33.png)

Then verify the policy side of the link:
![alt text](image-34.png)

Step 11: scheduled actions

Part 1 is the morning scale-out. Try the Asia/Thimphu time zone first:
![alt text](image-35.png)
![alt text](image-36.png)

Step 12 doesn't depend on scheduled actions, so you can carry on with it. 
Part 1 records the state before:
![alt text](image-37.png)

Part 2: push the metric past the threshold
![alt text](image-38.png)

Then watch whether the alarm fires by itself:
![alt text](image-39.png)

Part 3 (only if the alarm stays OK/INSUFFICIENT_DATA)
![alt text](image-40.png)

Part 4: read back the number and the record
![alt text](image-41.png)

Part 5 (the fallback proof) so you have outputs/lab-06-scaling-proof.txt. It is the evidence file the lab asks you to keep:
![alt text](image-42.png)

Part 6, in the right order. The alarm is still ALARM and the metric is still 260, so if you only set the count, the policy would scale it straight back up. Push the metric down first, then reset the alarm, wait, and only then lower the count:
![alt text](image-43.png)

If it says OK, continue. If it flipped back to ALARM, the 260 datapoint is still in its window; wait another minute and re-check.
![alt text](image-44.png)

Then record the after-state:
![alt text](image-45.png)

Step 13: suspend and resume scaling. 
Part 1 suspends scale-in only:
![alt text](image-46.png)

Part 2: confirm the policies and alarms are untouched
![alt text](image-47.png)

Part 3: resume, and prove it (required)
![alt text](image-48.png)

Then check the capitalisation the lab mentions:
![alt text](image-49.png)

Step 14: prove the configuration survives a restart

Part 1: record the truth before
![alt text](image-50.png)

check the alarm is OK and the count is 2, so the restart doesn't start with a scaling loop in flight:
![alt text](image-51.png)

Part 2: perturb (restart Floci)
![alt text](image-52.png)

Part 3: read back, re-deriving every identifier
![alt text](image-53.png)

Check what you have, and that the restart was clean
![alt text](image-54.png)

Recreate the pre-restart file from the output you captured before the restart
![alt text](image-55.png)

Build a snapshot function in two small pieces
![alt text](image-56.png)

Re-derive every identifier from the API, then diff
![alt text](image-57.png)
![alt text](image-58.png)

Step 15: trace the whole path, from metric to serving task
![alt text](image-59.png)

Blocks 1 to 3, the metric, the policies and the scalable target:
![alt text](image-60.png)

Blocks 4 to 7, the service, network, load balancer and what this lab changed:
![alt text](image-61.png)

Step 16: write configs/lab-06.env
![alt text](image-62.png)
![alt text](image-63.png)
![alt text](image-64.png)
![alt text](image-65.png)

Step 17: commit, and repair two stale strings