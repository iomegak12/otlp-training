package com.tradenova.order;

import java.util.concurrent.atomic.AtomicLong;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Keeps the (simulated) market session alive. Runs five times per second.
 *
 * The Java agent instruments Spring @Scheduled methods, so once the agent is on (Lab B)
 * every run becomes its own trace: about 300 useless traces per minute.
 */
@Component
public class MarketHeartbeat {

    private final AtomicLong ticks = new AtomicLong();

    @Scheduled(fixedRate = 200)
    public void refreshSessionStatus() {
        ticks.incrementAndGet();
    }
}
