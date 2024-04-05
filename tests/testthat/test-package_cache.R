library("BiodiverseR")

test_that("Test to see if package cache is created after analysis call", {
  bd = basedata$new(cellsizes=c(500,500))

  expect_equal(bd$cache_list, NULL)

  results = bd$run_spatial_analysis (
      calculations = c("calc_richness", "calc_endemism_central"),
      spatial_conditions = "sp_self_only()"   
  )

  result = bd$get_indices_metadata()
  expect_false(bd$cache_list == NULL)
})
