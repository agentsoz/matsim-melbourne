library(XML)
xml <- xmlTree()


extract_name <- "carltonSingleBlock"
oneDriveURL <- "../../../../OneDrive/OneDrive - RMIT University"
# oneDriveURL <- "../../../OneDrive"


links_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/links_new3.csv", sep = ""))

nodes_df <- read.csv(paste(oneDriveURL, "/Data/processedSpatial/", extract_name, "/nodes_new3.csv", sep = ""))

# names(xml)
xml$addTag("network", close=FALSE)
xml$addTag("nodes", close=FALSE)

for (i in 1:nrow(nodes_df)) {
  xml$addTag("node", attrs = c(id=nodes_df$id[i], x=nodes_df$x[i], y=nodes_df$y[i], z="0"))
}
xml$closeTag()

xml$addTag("links", close=FALSE)
for(i in 1:nrow(links_df)){
  xml$addTag("link", attrs = c(id=links_df$id[i], from=links_df$from[i], to=links_df$to[i],
                                           length=links_df$length[i], capacity=links_df$capacity[i], freespeed=links_df$freespeed[i],
                                           permlanes=links_df$permlanes[i], oneway="1", modes=links_df$id[i], origid=""))
}
xml$closeTag()
xml$closeTag()

saveXML(xml, "./test100.XML")
