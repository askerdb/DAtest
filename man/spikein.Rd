% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/spikein.R
\name{spikein}
\alias{spikein}
\title{Spike-in}
\usage{
spikein(count_table, predictor, effectSize = 2, k, num.pred = FALSE,
  relative = TRUE)
}
\arguments{
\item{count_table}{Matrix or data.frame. Table with taxa/genes/proteins as rows and samples as columns}

\item{predictor}{Factor or Numeric. The predictor of interest. E.g. case and control. If the \code{predictor} has more than two levels, only the 2. level will be spiked.}

\item{effectSize}{Integer. The effect size for the spike-ins. Default 2}

\item{k}{Vector of length 3. Number of Features to spike in each tertile (lower, mid, upper). k=c(5,10,15): 5 features spiked in low abundance tertile, 10 features spiked in mid abundance tertile and 15 features spiked in high abundance tertile. Default c(5,5,5)}

\item{num.pred}{Logical. Is the \code{predictor} numeric? Default FALSE}

\item{relative}{Logical. Are abundances relative? Default TRUE}
}
\description{
Internal function for the \code{testDA} function.
}
\details{
Modified version of the one from:
https://microbiomejournal.biomedcentral.com/articles/10.1186/s40168-016-0208-8.
}
