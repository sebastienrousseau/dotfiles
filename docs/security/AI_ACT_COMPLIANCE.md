# EU AI Act Compliance Assessment

This document maps the dotfiles project against the EU Artificial Intelligence Act (Regulation (EU) 2024/1689) to confirm compliance posture and applicable obligations.

---

## Risk Classification (Annex III Assessment)

| Criterion | Assessment | Result |
|-----------|-----------|--------|
| Biometric identification | Not applicable | N/A |
| Critical infrastructure | Not applicable | N/A |
| Education / employment | Not applicable | N/A |
| Essential services | Not applicable | N/A |
| Law enforcement | Not applicable | N/A |
| Migration / border control | Not applicable | N/A |

**Classification: Minimal Risk**

This project is a workstation configuration management tool. It does not deploy, train, or host AI models. It integrates with external AI CLI tools (Claude, Gemini, Ollama) as a consumer, not a provider.

---

## Open-Source Exemption (Article 2(12))

| Requirement | Status |
|-------------|--------|
| License type | MIT (permissive, open-source) |
| Model weights distributed | No — no model training or distribution |
| Free and open-source | Yes — publicly available source code |
| No prohibited practices (Article 5) | Confirmed — no subliminal, exploitative, or social scoring use |

**Result:** This project qualifies for the open-source exemption under Article 2(12). Open-source AI components released under free licenses are exempt from most AI Act obligations, provided they do not fall under prohibited practices or high-risk classifications.

---

## Transparency Obligations

Even for minimal-risk and exempt systems, the AI Act encourages transparency. This project voluntarily implements the following:

| Obligation | Implementation | Evidence |
|-----------|----------------|----------|
| AI interaction disclosure | Agent session logging | `agent-sessions.jsonl` via `dot_agent_session_log()` |
| Model identification | Model registry | `dot_config/dotfiles/model-registry.json` |
| Configuration transparency | Agent profiles | `dot_config/dotfiles/agent-profiles.json` |
| Audit trail | Structured logging | `~/.local/share/dotfiles.log`, `~/.local/state/dotfiles/` |
| Workstation attestation | Attestation export | `dot attest --json` |

---

## GPAI Provisions (Chapter V)

| Criterion | Assessment |
|-----------|-----------|
| General-purpose AI model provider | **No** — this project does not train, fine-tune, or distribute AI models |
| Systemic risk model | **No** — no model hosting or inference serving |
| Downstream provider obligations | **No** — consumer of external AI APIs only |

**Result:** GPAI provisions are not applicable. This project consumes AI services but does not provide them.

---

## Enforcement Timeline

| Milestone | Date | Relevance |
|-----------|------|-----------|
| AI Act entered into force | August 1, 2024 | Awareness |
| Prohibited practices apply | February 2, 2025 | Confirmed no prohibited use |
| GPAI rules apply | August 2, 2025 | Not applicable |
| High-risk obligations apply | **August 2, 2026** | Not applicable (minimal risk) |
| Full enforcement | August 2, 2027 | Maintain compliance posture |

**Next review:** Before August 2026 enforcement date — reassess if project scope changes to include model hosting or high-risk use cases.

---

## Cross-References

| Document | Relevance |
|----------|-----------|
| [COMPLIANCE.md](COMPLIANCE.md) | SOC 2, ISO 27001, GDPR framework mapping |
| [THREAT_MODEL.md](THREAT_MODEL.md) | Trust boundaries and attack surface |
| [MCP_POLICY.md](MCP_POLICY.md) | MCP governance and supply-chain controls |
| [SECURITY.md](SECURITY.md) | Core security model |

---

## Summary

This project is classified as **minimal risk** under the EU AI Act and qualifies for the **open-source exemption** under Article 2(12). No mandatory obligations apply. Transparency measures are voluntarily implemented through agent session logging, model registry, and workstation attestation.
