#' Use the Biodiverse server to load a set of rasters and then analyse them
#'
#' @param raster_files character
#' @param r_data list
#' @param spreadsheet_data list
#' @param delimited_text_file_data list
#' @param shapefile_data list
#' @param cellsizes numeric
#' @param calculations character
#' @param tree class phylo
#' @param ... passed on to start_server call
#'
#' @return The results of the analysis as an R list
#'
#' @examples
#' if(interactive()) {
#'   analysis_results = analyse_oneshot_spatial (
#'     raster_files             = c("r1.tif", "r2.tif"),
#'     r_data                   = list(
#'                                     '250:250' = list (r1 = 13758, r2 = 13860),
#'                                     '250:750' = list (r1 = 11003, r2 = 11134),
#'                                    ),
#'     spreadsheet_data         = c("r1.xlsx", "r2.xlsx"),
#'     delimited_text_file_data = c("r1.csv", "r2.csv"),
#'     shapefile_data           = c("r1.shp", "r2.shp"),
#'     cellsizes                = c(500, 500),
#'     calculations             = c("calc_endemism_central", "calc_richness", "calc_pd"),
#'     tree                     = some_phylo_tree
#'   )
#' }
#format for data is list(list(files), list(group_columns), list(label_columns), list(sample_count_columns)) # nolint
analyse_oneshot_spatial <- function(
    raster_files = NULL,
    r_data = NULL,
    spreadsheet_data = NULL,
    delimited_text_file_data = NULL,
    shapefile_data = NULL,
    cellsizes,
    calculations = c("calc_richness", "calc_endemism_central"),
    tree = NULL,
    ...) {

  stopifnot("cellsizes argument must be a numeric vector" = any(class(cellsizes) == "numeric")) # nolint
  stopifnot("cellsizes must have exactly two axes" = length(cellsizes) == 2)

  if (!is.null(tree)) {
    stopifnot("tree must be of class phylo or inherit from it" = inherits (tree, "phylo")) # nolint
  }

  bd = basedata$new(
    cellsizes = cellsizes
  )
  params = list (
    raster_params = list (
      files = raster_files
    ),
    spreadsheet_params = convert_to_params(spreadsheet_data),
    delimited_text_params = convert_to_params(delimited_text_file_data),
    shapefile_params = convert_to_params(shapefile_data),
    r_data = list (data = r_data)
  )
  result = bd$load_data(params)

  result = bd$run_spatial_analysis(
    spatial_conditions = c("sp_self_only()"),
    calculations = calculations,
    tree = tree
  )

  #  clean up
  bd$stop_server()
  bd = NULL
  gc()

  # message(result)
  return (result)
}

#' Doodle and fiddle to get some args in the right format
#' @param list list
#' @noRd
convert_to_params <- function(list) {
  if (!is.null(list)) {

    #Check if the first file passed in is a shapefile or spreadsheet
    file_ends <- list(".shp", ".xlsx", ".xls", ".ods", ".sxc")
    flag <- FALSE
    for (i in seq(1, length(file_ends))) {
      if (grepl(file_ends[i], list[[1]][[1]])) {
        flag <- TRUE
      }
    }

    if (flag) {
      #format for shapefiles and spreadsheets
      return(list(files = list[[1]], group_field_names = list[[2]], label_field_names = list[[3]], sample_count_col_names = list[[4]])) # nolint
    } else {
      #format for delimited text files
      return(list(files = list[[1]], group_columns = list[[2]], label_columns = list[[3]], sample_count_columns = list[[4]])) # nolint
    }
  }
}
