package com.tradenova.order;

/** Thrown when quote-service does not know the requested ticker symbol. */
public class UnknownSymbolException extends RuntimeException {

    public UnknownSymbolException(String symbol) {
        super("Unknown symbol " + symbol);
    }
}
