#' Use the Biodiverse server to load a set of rasters and then analyse them
#'
#'
#' @param raster_files character
#' @param cellsizes numeric
#' @param calculations character
#' @param tree class phylo
#' @param ... passed on to start_server call
#'
#' @examples
#' if(interactive()) {
#'   analyse_rasters_spatial (
#'     raster_files = c("r1.tif", "r2.tif"),
#'     calculations = c("calc_endemism_central", "calc_richness", "calc_pd"),
#'     tree = some_phylo_tree
#'   )
#' }

analyse_rasters_spatial = function(
    raster_files, cellsizes,
    calculations=c('calc_richness', 'calc_endemism_central'),
    tree=NULL,
    ...){

  stopifnot("raster_files argument must be a character vector" = any(class(raster_files)=="character"))
  stopifnot(length(raster_files) > 0) # disable when we support other files
  stopifnot(all(file.exists(raster_files)))
  stopifnot("cellsizes argument must be a numeric vector" = any(class(cellsizes)=="numeric"))
  stopifnot("cellsizes must have exactly two axes" = length(cellsizes) == 2)

  if (!is.null(tree)) {
    stopifnot("tree must be of class phylo or inherit from it" = inherits (tree, "phylo"))
  }

  config = start_server(...)
  utils::str (config)
  message ("server process is live? ", config$server_object$is_alive())
  stopifnot(config$server_object$is_alive())  #  need a better error

  #  unique-ish name that is human readable
  sp_output_name = paste ('BiodiversR_analyse_rasters_spatial', Sys.time())
  params = list (
    analysis_config = list (
      spatial_conditions = 'sp_self_only()',  #  limited options for now
      calculations = calculations
    ),
    raster_params = list(
      files = raster_files
    ),
    bd = list (
      params = list (
        name = sp_output_name,
        cellsizes = cellsizes
      )
    ),
    tree = tree
  )
  params_as_json = rjson::toJSON(params)


  target_url = paste0(config$server_url, '/analysis_spatial_oneshot')

  message (target_url)
  message ("Posting data ", params_as_json)

  req <- httr2::request(target_url)
  req <- httr2::req_body_raw(req, params_as_json)
  response <- httr2::req_perform(req)
  call_results <- httr2::resp_body_json(response)

  #  terminate the server - don't wait for garbage collection
  config$server_object$kill()

  # browser()

  processed_results = list()
  #  lapply? - nah.  There will never be more than ten list elements
  for (list_name in sort(names(call_results))) {
    message ("Processing ", list_name)
    #  convert list structure to a data frame
    #  maybe the server could give a more DF-like structure,
    #  but this is already an array
    results = call_results[[list_name]]  #  need to handle when it is not there
    header = unlist(results[[1]])
    results[[1]] = NULL  #  remove the header
    df <- do.call(rbind, lapply(results, rbind)) |> as.data.frame()
    df[df == "NULL"] = NA
    colnames(df) = header
    if (header[1] == "ELEMENT") {
      #  make the element names the row names, and remove from main table
      row.names(df) = df$ELEMENT
      df[[1]] = NULL
      #  the other data are numeric for raster inputs
      for (c in colnames(df)) {
        df[[c]] = as.numeric(df[[c]])
      }
    }
    processed_results[[list_name]] = df
  }

  return (processed_results)
}

