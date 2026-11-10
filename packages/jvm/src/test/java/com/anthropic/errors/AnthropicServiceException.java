package com.anthropic.errors;

/** Shaped like the Anthropic Java SDK's: the helper knows it by name and its statusCode(). */
public class AnthropicServiceException extends RuntimeException {
    private final int status;

    public AnthropicServiceException(int status, String message) {
        super(message);
        this.status = status;
    }

    public int statusCode() {
        return status;
    }
}
