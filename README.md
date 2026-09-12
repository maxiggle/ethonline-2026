# Chapter 2

> **AI Guardian for Autonomous Treasuries**
> *"AI agents can manage your treasury. Chapter 2 makes sure they never manage to control it."*

Chapter 2 is an institutional-grade mobile command center and on-chain governance system that supervises autonomous AI agents operating a treasury. It establishes independent, cryptographic boundaries between an AI agent's proposals and final financial execution.

---

## The Hierarchy of Authority

1. **Identity & Key Lifecycle (Privy & World ID)**: *Who is behind the agent?* Authenticates the human principal, provisions a unique secure-enclave embedded EVM wallet as the Autonomous Agent, and verifies personhood with World ID.
2. **Proposer (Autonomous Treasury Agent)**: *What should we do?* Executes micro-disbursements autonomously within on-chain spending caps enforced by `Chapter2Guard`; holds zero authority outside pre-approved limits.
3. **Supervision (AI Guardian)**: *Should we allow it?* Two-layer evaluation (deterministic hard floor + AI contextual anomaly analysis).
4. **Human Review (Mobile Command Center)**: *Do I approve this?* Native hardware biometrics (Secure Enclave / StrongBox Keystore) gating approvals.
5. **Final Authority (Ledger)**: *Physical authorization.* Headless Key Ring for secret protection; EIP-712 clear-signing on device screens for high-risk executions and policy changes.

---

## Monorepo Structure

- `contracts/`: Foundry smart contracts implementing Gnosis Safe transaction guards (`Chapter2Guard`), spending caps, and EIP-712 verification.
- `backend/`: NestJS orchestrator with the Asymmetric AI Guardian, deterministic policy engine, Ledger Key Ring integration, and World ID verification.
- `native_security/`: iOS Secure Enclave and Android StrongBox Keystore biometric signature plugins.
- `chapter2/`: Flutter mobile command center built with Very Good CLI, BLoC architecture, and multi-flavor support.
