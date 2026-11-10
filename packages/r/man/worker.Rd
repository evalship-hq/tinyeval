\name{worker}
\alias{worker}
\alias{couldnt_run}
\title{Answer tinyeval's test cases from R}
\description{
\code{worker()} answers each input tinyeval sends with \code{answer(input)}, until tinyeval closes stdin.
Start it from the \code{worker} line of an eval file, such as \code{worker Rscript evals/worker.R}.

\code{couldnt_run()} signals that the AI call couldn't run, such as on a missing key.
tinyeval counts the test case apart from the failures, and the run still exits 1.
}
\usage{
worker(answer)

couldnt_run(reason)
}
\arguments{
\item{answer}{A function that takes the input string and returns the reply.}
\item{reason}{Why the AI call couldn't run, shown in tinyeval's summary.}
}
\details{
Call \code{library(tinyeval)} before your app loads. In a worker tinyeval starts, it points R's output at
stderr with \code{\link{sink}}, so \code{print()} and \code{cat()} in your app can't end up in a reply.
The replies go to the process's stdout. Programs started with \code{system()} still write to stdout.

httr2's errors, ellmer's included, count as couldn't run when the status is 401, 429 or 500 and up, and when the request
couldn't connect or timed out. Any other error becomes the reply, as \code{class: message}, so the eval fails, and
the calls that led to it go to stderr. The worker goes on with the next input.
}
\value{
\code{worker()} returns when stdin closes. \code{couldnt_run()} doesn't return.
}
