# @file predict.R
#
# Copyright 2019 Observational Health Data Sciences and Informatics
#
# This file is part of Metis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#' predictPs
#'
#' @description
#' Predict the propensity score of given population using external propensity score model
#' @details
#' The function applied the trained model on the plpData to make predictions
#' @param psModel                          An object of propensity score model
#' @param cohortMethodData                 The cohort method data of target
#' @param population                       The population data of target
#'
#' @return
#' A dataframe containing the prediction for each person in the populatio.
#'
#' @export
predictPs <- function(psModel,
                      population,
                      cohortMethodData){
  
  start<-Sys.time()
  
  #limit covariate to population of interest
  covariates <- limitCovariatesToPopulation(cohortMethodData$covariates, ff::as.ff(population$rowId))
  
  psModel$modelType = "logistic"
  
  #make coefficients data frame from ps Model
  coefficients = psModel$coefficient
  intercept <- coefficients[psModel$covariateName%in%'(Intercept)']
  if(length(intercept)==0) intercept <- 0
  coefficients <- coefficients[!psModel$covariateName%in%'(Intercept)']
  covariateId <- psModel$covariateId[!psModel$covariateName%in%'(Intercept)']
  coefficients <- data.frame(beta = as.numeric(coefficients),
                             covariateId = as.numeric(covariateId))
  coefficients <- coefficients[coefficients$beta != 0, ]
  
  if(sum(coefficients$beta != 0)>0){
    prediction <- merge(covariates, ff::as.ffdf(coefficients), by = "covariateId")
    prediction$value <- prediction$covariateValue * prediction$beta
    prediction <- PatientLevelPrediction::bySumFf(prediction$value, prediction$rowId)
    colnames(prediction) <- c("rowId", "value")
    # prediction <- merge(population, ff::as.ram(prediction), by = "rowId", all.x = TRUE)
    prediction <- merge(ff::as.ram(population), prediction, by ="rowId", all.x = TRUE)
    prediction$value[is.na(prediction$value)] <- 0
    prediction$value <- prediction$value + intercept
  } else{
    warning('Model had no non-zero coefficients so predicted same for all population...')
    prediction <- population
    prediction$value <- rep(0, nrow(population)) + intercept
  }
  if (psModel$modelType == "logistic") {
    link <- function(x) {
      return(1/(1 + exp(0 - x)))
    }
    prediction$value <- link(prediction$value)
  } else if (psModel$modelType == "poisson" || psModel$modelType == "survival" || psModel$modelType == "cox") {
    prediction$value <- exp(prediction$value)
    if(max(prediction$value)>1){
      prediction$value <- prediction$value/max(prediction$value)
    }
  }
  population$propensityScore<-prediction$value
  population <- computePreferenceScore(population)
  
  delta <- Sys.time() - start
  #ParallelLogger::logDebug("Propensity model fitting finished with status ", error)
  ParallelLogger::logInfo(paste("Predicting propensity scores took", signif(delta, 3), attr(delta, "units")))
  
  return(population)
}

limitCovariatesToPopulation <- function(covariates, rowIds) {
  idx <- !is.na(ffbase::ffmatch(covariates$rowId, rowIds))
  if(sum(idx)!=0){
    covariates <- covariates[ffbase::ffwhich(idx, idx == TRUE), ]
  }else{
    stop('No covariates')
  }
  return(covariates)
}
