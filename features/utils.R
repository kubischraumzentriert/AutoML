safe_divide <- function(numerator, denominator) {
  if_else(
    is.na(numerator) | is.na(denominator) | denominator == 0,
    NA_real_,
    numerator / denominator
  )
}
