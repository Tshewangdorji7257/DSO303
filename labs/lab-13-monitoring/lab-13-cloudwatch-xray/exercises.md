# Lab 13 exercises

## Step 8 - ERROR filter pattern
Pattern tested: ERROR
Result on the four Step 7 messages: matched only message 4 (the failed transcript).
Result on the "no ERROR here" line: it MATCHED (false positive). The text dialect splits on whitespace and matches a token anywhere in the line.
Would I accept this in production? Not as-is. A reason string containing "ERROR" would inflate CentralErrorCount and could page someone for a healthy system. Better: a JSON filter such as { $.event = "transcript.failed" }, or a dedicated marker like USMS_FAILED. Plain ERROR is acceptable only for a low-stakes lab metric.

## Step 10 - defaultValue
Window before the filter existed (07:20-07:35 UTC), period 300: Datapoints = [] (EMPTY list).
Window containing the upload, period 300: one point, Sum 2.0, SampleCount 4.0.
An empty list means no data was ever published for that period (CloudWatch cannot tell "nothing happened" from "nothing was reported"). A list of zeroes would mean a data point of 0 was actually published, which is what defaultValue=0 produces while a filter is active. My build returned an EMPTY list for the pre-filter window, because filters are not retroactive. Sum 2 with SampleCount 4 suggests the zeroes from defaultValue are counted as samples.
This matters for Step 19: an alarm on NotifyCount needs --treat-missing-data breaching to catch silence, because absence of data is not the same as a zero.

## Step 13 - rollback
Rolling back this deployment is one update-alias call and takes seconds, because versions are immutable and the S3 notification already points at the alias. Lambda@Edge (Lab 10 Step 11) is slower to roll back because a new version must be re-associated with the CloudFront distribution and propagated to edge locations, which takes minutes.

## Step 18 - sampling rule
ReservoirSize 2 guarantees the first two matching requests each second are traced, so low-volume incidents are never missed. FixedRate 0.10 then traces one in ten of the rest, so cost does not grow with traffic. Priority 1000 beats the account's Default rule at 10000 because lower numbers win.
