##Parameter settings
connectionDetails <- DatabaseConnector::createConnectionDetails()

options(fftempdir ="s:/FFtemp")

bigOutputFolder <- file.path("~/myResults", "synpufBig")
mediumOutputFolder <- file.path("~/myResults","synpufMedium")
smallOutputFolder <- file.path("~/myResults", "myResults","synpufSmall")
bigToSmallOutputFolder  <- file.path("~/myResults", "synpufBigToSmall")
SmallToBigOutputFolder  <- file.path("~/myResults", "synpufSmallToBig")

bigCdmDatabaseSchema <- "CMSDESynPUF23m"
bigCohortDatabaseSchema <- "CMSDESynPUF23mresults"

mediumCdmDatabaseSchema <- "CMSDESynPUF100k"
mediumCohortDatabaseSchema <- "CMSDESynPUF100kresults"

smallCdmDatabaseSchema <- "CMSDESynPUF1k"
smallCohortDatabaseSchema <- "CMSDESynPUF1kresults"

outcomeTable <- "outcome_metis"
nestingTable <- "nesting_metis"
oracleTempSchema <- NULL
cdmVersion<-"5"

##Cohort generation in big, medium, and small dataset

MethodEvaluation::createReferenceSetCohorts(connectionDetails,
                                            oracleTempSchema = oracleTempSchema,
                                            cdmDatabaseSchema = bigCdmDatabaseSchema,
                                            outcomeDatabaseSchema = bigCohortDatabaseSchema,
                                            outcomeTable = outcomeTable,
                                            nestingDatabaseSchema = bigCohortDatabaseSchema,
                                            nestingTable = nestingTable,
                                            referenceSet = "ohdsiMethodsBenchmark")

MethodEvaluation::createReferenceSetCohorts(connectionDetails,
                                            oracleTempSchema = oracleTempSchema,
                                            cdmDatabaseSchema = mediumCdmDatabaseSchema,
                                            outcomeDatabaseSchema = mediumCohortDatabaseSchema,
                                            outcomeTable = outcomeTable,
                                            nestingDatabaseSchema = mediumCohortDatabaseSchema,
                                            nestingTable = nestingTable,
                                            referenceSet = "ohdsiMethodsBenchmark")

MethodEvaluation::createReferenceSetCohorts(connectionDetails,
                                            oracleTempSchema = oracleTempSchema,
                                            cdmDatabaseSchema = smallCdmDatabaseSchema,
                                            outcomeDatabaseSchema = smallCohortDatabaseSchema,
                                            outcomeTable = outcomeTable,
                                            nestingDatabaseSchema = smallCohortDatabaseSchema,
                                            nestingTable = nestingTable,
                                            referenceSet = "ohdsiMethodsBenchmark")


## Positivie Controls
# MethodEvaluation::synthesizeReferenceSetPositiveControls(connectionDetails = connectionDetails,
#                                                          oracleTempSchema = oracleTempSchema,
#                                                          cdmDatabaseSchema = cdmDatabaseSchema,
#                                                          outcomeDatabaseSchema = cohortDatabaseSchema,
#                                                          outcomeTable = outcomeTable,
#                                                          maxCores = 10,
#                                                          workFolder = outputFolder,
#                                                          summaryFileName = file.path(outputFolder,
#                                                                                      "allControls.csv"),
#                                                          referenceSet = "ohdsiMethodsBenchmark")

##check the controls
# allControls <- read.csv(file.path(outputFolder, "allControls.csv"))
# head(allControls)
#
# #generate TCOs
# allControls <- read.csv(file.path(outputFolder , "allControls.csv"))
# eos <- list()
# for (i in 1:nrow(allControls)) {
#   eos[[length(eos) + 1]] <- createExposureOutcome(exposureId = allControls$targetId[i],
#                                                   outcomeId = allControls$outcomeId[i])
# }

##CREATE cmObject

# Run CohortMethod ---------------------------------------------------------
library(CohortMethod)
covariateSettings <- FeatureExtraction::createDefaultCovariateSettings(addDescendantsToExclude = TRUE)

getDbCmDataArgs <- CohortMethod::createGetDbCohortMethodDataArgs(covariateSettings = covariateSettings,
                                                                 firstExposureOnly = TRUE,
                                                                 washoutPeriod = 183)

createStudyPopArgsOnTreatment <- CohortMethod::createCreateStudyPopulationArgs(removeDuplicateSubjects = "keep first",
                                                                               removeSubjectsWithPriorOutcome = TRUE,
                                                                               riskWindowStart = 0,
                                                                               riskWindowEnd = 0,
                                                                               addExposureDaysToEnd = TRUE,
                                                                               minDaysAtRisk = 1)

createStudyPopArgsItt <- CohortMethod::createCreateStudyPopulationArgs(removeDuplicateSubjects = "keep first",
                                                                       removeSubjectsWithPriorOutcome = TRUE,
                                                                       riskWindowStart = 0,
                                                                       riskWindowEnd = 9999,
                                                                       addExposureDaysToEnd = FALSE,
                                                                       minDaysAtRisk = 1)

createPsArgs <- CohortMethod::createCreatePsArgs(control = Cyclops::createControl(noiseLevel = "silent",
                                                                                  cvType = "auto",
                                                                                  tolerance = 2e-07,
                                                                                  cvRepetitions = 1,
                                                                                  startingVariance = 0.01,
                                                                                  seed = 123), maxCohortSizeForFitting = 1e+05)

stratifyByPsArgs <- CohortMethod::createStratifyByPsArgs(numberOfStrata = 10, baseSelection = "all")

fitOutcomeModelArgs1 <- CohortMethod::createFitOutcomeModelArgs(stratified = TRUE,
                                                                modelType = "cox")

cmAnalysis1 <- CohortMethod::createCmAnalysis(analysisId = 1,
                                              description = "PS stratification, on-treatment",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createStudyPopArgsOnTreatment,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              stratifyByPs = TRUE,
                                              stratifyByPsArgs = stratifyByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysis2 <- CohortMethod::createCmAnalysis(analysisId = 2,
                                              description = "PS stratification, intent-to-treat",
                                              getDbCohortMethodDataArgs = getDbCmDataArgs,
                                              createStudyPopArgs = createStudyPopArgsItt,
                                              createPs = TRUE,
                                              createPsArgs = createPsArgs,
                                              stratifyByPs = TRUE,
                                              stratifyByPsArgs = stratifyByPsArgs,
                                              fitOutcomeModel = TRUE,
                                              fitOutcomeModelArgs = fitOutcomeModelArgs1)

cmAnalysisList <- list(cmAnalysis1
                       #, cmAnalysis2
)

targetId = 1314002
comparatorId = 1308216
outcomeIdsOfInterest = c(141932)

tcos <- createTargetComparatorOutcomes(targetId = targetId, #1124300
                                       comparatorId = comparatorId, #1118084
                                       outcomeIds = c(#x$newOutcomeId,
                                         192671,
                                         24609,
                                         29735,
                                         73754,
                                         80004,
                                         134718,
                                         139099,
                                         141932,
                                         192367,
                                         193739,
                                         194997,
                                         197236,
                                         199074,
                                         255573,
                                         257007,
                                         313459,
                                         314658,
                                         316084,
                                         319843,
                                         321596,
                                         374366,
                                         375292,
                                         380094,
                                         433753,
                                         433811,
                                         436665,
                                         436676,
                                         436940,
                                         437784,
                                         438134,
                                         440358,
                                         440374,
                                         443617,
                                         443800,
                                         4084966,
                                         4288310), excludedCovariateConceptIds = 21603933)
targetComparatorOutcomesList <- list(tcos)


##PS matching in big, medium, and small dataset
result <- CohortMethod::runCmAnalyses(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = bigCdmDatabaseSchema,
                                      exposureDatabaseSchema = bigCdmDatabaseSchema,
                                      exposureTable = "drug_era",
                                      outcomeDatabaseSchema = bigCohortDatabaseSchema,
                                      outcomeTable = outcomeTable,
                                      outputFolder = bigOutputFolder,
                                      cdmVersion = cdmVersion,
                                      cmAnalysisList = cmAnalysisList,
                                      targetComparatorOutcomesList = targetComparatorOutcomesList,
                                      refitPsForEveryOutcome = FALSE,
                                      refitPsForEveryStudyPopulation = FALSE,
                                      getDbCohortMethodDataThreads = 1,
                                      createPsThreads = 1,
                                      psCvThreads = 16,
                                      createStudyPopThreads = 3,
                                      trimMatchStratifyThreads = 5,
                                      prefilterCovariatesThreads = 3,
                                      fitOutcomeModelThreads = 5,
                                      outcomeCvThreads = 10,
                                      outcomeIdsOfInterest =outcomeIdsOfInterest) #192671

result <- CohortMethod::runCmAnalyses(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = mediumCdmDatabaseSchema,
                                      exposureDatabaseSchema = mediumCdmDatabaseSchema,
                                      exposureTable = "drug_era",
                                      outcomeDatabaseSchema = mediumCohortDatabaseSchema,
                                      outcomeTable = outcomeTable,
                                      outputFolder = mediumOutputFolder,
                                      cdmVersion = cdmVersion,
                                      cmAnalysisList = cmAnalysisList,
                                      targetComparatorOutcomesList = targetComparatorOutcomesList,
                                      refitPsForEveryOutcome = FALSE,
                                      refitPsForEveryStudyPopulation = FALSE,
                                      getDbCohortMethodDataThreads = 1,
                                      createPsThreads = 1,
                                      psCvThreads = 16,
                                      createStudyPopThreads = 3,
                                      trimMatchStratifyThreads = 5,
                                      prefilterCovariatesThreads = 3,
                                      fitOutcomeModelThreads = 5,
                                      outcomeCvThreads = 10,
                                      outcomeIdsOfInterest =outcomeIdsOfInterest) #192671

##PS matching  in small dataset
result <- CohortMethod::runCmAnalyses(connectionDetails = connectionDetails,
                                      cdmDatabaseSchema = smallCdmDatabaseSchema,
                                      exposureDatabaseSchema = smallCdmDatabaseSchema,
                                      exposureTable = "drug_era",
                                      outcomeDatabaseSchema = smallCohortDatabaseSchema,
                                      outcomeTable = outcomeTable,
                                      outputFolder = smallOutputFolder,
                                      cdmVersion = cdmVersion,
                                      cmAnalysisList = cmAnalysisList,
                                      targetComparatorOutcomesList = targetComparatorOutcomesList,
                                      refitPsForEveryOutcome = FALSE,
                                      refitPsForEveryStudyPopulation = FALSE,
                                      getDbCohortMethodDataThreads = 1,
                                      createPsThreads = 1,
                                      psCvThreads = 16,
                                      createStudyPopThreads = 3,
                                      trimMatchStratifyThreads = 5,
                                      prefilterCovariatesThreads = 3,
                                      fitOutcomeModelThreads = 5,
                                      outcomeCvThreads = 10,
                                      outcomeIdsOfInterest = outcomeIdsOfInterest) #192671

###check the result from Big dataset
bigPropensityScore <- readRDS(file.path(bigOutputFolder, sprintf("Ps_l1_p1_t%d_c%d.rds",targetId,comparatorId)))
bigCohortMethodData <-  CohortMethod::loadCohortMethodData(file.path(bigOutputFolder, sprintf("CmData_l1_t%d_c%d",targetId,comparatorId)))
CohortMethod::computePsAuc(bigPropensityScore)
#AUROC 0.5944368
CohortMethod::plotPs(bigPropensityScore, showCountsLabel = TRUE, showAucLabel = TRUE, showEquiposeLabel = TRUE)

bigMatchedPop <- CohortMethod::matchOnPs(bigPropensityScore, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(bigMatchedPop, bigPropensityScore)
CohortMethod::drawAttritionDiagram(bigMatchedPop)

bigBalance <- CohortMethod::computeCovariateBalance(bigMatchedPop, bigCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(bigBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE)
CohortMethod::plotCovariateBalanceOfTopVariables(bigBalance)

###check the result from medium dataset
mediumPropensityScore <- readRDS(file.path(mediumOutputFolder, sprintf("Ps_l1_p1_t%d_c%d.rds",targetId,comparatorId)))
mediumCohortMethodData <-  CohortMethod::loadCohortMethodData(file.path(mediumOutputFolder, sprintf("CmData_l1_t%d_c%d",targetId,comparatorId)))
CohortMethod::computePsAuc(mediumPropensityScore)
#AUROC 
CohortMethod::plotPs(mediumPropensityScore, showCountsLabel = TRUE, showAucLabel = TRUE, showEquiposeLabel = TRUE)

mediumMatchedPop <- CohortMethod::matchOnPs(mediumPropensityScore, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(mediumMatchedPop, mediumPropensityScore)
CohortMethod::drawAttritionDiagram(mediumMatchedPop)

mediumBalance <- CohortMethod::computeCovariateBalance(mediumMatchedPop, mediumCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(mediumBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE)
CohortMethod::plotCovariateBalanceOfTopVariables(mediumBalance)

###check the result from Small dataset
smallPropensityScore <- readRDS(file.path(smallOutputFolder, sprintf("Ps_l1_p1_t%d_c%d.rds",targetId,comparatorId)))
smallCohortMethodData <-  CohortMethod::loadCohortMethodData(file.path(smallOutputFolder, sprintf("CmData_l1_t%d_c%d",targetId,comparatorId)))
CohortMethod::computePsAuc(smallPropensityScore)
#AUROC 0.5
CohortMethod::plotPs(smallPropensityScore, showCountsLabel = TRUE, showAucLabel = TRUE, showEquiposeLabel = TRUE)

smallMatchedPop <- CohortMethod::matchOnPs(smallPropensityScore, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(smallMatchedPop, smallPropensityScore)
CohortMethod::drawAttritionDiagram(smallMatchedPop)

smallBalance <- CohortMethod::computeCovariateBalance(smallMatchedPop, smallCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(smallBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE)
CohortMethod::plotCovariateBalanceOfTopVariables(smallBalance)

##extract PS model

bigPsModel <- CohortMethod::getPsModel(
  propensityScore =    bigPropensityScore,
  cohortMethodData = bigCohortMethodData)

mediumPsModel <- CohortMethod::getPsModel(
  propensityScore =    mediumPropensityScore,
  cohortMethodData = mediumCohortMethodData)

smallPsModel <- CohortMethod::getPsModel(
  propensityScore =    smallPropensityScore,
  cohortMethodData = smallCohortMethodData)

##Use PS for big dataset in small dataset
smallStudyPop <- readRDS(file.path(smallOutputFolder, sprintf("StudyPop_l1_s1_t%d_c%d_o%d.rds",targetId,comparatorId,outcomeIdsOfInterest[i])))

bigToSmallPropensityScore <- Metis::predictPs(psModel=bigPsModel,
                                              population = smallStudyPop,
                                              cohortMethodData = smallCohortMethodData)

smallToSmallpropensityScore <- Metis::predictPs(psModel=smallPsModel,
                                                population = smallStudyPop,
                                                cohortMethodData = smallCohortMethodData)

CohortMethod::computePsAuc(bigToSmallPropensityScore)
#AUROC 0.656746
CohortMethod::computePsAuc(smallToSmallpropensityScore)
#AUROC 0.5

CohortMethod::plotPs(bigToSmallPropensityScore, showCountsLabel = TRUE, showAucLabel = TRUE, showEquiposeLabel = TRUE)
CohortMethod::plotPs(smallToSmallpropensityScore, showCountsLabel = TRUE, showAucLabel = TRUE, showEquiposeLabel = TRUE)

bigToSmallMatchedPop <- CohortMethod::matchOnPs(bigToSmallPropensityScore, caliperScale = "standardized logit", maxRatio = 1)
smallToSmallMatchedPop <- CohortMethod::matchOnPs(smallToSmallpropensityScore, caliperScale = "standardized logit", maxRatio = 1)

CohortMethod::drawAttritionDiagram(bigToSmallMatchedPop)
CohortMethod::drawAttritionDiagram(smallToSmallMatchedPop)

bigToSmallBalance <- CohortMethod::computeCovariateBalance(bigToSmallMatchedPop, smallCohortMethodData)
samllToSmallBalance <- CohortMethod::computeCovariateBalance(smallToSmallMatchedPop, smallCohortMethodData)


CohortMethod::plotCovariateBalanceScatterPlot(bigToSmallBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE)
CohortMethod::plotCovariateBalanceOfTopVariables(samllToSmallBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE)