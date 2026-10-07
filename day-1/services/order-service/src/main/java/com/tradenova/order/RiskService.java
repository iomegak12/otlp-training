package com.tradenova.order;

import java.util.concurrent.ThreadLocalRandom;
import org.springframework.stereotype.Service;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import java.util.Locale;

/**
 * Pre-trade risk check: is the order value within the account limit?
 *
 * LAB C, step 1: this method does real work but is invisible in traces, because
 * no library instrumentation knows about it. Add a span for it with @WithSpan,
 * and record the symbol, order value and decision as span attributes.
 */
@Service
public class RiskService {

    static final double ACCOUNT_LIMIT = 250_000.00;

    public enum Decision {
        APPROVED, REJECTED
    }

    @WithSpan("risk.check")
    public Decision check(String accountId,
            @SpanAttribute("tradenova.order.symbol") String symbol,
            @SpanAttribute("tradenova.order.value") double orderValue) {
        evaluateRules();
        Decision decision = orderValue <= ACCOUNT_LIMIT ? Decision.APPROVED : Decision.REJECTED;

        // A rejected order is a valid outcome, not an error: record it, don't set ERROR
        // status.
        Span span = Span.current();
        span.setAttribute("tradenova.risk.limit", ACCOUNT_LIMIT);
        span.setAttribute("tradenova.risk.decision", decision.name().toLowerCase(Locale.ROOT));
        return decision;
    }

    /** Simulates evaluating the risk rules (5 to 25 ms). */
    private void evaluateRules() {
        try {
            Thread.sleep(ThreadLocalRandom.current().nextInt(5, 25));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
