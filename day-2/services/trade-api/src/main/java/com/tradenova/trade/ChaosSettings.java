package com.tradenova.trade;

import java.util.concurrent.ThreadLocalRandom;
import org.springframework.stereotype.Component;

/**
 * Failure injection used by the scenarios:
 *  - latencyMs slows every trade request down (scenario 9, slow trades; scenario 8, latency alert)
 *  - errorRate makes a share of requests fail with HTTP 500 (scenario 8, error-rate alert)
 * Changed at runtime through /admin/chaos, so no restart is needed during a demo.
 */
@Component
public class ChaosSettings {

    private volatile int latencyMs = 0;
    private volatile double errorRate = 0.0;

    public int latencyMs() {
        return latencyMs;
    }

    public double errorRate() {
        return errorRate;
    }

    public void update(Integer newLatencyMs, Double newErrorRate) {
        if (newLatencyMs != null) {
            latencyMs = Math.max(0, newLatencyMs);
        }
        if (newErrorRate != null) {
            errorRate = Math.min(1.0, Math.max(0.0, newErrorRate));
        }
    }

    /** Applies the configured delay. */
    public void applyLatency() {
        if (latencyMs <= 0) {
            return;
        }
        // +/- 20% jitter so the latency looks realistic in traces and histograms
        int jitter = (int) (latencyMs * 0.2);
        int delay = latencyMs + ThreadLocalRandom.current().nextInt(-jitter, jitter + 1);
        try {
            Thread.sleep(Math.max(0, delay));
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    /** True when this request should fail. */
    public boolean shouldFail() {
        return errorRate > 0 && ThreadLocalRandom.current().nextDouble() < errorRate;
    }
}
