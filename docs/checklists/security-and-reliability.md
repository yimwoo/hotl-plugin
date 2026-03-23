# Security and Reliability Checklist

These are review heuristics, not merge policy. Reviewers use professional judgment to decide severity based on exploitability, impact, and codebase context.

When flagging a security finding, note both **exploitability** (how easy is it to trigger?) and **impact** (what damage can it cause?).

## Injection

- **SQL injection:** String concatenation or template literals in SQL queries instead of parameterized queries.
- **Command injection:** User input passed to shell execution (`exec`, `spawn`, `system`, `os.popen`) without sanitization.
- **XSS (Cross-Site Scripting):** User-controlled data rendered in HTML without escaping. Watch for `dangerouslySetInnerHTML`, `innerHTML`, and unescaped template variables.
- **NoSQL injection:** User input passed directly to NoSQL query operators (`$where`, `$regex`, `$gt`).
- **Template injection:** User input embedded in server-side templates that support code execution.

## Network and Request Handling

- **SSRF (Server-Side Request Forgery):** User-controlled URLs passed to server-side HTTP clients without allowlist validation.
- **Path traversal:** User input used in file paths without canonicalization or directory restriction (`../` attacks).

## Authentication and Authorization

- **AuthN gaps:** Missing authentication on endpoints that should be protected.
- **AuthZ gaps:** Missing authorization checks — authenticated users accessing resources they shouldn't.
- **Tenancy isolation:** Multi-tenant systems where one tenant's data could be accessed by another through missing or incorrect tenant scoping.

## Secrets and Data Exposure

- **Hardcoded secrets:** API keys, tokens, passwords, connection strings in source code.
- **Secret leakage:** Sensitive data in logs, error messages, stack traces, or environment variable dumps.
- **Sensitive data exposure:** PII, credentials, or internal system details exposed in API responses or client-side code.

## Concurrency and State

- **Race conditions:** Concurrent access to shared state without synchronization (locks, transactions, atomic operations).
- **TOCTOU (Time-of-Check-to-Time-of-Use):** Check-then-act patterns where state can change between the check and the action.
- **Missing locks:** Shared mutable state accessed from multiple threads or processes without coordination.

## Cryptography and Deserialization

- **Unsafe deserialization:** Deserializing untrusted input with formats that support code execution (pickle, Java serialization, YAML `!!python`).
- **Weak cryptography:** Use of broken or deprecated algorithms (MD5, SHA1 for security, DES, RC4). Use of ECB mode.
- **Insecure defaults:** Security features disabled by default (TLS verification off, CORS wildcard, debug mode in production).

## Resource Exhaustion

- **Rate limits:** Missing rate limiting on public or expensive endpoints.
- **Unbounded loops:** Loops whose iteration count is controlled by external input without upper bounds.
- **CPU/memory hotspots:** Operations that scale poorly with input size (quadratic algorithms, unbounded memory allocation, large file reads into memory).
