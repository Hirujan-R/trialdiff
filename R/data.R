#' Synthetic ADSL data cuts
#'
#' Two synthetic subject-level analysis datasets (`ADSL`) representing two data
#' cuts of the same study. No proprietary or real patient data is used. The
#' later cut contains new subjects, a withdrawn subject, a treatment-assignment
#' correction, age corrections, missingness changes, a new variable (`REGION`)
#' and a label change for `AGE`.
#'
#' @format A data frame with one row per subject and variables:
#' \describe{
#'   \item{STUDYID}{Study identifier.}
#'   \item{USUBJID}{Unique subject identifier.}
#'   \item{SUBJID}{Subject identifier within study.}
#'   \item{SITEID}{Investigator site identifier.}
#'   \item{AGE}{Age.}
#'   \item{SEX}{Sex.}
#'   \item{RACE}{Race.}
#'   \item{TRT01P}{Planned treatment for period 01.}
#'   \item{TRT01A}{Actual treatment for period 01.}
#'   \item{SAFFL}{Safety population flag.}
#'   \item{ITTFL}{Intention-to-treat population flag.}
#'   \item{REGION}{Geographic region (later cut only).}
#' }
#' @name adsl_cut1
#' @aliases adsl_cut2
#' @keywords datasets
"adsl_cut1"

#' @rdname adsl_cut1
"adsl_cut2"

#' Synthetic ADLB data cuts
#'
#' Two synthetic laboratory analysis datasets (`ADLB`) with a long structure
#' keyed by subject, parameter and visit. The later cut adds records for new
#' subjects and includes corrected, missing-to-value and value-to-missing
#' laboratory values.
#'
#' @format A data frame with one row per subject/parameter/visit and variables:
#' \describe{
#'   \item{USUBJID}{Unique subject identifier.}
#'   \item{PARAMCD}{Parameter code.}
#'   \item{PARAM}{Parameter name.}
#'   \item{AVISIT}{Analysis visit.}
#'   \item{TRT01P}{Planned treatment for period 01.}
#'   \item{AVAL}{Analysis value.}
#'   \item{BASE}{Baseline value.}
#'   \item{CHG}{Change from baseline.}
#'   \item{ABLFL}{Baseline flag.}
#' }
#' @name adlb_cut1
#' @aliases adlb_cut2
#' @keywords datasets
"adlb_cut1"

#' @rdname adlb_cut1
"adlb_cut2"

#' Example ADSL/ADLB lineage
#'
#' A `td_lineage` object linking treatment assignment, population flags and
#' laboratory analysis values to downstream summaries, an MMRM analysis and
#' outputs. Intended for use in examples and vignettes.
#'
#' @format A `td_lineage` object (see [define_lineage()]).
#' @keywords datasets
"adsl_adlb_lineage"
