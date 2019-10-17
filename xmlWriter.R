 # I needed to change the function a bit to also read the attributes as characters
library(igraph)
library(raster)
library(sf)
library(XML)

extract_name <- "homeToWoolies"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"


links_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/links_new30.csv", sep = ""))

nodes_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/nodes_new30.csv", sep = ""))

network_tag <- newXMLNode("network")

nodes_tag <- newXMLNode("nodes", parent = network_tag)

for(i in 1:nrow(nodes_df)){
  
  newXMLNode("node", attrs = c(id=nodes_df$id[i], x=nodes_df$x[i], y=nodes_df$y[i], z="0"), "", parent = nodes_tag)

}


links_tag <- newXMLNode("links", parent = network_tag)

for(i in 1:nrow(links_df)){
  link_tag <- newXMLNode("link", attrs = c(id=links_df$id[i], from=links_df$from[i], to=links_df$to[i],
                                           length=links_df$length[i], capacity=links_df$capacity[i], freespeed=links_df$freespeed[i],
                                           permlanes=links_df$permlanes[i], oneway="1", modes=links_df$id[i], origid=""), 
                         "", parent = links_tag)
  
  attributes_tag <- newXMLNode("attributes",parent = link_tag)
  newXMLNode("attribute", attrs = c(name="type", class="java.lang.String"), links_df$highway[i], parent = attributes_tag)
  newXMLNode("attribute", attrs = c(name="bicycleInfrastructureSpeedFactor", class="java.lang.Double" ), "1.0", parent = attributes_tag)
}




saveXML(network_tag, "./test30.XML")


## generating an igraph 
#shp_graph <- igraph_generator(node_list = shp_node_edge[[2]], edge_list = shp_node_edge[[3]],  attribs_df = shp_node_edge[[5]])

#plot(shp_graph, vertex.label = NA, vertex.size = 0.5, vertex.size2 = 0.5, mark.col = "green",
#     main = "The converted igraph graph")

#write_graph(shp_graph, file = outputXml, "graphml")

