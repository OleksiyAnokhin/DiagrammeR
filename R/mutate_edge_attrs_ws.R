#' Mutate edge attribute values for a selection of edges
#' @description Within a graph's internal edge
#' data frame (edf), mutate edge attribute
#' values only for edges in a selection by
#' using one or more expressions.
#' @param graph a graph object of class
#' \code{dgr_graph}.
#' @param ... expressions used for the mutation
#' of edge attributes. LHS of each expression is
#' either an existing or new edge attribute name.
#' The RHS can consist of any valid R code that
#' uses edge attributes as variables. Expressions
#' are evaluated in the order provided, so, edge
#' attributes created or modified are ready to
#' use in subsequent expressions.
#' @return a graph object of class
#' \code{dgr_graph}.
#' @examples
#' # Create a graph with 3 edges
#' # and then select edge `1`
#' graph <-
#'   create_graph() %>%
#'   add_path(n = 4) %>%
#'   set_edge_attrs(
#'     edge_attr = width,
#'     values = c(3.4, 2.3, 7.2)) %>%
#'   select_edges(edges = 1)
#'
#' # Get the graph's internal edf
#' # to show which edge attributes
#' # are available
#' graph %>%
#'   get_edge_df()
#'
#' # Mutate the `width` edge
#' # attribute for the edges
#' # only in the active selection
#' # of edges (edge `1`); here,
#' # we divide each value in the
#' # selection by 2
#' graph <-
#'   graph %>%
#'   mutate_edge_attrs_ws(
#'     width = width / 2)
#'
#' # Get the graph's internal
#' # edf to show that the edge
#' # attribute `width` had its
#' # values changed
#' graph %>%
#'   get_edge_df()
#'
#' # Create a new edge attribute,
#' # called `length`, that is the
#' # log of values in `width` plus
#' # 2 (and, also, round all values
#' # to 2 decimal places)
#' graph <-
#'   graph %>%
#'   clear_selection() %>%
#'   select_edges(edges = 2:3) %>%
#'   mutate_edge_attrs_ws(
#'     length = (log(width) + 2) %>%
#'                round(2))
#'
#' # Get the graph's internal edf
#' # to show that the edge attribute
#' # values had been mutated only
#' # for edges `2` and `3` (since
#' # edge `1` is excluded, an NA
#' # value is applied)
#' graph %>%
#'   get_edge_df()
#'
#' # Create a new edge attribute
#' # called `area`, which is the
#' # product of the `width` and
#' # `length` attributes
#' graph <-
#'   graph %>%
#'   mutate_edge_attrs_ws(
#'     area = width * length)
#'
#' # Get the graph's internal edf
#' # to show that the edge attribute
#' # values had been multiplied
#' # together (with new attr `area`)
#' # for nodes `2` and `3`
#' graph %>%
#'   get_edge_df()
#'
#' # We can invert the selection
#' # and mutate edge `1` several
#' # times to get an `area` value
#' # for that edge
#' graph <-
#'   graph %>%
#'   invert_selection() %>%
#'   mutate_edge_attrs_ws(
#'     length = (log(width) + 5) %>%
#'                round(2),
#'     area = width * length)
#'
#' # Get the graph's internal edf
#' # to show that the 2 mutations
#' # occurred for edge `1`, yielding
#' # non-NA values for its edge
#' # attributes without changing
#' # those of the other edges
#' graph %>%
#'   get_edge_df()
#' @importFrom dplyr mutate_
#' @importFrom rlang exprs
#' @export mutate_edge_attrs_ws

mutate_edge_attrs_ws <- function(graph,
                                 ...) {

  # Get the time of function start
  time_function_start <- Sys.time()

  # Validation: Graph object is valid
  if (graph_object_valid(graph) == FALSE) {

    stop(
      "The graph object is not valid.",
      call. = FALSE)
  }

  # Validation: Graph contains edges
  if (graph_contains_edges(graph) == FALSE) {

    stop(
      "The graph contains no edges, so, no edge attributes can undergo mutation.",
      call. = FALSE)
  }

  # Validation: Graph object has valid edge selection
  if (graph_contains_edge_selection(graph) == FALSE) {

    stop(
      "There is no selection of edges available.",
      call. = FALSE)
  }

  # Collect expressions
  exprs <- rlang::exprs(...)

  # Extract the graph's edf
  edf <- get_edge_df(graph)

  # Stop function if any supplied
  # expressions mutate columns that
  # should not be changed
  if ("id" %in% names(exprs) |
      "from" %in% names(exprs) |
      "to" %in% names(exprs)) {

    stop(
      "The variables `id`, `from`, or `to` cannot undergo mutation.",
      call. = FALSE)
  }

  # Determine which edges are not
  # in the active selection
  unselected_edges <-
    base::setdiff(get_edge_ids(graph), get_selection(graph))

  for (i in 1:length(exprs)) {

    # Case where mutation occurs for an
    # existing edge attribute
    if (names(exprs)[i] %in% colnames(edf)) {

      edf_replacement <-
        edf %>%
        dplyr::mutate_(
          .dots = setNames(list((exprs %>% paste())[i]),
                           names(exprs)[i]))

      edf_replacement[
        which(edf$id %in% unselected_edges), ] <-
        edf[
          which(edf$id %in% unselected_edges), ]

      # Update the graph's edf
      graph$edges_df <- edf_replacement

      # Reobtain the changed edf for
      # any subsequent mutations
      edf <- get_edge_df(graph)
    }

    # Case where mutation creates a
    # new edge attribute
    if (!(names(exprs)[i] %in% colnames(edf))) {

      edf_replacement <-
        edf %>%
        dplyr::mutate_(
          .dots = setNames(list((exprs %>% paste())[i]),
                           names(exprs)[i]))

      edf_replacement[
        which(edf$id %in% unselected_edges),
        which(colnames(edf_replacement) == names(exprs)[i])] <- NA

      # Update the graph's edf
      graph$edges_df <- edf_replacement

      # Reobtain the changed edf for
      # any subsequent mutations
      edf <- get_edge_df(graph)
    }
  }

  # Update the `graph_log` df with an action
  graph$graph_log <-
    add_action_to_log(
      graph_log = graph$graph_log,
      version_id = nrow(graph$graph_log) + 1,
      function_used = "mutate_edge_attrs_ws",
      time_modified = time_function_start,
      duration = graph_function_duration(time_function_start),
      nodes = nrow(graph$nodes_df),
      edges = nrow(graph$edges_df))

  # Write graph backup if the option is set
  if (graph$graph_info$write_backups) {
    save_graph_as_rds(graph = graph)
  }

  graph
}
