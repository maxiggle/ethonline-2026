import "./style.css";
import { fetchApprovalConfig, fetchPendingApprovals, ApiError } from "./api";
import { formatUsdcAmount, formatValidBefore, shortenAddress } from "./format";
import { connectLedger, getApproverAddress, isWebHidSupported } from "./ledger";
import type { ApprovalConfig, PendingApproval } from "./types";

const PENDING_POLL_INTERVAL_MS = 3000;
const LEDGER_ORIGIN_TOKEN = import.meta.env.VITE_LEDGER_ORIGIN_TOKEN as string | undefined;

interface AppState {
  config: ApprovalConfig | null;
  configError: string | null;
  connecting: boolean;
  connectionError: string | null;
  approverAddress: `0x${string}` | null;
  signerEth: Awaited<ReturnType<typeof connectLedger>>["signerEth"] | null;
  pending: PendingApproval[];
  pendingError: string | null;
}

const state: AppState = {
  config: null,
  configError: null,
  connecting: false,
  connectionError: null,
  approverAddress: null,
  signerEth: null,
  pending: [],
  pendingError: null,
};

const app = document.querySelector<HTMLDivElement>("#app");
if (!app) {
  throw new Error("missing #app root element");
}

function isApproverMismatched(): boolean {
  return Boolean(state.config && state.approverAddress && state.config.approverAddress.toLowerCase() !== state.approverAddress.toLowerCase());
}

async function handleConnect(): Promise<void> {
  state.connecting = true;
  state.connectionError = null;
  render();
  try {
    const { signerEth } = await connectLedger(LEDGER_ORIGIN_TOKEN);
    state.signerEth = signerEth;
    const address = await getApproverAddress(signerEth, (message) => {
      state.connectionError = message ? `Connecting… ${message}` : null;
      render();
    });
    state.approverAddress = address;
  } catch (error) {
    state.signerEth = null;
    state.approverAddress = null;
    state.connectionError = error instanceof Error ? error.message : "Failed to connect to the Ledger device.";
  } finally {
    state.connecting = false;
    render();
  }
}

function describeActionError(error: unknown): string {
  if (error instanceof ApiError) {
    return `Backend rejected the request: ${error.message}`;
  }
  return error instanceof Error ? error.message : "Unexpected error.";
}

async function refreshPendingApprovals(): Promise<void> {
  try {
    state.pending = await fetchPendingApprovals();
    state.pendingError = null;
  } catch (error) {
    state.pendingError = describeActionError(error);
  }
  render();
}

async function loadConfig(): Promise<void> {
  try {
    state.config = await fetchApprovalConfig();
    state.configError = null;
  } catch (error) {
    state.configError = describeActionError(error);
  }
  render();
}

function renderBanners(): string {
  const banners: string[] = [];
  if (!LEDGER_ORIGIN_TOKEN) {
    banners.push('<div class="banner warning">Ledger transaction checks unavailable (no origin token).</div>');
  }
  if (!isWebHidSupported()) {
    banners.push('<div class="banner error">WebHID is not supported in this browser. Use Chrome or Edge.</div>');
  }
  if (state.configError) {
    banners.push(`<div class="banner error">Could not load approval config: ${escapeHtml(state.configError)}</div>`);
  }
  if (isApproverMismatched()) {
    banners.push(
      `<div class="banner error">This Ledger (${escapeHtml(shortenAddress(state.approverAddress!))}) is not the configured approver (${escapeHtml(
        shortenAddress(state.config!.approverAddress),
      )}). Approvals are disabled.</div>`,
    );
  }
  if (state.connectionError) {
    banners.push(`<div class="banner error">${escapeHtml(state.connectionError)}</div>`);
  }
  if (state.pendingError) {
    banners.push(`<div class="banner error">Could not load pending approvals: ${escapeHtml(state.pendingError)}</div>`);
  }
  return banners.join("");
}

function renderConnectionStatus(): string {
  if (state.connecting) {
    return "Connecting…";
  }
  if (state.approverAddress) {
    return `Connected: ${shortenAddress(state.approverAddress)}`;
  }
  return "Not connected";
}

function renderCard(approval: PendingApproval): string {
  return `
    <div class="card" data-action-id="${escapeHtml(approval.actionId)}">
      <div class="card-header">
        <span class="card-amount">${escapeHtml(formatUsdcAmount(approval.amount))}</span>
        <span class="risk-score">risk ${escapeHtml(String(approval.riskScore))}/100</span>
      </div>
      <dl class="card-fields">
        <dt>Resource</dt><dd>${escapeHtml(approval.resourceUrl)}</dd>
        <dt>Pay to</dt><dd>${escapeHtml(approval.payTo)}</dd>
        <dt>Agent</dt><dd>${escapeHtml(approval.agentAddress)}</dd>
        <dt>Justification</dt><dd>${escapeHtml(approval.justification)}</dd>
        <dt>Expires</dt><dd>${escapeHtml(formatValidBefore(approval.typedData.message.validBefore))}</dd>
      </dl>
      ${approval.reasons.length > 0 ? `<div class="reasons">Guardian: ${escapeHtml(approval.reasons.join("; "))}</div>` : ""}
    </div>
  `;
}

function renderPendingList(): string {
  if (state.pending.length === 0) {
    return '<div class="empty-state">No escalated payments awaiting approval.</div>';
  }
  return state.pending.map(renderCard).join("");
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (char) => {
    switch (char) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      default:
        return "&#39;";
    }
  });
}

function render(): void {
  app!.innerHTML = `
    <header>
      <h1>Ledger Approval Console</h1>
      <div>
        <button id="connect-button" ${state.connecting || Boolean(state.signerEth) ? "disabled" : ""}>
          ${state.signerEth ? "Connected" : "Connect Ledger"}
        </button>
        <div class="connection-status">${escapeHtml(renderConnectionStatus())}</div>
      </div>
    </header>
    ${renderBanners()}
    <section>${renderPendingList()}</section>
  `;

  document.querySelector("#connect-button")?.addEventListener("click", () => {
    void handleConnect();
  });
}

render();
void loadConfig();
void refreshPendingApprovals();
setInterval(() => {
  void refreshPendingApprovals();
}, PENDING_POLL_INTERVAL_MS);
