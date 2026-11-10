package com.anthropic.errors;

/** Shaped like the Anthropic Java SDK's network error. */
public class AnthropicIoException extends RuntimeException {
    public AnthropicIoException(String message, Throwable cause) {
        super(message, cause);
    }
}
