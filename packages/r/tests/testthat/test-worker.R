nul <- as.raw(0L)
bytes <- function(...) unlist(lapply(list(...), function(x) if (is.raw(x)) x else charToRaw(enc2utf8(x))))

# The bytes serve() writes for these input bytes.
served <- function(answer, input) {
  inp <- rawConnection(input)
  out <- rawConnection(raw(0), "wb")
  on.exit({
    close(inp)
    close(out)
  })
  serve(answer, inp, out)
  rawConnectionValue(out)
}

echo <- function(input) paste("You said:", input)

test_that("several inputs in one read get one reply each", {
  expect_identical(
    served(echo, bytes("one", nul, "two", nul)),
    bytes("You said: one", nul, "You said: two", nul)
  )
})

test_that("UTF-8 input arrives as UTF-8, and the reply goes out as UTF-8", {
  text <- "naïve 日本語 ✓"
  got <- NULL
  out <- served(function(input) {
    got <<- input
    input
  }, bytes(text, nul))
  expect_identical(got, text)
  expect_identical(Encoding(got), "UTF-8")
  expect_identical(out, bytes(text, nul))
})

test_that("couldnt_run() and httr2's 429 count as couldn't run, on one line", {
  http <- function(status, message) {
    structure(
      class = c(paste0("httr2_http_", status), "httr2_http", "httr2_error", "error", "condition"),
      list(message = message, call = NULL, status = status)
    )
  }
  failure <- structure(
    class = c("httr2_failure", "httr2_error", "error", "condition"),
    list(message = "Failed to perform HTTP request.", call = NULL, parent = simpleError("Timeout was reached:\nafter 1000 ms"))
  )
  errors <- list(
    function() couldnt_run("ANTHROPIC_API_KEY isn't set\nin the env"),
    function() stop(http(429L, "HTTP 429 Too Many Requests.\n* Rate limited")),
    function() stop(http(529L, "HTTP 529.")),
    function() stop(failure)
  )
  out <- served(function(input) errors[[as.integer(input)]](), bytes("1", nul, "2", nul, "3", nul, "4", nul))
  expect_identical(out, bytes(
    "#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set in the env\n", nul,
    "#tinyeval couldnt_run httr2: HTTP 429 Too Many Requests.\n", nul,
    "#tinyeval couldnt_run httr2: HTTP 529.\n", nul,
    "#tinyeval couldnt_run httr2: Timeout was reached: after 1000 ms\n", nul
  ))
})

test_that("an app error, or an API error such as a 400, becomes the reply, and the worker goes on", {
  answer <- function(input) {
    if (input == "crash") stop("boom")
    if (input == "400") {
      stop(structure(class = c("httr2_http_400", "httr2_http", "error", "condition"), list(message = "HTTP 400 Bad Request.", call = NULL, status = 400L)))
    }
    echo(input)
  }
  expect_message(
    out <- served(answer, bytes("crash", nul, "400", nul, "hi", nul)),
    "simpleError: boom\n.*answer\\(input\\)"
  )
  expect_identical(out, bytes("simpleError: boom", nul, "httr2_http_400: HTTP 400 Bad Request.", nul, "You said: hi", nul))
})

test_that("a worker tinyeval starts keeps the app's output off stdout, and joins an input split across reads", {
  skip_on_os("windows") # the end-to-end run covers Windows, under Git Bash
  skip_if_not(nzchar(Sys.which("bash")))
  out <- tempfile()
  err <- tempfile()
  app <- 'library(tinyeval); cat("app loaded\\n"); worker(function(input) { print("app called"); paste("You said:", input) })'
  # The first write ends in the middle of the two bytes of the i in "naive".
  feed <- "printf 'one\\0two\\0na\\303'; sleep 0.5; printf '\\257ve\\0'"
  script <- sprintf("(%s) | TINYEVAL_CALLS=calls %s --vanilla -e %s", feed, shQuote(file.path(R.home("bin"), "Rscript")), shQuote(app))
  status <- system2("bash", c("-c", shQuote(script)), stdout = out, stderr = err)
  expect_identical(status, 0L)
  expect_identical(readBin(out, "raw", 1000L), bytes("You said: one", nul, "You said: two", nul, "You said: naïve", nul))
  expect_match(paste(readLines(err), collapse = "\n"), "app loaded\n.*app called")
})
