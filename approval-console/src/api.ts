import type { ApprovalConfig, PendingApproval } from "./types";

export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

function requireApiBaseUrl(): string {
  const apiBaseUrl = import.meta.env.VITE_API_BASE_URL;
  if (!apiBaseUrl) {
    throw new Error("VITE_API_BASE_URL is not configured");
  }
  return apiBaseUrl;
}

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${requireApiBaseUrl()}${path}`, {
    ...init,
    headers: { "Content-Type": "application/json", ...init?.headers },
  });
  const body = await response.text();
  const parsed = body.length > 0 ? JSON.parse(body) : undefined;
  if (!response.ok) {
    const message = parsed?.message ?? `request to ${path} failed with status ${response.status}`;
    throw new ApiError(Array.isArray(message) ? message.join(", ") : message, response.status);
  }
  return parsed as T;
}

export function fetchApprovalConfig(): Promise<ApprovalConfig> {
  return requestJson<ApprovalConfig>("/x402/approvals/config");
}

export function fetchPendingApprovals(): Promise<PendingApproval[]> {
  return requestJson<PendingApproval[]>("/x402/approvals/pending");
}

export function submitApprovalSignature(actionId: string, signature: `0x${string}`): Promise<unknown> {
  return requestJson(`/x402/approvals/${actionId}/signature`, {
    method: "POST",
    body: JSON.stringify({ signature }),
  });
}

export function submitApprovalRejection(actionId: string, signature: `0x${string}`): Promise<unknown> {
  return requestJson(`/x402/approvals/${actionId}/reject`, {
    method: "POST",
    body: JSON.stringify({ signature }),
  });
}
