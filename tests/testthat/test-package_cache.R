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

  results = bd$get_indices_metadata("test")
  # print(bd$cache_list["test"])
  expect_equal(bd$cache_list, list())
})