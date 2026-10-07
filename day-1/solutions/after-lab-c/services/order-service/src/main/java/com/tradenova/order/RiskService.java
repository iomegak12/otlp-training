package com.tradenova.order;

import io.opentelemetry.api.trace.Span;
import io.opentelemetry.instrumentation.annotations.SpanAttribute;
import io.opentelemetry.instrumentation.annotations.WithSpan;
import java.util.Locale;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.stereotype.Service;

/**
 * Pre-trade risk check: is the order value within the account limit?
 *
 * LAB C, step 1 (solution): @WithSpan creates an INTERNAL span named "risk.check" every time
 * this method runs. @SpanAttribute records method arguments as span attributes, and
 * Span.current() adds attributes that are only known inside the method.
 */
@Service
public class RiskService {

    static final double ACCOUNT_LIMIT = 250_000.00;

    public enum Decision { APPROVED, REJECTED }

    @WithSpan("risk.check")
    public Decision check(String accountId,
                          @SpanAttribute("tradenova.order.symbol") String symbol,
                          @SpanAttribute("tradenova.order.value") double orderValue) {
        evaluateRules();
        Decision decision = orderValue <= ACCOUNT_LIMIT ? Decision.APPROVED : Decision.REJECTED;

        // A rejected order is a valid business outcome, not an error: record it as an
        // attribute and leave the span status unset.
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
