package com.tradenova.trade;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Tells notification-service about an accepted trade.
 *
 * notification-service is deployed later in the Day 3 demo. Until it exists, the call fails
 * quickly and is ignored, so trade-api works the same with or without it. Once it is deployed,
 * it appears inside existing trade traces with no change to this service.
 */
@Component
public class NotificationClient {

    private static final Logger log = LoggerFactory.getLogger(NotificationClient.class);

    private final RestClient restClient;
    private final boolean enabled;

    public NotificationClient(@Value("${tradenova.notification-service.url:}") String baseUrl) {
        this.enabled = baseUrl != null && !baseUrl.isBlank();
        HttpClient httpClient = HttpClient.newBuilder().connectTimeout(Duration.ofMillis(500)).build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
        factory.setReadTimeout(Duration.ofSeconds(2));
        this.restClient = RestClient.builder()
                .baseUrl(enabled ? baseUrl : "http://localhost")
                .requestFactory(factory)
                .build();
    }

    public void tradeAccepted(Trade trade, String customerEmail) {
        if (!enabled) {
            return;
        }
        try {
            restClient.post()
                    .uri("/api/notifications")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                            "tradeId", trade.tradeId(),
                            "accountNumber", trade.accountNumber(),
                            "customerEmail", customerEmail == null ? "" : customerEmail,
                            "symbol", trade.symbol(),
                            "side", trade.side(),
                            "quantity", trade.quantity()))
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception e) {
            // notification-service not deployed (yet) or unavailable: the trade is still accepted.
            log.debug("Notification skipped for trade {}: {}", trade.tradeId(), e.getMessage());
        }
    }
}
