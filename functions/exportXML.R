
exportXML <- function(l_df, n_df, outputFileName = "outputSQlite"){
  
  addMATSimNode <- function(this_node, nodesn){
    xnn<-newXMLNode("node", attrs=c(id=as.character(this_node$id), x=this_node$x, y=this_node$y, z=this_node$z))# assign attribute list to attributes tag
    addChildren(nodesn,xnn) 
    return(nodesn)
  }
  
  addMATSimLink <- function(this_link, linksn){
    
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
    
    addChildren(linksn, xll)
    return(linksn)
  }
  doc = newXMLDoc()
  netn<-newXMLNode("network", doc = doc)
  
  # Generating XML
  nodesn <-newXMLNode("nodes")
  echo('Starting to add nodes to XML\n')
  for (i in 1:nrow(n_df)) {
    if(i %%50 == 0) printProgress(i, nrow(n_df), 'node')
    nodesn <- addMATSimNode(n_df[i,], nodesn)
  }
  
  addChildren(netn, nodesn)
  
  linksn <-newXMLNode("links")
  for (i in 1:nrow(l_df)) {
    if(i %%10 == 0) printProgress(i, nrow(l_df), 'link')
    linksn <- addMATSimLink(l_df[i,], linksn)
  }
  addChildren(netn, linksn)
  
  xml_file  <- paste0('../outputs/outputNetworks/',outputFileName, '.xml')
  
  cat(saveXML(doc, 
              prefix=paste0('<?xml version="1.0" encoding="utf-8"?>\n',
                            '<!DOCTYPE network SYSTEM "http://www.matsim.org/files/dtd/network_v2.dtd">\n')),
      file=xml_file)
}
