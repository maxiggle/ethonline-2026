import {
  ConsoleLogger,
  DeviceActionStatus,
  DeviceManagementKit,
  DeviceManagementKitBuilder,
  UserInteractionRequired,
  type DmkError,
  type ExecuteDeviceActionReturnType,
} from "@ledgerhq/device-management-kit";
import { webHidTransportFactory } from "@ledgerhq/device-transport-kit-web-hid";
import { SignerEthBuilder, type SignerEth } from "@ledgerhq/device-signer-kit-ethereum";
import { firstValueFrom } from "rxjs";

export const AGENT_APPROVER_DERIVATION_PATH = "44'/60'/0'/0/0";

let deviceManagementKit: DeviceManagementKit | undefined;

function getDeviceManagementKit(): DeviceManagementKit {
  if (!deviceManagementKit) {
    deviceManagementKit = new DeviceManagementKitBuilder()
      .addLogger(new ConsoleLogger())
      .addTransport(webHidTransportFactory)
      .build();
  }
  return deviceManagementKit;
}

export function isWebHidSupported(): boolean {
  return typeof navigator !== "undefined" && "hid" in navigator;
}

export class LedgerDeviceError extends Error {
  constructor(readonly deviceError: DmkError) {
    super(describeDeviceError(deviceError));
    this.name = "LedgerDeviceError";
  }
}

function describeDeviceError(error: DmkError): string {
  switch (error._tag) {
    case "DeviceLockedError":
      return "Unlock your Ledger device and try again.";
    case "RefusedByUserDAError":
      return "The action was rejected on the Ledger device.";
    case "UnsupportedApplicationDAError":
    case "UnsupportedFirmwareDAError":
      return "Open the Ethereum app on your Ledger device.";
    case "DeviceNotOnboardedError":
      return "This Ledger device has not been set up yet.";
    case "NoAccessibleDeviceError":
      return "No accessible Ledger device was found. Check the USB connection and browser permissions.";
    case "DeviceNotRecognizedError":
      return "The connected device was not recognized as a Ledger.";
    case "TransportNotSupportedError":
      return "WebHID is not supported in this browser. Use Chrome or Edge.";
    case "DisconnectError":
    case "DeviceDisconnectedWhileSendingError":
    case "DeviceNotInitializedError":
      return "The Ledger device disconnected. Reconnect and try again.";
    default:
      return error.message || `Ledger error: ${error._tag}`;
  }
}

function describeUserInteraction(interaction: string): string {
  switch (interaction) {
    case UserInteractionRequired.UnlockDevice:
      return "Unlock your Ledger device.";
    case UserInteractionRequired.ConfirmOpenApp:
      return "Open the Ethereum app on your Ledger device.";
    case UserInteractionRequired.SignTypedData:
      return "Review and confirm the payment on your Ledger device.";
    case UserInteractionRequired.SignPersonalMessage:
      return "Review and confirm the rejection on your Ledger device.";
    case UserInteractionRequired.Web3ChecksOptIn:
      return "Respond to the Web3 Checks prompt on your Ledger device.";
    case UserInteractionRequired.None:
      return "";
    default:
      return "Waiting for the Ledger device…";
  }
}

function awaitDeviceAction<Output, Err extends DmkError, Intermediate extends { requiredUserInteraction: string }>(
  action: ExecuteDeviceActionReturnType<Output, Err, Intermediate>,
  onStatus?: (message: string) => void,
): Promise<Output> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const subscription = action.observable.subscribe({
      next: (state) => {
        if (settled) {
          return;
        }
        switch (state.status) {
          case DeviceActionStatus.Pending:
            onStatus?.(describeUserInteraction(state.intermediateValue.requiredUserInteraction));
            break;
          case DeviceActionStatus.Completed:
            settled = true;
            resolve(state.output);
            subscription.unsubscribe();
            break;
          case DeviceActionStatus.Error:
            settled = true;
            reject(new LedgerDeviceError(state.error));
            subscription.unsubscribe();
            break;
          case DeviceActionStatus.Stopped:
            settled = true;
            reject(new Error("The Ledger action was cancelled."));
            subscription.unsubscribe();
            break;
        }
      },
      error: (error: unknown) => {
        if (settled) {
          return;
        }
        settled = true;
        reject(error instanceof Error ? error : new Error(String(error)));
      },
    });
  });
}

export interface ConnectedLedger {
  sessionId: string;
  signerEth: SignerEth;
}

export async function connectLedger(originToken: string | undefined): Promise<ConnectedLedger> {
  const dmk = getDeviceManagementKit();
  const discoveredDevice = await firstValueFrom(dmk.startDiscovering({}));
  await dmk.stopDiscovering();
  const sessionId = await dmk.connect({ device: discoveredDevice });
  const signerEth = new SignerEthBuilder({ dmk, sessionId, originToken }).build();
  return { sessionId, signerEth };
}

export function getApproverAddress(signerEth: SignerEth, onStatus?: (message: string) => void): Promise<`0x${string}`> {
  return awaitDeviceAction(signerEth.getAddress(AGENT_APPROVER_DERIVATION_PATH, { checkOnDevice: false }), onStatus).then(
    (output) => output.address,
  );
}
