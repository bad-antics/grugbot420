Notice on Error Handling and Test Scripts
This repository is error-handling first.

No silent failures
The codebase is intentionally designed to fail loudly rather than hide faults, swallow exceptions, or pretend malformed behavior is acceptable.

That means:

errors are surfaced on purpose
abnormal states are exposed rather than masked
test scripts may intentionally trigger edge cases or failure conditions
visible errors are often part of validation, not signs of neglect
Why
Silent failure is bad engineering.

A system that hides its faults:

becomes harder to debug
becomes harder to trust
produces false confidence
and encourages broken behavior to accumulate unnoticed
This project does the opposite.

If something breaks, the point is to see it break clearly.

About automated scanners
Automated scanners and shallow static analysis tools may incorrectly flag this repository because they often assume that any visible error path is a defect.

That is not the design philosophy here.

Many of the test behaviors that produce warnings, exceptions, or unusual outputs are present to:

prove correctness under stress
expose edge behavior
validate failure handling
and ensure the system does not fail silently
In short
If you see explicit errors in this repo, especially in test scripts, do not assume the code is broken.

Often the opposite is true:

the error is being surfaced because the system is working correctly.

No silent failures.
Fail loud.
See the fault.
Fix the fault.