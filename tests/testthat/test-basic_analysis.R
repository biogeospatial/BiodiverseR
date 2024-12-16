file_path <- system.file("extdata", package ="BiodiverseR")


test_that("Analyse rasters handles JSON", {
  gp_lb <- list(
    "50:50"   = list(label1 = 1, label2 = 1), # nolint
    "150:150" = list(label1 = 1, label2 = 1) # nolint
  )
  exp <- list(
    SPATIAL_RESULTS = data.frame(
      "Axis_0" = c(150, 50),
      "Axis_1" = c(150, 50),
      "ENDC_CWE" = c(0.5, 0.5),
      "ENDC_RICHNESS" = c(2, 2),
      "ENDC_SINGLE" = c(1.0, 1.0),
      "ENDC_WE" = c(1, 1)
    )
  )
  row.names(exp$SPATIAL_RESULTS) <- c("150:150", "50:50")

  results <- analyse_oneshot_spatial(
    r_data = gp_lb,
    cellsizes = c(100, 100),
    calculations = c("calc_endemism_central")
  )
  expect_equal(results, exp)
})

test_that("Oneshot analysis handles spreadsheets", {

  exp <- list(
    SPATIAL_RESULTS = data.frame( # nolint
      "Axis_0" = c(250, 250, 750, 750),
      "Axis_1" = c(250, 750, 250, 750),
      "ENDC_CWE" = c(0.25, 0.25, 0.25, 0.25),
      "ENDC_RICHNESS" = c(3, 3, 3, 3),
      "ENDC_SINGLE" = c(0.75, 0.75, 0.75, 0.75),
      "ENDC_WE" = c(0.75, 0.75, 0.75, 0.75),
      "REDUNDANCY_ALL"  = c(0.99992743983553, 0.999910222647833, 0.999909793426948, 0.999885974914481), # nolint
      "REDUNDANCY_SET1" = c(0.99992743983553, 0.999910222647833, 0.999909793426948, 0.999885974914481) # nolint
    )
  )
  row.names(exp$SPATIAL_RESULTS) <- c("250:250", "250:750", "750:250", "750:750") # nolint

  #get files
  spreadsheets = normalizePath(list.files (path = file_path, pattern = "r[123].xlsx$", full.names=TRUE)) # nolint

  #sanity check
  expect_equal(length(spreadsheets), 3, label = "we found three spreadsheets")

  result <- analyse_oneshot_spatial(
    spreadsheet_data = list(spreadsheets, list("X", "Y"), list("label"), list("count")), #nolint
    cellsizes = c(500, 500),
    # calc_pd should not be run as we have no tree
    calculations = c("calc_endemism_central", "calc_redundancy")
  )
  expect_equal(result, exp)
})

test_that("Oneshot analysis handles demilimited text files", {

  exp <- list(
    SPATIAL_RESULTS = data.frame( # nolint

      "Axis_0" = c(250, 250, 750, 750),
      "Axis_1" = c(250, 750, 250, 750),
      "ENDC_CWE" = c(0.25, 0.25, 0.25, 0.25),
      "ENDC_RICHNESS" = c(3, 3, 3, 3),
      "ENDC_SINGLE" = c(0.75, 0.75, 0.75, 0.75),
      "ENDC_WE" = c(0.75, 0.75, 0.75, 0.75),
      "REDUNDANCY_ALL"  = c(0.99992743983553, 0.999910222647833, 0.999909793426948, 0.999885974914481), # nolint
      "REDUNDANCY_SET1" = c(0.99992743983553, 0.999910222647833, 0.999909793426948, 0.999885974914481) # nolint
    )
  )
  row.names(exp$SPATIAL_RESULTS) <- c("250:250", "250:750", "750:250", "750:750") # nolint

  #get files
  delim_files = normalizePath(list.files (path = file_path, pattern = "r[123].csv$", full.names=TRUE)) # nolint

  #  sanity check
  expect_equal(length(delim_files), 3, label = "we found three delimited text files") # nolint

  result <- analyse_oneshot_spatial(
  delimited_text_file_data = list(delim_files, list(1, 2), list(4), list(3)),
  cellsizes = c(500, 500),
  calculations = c("calc_endemism_central", "calc_redundancy")
  )

  expect_equal(result, exp)
})

test_that("Oneshot analysis handles shapefiles", {

  exp <- list(
    SPATIAL_RESULTS = data.frame( # nolint

      "Axis_0" = c(250, 250, 750, 750),
      "Axis_1" = c(250, 750, 250, 750),
      "ENDC_CWE" = c(0.25, 0.25, 0.25, 0.25),
      "ENDC_RICHNESS" = c(3, 3, 3, 3),
      "ENDC_SINGLE" = c(0.75, 0.75, 0.75, 0.75),
      "ENDC_WE" = c(0.75, 0.75, 0.75, 0.75),
      "REDUNDANCY_ALL"  = c(0.99992743983553, 0.999910222647833, 0.999909793426948, 0.999885974914481), # nolint
      "REDUNDANCY_SET1" = c(0.99992743983553, 0.999910222647833, 0.999909793426948, 0.999885974914481) # nolint
    )
  )
  row.names(exp$SPATIAL_RESULTS) <- c("250:250", "250:750", "750:250", "750:750") # nolint

  #get files
  shape_files = normalizePath(list.files(path = file_path, pattern = "r[123].shp$", full.names=TRUE)) # nolint

  #  sanity check
  expect_equal(length(shape_files), 3, label = "we found three shapefiles") # nolint

  result <- analyse_oneshot_spatial(
    shapefile_data = list(shape_files, list(":shape_x", ":shape_y"), list("label"), list("count")), #nolint
    cellsizes = c(500, 500),
    calculations = c("calc_endemism_central", "calc_redundancy")
  )
  expect_equal(result, exp)
})
