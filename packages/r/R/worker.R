# tinyeval sets TINYEVAL_CALLS for the workers it starts. There, loading the package points R's output at stderr, so
# print() and cat() in the app can't end up in a reply. Base R can't dup2: system() children still write to stdout.
.onLoad <- function(libname, pkgname) {
  if (nzchar(Sys.getenv("TINYEVAL_CALLS"))) sink(stderr())
}

worker <- function(answer) {
  answer <- match.fun(answer)
  # The process's stdout, which sink() leaves alone. Windows has no /dev/stdout, so cat, from Git Bash's PATH, copies to it.
  output <- if (.Platform$OS.type == "windows") pipe("cat", "wb") else file("/dev/stdout", "wb", raw = TRUE)
  input <- file("stdin", "rb")
  on.exit({
    close(input)
    close(output)
  })
  serve(answer, input, output)
}

couldnt_run <- function(reason) {
  stop(errorCondition(reason, class = "tinyeval_couldnt_run", call = sys.call(-1)))
}

# Each input up to a NUL byte, answered with the reply and a NUL byte, until stdin closes.
serve <- function(answer, input, output) {
  buffer <- raw(4096)
  n <- 0L
  repeat {
    # shortcut: one byte per read, about 5 microseconds each, as a longer read waits for every byte it asks for.
    byte <- readBin(input, "raw", 1L)
    if (!length(byte)) return(invisible())
    if (byte != as.raw(0L)) {
      if (n == length(buffer)) length(buffer) <- 2L * n
      n <- n + 1L
      buffer[[n]] <- byte
      next
    }
    text <- rawToChar(buffer[seq_len(n)]) # decoded once the whole input is in
    Encoding(text) <- "UTF-8"
    n <- 0L
    writeBin(c(charToRaw(enc2utf8(reply(answer, text))), as.raw(0L)), output)
    flush(output)
  }
}

reply <- function(answer, input) {
  calls <- NULL
  tryCatch(
    paste(withCallingHandlers(answer(input), error = function(e) calls <<- sys.calls()), collapse = "\n"),
    error = function(e) {
      why <- couldnt_run_reason(e)
      if (!is.null(why)) {
        return(paste0("#tinyeval couldnt_run ", why, "\n"))
      }
      said <- paste0(class(e)[[1]], ": ", conditionMessage(e))
      message(said, "\n", paste0("  ", vapply(calls, function(call) deparse(call, nlines = 1L)[[1]], ""), collapse = "\n"))
      said # the reply, so the eval fails
    }
  )
}

# Why the AI call couldn't run, or NULL when the error is the app's. httr2's errors, which ellmer's are too, match by
# class, so httr2 needn't be installed: 401, 429 and 5xx responses, and failures to connect or time out.
couldnt_run_reason <- function(e) {
  if (inherits(e, "tinyeval_couldnt_run")) {
    why <- conditionMessage(e)
  } else if (inherits(e, "httr2_http") && is.numeric(e$status) && (e$status %in% c(401, 429) || e$status >= 500)) {
    why <- paste("httr2:", sub("(?s)\n.*", "", conditionMessage(e), perl = TRUE)) # its first line, "HTTP 429 Too Many Requests."
  } else if (inherits(e, "httr2_failure")) {
    why <- paste("httr2:", conditionMessage(if (inherits(e$parent, "condition")) e$parent else e))
  } else {
    return(NULL)
  }
  gsub("\\s*[\r\n]+\\s*", " ", trimws(why))
}
