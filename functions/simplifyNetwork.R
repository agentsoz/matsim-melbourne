
simplifyNetwork <- function(l_df, n_df, shortLinkLength = 10){
  
  # finding links with short length (default=10m)
  l_df_short <- l_df %>%
    filter(length<=shortLinkLength) 
  # Selecting nodes connected with short links
  n_df_short <- n_df %>% filter(id %in% l_df_short$from_id | id %in% l_df_short$to_id )
  # Making the graph for the bridges
  g <- graph_from_data_frame(l_df_short[,c("from_id", "to_id")], vertices = n_df_short) 
  #plot(g,  vertex.size=0.1, vertex.label=NA, vertex.color="red", edge.arrow.size=0, edge.curved = 0)
  
  # Getting components
  comp <- components(g)
  comp_df <- data.frame(segment_id=as.integer(names(comp$membership)), cluster_id=comp$membership, row.names=NULL)
  # Creating an empty lookup
  lookup_df <-  data.frame(new_id = unique(comp_df$cluster_id), old_ids = NA, x = NA, y = NA, z = NA)
  
  # Finding centroids
  for (i in 1:nrow(lookup_df)){
    lookup_df$old_ids[i] <- comp_df %>% filter(cluster_id == lookup_df$new_id[i]) %>% dplyr::select(segment_id) %>% as.list()
    this_old_ids <- which(n_df$id %in% unlist(lookup_df$old_ids[i]))
    if(length(this_old_ids) > 2){
      xcors <- n_df$x[this_old_ids]
      ycors <- n_df$y[this_old_ids]
      zcors <- n_df$z[this_old_ids]
      lookup_df$x[i] <- mean(xcors)
      lookup_df$y[i] <- mean(ycors)
      lookup_df$z[i] <- mean(zcors)
      newID <- paste("S_", i, sep = "")
      for (oldID in unlist(lookup_df$old_ids[i])){
        j <- which(n_df$id  == oldID)
        n_df$id[j] <- newID
        n_df$x[j] <- lookup_df$x[i]
        n_df$y[j] <- lookup_df$y[i]
        n_df$z[j] <- lookup_df$z[i]
        l_df[which(l_df$from_id  == oldID), "from_id"] <- newID
        l_df[which(l_df$to_id  == oldID), "to_id"] <- newID
      }
    }
  }
  
  return(list(n_df, l_df))
}