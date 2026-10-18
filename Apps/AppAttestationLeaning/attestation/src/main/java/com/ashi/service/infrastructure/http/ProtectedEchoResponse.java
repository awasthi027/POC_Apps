package com.ashi.service.infrastructure.http;

public record ProtectedEchoResponse(
        String status,
        String message,
        String method,
        String path,
        String body
) {
}
