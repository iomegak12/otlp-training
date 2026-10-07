-- Trades recorded by settlement-service
CREATE TABLE IF NOT EXISTS trades (
    order_id          TEXT PRIMARY KEY,
    account_id        TEXT          NOT NULL,
    symbol            TEXT          NOT NULL,
    side              TEXT          NOT NULL,
    quantity          INTEGER       NOT NULL,
    order_price       NUMERIC(12,2) NOT NULL,
    settlement_price  NUMERIC(12,2) NOT NULL,
    settled_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);
