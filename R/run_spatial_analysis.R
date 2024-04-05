#' Runs a spatial analysis with the given paramaters
#' Uses the basedata object (bd) to call the server
#'
#'
#' @param bd class R6 basedata
#' @param calculations integer
#' @param spatial_conditions character
#' @param def_query character
#' @param name character
#' @param tree class phylo
#'
#' @return The processed results of the spatial analysis
#'
#' @examples
#' if(interactive()) {
#'   bd = BiodiverseR::basedata$new(cellsizes=c(500,500))
#'
#'   results = bd$run_spatial_analysis (
#'      # name = "sp1",
#'      calculations = c("calc_richness", "calc_endemism_central"),
#'      spatial_conditions = "sp_self_only()"
#'   )
#' }
run_spatial_analysis = function (
    bd,
    calculations = NULL,
    spatial_conditions = c('sp_self_only()'),
    def_query = NULL,
    name = NULL,
    tree = NULL
) {
  checkmate::assertR6(bd, c("basedata"))
  stopifnot(bd$server_status())
# message ("------")
# message (calculations)
# message (class(calculations))
# message ("------")
  stopifnot(checkmate::test_vector(calculations))

  # params = as.list(match.call())
  # params[["bd"]] = NULL
  params = list (
    calculations = calculations,
    spatial_conditions = spatial_conditions,
    definition_query = def_query,
    name = name,
    tree = tree
  )

  call_results = bd$call_server("bd_run_spatial_analysis", params)

  processed_results = process_tabular_results(call_results)

  return(processed_results)
}

#' Process the results of the spatial analysis
#'
#'
#' @param call_results list
#'

process_tabular_results = function (call_results) {
  processed_results <- list()
  #apply? - nah.  There will never be more than ten list elements
  #  convert list structure to a data frame
  #  maybe the server could give a more DF-like structure,
  #  but this is already an array
  for (list_name in sort(names(call_results))) {
    #Spatial results is the only result in our test case. Which contains a list of expected stuff # nolint
    message("Processing ", list_name)

    results <- call_results[[list_name]]  #  need to handle when it is not there
    header <- unlist(results[[1]])
    results[[1]] <- NULL  #  remove the header
    #99 percent sure this removes the names of the rows, like axis_0, can always check  #nolint

    df <- do.call(rbind, lapply(results, rbind)) |> as.data.frame()
    df[df == "NULL"] <- NA
    colnames(df) <- header
    if (header[1] == "ELEMENT") {
      #  make the element names the row names, and remove from main table
      row.names(df) <- df$ELEMENT
      df[[1]] <- NULL
      #  the other data are numeric for raster inputs
      for (c in colnames(df)) {
        df[[c]] <- as.numeric(df[[c]])
      }
    }
    processed_results[[list_name]] <- df
  }
  #check if the processign happened before this function, using  utils::str (call_results)

  processed_results
}
