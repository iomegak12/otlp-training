package com.tradenova.order;

/** Message published to the trade.orders Kafka topic for settlement. */
public record OrderEvent(
        String orderId,
        String accountId,
        String symbol,
        String side,
        int quantity,
        double price,
        double orderValue,
        String placedAt) {
}
