outputFolder <- Sys.getenv("metis_output_folder")

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

if (!file.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
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
#CohortMethod::saveCohortMethodData(cohortMethodData, file.path(outputFolder,"arbVsCcbVsGiBleed.zip"))
cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(outputFolder,"arbVsCcbVsGiBleed.zip"))

####Compute PS####
ps <- CohortMethod::createPs(cohortMethodData = cohortMethodData, population = NULL, maxCohortSizeForFitting  = 10000)
#saveRDS(ps, file.path(outputFolder,"ps.rds"))

#Plot PS
CohortMethod::plotPs(ps,
                     scale = "preference",
                     showCountsLabel = TRUE,
                     showAucLabel = TRUE,
                     showEquiposeLabel = TRUE,
                     fileName = file.path(outputFolder, "preference_score.png"))

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
                                    cmOutputFolder = file.path(outputFolder, "analysis1"))
negCons <- analysisSum1 [(analysisSum1$outcomeId %in% ncs),]
hoi <- analysisSum1 [(analysisSum1$outcomeId %in% hoiIds),]
null <- EmpiricalCalibration::fitNull(negCons$logRr, negCons$seLogRr)
EmpiricalCalibration::plotCalibrationEffect(negCons$logRr, negCons$seLogRr, hoi$logRr, hoi$seLogRr, null)


# CohortMethod::getAttritionTable(studyPop)
matchedPop <- CohortMethod::matchOnPs(ps, caliper = 0.2, caliperScale = "standardized logit", maxRatio = 1)
balance <- CohortMethod::computeCovariateBalance(matchedPop, cohortMethodData)
CohortMethod::plotCovariateBalanceScatterPlot(balance, 
                                              showCovariateCountLabel = TRUE, showMaxLabel = TRUE,
                                              fileName = file.path(outputFolder, "balance.png"))
# matchedPop<- matchedPop %>% 
#   dplyr::select(rowId, propensityScore, preferenceScore,stratumId) %>%
#   dplyr::inner_join(studyPop, by = "rowId")
# 
# outcomeModel <- CohortMethod::fitOutcomeModel(population = matchedPop,
#                                               modelType = "cox")


####Using auto-encoder####
####assign newIds to covariateRef####
cohortMethodData <- CohortMethod::loadCohortMethodData(file.path(exportFolder,"coxibVsNonselVsGiBleed.zip"))
newcovariateData <- MapCovariates(cohortMethodData,
                                  studyPop,
                                  mapping=NULL)















####PS matching and plot balance scatter plot using small population####
set.seed(1)
smallStudyPop <- studyPop %>% dplyr::sample_n(smallNum, replace = FALSE)
smallPs <- CohortMethod::createPs(cohortMethodData = cohortMethodData, population = smallStudyPop, 
                                  errorOnHighCorrelation = FALSE)
#saveRDS(smallStudyPop, file.path(outputFolder,"samllStudyPop.rds"))
smallStudyPop <- readRDS(file.path(outputFolder,"samllStudyPop.rds"))

