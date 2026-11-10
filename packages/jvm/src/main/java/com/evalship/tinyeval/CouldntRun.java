package com.evalship.tinyeval;

/**
 * Throw it when the AI call couldn't run, such as with no API key. tinyeval counts the test case apart from the
 * failures, and still exits 1.
 */
public class CouldntRun extends RuntimeException {
    /** @param reason what tinyeval shows, such as "ANTHROPIC_API_KEY isn't set" */
    public CouldntRun(String reason) {
        super(reason);
    }
}
