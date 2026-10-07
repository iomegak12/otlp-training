package com.tradenova.order;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.metrics.Meter;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * POST /api/orders: price the order, run the risk check and publish accepted orders to Kafka.
 *
 * LAB C, step 2 (solution): tradenova.orders.placed counts every order by side and outcome,
 * and tradenova.order.value records the value of accepted orders.
 */
@RestController
@RequestMapping("/api/orders")
public class OrderController {

    private static final Logger log = LoggerFactory.getLogger(OrderController.class);
    private static final String TOPIC = "trade.orders";

    private static final AttributeKey<String> SIDE = AttributeKey.stringKey("side");
    private static final AttributeKey<String> OUTCOME = AttributeKey.stringKey("outcome");

    private final QuoteClient quoteClient;
    private final RiskService riskService;
    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    private final LongCounter ordersPlaced;
    private final DoubleHistogram orderValueHistogram;

    public OrderController(QuoteClient quoteClient,
                           RiskService riskService,
                           KafkaTemplate<String, OrderEvent> kafkaTemplate) {
        this.quoteClient = quoteClient;
        this.riskService = riskService;
        this.kafkaTemplate = kafkaTemplate;

        // With the Java agent attached, GlobalOpenTelemetry returns the agent's SDK.
        // Without it, these instruments are no-ops and cost almost nothing.
        Meter meter = GlobalOpenTelemetry.getMeter("com.tradenova.order");
        this.ordersPlaced = meter.counterBuilder("tradenova.orders.placed")
                .setDescription("Orders received by order-service, by side and outcome")
                .setUnit("{order}")
                .build();
        this.orderValueHistogram = meter.histogramBuilder("tradenova.order.value")
                .setDescription("Value of accepted orders")
                .setUnit("{USD}")
                // Advice: default bucket boundaries for this histogram (a View can still override them).
                .setExplicitBucketBoundariesAdvice(List.of(1_000.0, 5_000.0, 10_000.0, 25_000.0, 50_000.0, 100_000.0, 250_000.0))
                .build();
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> placeOrder(@RequestBody OrderRequest request) {
        if (request.accountId() == null || request.symbol() == null || request.quantity() <= 0) {
            ordersPlaced.add(1, Attributes.of(SIDE, "UNKNOWN", OUTCOME, "invalid_request"));
            return ResponseEntity.badRequest()
                    .body(Map.of("status", "REJECTED", "reason", "accountId, symbol and a positive quantity are required"));
        }
        String symbol = request.symbol().toUpperCase(Locale.ROOT);
        String side = request.side() == null ? "BUY" : request.side().toUpperCase(Locale.ROOT);

        double price;
        try {
            price = quoteClient.currentPrice(symbol);
        } catch (UnknownSymbolException e) {
            ordersPlaced.add(1, Attributes.of(SIDE, side, OUTCOME, "unknown_symbol"));
            log.warn("Order rejected: unknown symbol {}", symbol);
            return ResponseEntity.badRequest()
                    .body(Map.of("status", "REJECTED", "reason", e.getMessage()));
        }

        double orderValue = Math.round(price * request.quantity() * 100.0) / 100.0;
        RiskService.Decision decision = riskService.check(request.accountId(), symbol, orderValue);
        if (decision == RiskService.Decision.REJECTED) {
            ordersPlaced.add(1, Attributes.of(SIDE, side, OUTCOME, "risk_rejected"));
            log.info("Order rejected by risk check: {} {} x {} (value {})", side, symbol, request.quantity(), orderValue);
            return ResponseEntity.unprocessableEntity()
                    .body(Map.of("status", "REJECTED", "reason", "Order value exceeds account limit"));
        }

        String orderId = UUID.randomUUID().toString();
        OrderEvent event = new OrderEvent(orderId, request.accountId(), symbol, side,
                request.quantity(), price, orderValue, Instant.now().toString());
        kafkaTemplate.send(TOPIC, request.accountId(), event);

        ordersPlaced.add(1, Attributes.of(SIDE, side, OUTCOME, "accepted"));
        orderValueHistogram.record(orderValue, Attributes.of(SIDE, side));

        log.info("Order {} accepted: {} {} x {} at {}", orderId, side, symbol, request.quantity(), price);
        return ResponseEntity.accepted()
                .body(Map.of("orderId", orderId, "status", "ACCEPTED", "price", price, "orderValue", orderValue));
    }
}
