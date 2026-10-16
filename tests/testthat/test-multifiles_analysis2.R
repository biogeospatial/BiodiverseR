library("BiodiverseR")

test_that("Analyse oneshot handles multiple input files", {
  file_path <- system.file("extdata", package ="BiodiverseR")

  gp_lb <- list(
    '250:250' = list (r1 = 13758, r2 = 13860, r3 = 13727),
    '250:750' = list (r1 = 11003, r2 = 11134, r3 = 11279),
    '750:250' = list (r1 = 10981, r2 = 11302, r3 = 10974),
    '750:750' = list (r1 =  8807, r2 =  8715, r3 =  8788)
  )

  args = list (
    r_data = gp_lb,
    raster_files = normalizePath(list.files (path = file_path, pattern = "r[123].tif$",  full.names=TRUE)),
    delimited_text_file_data = list(
      files = normalizePath(list.files (path = file_path, pattern = "r[123].csv$",  full.names=TRUE)),
      list(1, 2), list(4), list(3)
    ),
    shapefile_data = list (
      files = normalizePath(list.files (path = file_path, pattern = "r[123].sh[pz]$",  full.names=TRUE)),
      list(":shape_x", ":shape_y"), list("label"), list("count")
    ),
    spreadsheet_data = list (
      files = normalizePath(list.files (path = file_path, pattern = "r[123].xlsx$", full.names=TRUE)),
      list("X", "Y"), list("label"), list("count")
    )
  )

  tree = ape::read.nexus (fs::path(file_path, "tree.nex"))

  expected_sp_results = data.frame(
    Axis_0         = c(250, 250, 750, 750),
    Axis_1         = c(250, 750, 250, 750),
    ENDC_CWE       = c(0.25, 0.25, 0.25, 0.25),
    ENDC_RICHNESS  = c(3, 3, 3, 3),
    ENDC_SINGLE    = c(0.75, 0.75, 0.75, 0.75),
    ENDC_WE        = c(0.75, 0.75, 0.75, 0.75),
    PD             = c(4, 4, 4, 4),
    PD_P           = c(1, 1, 1, 1),
    PD_P_per_taxon = c(1/3, 1/3, 1/3, 1/3),
    PD_per_taxon   = c(1+1/3, 1+1/3, 1+1/3, 1+1/3)
  )
  row.names(expected_sp_results) = c("250:250", "250:750", "750:250", "750:750")

  expected_sample_counts = data.frame (
    r1     = c(13758, 11003, 10981,  8807),
    r2     = c(13860, 11134, 11302,  8715),
    r3     = c(13727, 11279, 10974,  8788)
  )
  row.names(expected_sample_counts) = row.names(expected_sp_results)

  nargs = length(args)
  for (n in 2:nargs) {
    message(n)
    for (i in 1:(nargs-n)) {
      #  skip if too long - should perhaps use i+n-1 in target slice
      if (i+n > nargs) {break}

      targets = args[names(args)[i:(i+n)]]
      # message (paste(i, n, i+n))
      # message (paste(c(i:(i+n)), collapse=":"))
      # message (paste(names(targets), collapse=":"))
      # message (paste (names(args)[i:(i+n)]))

      results = analyse_oneshot_spatial(
        r_data           = targets[['r_data']],
        raster_files     = targets[['raster_files']],
        spreadsheet_data = targets[['spreadsheet_data']],
        delimited_text_file_data = targets[['delimited_text_file_data']],
        shapefile_data   = targets[['shapefile_data']],
        cellsizes        = c(500, 500),
        calculations     = c('calc_endemism_central', 'calc_pd', 'calc_local_sample_count_lists'),
        tree = tree
      )

      target_names = paste (names(targets), collapse=(":"))
      #message (length (targets))
      nn = length(names(targets))
      expected_abc3 = data.frame (
          Axis_0 = 0 + expected_sp_results$Axis_0, # force numeric
          Axis_1 = 0 + expected_sp_results$Axis_1,
          r1 = nn * expected_sample_counts[['r1']],
          r2 = nn * expected_sample_counts[['r2']],
          r3 = nn * expected_sample_counts[['r3']]
      )
      row.names(expected_abc3) = row.names(expected_sp_results)
      expected = list (
        ABC3_LABELS_SET1 = expected_abc3,
        SPATIAL_RESULTS  = expected_sp_results
      )
      expect_equal(results, expected, info=target_names)

    }
  }

})
