run <- function(...) {
  bash <- bash_path()
  if (is.null(bash)) {
    message("tinyeval needs bash 3.2 or later. On Windows, install Git for Windows: https://git-scm.com/download/win")
    return(invisible(2L))
  }
  env <- c(
    # tinyeval update prints this, and so does the notice of a new release.
    # In an renv project, renv.lock has to record the new version too.
    TINYEVAL_PACKAGE_UPDATE = paste0("Rscript -e 'install.packages(\"tinyeval\", repos = \"https://evalship-hq.r-universe.dev\")",
      if (file.exists("renv.lock")) "; renv::snapshot()", "'"),
    # .Rprofile runs before a worker's library(tinyeval), and renv's out-of-sync note there would land in a reply.
    RENV_CONFIG_SYNCHRONIZED_CHECK = "FALSE"
  )
  old <- Sys.getenv(names(env), NA, names = TRUE)
  on.exit({
    Sys.unsetenv(names(old)[is.na(old)])
    if (any(!is.na(old))) do.call(Sys.setenv, as.list(old[!is.na(old)]))
  })
  do.call(Sys.setenv, as.list(env))
  # stdin, stdout and stderr pass through. Ctrl-C reaches bash, which stops the run, and this returns its code.
  invisible(system2(bash, shQuote(c(system.file("tinyeval", package = "tinyeval"), as.character(c(...))))))
}

# Git for Windows' bash, next to the cmd folder that has git.exe, before a bash on PATH, which may be WSL's.
bash_path <- function() {
  candidates <- Sys.which("bash")
  if (.Platform$OS.type == "windows") {
    git <- Sys.which("git")
    candidates <- c(
      if (nzchar(git)) file.path(dirname(dirname(git)), "bin", "bash.exe"),
      "C:/Program Files/Git/bin/bash.exe",
      candidates
    )
  }
  found <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(found)) found[[1]]
}
