library("BiodiverseR")

test_that("basedata uses default cell size and origin", {
  initialize_formals = formals(basedata[["public_methods"]][["initialize"]])

  expect_equal(initialize_formals[["cellsizes"]], 1)
  expect_equal(initialize_formals[["cellorigins"]], 0)
})

test_that("Test to see if package cache is created after analysis call", {
  bd = basedata$new(cellsizes=c(500,500))

  #  run twice to ensure we hit the cache
  for (i in 1:2) {
    result = bd$get_indices_metadata()

    # Simple checks for correct type and to check if env was properly populated
    expect_equal(typeof(result), "list")
    expect_true(length(result) > 0)

    #print (names (result))
    names_are_all_calcs = all (grepl (r"(^calc_)", names(result)))

    expect_true (names_are_all_calcs)
  }

})
