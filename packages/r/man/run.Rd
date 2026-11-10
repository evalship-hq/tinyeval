\name{run}
\alias{run}
\title{Run tinyeval}
\description{
Runs the bundled tinyeval with bash, which runs the test cases in \file{evals/}.
stdin, stdout and stderr pass through. Ctrl-C reaches bash, which stops the run.
}
\usage{
run(...)
}
\arguments{
\item{...}{tinyeval's arguments, as strings or character vectors, such as \code{"-n", "3"}.}
}
\value{
tinyeval's exit code, invisibly: 0 when every eval passed, 1 when one failed or couldn't run, and 2 for a usage error or when bash is missing.
}
\details{
Needs bash 3.2 or later: macOS, Linux, or Git for Windows, whose bash goes before one on PATH.
A repo that commits its own \file{tinyeval} file runs that copy.
In CI, exit with its code: \code{Rscript -e 'quit(status = tinyeval::run())'}.
}
