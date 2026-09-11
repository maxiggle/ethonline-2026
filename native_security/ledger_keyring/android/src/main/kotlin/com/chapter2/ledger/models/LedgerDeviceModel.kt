package com.chapter2.ledger.models

public enum class LedgerDeviceModel(
    val displayName: String,
    val supportsBle: Boolean,
    val supportsTouchScreen: Boolean,
    val screenWidthPixels: Int,
    val serviceUuidString: String
) {
    NANO_S(
        displayName = "Nano S",
        supportsBle = false,
        supportsTouchScreen = false,
        screenWidthPixels = 128,
        serviceUuidString = ""
    ),
    NANO_SP(
        displayName = "Nano S Plus",
        supportsBle = false,
        supportsTouchScreen = false,
        screenWidthPixels = 128,
        serviceUuidString = ""
    ),
    NANO_X(
        displayName = "Nano X",
        supportsBle = true,
        supportsTouchScreen = false,
        screenWidthPixels = 128,
        serviceUuidString = "13D63400-2C97-0004-0000-4C6564676572"
    ),
    STAX(
        displayName = "Ledger Stax",
        supportsBle = true,
        supportsTouchScreen = true,
        screenWidthPixels = 400,
        serviceUuidString = "13D63400-2C97-6004-0000-4C6564676572"
    ),
    FLEX(
        displayName = "Ledger Flex",
        supportsBle = true,
        supportsTouchScreen = true,
        screenWidthPixels = 480,
        serviceUuidString = "13D63400-2C97-6004-0000-4C6564676572"
    );

    companion object {
        fun fromDisplayName(name: String): LedgerDeviceModel? {
            return entries.find { it.displayName.equals(name, ignoreCase = true) }
        }
    }
}
