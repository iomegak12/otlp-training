package com.tradenova.trade;

/**
 * Body of POST /api/trades.
 * customerEmail and fundingCardNumber are personal data: they end up in logs and spans on purpose
 * (scenario 3, PII compliance).
 */
public record TradeRequest(
        String accountNumber,
        String customerEmail,
        String fundingCardNumber,
        String symbol,
        String side,
        int quantity) {
}
