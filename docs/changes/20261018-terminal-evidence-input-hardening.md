# Terminal Closure G9 evidence input hardening

The G9 terminal projection previously hashed an unbounded `Path.read_bytes()` and reopened that path to parse via ordinary JSON. It now uses the existing canonical bounded intake functions: a maximum 4 MiB regular-file JSON, strict duplicate/nonfinite rejection, symlink rejection, and one byte snapshot for the Git blob SHA-1 and parsed decision. Index/backlog JSON reads also use the same strict bounded decoder.

The additional contract test runs in the always-on Root PR contract CI and covers byte identity, duplicate JSON fields, nonfinite values, symlinks, oversized bytes, noncanonical paths, non-object JSON and wrong Git blob identities. This changes no historical G9 capture, owner decision or protected release authority. Authentic G21/G22/LTA-04 evidence remains separate.
