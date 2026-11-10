<?php

namespace Tinyeval;

/**
 * Throw it when the AI call couldn't run, such as without an API key. tinyeval then counts the test case apart
 * from the failures, since it says nothing about the reply.
 */
class CouldntRun extends \RuntimeException
{
}
