exportFolder <- "/home/scyou2/output/metisV3T1"
library(dplyr)
largeNum = 10000
mediumNum = 3000
smallNum = 2000
maxCohortSizeForFitting = 10000 #250000


analysisId = 1 #full population, LSPS
analysisId = 2 #small population, LSPS
analysisId = 3 #full population, RL-PS
analysisId = 4 #small population, RL-PS

hoiIds = 4

####Generation cohorts####
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = Sys.getenv("ausom_dbms"),
                                                                server = Sys.getenv("ausom_database_server"),
                                                                user = Sys.getenv("ausom_database_user_id"),
                                                                password = Sys.getenv("ausom_database_user_pw"),
                                                                port = NULL)
cdmDatabaseSchema <- Sys.getenv("ausom_cdm_db_schema")
resultsDatabaseSchema <- Sys.getenv("ausom_cohort_db_schema")
cdmVersion <- "5"

if (!file.exists(exportFolder)) {
  dir.create(exportFolder, recursive = TRUE)
}
###Generate T and C cohorts
sql <- SqlRender::readSql("/home/scyou2/git/abmi/Metis/extras/arbVsCcbVsGiBleed.sql")
sql <- SqlRender::render(sql,
                         cdmDatabaseSchema = cdmDatabaseSchema,
                         resultsDatabaseSchema = resultsDatabaseSchema,
                         max_gap = 30)
sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)
connection <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::executeSql(connection, sql)

###Generate O (Acute myocardial infarction)
sql <- SqlRender::readSql("/home/scyou2/git/abmi/Metis/extras/AcuteMyocardialInfarction.sql")
sql <- SqlRender::render(sql,
                         cdm_database_schema = cdmDatabaseSchema,
                         target_database_schema = resultsDatabaseSchema,
                         target_cohort_id = 4,
                         target_cohort_table = "arbVsCcbVsGiBleed",
                         vocabulary_database_schema = cdmDatabaseSchema
)
sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)
connection <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::executeSql(connection, sql)

###NCS
ncs <- c(434165,436409,199192,4088290,4092879,44783954,75911,137951,77965,
         376707,4103640,73241,133655,73560,434327,4213540,140842,81378,
         432303,4201390,46269889,134438,78619,201606,76786,4115402,
         45757370,433111,433527,4170770,4092896,259995,40481632,4166231,
         433577,4231770,440329,4012570,4012934,441788,4201717,374375,
         4344500,139099,444132,196168,432593,434203,438329,195873,4083487,
         4103703,4209423,377572,40480893,136368,140648,438130,4091513,
         4202045,373478,46286594,439790,81634,380706,141932,36713918,
         443172,81151,72748,378427,437264,194083,140641,440193,4115367)
sql <- SqlRender::readSql("/home/scyou2/git/abmi/Metis/extras/NegativeControlOutcomes.sql")
sql <- SqlRender::render(sql,
                         cdm_database_schema = cdmDatabaseSchema,
                         target_database_schema = resultsDatabaseSchema,
                         target_cohort_table = "arbVsCcbVsGiBleed",
                         outcome_ids = ncs)
sql <- SqlRender::translate(sql, targetDialect = connectionDetails$dbms)
connection <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::executeSql(connection, sql)

#DatabaseConnector::disconnect(connection)
# Define which types of covariates must be constructed:
covSettings <- FeatureExtraction::createDefaultCovariateSettings(excludedCovariateConceptIds = c(1308842, 
                                                                                                 1317640, 
                                                                                                 1346686, 
                                                                                                 1347384,
                                                                                                 1351557, 
                                                                                                 1367500, 
                                                                                                 40226742, 
                                                                                                 40235485,
                                                                                                 1318137, 
                                                                                                 1318853, 
                                                                                                 1319880, 
                                                                                                 1326012, 
                                                                                                 1332418, 
                                                                                                 1353776),
                                                                 addDescendantsToExclude = TRUE)
covSettings$CharlsonIndex <- F
covSettings$Dcsi <- F
covSettings$Chads2 <- F
covSettings$Chads2Vasc <- F

####Generation cohortMethodData####
outcomeIds = c(3,4,ncs)
cohortMethodData <- CohortMethod::getDbCohortMethodData(connectionDetails = connectionDetails,
                                                        cdmDatabaseSchema = cdmDatabaseSchema,
                                                        oracleTempSchema = resultsDatabaseSchema,
                                                        targetId = 1,
                                                        comparatorId = 2,
                                                        outcomeIds = c(3,4,ncs),
                                                        studyStartDate = "",
                                                        studyEndDate = "",
                                                        exposureDatabaseSchema = resultsDatabaseSchema,
                                                        exposureTable = "arbVsCcbVsGiBleed",
                                                        outcomeDatabaseSchema = resultsDatabaseSchema,
                                                        outcomeTable = "arbVsCcbVsGiBleed",
                                                        cdmVersion = cdmVersion,
                                                        firstExposureOnly = FALSE,
                                                        removeDuplicateSubjects = FALSE,
                                                        restrictToCommonPeriod = FALSE,
                                                        washoutPeriod = 0,
                                                        covariateSettings = covSettings)

CohortMethod::summary(cohortMethodData)
####saveCohortMethodData####
#CohortMethod::saveCohortMethodData(cohortMethodData, file.path(exportFolder,"arbVsCcbVsGiBleed.zip"))
cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(exportFolder,"arbVsCcbVsGiBleed.zip"))

####Compute PS####
ps <- CohortMethod::createPs(cohortMethodData = cohortMethodData, population = NULL, maxCohortSizeForFitting  = 10000)
#saveRDS(ps, file.path(exportFolder,"ps.rds"))

#Plot PS
CohortMethod::plotPs(ps,
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(exportFolder, "preference_score.png"))

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


##Empirical evaluation
analysisSum1 <- EmpiricalEvaluation(cohortMethodData = cohortMethodData,
                                    ps= ps,
                                    outcomeIds =outcomeIds,
                                    hoiIds = 4,
                                    ncsIds = ncs,
                                    analysisId= 1,
                                    cmOutputFolder = file.path(exportFolder, "analysis1"))
negCons <- analysisSum1 [(analysisSum1$outcomeId %in% ncs),]
hoi <- analysisSum1 [(analysisSum1$outcomeId %in% hoiIds),]
null <- EmpiricalCalibration::fitNull(negCons$logRr, negCons$seLogRr)
EmpiricalCalibration::plotCalibrationEffect(negCons$logRr, negCons$seLogRr, hoi$logRr, hoi$seLogRr, null)


# CohortMethod::getAttritionTable(studyPop)
matchedPop <- CohortMethod::matchOnPs(ps, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
balance <- CohortMethod::computeCovariateBalance(matchedPop, cohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(balance, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(exportFolder, "balance.png"))
# matchedPop<- matchedPop %>% 
#   dplyr::select(rowId, propensityScore, preferenceScore,stratumId) %>%
#   dplyr::inner_join(studyPop, by = "rowId")
# 
# outcomeModel <- CohortMethod::fitOutcomeModel(population = matchedPop,
#                                               modelType = "cox")

####PS matching and plot balance scatter plot using small population####
set.seed(1)
smallStudyPop <- studyPop %>% dplyr::sample_n(smallNum, replace = FALSE)
smallPs <- CohortMethod::createPs(cohortMethodData = cohortMethodData, population = smallStudyPop, 
                                  errorOnHighCorrelation = FALSE)
#saveRDS(smallStudyPop, file.path(exportFolder,"samllStudyPop.rds"))
smallStudyPop <- readRDS(file.path(exportFolder,"samllStudyPop.rds"))

##Multiple sampling

for(i in 1:1){
  #i= 1
  if(i==1) analysisSum2 <- data.frame()
  set.seed(i)
  smallStudyPop <- studyPop %>% dplyr::sample_n(smallNum, replace = FALSE)
  smallPs <- CohortMethod::createPs(cohortMethodData = cohortMethodData, population = smallStudyPop, 
                                    errorOnHighCorrelation = FALSE)
  analysisResult <-EmpiricalEvaluation(cohortMethodData = cohortMethodData,
                                       ps= smallPs,
                                       outcomeIds =outcomeIds,
                                       hoiIds = 4,
                                       ncsIds = ncs,
                                       balancePlot = F,
                                       analysisId = 2,
                                       cmOutputFolder = file.path(exportFolder,"analysis2"))
  analysisResult$trialId <- i
  
  
  analysisSum2 <- rbind(analysisSum2, 
                        analysisResult
  )
}

analysisSumTemp <- analysisSum2[analysisSum2$trialId==1,]

negCons <- analysisSumTemp [(analysisSumTemp$outcomeId %in% ncsIds),]
hoi <- analysisSumTemp [(analysisSumTemp$outcomeId %in% hoiIds),]
null <- EmpiricalCalibration::fitNull(negCons$logRr, negCons$seLogRr)
#null <- EmpiricalCalibration::fitMcmcNull(negCons$logRr, negCons$seLogRr)

EmpiricalCalibration::plotCalibrationEffect(negCons$logRr, negCons$seLogRr, hoi$logRr, hoi$seLogRr, null)#, showCis = T)



smallPs <- CohortMethod::createPs(cohortMethodData = cohortMethodData, population = smallStudyPop, 
                                  errorOnHighCorrelation = FALSE)

analysisSum2 <- EmpiricalEvaluation(cohortMethodData = cohortMethodData,
                                    ps= smallPs,
                                    outcomeIds =outcomeIds,
                                    hoiIds = 4,
                                    ncsIds = ncs,
                                    analysisId= 2,
                                    cmOutputFolder = file.path(exportFolder, "analysis2"))
negCons <- analysisSum2 [(analysisSum2$outcomeId %in% ncsIds),]
hoi <- analysisSum2 [(analysisSum2$outcomeId %in% hoiIds),]
null <- EmpiricalCalibration::fitNull(negCons$logRr, negCons$seLogRr)
EmpiricalCalibration::plotCalibrationEffect(negCons$logRr, negCons$seLogRr, hoi$logRr, hoi$seLogRr, null)

CohortMethod::computePsAuc(smallPs)
CohortMethod::plotPs(smallPs,
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(exportFolder, "small_preference_score.png"))
CohortMethod::computePsAuc(smallPs)
smallMatchedPop <- CohortMethod::matchOnPs(smallPs, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(smallMatchedPop, ps)
smallBalance <- CohortMethod::computeCovariateBalance(smallMatchedPop, cohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(smallBalance, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(exportFolder, "small_balance.png"))

sum(abs(smallBalance$afterMatchingStdDiff) <= 0.1, na.rm =T)
sum(abs(smallBalance$afterMatchingStdDiff) > 0.1, na.rm =T)
hist(abs(smallBalance$afterMatchingStdDiff))
CohortMethod::plotCovariateBalanceOfTopVariables(smallBalance,
                                                 fileName = file.path(exportFolder, "top_small_balance.png"))

####Using auto-encoder####
####assign newIds to covariateRef####
#cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(exportFolder,"arbVsCcbVsGiBleed.zip"))

dataForEncoder <- createDataForEncoder(cohortMethodData,
                                       population = NULL,
                                       mapping = covariateData$mapping,
                                       excludeCovariateIds = c(),
                                       includeCovariateIds = c(),
                                       maxCohortSizeForFitting = 250000,
                                       fileName = file.path(exportFolder,'newCovariate'),
                                       weight = "default",
                                       tidyCovariate = F)
newcovariateData <- dataForEncoder$newcovariateData
data <- dataForEncoder$data
mapping <- dataForEncoder$mapping

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
reducedDim <- encoder_model %>% 
  keras::predict_on_batch (data)

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
#cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(exportFolder,"arbVsCcbVsGiBleed.zip"))
encodedCohortMethodData <- Andromeda::copyAndromeda(cohortMethodData)

encodedCohortMethodData$covariates <- newCovariates
encodedCohortMethodData$covariateRef <- newCovariateRef
encodedCohortMethodData$analysisRef <- newCovariateAnalysisRef

hist(newCovariates$covariateValue)


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
                     fileName = file.path(exportFolder, "ps_after_encoding.png"))

EncodedMatchedPop <- CohortMethod::matchOnPs(EncodedPs, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(EncodedMatchedPop, EncodedPs)

EncodedBalance <- CohortMethod::computeCovariateBalance(EncodedMatchedPop, encodedCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(EncodedBalance, showCovariateCountLabel = TRUE, showMaxLabel = TRUE, fileName = file.path(exportFolder, "EncodedBalance_50.png"))

EncodedBalanceOriginal <- CohortMethod::computeCovariateBalance(EncodedMatchedPop, cohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(EncodedBalanceOriginal, showCovariateCountLabel = TRUE, showMaxLabel = TRUE, fileName = file.path(exportFolder, "EncodedBalance_Orig.png"))
CohortMethod::plotCovariateBalanceOfTopVariables(EncodedBalanceOriginal, fileName = file.path(exportFolder,"top_balance_after_encoding.png"))


CohortMethod::drawAttritionDiagram(EncodedMatchedPop, fileName = "encoded_attrition_diagram.png")



















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
                     fileName = file.path(exportFolder, "small_ps_after_encoding.png"))

##Multiple sampling
for(i in 1:1){
  #i= 1
  if(i==1) analysisSum4 <- data.frame()
  set.seed(i)
  smallStudyPop <- studyPop %>% dplyr::sample_n(smallNum, replace = FALSE)
  EncodedSmallPs <- CohortMethod::createPs(cohortMethodData = encodedCohortMethodData, population = smallStudyPop, 
                                           errorOnHighCorrelation = FALSE)
  analysisResult <-EmpiricalEvaluation(cohortMethodData = encodedCohortMethodData,
                                       ps= EncodedSmallPs,
                                       outcomeIds =outcomeIds,
                                       hoiIds = 4,
                                       ncsIds = ncs,
                                       balancePlot = F,
                                       analysisId = 4,
                                       cmOutputFolder = file.path(exportFolder,"analysis4"))
  analysisResult$trialId <- i
  
  
  analysisSum3 <- rbind(analysisSum4, 
                        analysisResult
  )
}

analysisSumTemp <- analysisSum2[analysisSum2$analysisId=4,]

negCons <- analysisSumTemp [(analysisSumTemp$outcomeId %in% ncsIds),]
hoi <- analysisSumTemp [(analysisSumTemp$outcomeId %in% hoiIds),]
null <- EmpiricalCalibration::fitNull(negCons$logRr, negCons$seLogRr)
#null <- EmpiricalCalibration::fitMcmcNull(negCons$logRr, negCons$seLogRr)


EncodedSmallMatchedPop <- CohortMethod::matchOnPs(EncodedSmallPs, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
CohortMethod::plotPs(EncodedSmallMatchedPop, EncodedSmallPs)

EncodedSmallBalance <- CohortMethod::computeCovariateBalance(EncodedSmallMatchedPop, encodedCohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(EncodedSmallBalance, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(exportFolder, "small_balance_after_encoding.png"))

sum(abs(EncodedSmallBalance$afterMatchingStdDiff)<=0.1,na.rm =T)
sum(abs(EncodedSmallBalance$afterMatchingStdDiff)>0.1,na.rm =T)
hist(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff))

EncodedSmallBalanceOrigin <- CohortMethod::computeCovariateBalance(EncodedSmallMatchedPop, cohortMethodData)

CohortMethod::plotCovariateBalanceScatterPlot(EncodedSmallBalanceOrigin, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(exportFolder, "small_balance_orig_after_encoding.png"))

hist(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff))
sum(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff)<=0.1,na.rm =T)
sum(abs(EncodedSmallBalanceOrigin$afterMatchingStdDiff)>0.1,na.rm =T)

CohortMethod::plotCovariateBalanceOfTopVariables(EncodedSmallBalanceOrigin,
                                                 fileName = file.path(exportFolder, "top_small_balance_top_after_encoding.png"))


