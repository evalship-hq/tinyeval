/** Throw it when the AI call couldn't run, such as without an API key: tinyeval counts the test case apart from the failures. */
export class CouldntRun extends Error {
  constructor(reason?: string);
}

/**
 * Answers each input from an eval file's `worker` line with `answer`, one at a time, and exits when tinyeval is done.
 * An error from `answer` becomes the reply, so the eval fails. CouldntRun, and auth, rate-limit, server, connection
 * and timeout errors from `@anthropic-ai/sdk` and `openai`, make the test case couldn't run instead.
 */
export function worker(answer: (input: string) => string | PromiseLike<string>): Promise<never>;
