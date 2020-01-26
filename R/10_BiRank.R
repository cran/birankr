#' BiRanks
#' @description Estimate BiRanks of nodes from an edge list or adjacency matrix. Returns a vector of ranks or (optionally) a list containing a vector for each mode. If the provided data is an edge list, this function returns ranks ordered by the unique values in the selected mode.
#' 
#' @details Created by He et al. (2017) \doi{10.1109/TKDE.2016.2611584}, BiRank is a highly generalizable algorithm that was developed explicitly for use in bipartite graphs. In fact, He et al.'s implementation of BiRank forms the basis of this package's implementation of all other bipartite ranking algorithms. Like every other bipartite ranking algorithm, BiRank simultaneously estimates ranks across each mode of the input data. BiRank's implementation is also highly similar to BGRM in that it symmetrically normalizes the transition matrix. BiRank differs from BGRM only in that it normalizes the transition matrix by the square-root outdegree of the source node and the square-root indegree of the target node. 
#' @param data Data to use for estimating BiRank. Must contain bipartite graph data, either formatted as an edge list (class data.frame, data.table, or tibble (tbl_df)) or as an adjacency matrix (class matrix or dgCMatrix).
#' @param sender_name Name of sender column. Parameter ignored if data is an adjacency matrix. Defaults to first column of edge list.
#' @param receiver_name Name of sender column. Parameter ignored if data is an adjacency matrix. Defaults to the second column of edge list.
#' @param weight_name Name of edge weights. Parameter ignored if data is an adjacency matrix. Defaults to edge weights = 1.
#' @param rm_weights Removes edge weights from graph object before estimating BiRank. Parameter ignored if data is an edge list. Defaults to FALSE.
#' @param duplicates How to treat duplicate edges if any in data. Parameter ignored if data is an adjacency matrix. If option "add" is selected, duplicated edges and corresponding edge weights are collapsed via addition. Otherwise, duplicated edges are removed and only the first instance of a duplicated edge is used. Defaults to "add".
#' @param return_mode Mode for which to return BiRank ranks. Defaults to "rows" (the first column of an edge list).
#' @param return_data_frame Return results as a data frame with node names in first column and ranks in the second column. If set to FALSE, the function just returns a named vector of ranks. Defaults to TRUE.
#' @param alpha Dampening factor for first mode of data. Defaults to 0.85.
#' @param beta Dampening factor for second mode of data. Defaults to 0.85.
#' @param max_iter Maximum number of iterations to run before model fails to converge. Defaults to 200.
#' @param tol Maximum tolerance of model convergence. Defaults to 1.0e-4.
#' @param verbose Show the progress of this function. Defaults to FALSE.
#' @return A dataframe containing each node name and node rank. If return_data_frame changed to FALSE, returns a vector of node ranks.
#' @keywords Bipartite rank centrality BiRank 
#' @export
#' @import Matrix data.table
#' @md
#' @references 
#' Xiangnan He, Ming Gao, Min-Yen Kan, and Dingxian Wang. "Birank: Towards ranking on bipartite graphs". *IEEE Transactions on Knowledge and Data Engineering*, 29(1):57-71, 2016
#' @examples
#' #create edge list between patients and providers
#'     df <- data.table(
#'       patient_id = sample(x = 1:10000, size = 10000, replace = TRUE),
#'       provider_id = sample(x = 1:5000, size = 10000, replace = TRUE)
#'     )
#'
#' #estimate BiRank ranks
#'     BiRank <- br_birank(data = df)

br_birank <- function(
  data,
  sender_name = NULL,
  receiver_name = NULL,
  weight_name = NULL,
  rm_weights= FALSE,
  duplicates = c("add", "remove"),
  return_mode = c("rows", "columns", "both"),
  return_data_frame = TRUE,
  alpha = 0.85,
  beta = 0.85,
  max_iter = 200,
  tol = 1.0e-4,
  verbose = FALSE
){
  #a) if weight name = "unweighted", change to NULL
      if(!is.null(weight_name)){
          if(weight_name == "unweighted"){
            weight_name <- NULL
          }
      }

  #b) convert to sparse matrix if a dataframe or matrix
      if(any(class(data) == "data.frame")){
        data <- data.table(data)
        if(verbose) message("Converting to sparse matrix...")
        adj_mat <- sparsematrix_from_edgelist(
          data = data,
          sender_name = sender_name,
          receiver_name = receiver_name,
          weight_name = weight_name,
          duplicates = duplicates[1]
        )
      }else if(length(class(data)) == 1 & class(data) == "matrix"){
        sparsematrix_from_matrix(adj_mat)
      }else if(class(data) != "dgCMatrix"){
        stop('data is not a data.frame, tbl_df, data.table, matrix, or dgCMatrix')
      }

  #d) remove weights
      if(rm_weights){
          if(verbose) message("Removing edge weights...")
          adj_mat <- sparsematrix_rm_weights(adj_mat)
      }

  #e) estimate bipartite rank
      if(verbose) message("Estimating bipartite rank...")
      rank <- bipartite_pagerank_from_matrix(
        adj_mat = adj_mat,
        normalizer = "BiRank",
        alpha = alpha,
        beta = beta,
        max_iter = max_iter,
        tol = tol,
        verbose = verbose,
        return_mode = return_mode[1]
      )

  #f) find rank labels
      #i) get labels if data is data frame
          if(any(class(data) == "data.frame")){
            #1) determine ID index
                if(is.null(sender_name) | is.null(receiver_name)){
                    id1 = 1
                    id2 = 2
                }else{
                    id1 = match(sender_name, names(data))
                    id2 = match(receiver_name, names(data))
                }
            #2) pull IDs for each mode in order of function
                edges <- data[, c(id1, id2), with = F]
                id_names1 <- as.character(unlist(unique(edges[, id1, with = F])))
                id_names2 <- as.character(unlist(unique(edges[, id2, with = F])))
          }
      #ii) get labels if data is matrix
          if(!any(class(data) == "data.frame")){
            #1) sender names
              if(!is.null(rownames(data))){
                id_names1 <- rownames(data)
              }else{
                id_names1 <- 1:ncol(data)
              }
            #2) receiver names
              if(!is.null(colnames(data))){
                id_names2 <- colnames(data)
              }else{
                id_names2 <- 1:ncol(data)
              }
          }

  #g) format results
      #i) get variable name id of a data.frame
          if(any(class(data) == "data.frame")){
            sender_name <- names(edges)[1]
            receiver_name <- names(edges)[2]
          } else{
            sender_name <- "ID"
            receiver_name <- "ID"
          }

      #ii) if return a data frame, format results as a dataframe
          if(return_data_frame){
            if(return_mode[1] == "rows"){
              rank <- data.frame(ID = id_names1, rank = rank)
              names(rank)[1] <- sender_name
            }
            if(return_mode[1] == "columns"){
              rank <- data.frame(ID = id_names2, rank = rank)
              names(rank)[1] <- receiver_name
            }
            if(return_mode[1] == "both"){
              rank <- list(
                rows = data.frame(ID = id_names1, rank = rank[[1]]),
                columns = data.frame(ID = id_names2, rank = rank[[2]])
              )
              names(rank$rows)[1] <- sender_name
              names(rank$columns)[1] <- receiver_name
            }
          }
      #iii) if not return data frame, format results as vector
          if(!return_data_frame){
            if(return_mode[1] == "rows"){
              names(rank) <- id_names1
            }
            if(return_mode[1] == "columns"){
              names(rank) <- id_names2
            }
            if(return_mode[1] == "both"){
              names(rank[[1]]) <- id_names1
              names(rank[[2]]) <- id_names2
            }
          }

  #h) return data
      return(rank)

}
      