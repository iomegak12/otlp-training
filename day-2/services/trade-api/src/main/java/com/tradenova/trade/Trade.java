package com.tradenova.trade;

/** A trade that has been accepted. */
public record Trade(
        String tradeId,
        String accountNumber,
        String symbol,
        String side,
        int quantity,
        double price,
        String placedAt) {
}
