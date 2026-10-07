package com.tradenova.order;

/** Body of POST /api/orders. */
public record OrderRequest(String accountId, String symbol, String side, int quantity) {
}
