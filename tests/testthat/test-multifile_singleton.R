library("fs")
library("BiodiverseR")
test_that("Analyse singleton handles multiple input files", {
  file_path <- system.file("extdata", package ="BiodiverseR")

  gp_lb <- list(
    '250:250' = list (r1 = 13758, r2 = 13860, r3 = 13727),
    '250:750' = list (r1 = 11003, r2 = 11134, r3 = 11279),
    '750:250' = list (r1 = 10981, r2 = 11302, r3 = 10974),
    '750:750' = list (r1 =  8807, r2 =  8715, r3 =  8788)
  )

  args = list (
    r_data = list (
      data = gp_lb
    ),
    raster_params = list (
      files = c(normalizePath(
        list.files (path = file_path, pattern = "r[123].tif$",  full.names=TRUE)
      ))
    ),
    delimited_text_params = list(
      files = normalizePath(
        list.files (path = file_path, pattern = "r[123].csv$",  full.names=TRUE)
      ),
      group_columns = c(1, 2),
      label_columns = c(4),
      sample_count_columns = c(3)
    ),
    shapefile_params = list (
      files = normalizePath(
        list.files (path = file_path, pattern = "r[123].shp$",  full.names=TRUE)
      ),
      group_field_names = c(":shape_x", ":shape_y"),
      label_field_names = c("label"),
      sample_count_col_names = c("count")
    ),
    spreadsheet_params = list (
      files = normalizePath(
        list.files (path = file_path, pattern = "r[123].xlsx$", full.names=TRUE)
      ),
      group_field_names = c("X", "Y"),
      label_field_names = c("label"),
      sample_count_col_names = c("count")
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

  calculations = c(
    'calc_endemism_central',
    'calc_pd',
    'calc_local_sample_count_lists'
  )

  nargs = length(args)
  for (n in 2:nargs) {
    message(n)
    for (i in 1:(nargs-n)) {
      #  skip if too long - should perhaps use i+n-1 in target slice
      if (i+n > nargs) {break}

      targets = args[names(args)[i:(i+n)]]
      target_names = paste (names(targets), collapse=(":"))

      bd = basedata$new(cellsizes=c(500,500))

      result = bd$load_data(targets)

      expect_equal(result, 1, info=paste ("load_data", target_names))

      results = bd$run_spatial_analysis (
        calculations = calculations,
        tree = tree
      )

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

      #  def query only needs to be done once
      #  should be in a separate test
      if (n == 2 && i == 1) {

        f = fs::file_temp(pattern = "test_", tmp_dir = tempdir(), ext = "bds")
        #message ("Saving to ", f)
        results = bd$save_to_bds (f)
        expect_true(results, info="basedata saved to file")
        bd2 = basedata$new(filename = f)
        gp_cnt = bd2$get_group_count()
        expect_equal(
          gp_cnt,
          4,
          info="basedata loaded from file"
        )
        expect_equal(
          bd$cellsizes,
          bd2$cellsizes,
          info="cellsizes match after save/reload"
        )
        expect_equal(
          bd$cellorigins,
          bd2$cellorigins,
          info="cell origins match after save/reload"
        )
        fs::file_delete(f)

        defq_analysis_name = "with def query"
        results = bd$run_spatial_analysis (
          calculations = calculations,
          def_query = '$y <= 250',
          tree = tree,
          name = defq_analysis_name
        )
        names = colnames(expected_abc3)
        expected_abc3['250:750', names[3:length(names)]] = NA
        expected_abc3['750:750', names[3:length(names)]] = NA
        ex = expected_sp_results
        names = colnames(ex)
        ex['250:750', names[3:length(names)]] = NA
        ex['750:750', names[3:length(names)]] = NA
        expected = list (
          ABC3_LABELS_SET1 = expected_abc3,
          SPATIAL_RESULTS  = ex
        )
        expect_equal(results, expected, info=target_names)

        results2 = bd$get_analysis_results(name = defq_analysis_name)
        expect_equal(results, results2, info="post-hoc grab of analysis results")


        #  now some deletions
        expect_equal(
          bd$get_analysis_count(),
          2,
          info="correct analysis count before deletion"
        )
        expect_equal(
          bd$delete_analysis(name = defq_analysis_name),
          1,
          info="successful deletion of defq analysis"
        )
        expect_equal(
          bd$get_analysis_count(),
          1,
          info="correct analysis count after deletion"
        )
        expect_equal(
          bd$delete_all_analyses(),
          1,
          info="successful deletion of all analysis"
        )
        expect_equal(
          bd$get_analysis_count(),
          0,
          info="correct analysis count after all deleted"
        )
      }

    }
  }

  # files <- list.files(temp_dir, full.names=TRUE)
  # file.remove(files)
  # file.remove(temp_dir)

})
