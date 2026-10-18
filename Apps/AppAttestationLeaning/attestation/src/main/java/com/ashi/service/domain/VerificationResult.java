package com.ashi.service.domain;

public record VerificationResult(boolean valid, String message) {
    public static VerificationResult pass() {
        return new VerificationResult(true, "");
    }

    public static VerificationResult fail(String message) {
        return new VerificationResult(false, message);
    }
}
