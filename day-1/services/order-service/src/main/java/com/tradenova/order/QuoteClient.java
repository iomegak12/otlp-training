package com.tradenova.order;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

/**
 * Calls quote-service for the current price of a symbol.
 * The Java agent instruments this HTTP call automatically and adds the traceparent header.
 */
@Component
public class QuoteClient {

    private final RestClient restClient;

    public QuoteClient(RestClient.Builder builder,
                       @Value("${tradenova.quote-service.url}") String quoteServiceUrl) {
        this.restClient = builder.baseUrl(quoteServiceUrl).build();
    }

    public double currentPrice(String symbol) {
        try {
            Quote quote = restClient.get()
                    .uri("/api/quotes/{symbol}", symbol)
                    .retrieve()
                    .body(Quote.class);
            if (quote == null) {
                throw new IllegalStateException("Empty response from quote-service");
            }
            return quote.price();
        } catch (HttpClientErrorException.NotFound e) {
            throw new UnknownSymbolException(symbol);
        }
    }

    public record Quote(String symbol, double price, String currency) {
    }
}
