## Generate synthetic clinical-trial data cuts for trialdiff
## No proprietary or real patient data is used.
##
## Run from the package root:
##   Rscript data-raw/synthetic-data.R

set.seed(2026)

n <- 30
subjects <- sprintf("S%03d", seq_len(n))

adsl_cut1 <- data.frame(
  STUDYID = "TD001",
  USUBJID = paste0("TD001-", subjects),
  SUBJID = subjects,
  SITEID = sprintf("%02d", rep(1:6, length.out = n)),
  AGE = sample(18:75, n, replace = TRUE),
  SEX = sample(c("F", "M"), n, replace = TRUE),
  RACE = sample(c("WHITE", "ASIAN", "BLACK OR AFRICAN AMERICAN"),
                n, replace = TRUE),
  TRT01P = sample(c("Placebo", "Drug A", "Drug B"), n, replace = TRUE,
                  prob = c(0.34, 0.33, 0.33)),
  SAFFL = sample(c("Y", "N"), n, replace = TRUE, prob = c(0.9, 0.1)),
  ITTFL = sample(c("Y", "N"), n, replace = TRUE, prob = c(0.85, 0.15)),
  stringsAsFactors = FALSE
)
adsl_cut1$TRT01A <- adsl_cut1$TRT01P
attr(adsl_cut1$AGE, "label") <- "Age"
attr(adsl_cut1$TRT01P, "label") <- "Planned Treatment for Period 01"
attr(adsl_cut1$SAFFL, "label") <- "Safety Population Flag"

## Cut 2: two new subjects, one subject withdrawn, one treatment correction,
## two age corrections, one missing-to-non-missing, one non-missing-to-missing,
## a new variable (REGION) and a label change for AGE.
adsl_cut2 <- adsl_cut1
adsl_cut2 <- adsl_cut2[!(adsl_cut2$SUBJID %in% c("S003")), ]

new_rows <- adsl_cut1[c(1, 2), ]
new_rows$SUBJID <- c("S031", "S032")
new_rows$USUBJID <- paste0("TD001-", new_rows$SUBJID)
new_rows$AGE <- c(44, 59)
new_rows$TRT01P <- c("Drug B", "Placebo")
new_rows$TRT01A <- new_rows$TRT01P
adsl_cut2 <- rbind(adsl_cut2, new_rows)

adsl_cut2$TRT01P[adsl_cut2$SUBJID == "S005"] <- "Drug A"
adsl_cut2$TRT01A[adsl_cut2$SUBJID == "S005"] <- "Drug A"
adsl_cut2$AGE[adsl_cut2$SUBJID == "S007"] <- adsl_cut2$AGE[adsl_cut2$SUBJID == "S007"] + 1
adsl_cut2$AGE[adsl_cut2$SUBJID == "S011"] <- adsl_cut2$AGE[adsl_cut2$SUBJID == "S011"] - 1
adsl_cut2$SEX[adsl_cut2$SUBJID == "S014"] <- NA_character_
adsl_cut2$RACE[adsl_cut2$SUBJID == "S018"] <- "WHITE"

adsl_cut2$REGION <- sample(c("EU", "NA", "APAC"), nrow(adsl_cut2), replace = TRUE)
attr(adsl_cut2$AGE, "label") <- "Age at informed consent"
attr(adsl_cut2$TRT01P, "label") <- "Planned Treatment for Period 01"
attr(adsl_cut2$SAFFL, "label") <- "Safety Population Flag"

adsl_cut1 <- adsl_cut1[order(adsl_cut1$USUBJID), ]
adsl_cut2 <- adsl_cut2[order(adsl_cut2$USUBJID), ]
rownames(adsl_cut1) <- NULL
rownames(adsl_cut2) <- NULL

## ---- ADLB -----------------------------------------------------------------

params <- c("ALT" = "Alanine Aminotransferase", "AST" = "Aspartate Aminotransferase",
            "CREAT" = "Creatinine", "HGB" = "Haemoglobin")
visits <- c("Baseline", "Week 4", "Week 8")
trt <- stats::setNames(adsl_cut1$TRT01P, adsl_cut1$SUBJID)

make_adlb <- function(subjects, trt_map, seed) {
  set.seed(seed)
  grid <- expand.grid(
    USUBJID = paste0("TD001-", subjects),
    PARAMCD = names(params),
    AVISIT = visits,
    stringsAsFactors = FALSE
  )
  grid$PARAM <- params[grid$PARAMCD]
  grid$TRT01P <- trt_map[sub("TD001-", "", grid$USUBJID)]
  base <- stats::rnorm(nrow(grid), mean = 40, sd = 12)
  base[grid$PARAMCD == "HGB"] <- stats::rnorm(sum(grid$PARAMCD == "HGB"),
                                              mean = 130, sd = 15)
  grid$AVAL <- round(base, 2)
  key <- paste(grid$USUBJID, grid$PARAMCD, sep = "|")
  base_key <- paste(
    grid$USUBJID[grid$AVISIT == "Baseline"],
    grid$PARAMCD[grid$AVISIT == "Baseline"],
    sep = "|"
  )
  base_vals <- stats::setNames(grid$AVAL[grid$AVISIT == "Baseline"], base_key)
  grid$BASE <- round(unname(base_vals[key]), 2)
  grid$CHG <- round(grid$AVAL - grid$BASE, 2)
  grid$ABLFL <- ifelse(grid$AVISIT == "Baseline", "Y", "")
  grid[, c("USUBJID", "PARAMCD", "PARAM", "AVISIT", "TRT01P", "AVAL", "BASE",
           "CHG", "ABLFL")]
}

adlb_cut1 <- make_adlb(adsl_cut1$SUBJID, trt, 101)
adlb_cut2 <- adlb_cut1

## New subject records
new_subj <- setdiff(adsl_cut2$SUBJID, adsl_cut1$SUBJID)
if (length(new_subj) > 0L) {
  trt2 <- stats::setNames(adsl_cut2$TRT01P, adsl_cut2$SUBJID)
  add <- make_adlb(new_subj, trt2, 202)
  adlb_cut2 <- rbind(adlb_cut2, add)
}

## Corrected AVAL for one record, missing -> value and value -> missing
idx1 <- which(adlb_cut2$USUBJID == "TD001-S004" & adlb_cut2$PARAMCD == "ALT" &
                adlb_cut2$AVISIT == "Week 4")
if (length(idx1) == 1L) adlb_cut2$AVAL[idx1] <- adlb_cut2$AVAL[idx1] + 5
idx2 <- which(adlb_cut2$USUBJID == "TD001-S006" & adlb_cut2$PARAMCD == "AST" &
                adlb_cut2$AVISIT == "Week 8")
if (length(idx2) == 1L) adlb_cut2$AVAL[idx2] <- NA_real_
idx3 <- which(adlb_cut2$USUBJID == "TD001-S009" & adlb_cut2$PARAMCD == "HGB" &
                adlb_cut2$AVISIT == "Week 4")
if (length(idx3) == 1L) adlb_cut2$AVAL[idx3] <- 128.4

adlb_cut2$CHG <- round(adlb_cut2$AVAL - adlb_cut2$BASE, 2)
adlb_cut1 <- adlb_cut1[order(adlb_cut1$USUBJID, adlb_cut1$PARAMCD,
                             adlb_cut1$AVISIT), ]
adlb_cut2 <- adlb_cut2[order(adlb_cut2$USUBJID, adlb_cut2$PARAMCD,
                             adlb_cut2$AVISIT), ]
rownames(adlb_cut1) <- NULL
rownames(adlb_cut2) <- NULL

## ---- Example lineage ------------------------------------------------------

adsl_adlb_lineage <- define_lineage(
  lineage_edge("ADSL.TRT01P", "ADLB.TRT01P", relationship = "groups_by"),
  lineage_edge("ADSL.TRT01P", "ADSL.TRT01A", relationship = "derives"),
  lineage_edge("ADSL.SAFFL", "Safety_Set", relationship = "filters"),
  lineage_edge("ADSL.ITTFL", "Efficacy_Set", relationship = "filters"),
  lineage_edge("ADLB.TRT01P", "Lab_Summary_By_Treatment", relationship = "summarises"),
  lineage_edge("ADLB.AVAL", "ADLB.BASE", relationship = "derives"),
  lineage_edge("ADLB.AVAL", "ADLB.CHG", relationship = "derives"),
  lineage_edge("ADLB.BASE", "ADLB.CHG", relationship = "derives"),
  lineage_edge("ADLB.AVAL", "MMRM", relationship = "models"),
  lineage_edge("ADLB.CHG", "MMRM", relationship = "models"),
  lineage_edge("Lab_Summary_By_Treatment", "Table_14_2_1", relationship = "reports"),
  lineage_edge("MMRM", "Table_14_2_2", relationship = "reports"),
  lineage_edge("Efficacy_Set", "MMRM", relationship = "filters")
)

save(adsl_cut1, file = "data/adsl_cut1.rda", compress = "xz", version = 2)
save(adsl_cut2, file = "data/adsl_cut2.rda", compress = "xz", version = 2)
save(adlb_cut1, file = "data/adlb_cut1.rda", compress = "xz", version = 2)
save(adlb_cut2, file = "data/adlb_cut2.rda", compress = "xz", version = 2)
save(adsl_adlb_lineage, file = "data/adsl_adlb_lineage.rda",
     compress = "xz", version = 2)

message("Synthetic data written to data/")
