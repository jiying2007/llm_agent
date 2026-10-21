# Design

The checker uses one exception handler for `verify_review()` and `snapshot()`.
The former can reject an expired review before the latter is called. Separate
the two exception boundaries and continue to the next item after either
failure. Keep the exception classes, ordering and nonzero result unchanged.

Review failures use one fixed diagnostic, without including raw exception text
or evidence contents. Only an exception from the actual snapshot call uses
the existing snapshot-unavailable diagnostic.

The existing test module executes the checker's actual embedded Python body.
It uses the real review validator with expired and invalid-digest fixtures,
observes that the snapshot function is not called, and separately injects a
snapshot-reader failure after a valid review. Fixtures remain in temporary
directories and have no qualification or reference-adoption authority.

Rollback is limited to this diagnostic split and its regression coverage. It
does not restore, modify or refresh any reference working tree or baseline.
