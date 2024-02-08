#' Runs a cluster analysis with the given parameters
#' Uses the given basedata object to call the server
#'
#'
#' @param bd class R6 basedata
#' @param index character
#' @param linkage_function character
#' @param calculations character
#' @param spatial_conditions character
#' @param def_query character
#' @param name character
#' @param tree class phylo
#' @param cluster_tie_breakers
#'
#' @return The processed results of the cluster analysis
#'
#' @examples
#' if(interactive()) {
#'   bd = BiodiverseR::basedata$new(cellsizes=c(500,500))
#'
#'   r_data = list(
#'                 '250:250' = list (r1 = 13, r2 = 13),
#'                 '250:750' = list (r2 = 11),
#'                )
#'
#'   params = list (bd_params = r_data, raster_params = NULL)
#'   result = bd$load_data(params)
#'
#'   results = bd$run_cluster_analysis (
#'     # calculations = calculations,
#'     # tree = tree
#'   )
#' }
run_cluster_analysis = function (
    bd,
    index = 'SORENSON',
    linkage_function = 'link_average',
    calculations = NULL,
    spatial_conditions = NULL,
    def_query = NULL,
    name = NULL,
    tree = NULL,
    cluster_tie_breakers = NULL
) {
  checkmate::assertR6(bd, c("basedata"))
  stopifnot(bd$server_status())

  if (!is.null(calculations)) {
    stopifnot(checkmate::test_vector(calculations))
  }

  # params = as.list(match.call())
  # params[["bd"]] = NULL
  params = list (
    spatial_calculations = calculations,
    spatial_conditions   = spatial_conditions,
    definition_query     = def_query,
    name = name,
    tree = tree,
    linkage_function     = linkage_function,
    index = index,
    cluster_tie_breaker  = cluster_tie_breakers
  )

  call_results = bd$call_server("bd_run_cluster_analysis", params)

  #  munge the data into the expected form
  processed_results = list()
  processed_results$lists = process_tabular_results(call_results$lists)

  tree = call_results[['dendrogram']]
  tree[['edge']]        = matrix (as.integer(tree[['edge']]), ncol=2)
  tree[['tip.label']]   = as.character(tree[['tip.label']])
  tree[['node.label']]  = as.character(tree[['node.label']])
  tree[['edge.length']] = as.numeric(tree[['edge.length']])
  class(tree) = "phylo"
  processed_results[['dendrogram']] = tree

  #  needs special handling due to text values
  node_vals <- call_results[['NODE_VALUES']]
  header <- unlist(node_vals[[1]])
  node_vals[[1]] <- NULL  #  remove the header

  df <- do.call(rbind, lapply(node_vals, rbind)) |> as.data.frame()
  df[df == "NULL"] <- NA
  colnames(df) <- header
  if (header[1] == "ELEMENT") {
    #  make the element names the row names, and remove from main table
    row.names(df) <- as.character(df[['ELEMENT']])
    df[[1]] <- NULL

    df[['Axis_0']]   = as.character(df[['Axis_0']])
    df[['NAME']]     = as.character(df[['NAME']])
    df[['TREENAME']] = as.character(df[['TREENAME']])
    df[['LENGTHTOPARENT']] = as.numeric(df[['LENGTHTOPARENT']])
    df[['NODE_NUMBER']] = as.integer(df[['NODE_NUMBER']])
    df[['COLOUR']]      = unlist (df[['COLOUR']])
    df[['PARENTNODE']]  = as.character(df[['PARENTNODE']])
  }
  processed_results[['node_values']] <- df

  return(processed_results)
}

