package com.tradenova.trade;

import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.common.AttributeKey;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.LongCounter;
import io.opentelemetry.api.trace.Span;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ThreadLocalRandom;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * trade-api: accepts trades and returns an account's recent trades.
 *
 * This service is deliberately "badly behaved" so the Day 2 scenarios have something to fix
 * in the Collector, without touching this code:
 *   - it logs and records personal data (account number, email, card number)    -> scenario 3
 *   - it writes DEBUG logs for every request                                    -> scenario 4
 *   - it records account.id on a metric (one series per account)                -> scenario 4
 *   - latency and errors can be injected through /admin/chaos                   -> scenarios 8 and 9
 */
@RestController
public class TradeController {

    private static final Logger log = LoggerFactory.getLogger(TradeController.class);

    private static final AttributeKey<String> ACCOUNT_ID = AttributeKey.stringKey("account.id");
    private static final AttributeKey<String> SYMBOL = AttributeKey.stringKey("symbol");
    private static final AttributeKey<String> SIDE = AttributeKey.stringKey("side");

    private static final Map<String, Double> PRICES = new ConcurrentHashMap<>(Map.of(
            "TNVA", 182.40, "ACME", 64.15, "ORBT", 27.80, "QNTM", 245.90, "ZEPH", 118.35));

    private final ChaosSettings chaos;
    private final NotificationClient notifications;
    private final Map<String, Deque<Trade>> recentTrades = new ConcurrentHashMap<>();
    private final LongCounter tradesPlaced;

    public TradeController(ChaosSettings chaos, NotificationClient notifications) {
        this.chaos = chaos;
        this.notifications = notifications;
        this.tradesPlaced = GlobalOpenTelemetry.getMeter("com.tradenova.trade")
                .counterBuilder("tradenova.trades.placed")
                .setDescription("Trades accepted by trade-api")
                .setUnit("{trade}")
                .build();
    }

    @PostMapping("/api/trades")
    public ResponseEntity<Trade> placeTrade(@RequestBody TradeRequest request) {
        log.debug("Validating trade request {}", request);
        if (request.accountNumber() == null || request.symbol() == null || request.quantity() <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "accountNumber, symbol and quantity are required");
        }

        // Personal data on the span: visible in Tempo until scenario 3 masks it.
        Span span = Span.current();
        span.setAttribute("tradenova.account.number", request.accountNumber());
        if (request.customerEmail() != null) {
            span.setAttribute("tradenova.customer.email", request.customerEmail());
        }

        chaos.applyLatency();
        if (chaos.shouldFail()) {
            log.error("Ledger service unavailable while booking trade for account {}", request.accountNumber());
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Ledger service unavailable");
        }

        String symbol = request.symbol().toUpperCase(Locale.ROOT);
        Double basePrice = PRICES.get(symbol);
        if (basePrice == null) {
            log.warn("Unknown symbol {} requested by {}", symbol, request.customerEmail());
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unknown symbol " + symbol);
        }
        double price = nextPrice(symbol, basePrice);
        log.debug("Price lookup for {} returned {}", symbol, price);

        if (request.fundingCardNumber() != null) {
            log.info("Funding check passed for card {}", request.fundingCardNumber());
        }

        String side = request.side() == null ? "BUY" : request.side().toUpperCase(Locale.ROOT);
        Trade trade = new Trade(UUID.randomUUID().toString(), request.accountNumber(), symbol, side,
                request.quantity(), price, Instant.now().toString());
        Deque<Trade> history = recentTrades.computeIfAbsent(request.accountNumber(), k -> new ArrayDeque<>());
        synchronized (history) {
            history.addFirst(trade);
            while (history.size() > 20) {
                history.removeLast();
            }
        }

        // account.id makes this metric one series per account: the cost problem in scenario 4.
        tradesPlaced.add(1, Attributes.of(ACCOUNT_ID, request.accountNumber(), SYMBOL, symbol, SIDE, side));

        notifications.tradeAccepted(trade, request.customerEmail());

        log.info("Trade {} accepted for account {} (customer {}): {} {} x {} at {}",
                trade.tradeId(), request.accountNumber(), request.customerEmail(), side, symbol, request.quantity(), price);
        return ResponseEntity.status(HttpStatus.CREATED).body(trade);
    }

    @GetMapping("/api/trades/{accountNumber}/recent")
    public List<Trade> recent(@PathVariable String accountNumber) {
        log.debug("Loading recent trades for account {}", accountNumber);
        Span.current().setAttribute("tradenova.account.number", accountNumber);

        chaos.applyLatency();
        if (chaos.shouldFail()) {
            log.error("Trade store timeout for account {}", accountNumber);
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Trade store timeout");
        }

        Deque<Trade> history = recentTrades.get(accountNumber);
        if (history == null) {
            return List.of();
        }
        synchronized (history) {
            return List.copyOf(history);
        }
    }

    /** Called every second by the load balancer simulation in loadgen: the noise in scenario 4. */
    @GetMapping("/health")
    public String health() {
        return "ok";
    }

    private double nextPrice(String symbol, double current) {
        double next = Math.round(current * (1 + ThreadLocalRandom.current().nextDouble(-0.005, 0.005)) * 100.0) / 100.0;
        PRICES.put(symbol, next);
        return next;
    }
}
