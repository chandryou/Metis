INSERT INTO @cohort_database_schema.@cohort_table (
cohort_definition_id,
cohort_start_date,
cohort_end_date,
subject_id
)
SELECT @cohort_definition_id AS cohort_definition_id,
      cohort_start_date,
      cohort_end_date,
      subject_id
  FROM (
    SELECT drug_era_start_date AS cohort_start_date,
    drug_era_end_date AS cohort_end_date,
    person_id AS subject_id
    FROM (
      SELECT drug_era_start_date,
      drug_era_end_date,
      person_id,
      ROW_NUMBER() OVER (
        PARTITION BY person_id, drug_era_start_date
        ORDER BY drug_era_start_date
      ) order_nr
      FROM @cdm_database_schema.drug_era
    ) ordered_exposures
    WHERE order_nr = 1
  ) first_era
  INNER JOIN @cdm_database_schema.observation_period
  ON subject_id = person_id
  AND observation_period_start_date < cohort_start_date
  AND observation_period_end_date > cohort_start_date
  WHERE DATEDIFF(DAY,
                 observation_period_start_date,
                 cohort_start_date) >= @minimum_prior_observation
  ;