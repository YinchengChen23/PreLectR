% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/MultiClass.R
\name{AutoScanningMultiClass}
\alias{AutoScanningMultiClass}
\title{Automatically Lambda Scanning for Multi-Class Classification}
\usage{
AutoScanningMultiClass(
  X_scale,
  X_raw,
  Y,
  step = 50,
  run_echo = FALSE,
  max_iter = 10000,
  tol = 1e-04,
  lr = 0.001,
  alpha = 0.9,
  epsilon = 1e-08
)
}
\arguments{
\item{X_scale}{Matrix or DataFrame. Scaled data with samples as rows and features as columns, used for machine learning. If no scaled data is provided, raw count data may be used.}

\item{X_raw}{Matrix or DataFrame. Raw count data with samples as rows and features as columns, used to calculate feature prevalence.}

\item{Y}{Character vector. Labels for the data.}

\item{step}{Integer. The number of intervals for splitting within the upper and lower bounds when examining lambda values (default is 50).}

\item{run_echo}{Logical. If TRUE, prints the training result for each lambda being tested (default is FALSE).}

\item{max_iter}{Integer. Maximum number of iterations taken for the solvers to converge (default is 10000).}

\item{tol}{Numeric. Tolerance for stopping criteria (default is 1e-4).}

\item{lr}{Numeric. Learning rate in RMSprop optimizer (default is 0.001).}

\item{alpha}{Numeric. Smoothing constant in RMSprop optimizer (default is 0.9).}

\item{epsilon}{Numeric. Small constant added to the denominator to improve numerical stability (default is 1e-8).}
}
\value{
A vector for examining log-lambda.
}
\description{
This function scans a range of lambda values from 1e-10 to 0.1, identifying the upper and lower boundaries that represent when lasso starts filtering and when it drops all features. The range is divided into `k` parts for examining lambda values.
}
\examples{
set.seed(42)
n_samples <- 10
n_features <- 100

X_raw <- matrix(rnbinom(n_features * n_samples, size = 10, mu = 1), nrow = n_features, ncol = n_samples)
X_scaled <- t(scale(t(X_raw)))  # feature-wise z-standardization

diagnosis <- c('CRC','CRC','control','Adenoma','Adenoma','CRC','control','control','CRC','CRC')

lrange <- AutoScanningMultiClass(X_scaled, X_raw, diagnosis, step=30)

tuning_res <- LambdaTuningMultiClass(X_scaled, X_raw, diagnosis, lrange, outpath=getwd())

lmbd_picking <- LambdaDecision(tuning_res$TuningResult, tuning_res$PvlDistSummary)

# optimal lambda
lmbd_picking$opt_lmbd

# segmented regression visualization
library(patchwork)
lmbd_picking$selected_lmbd_plot/lmbd_picking$pvl_plot

}
