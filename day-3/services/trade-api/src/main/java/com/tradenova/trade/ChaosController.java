package com.tradenova.trade;

import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * GET  /admin/chaos                              current settings
 * POST /admin/chaos?latencyMs=800&errorRate=0.3  change them (either parameter is optional)
 * POST /admin/chaos?latencyMs=0&errorRate=0      back to normal
 */
@RestController
@RequestMapping("/admin/chaos")
public class ChaosController {

    private static final Logger log = LoggerFactory.getLogger(ChaosController.class);

    private final ChaosSettings chaos;

    public ChaosController(ChaosSettings chaos) {
        this.chaos = chaos;
    }

    @GetMapping
    public Map<String, Object> current() {
        return Map.of("latencyMs", chaos.latencyMs(), "errorRate", chaos.errorRate());
    }

    @PostMapping
    public Map<String, Object> update(@RequestParam(required = false) Integer latencyMs,
                                      @RequestParam(required = false) Double errorRate) {
        chaos.update(latencyMs, errorRate);
        log.warn("Chaos settings changed: latencyMs={} errorRate={}", chaos.latencyMs(), chaos.errorRate());
        return current();
    }
}
