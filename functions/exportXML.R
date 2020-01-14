
exportXML <- function(l_df, n_df, outputFileName = "outputXML"){
  
  addMATSimNode <- function(this_node){
    xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), x=this_node$x, y=this_node$y, z=this_node$z))# assign attribute list to attributes tag
    # addChildren(nodesn,xnn) 
     return(xnn)
  }
  
  addMATSimLink <- function(this_link){
    
    xll <- newXMLNode("link", attrs = c(id=as.character(this_link$id), from=as.character(this_link$from_id), to=as.character(this_link$to_id),
                                        length=this_link$length, capacity=this_link$capacity, freespeed=this_link$freespeed,
                                        permlanes=this_link$permlanes, oneway="1", modes=as.character(this_link$modes), origid=""))
    
    attribs <- this_link %>% mutate(bicycleInfrastructureSpeedFactor = 1.0) %>% 
      dplyr::select(osm_id, type = highway, bikeway, bicycleInfrastructureSpeedFactor) %>% 
      mutate(bikeway = if_else(is.na(bikeway),true = "No", bikeway))
    
    xlattribs <- lapply(
      seq_along(attribs),
      function(i,x,n) { 
        xx<-newXMLNode("attribute", attrs=c(name = n[[i]], class="java.lang.String"))
        xmlValue(xx)<-x[[i]]
        xx
      }, 
      x=attribs, 
     n=names(attribs))
    
   lattribs <- newXMLNode("attributes")
      addChildren(lattribs, xlattribs)  
      addChildren(xll, lattribs)
    
  #  addChildren(linksn, xll)
    return(xll)
  }
  
  #doc = newXMLDoc()
  #netn<-newXMLNode("network", doc = doc)
  
  #temp <- addMATSimNode(nodes_np[1,], 'node')
  #xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), x=this_node$x, y=this_node$y, z=this_node$z))# assign attribute list to attributes tag
  
  
  # Generating XML
  #nodesn <-newXMLNode("nodes")
  #echo('Starting to add nodes to XML\n')
  #for (i in 1:nrow(n_df)) {
  #  if(i %%50 == 0) printProgress(i, nrow(n_df), 'node')
  #  nodesn <- addMATSimNode(n_df[i,], nodesn)
  #}
  
  echo('Starting to write the XML\n')
  
  cat("<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE network SYSTEM \"http://www.matsim.org/files/dtd/network_v2.dtd\">\n
<network>\n
<nodes>\n",file=paste0(outputFileName,".xml"),append=FALSE)


  # addChildren(netn, nodesn)
  # linksn <-newXMLNode("links")
  # cat('\n')
  echo('Starting to add nodes to XML\n')
  for (i in 1:nrow(n_df)) {
    if(i %%50 == 0) printProgress(i, nrow(n_df), 'node')
    i <- 1
    this_node_xml <- addMATSimNode(n_df[i,])
    cat(saveXML(this_node_xml),# assign attribute list to attributes tag
        file=paste0(outputFileName,".xml"),append=TRUE)
    cat("\n",file=paste0(outputFileName,".xml"),append=TRUE)
  }
  
  cat("</nodes>\n",file=paste0(outputFileName,".xml"),append=TRUE)
  cat("<links>\n",file=paste0(outputFileName,".xml"),append=TRUE)
  
  echo('\n')
  echo('Starting to add links to XML\n')
  

  for (i in 1:nrow(l_df)) {
    if(i %%50 == 0) printProgress(i, nrow(l_df), 'link')
    
    this_link_xml <- addMATSimLink(l_df[i,])
    
    
    cat(saveXML(this_link_xml),
        file=paste0(outputFileName,".xml"),append=TRUE)
    cat("\n",file=paste0(outputFileName,".xml"),append=TRUE)
    # linksn <- addMATSimLink(l_df[i,], linksn)
  }
  
  cat("</links>\n",file=paste0(outputFileName,".xml"),append=TRUE)
  cat("</network>\n",file=paste0(outputFileName,".xml"),append=TRUE)
  
  #addChildren(netn, linksn)
  #cat('\n')
  #echo('Exporting the XML file\n')
  #xml_file  <- paste0('../outputs/outputNetworks/',outputFileName, '.xml')
  
  #cat(saveXML(doc, 
  #            prefix=paste0('<?xml version="1.0" encoding="utf-8"?>\n',
  #                          '<!DOCTYPE network SYSTEM "http://www.matsim.org/files/dtd/network_v2.dtd">\n')),
  #    file=xml_file)
}
