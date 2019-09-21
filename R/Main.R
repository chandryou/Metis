# Copyright 2019 Observational Health Data Sciences and Informatics
#
# This file is part of Prometheus
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

#' Generation cmObject and fitted PS model
generateSingleSiteResult <- function(connectionDetails,
                                     oracleTempSchema = NULL,
                                     outputFolder,
                                     databaseId = "Unknown",
                                     databaseName = "Unknown",
                                     databaseDescription = "Unknown",
                                     cdmDatabaseSchema,
                                     outcomeDatabaseSchema = cdmDatabaseSchema,
                                     outcomeTable = "outcome",
                                     nestingDatabaseSchema = cdmDatabaseSchema,
                                     nestingTable = "nesting",
                                     createCohorts = TRUE,
                                     createCmObject = TRUE,
                                     fitPsModel = TRUE,
                                     uploadResult = FALSE,
                                     maxCores = 4){
  if (!file.exists(outputFolder))
    dir.create(outputFolder, recursive = TRUE)
  if (!is.null(getOption("fftempdir")) && !file.exists(getOption("fftempdir"))) {
    warning("fftempdir '", getOption("fftempdir"), "' not found. Attempting to create folder")
    dir.create(getOption("fftempdir"), recursive = TRUE)
  }
  
  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "log.txt"))
  
  ##COHORT GENERATION
  if(createCohorts){
    ParallelLogger::logInfo("Creating Method Evaluation Benchmark cohorts")
    MethodEvaluation::createReferenceSetCohorts(connectionDetails, 
                                                oracleTempSchema = oracleTempSchema,
                                                cdmDatabaseSchema = cdmDatabaseSchema, 
                                                outcomeDatabaseSchema = outcomeDatabaseSchema,
                                                outcomeTable = outcomeTable, 
                                                nestingDatabaseSchema = nestingDatabaseSchema,
                                                nestingTable = nestingTable, 
                                                referenceSet = "ohdsiMethodsBenchmark")
  }
  
  
  ##CREATE cmObject
  
  if(createCmObject){
    
    ##Adding databaseId to the CmObject
  }
  
  ##Fit PS model
  
  ##Export cmObject and PS model
  
}


