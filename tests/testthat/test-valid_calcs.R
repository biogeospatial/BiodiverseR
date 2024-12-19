
library("BiodiverseR")

test_that("Test to see if passed calculations are valid", {
  bd = basedata$new(cellsizes=c(500,500))

  # TODO: Check REGEXP of error messages

  # Multiple def_query vals
  expect_error(bd$calcs_are_valid(calc_names=c("calc_richness"), spatial_conditions="sp_self_only", def_query=c("first", "second")))


  # Check if neighbour sets are different
  expect_error(bd$calcs_are_valid(calc_names=c("calc_sorenson"), spatial_conditions="sp_self_only"))


  ### Invalid calc names
  expect_error(bd$calcs_are_valid(calc_names=c("xxxINVALID1"), spatial_conditions="sp_self_only"))
  expect_error(bd$calcs_are_valid(calc_names=c("calc_richness", "xxxINVALID1"), spatial_conditions="sp_self_only"))
  ###


  # No spatial conditions passed
  expect_error(bd$calcs_are_valid(calc_names=c("calc_sorenson")))


  # Check if calc_pd causes an error when no tree is passed
  expect_error(bd$calcs_are_valid(calc_names=c("calc_pd"), spatial_conditions="sp_self_only", def_query=c("first")))
  expect_true(bd$calcs_are_valid(calc_names=c("calc_pd"), spatial_conditions="sp_self_only", def_query=c("first"), tree="tree"))

})

  