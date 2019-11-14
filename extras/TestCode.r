##Parameter settings
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("awsDbms"),
                                                                server = Sys.getenv("awsServer"),
                                                                user = Sys.getenv("awsUser"),
                                                                password = Sys.getenv("awsPassword"),
                                                                port = Sys.getenv("awsPort"))

options(fftempdir = Sys.getenv("fftempdir"))
outputFolder <- file.path(Sys.getenv("outputFolder"),"metisExternal")

# cdmDatabaseSchema <- "CMSDESynPUF23m"
# cohortDatabaseSchema <- "CMSDESynPUF23mresults"

cdmDatabaseSchema <- "CMSDESynPUF100k"
cohortDatabaseSchema <- "CMSDESynPUF100kresults"
outcomeTable <- "Metis_external"
nestingTable <- "nesting_external"
oracleTempSchema <- NULL
cdmVersion<-"5"

##Cohort generation

MethodEvaluation::createReferenceSetCohorts(connectionDetails, 
                                            oracleTempSchema = oracleTempSchema,
                                            cdmDatabaseSchema = cdmDatabaseSchema, 
                                            outcomeDatabaseSchema = cohortDatabaseSchema,
                                            outcomeTable = outcomeTable, 
                                            nestingDatabaseSchema = cohortDatabaseSchema,
                                            nestingTable = nestingTable, 
                                            referenceSet = "ohdsiMethodsBenchmark")



##CREATE cmObject

# Run CohortMethod ---------------------------------------------------------
library(CohortMethod)
covariateSettings <- createDefaultCovariateSettings(addDescendantsToExclude = TRUE)

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

cmAnalysisList <- list(cmAnalysis1, cmAnalysis2)

tcos <- createTargetComparatorOutcomes(targetId = 1124300,
                                       comparatorId = 1118084,
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

result <- runCmAnalyses(connectionDetails = connectionDetails,
                        cdmDatabaseSchema = cdmDatabaseSchema,
                        exposureDatabaseSchema = cdmDatabaseSchema,
                        exposureTable = "drug_era",
                        outcomeDatabaseSchema = cohortDatabaseSchema,
                        outcomeTable = outcomeTable,
                        outputFolder = outputFolder,
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
                        outcomeIdsOfInterest = c(192671))

save(result, file=file.path(outputFolder,"result.rda"))


