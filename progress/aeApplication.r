library(dplyr)
outputFolder <- Sys.getenv("metis_output_folder")


####assign newIds to covariateRef####
cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(outputFolder,"arbVsCcbVsGiBleed.zip"))
mapping <- readRDS(file.path(outputFolder, "map.rds"))

studyPop <- CohortMethod::createStudyPopulation(cohortMethodData = cohortMethodData,
                                                outcomeId = 4,
                                                firstExposureOnly = FALSE,
                                                restrictToCommonPeriod = FALSE,
                                                washoutPeriod = 0,
                                                removeDuplicateSubjects = "keep first",
                                                removeSubjectsWithPriorOutcome = FALSE,
                                                minDaysAtRisk = 1,
                                                riskWindowStart = 0,
                                                startAnchor = "cohort start",
                                                riskWindowEnd = 30,
                                                endAnchor = "cohort end")
newcovariateData <- MapCovariates2(covariateData = cohortMethodData,
                                   population= studyPop,
                                   mapping = mapping)

ParallelLogger::logDebug(paste0('Max covariateId in covariates: ',as.data.frame(newcovariateData$covariates %>% dplyr::summarise(max = max(covariateId, na.rm=T)))))
ParallelLogger::logDebug(paste0('# covariates in covariateRef: ', nrow(newcovariateData$covariateRef)))
ParallelLogger::logDebug(paste0('Max rowId in covariates: ', as.data.frame(newcovariateData$covariates %>% dplyr::summarise(max = max(rowId, na.rm=T)))))

maxY <- as.data.frame(newcovariateData$mapping %>% dplyr::summarise(max=max(newCovariateId, na.rm = TRUE)))$max
ParallelLogger::logDebug(paste0('Max newCovariateId in mapping: ',maxY))
maxX <- max(studyPop$rowId)
ParallelLogger::logDebug(paste0('Max rowId in population: ',maxX))

data <- Matrix::sparseMatrix(i=1,
                             j=1,
                             x=0,
                             dims=c(maxX,maxY))
convertData <- function(batch) {
  data <<- data + Matrix::sparseMatrix(i=as.data.frame(batch %>% select(rowId))$rowId,
                                       j=as.data.frame(batch %>% select(covariateId))$covariateId,
                                       x=as.data.frame(batch %>% select(covariateValue))$covariateValue,
                                       dims=c(maxX,maxY))
  return(NULL)
}
Andromeda::batchApply(newcovariateData$covariates, convertData, batchSize = 100000)


####Using auto-encoder####
originalDim = dim(data)[2]
targetDim = dim(outcome)[2]

input_layer <- 
  keras::layer_input(shape = originalDim)

metric_f1 <- function (y_true,y_pred) {
  y_pred <- keras::k_round(y_pred)
  precision <- keras::k_sum(y_pred*y_true)/(keras::k_sum(y_pred)+keras::k_epsilon())
  recall    <- keras::k_sum(y_pred*y_true)/(keras::k_sum(y_true)+keras::k_epsilon())
  (2*precision*recall)/(precision+recall+keras::k_epsilon())
} 

encoder <-
  input_layer %>%
  keras::layer_dense(units = 1024, 
                     activation = "relu") %>%
  keras::layer_dropout(rate = 0.2) %>%
  keras::layer_dense(units = 512,
                     activation = "relu") %>%
  keras::layer_dropout(rate = 0.2) %>%
  keras::layer_dense(units = 124, 
                     activation = "relu")

encoder_model <- keras::keras_model(inputs = input_layer, outputs = encoder)
encoder_model %>% keras::load_model_weights_hdf5(file.path(outputFolder,"autoencoder_model_weights.h5"), skip_mismatch = TRUE, by_name = TRUE)
encoder_model %>% keras::compile(
  loss= weighted_crossentropy,#'mean_squared_error',#weighted_mse,#'mean_squared_error',#weighted_mse
  optimizer= keras::optimizer_adam(lr=learningRate),
  metrics = c("binary_crossentropy", "accuracy",metric_f1)
)

reducedDim <- encoder_model %>% 
  keras::predict_on_batch (data)

####Generate new CovariateData based on encoded covariates####
newCovariates <- data.frame()
newCovariateRef <- data.frame()
newCovariateAnalysisRef <- data.frame(analysisId = 1000,
                                      analysisName = "encoded covariates",
                                      domainId = NA,
                                      startDay = NA,
                                      endDay = NA,
                                      isBinary = "N",
                                      missingMeansZero = "N")
for(i in 1:dim(reducedDim)[2]){
  newCovariates <- newCovariates %>% 
    rbind(data.frame(rowId = 1:dim(reducedDim)[1],
                     covariateId = i,
                     covariateValue = reducedDim[,i]))
  
  newCovariateRef <- newCovariateRef %>% 
    rbind(data.frame(covariateId = i,
                     covariateName = sprintf("%dth value",i),
                     analysisId = 1000,
                     conceptId = 0))
  
}
encodedCohortMethodData <- Andromeda::copyAndromeda(cohortMethodData)


encodedCohortMethodData$covariates <- newCovariates
encodedCohortMethodData$covariateRef <- newCovariateRef
encodedCohortMethodData$analysisRef <- newCovariateAnalysisRef

hist(newCovariates$covariateValue)

####PS matching by using encoded covariates in small population####
EncodedSmallPs <- CohortMethod::createPs(cohortMethodData = encodedCohortMethodData, 
                                         population = smallStudyPop,
                                         errorOnHighCorrelation = F,
                                         removeRedundancy = F)

CohortMethod::computePsAuc(EncodedSmallPs)
CohortMethod::plotPs(EncodedSmallPs,
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, "small_ps_after_encoding.png"))

EncodedSmallMatchedPop <- CohortMethod::matchOnPs(EncodedSmallPs, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(EncodedSmallMatchedPop, EncodedSmallPs)

EncodedSmallBalance <- CohortMethod::computeCovariateBalance(EncodedSmallMatchedPop, encodedCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(EncodedSmallBalance, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(outputFolder, "balance_after_encoding.png"))

sum(abs(EncodedSmallBalance$afterMatchingStdDiff)<=0.1,na.rm =T)
sum(abs(EncodedSmallBalance$afterMatchingStdDiff)>0.1,na.rm =T)
hist(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff))

cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(outputFolder,"coxibVsNonselVsGiBleed.zip"))
EncodedSmallBalanceOrigin <- CohortMethod::computeCovariateBalance(EncodedSmallMatchedPop, cohortMethodData)

CohortMethod::plotCovariateBalanceScatterPlot(EncodedSmallBalanceOrigin, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(outputFolder, "balance_orig_after_encoding.png"))

hist(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff))
sum(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff)<=0.1,na.rm =T)
sum(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff)>0.1,na.rm =T)

CohortMethod::plotCovariateBalanceOfTopVariables(EncodedSmallBalanceOrigin)


####PS matching by using encoded covariates in total population####
EncodedPs <- CohortMethod::createPs(cohortMethodData = encodedCohortMethodData, 
                                    population = studyPop,
                                    errorOnHighCorrelation = FALSE,
                                    removeRedundancy = F)
CohortMethod::plotPs(EncodedPs,
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, "ps_after_encoding.png"))

EncodedMatchedPop <- CohortMethod::matchOnPs(EncodedPs, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(EncodedMatchedPop, EncodedPs)

EncodedBalance <- CohortMethod::computeCovariateBalance(EncodedMatchedPop, encodedCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(EncodedBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE, fileName = file.path(outputFolder, "EncodedBalance_50.png"))

EncodedBalanceOriginal <- CohortMethod::computeCovariateBalance(EncodedMatchedPop, cohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(EncodedBalanceOriginal, showCovariateCountLabel = TRUE, showMaxLabel = TRUE, fileName = file.path(outputFolder, "EncodedBalance_Orig.png"))

CohortMethod::drawAttritionDiagram(EncodedMatchedPop, fileName = "encoded_attrition_diagram.png")