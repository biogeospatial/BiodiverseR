library("BiodiverseR")

test_that("Test to see if package cache is created after analysis call", {
  bd = basedata$new(cellsizes=c(500,500))

  expect_equal(bd$cache_list, list())
  r_data = list (
    data = list(
      '250:250' = list (r1 = 13, r2 = 13, r3 = 13),
      '250:750' = list (r2 = 11, r3 = 11, r4 = 10),
      '750:250' = list (r3 = 10),
      '750:750' = list (r1 =  8, r3 =  8)
    )
  )
  params = list (bd_params = r_data)
  results = bd$load_data(params)

  results = bd$run_spatial_analysis (
      calculations = c("calc_richness", "calc_endemism_central"),
      spatial_conditions = "sp_self_only()"   
  )

  cache_type = "test"
  result = bd$get_indices_metadata(cache_type)

  # Simple checks for correct type and to check if env was properly populated
  expect_equal(typeof(result), "environment")
  expect_true(length(result) > 0)

  # Check if the content of the env exists
  expect_true(!is.null(result$indices_metadata))
})