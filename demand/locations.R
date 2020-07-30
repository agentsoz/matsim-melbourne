suppressPackageStartupMessages(library(sf)) # for spatial things
suppressPackageStartupMessages(library(dplyr)) # for manipulating data
suppressPackageStartupMessages(library(scales)) # for scaling datasets
suppressPackageStartupMessages(library(data.table)) # for sa1_main16 indexing for faster lookups

# Read in the distance matrix. This matrix is symmetric so it doesn't matter if
# you do lookups by column or row.
distanceMatrix <- readRDS(file="data/distanceMatrix.rds")

# Some SA1s ended up snapping their centroid to the same node in the road
# network so we need to use an index.
distanceMatrixIndex <- read.csv("data/distanceMatrixIndex.csv")
distanceMatrixIndex_dt<-data.table(distanceMatrixIndex)
setkey(distanceMatrixIndex_dt, sa1_maincode_2016)

# Reading in the attributed SA1 regions. I'm removing the geometry since it
# won't be used here. Joining with the distance matrix index so the regions are
# in the correct order.
SA1_attributed <- inner_join(distanceMatrixIndex,
                             st_read("data/SA1attributed.sqlite", quiet=TRUE) %>%
                               st_drop_geometry(),
                             by="sa1_maincode_2016")
SA1_attributed_dt<-data.table(SA1_attributed)
setkey(SA1_attributed_dt,sa1_maincode_2016)

# Reading in the addresses. I'm removing the geometry and converting it to X,Y.
# These coordinates are in EPSG:28355, which is a projected coordinate system.
addresses <- st_read("data/addresses.sqlite", quiet=TRUE)
addresses <- cbind(st_drop_geometry(addresses),
                   st_coordinates(addresses))
addresses_dt<-data.table(addresses)
setkey(addresses_dt, sa1_maincode_2016)

# Need the x and y locations of the centroids
sa1_centroids <- st_read("data/SA1centroids.sqlite", quiet=TRUE) %>%
  st_drop_geometry()
sa1_centroids_dt<-data.table(sa1_centroids)
setkey(sa1_centroids_dt, sa1_maincode_2016)



# This returns a dataframe with possible SA1_ids and their probabilities.
# There are three probabilites returned:
# 1: distProb. The probability of choosing a destination based on distance.
# 2: attractProb. The probability of choosing a destination based on that
#                 destination's attractiveness.
# 3: combinedProb. The combined probability of choosing a destination based on
#                  distance and destination attractiveness. Distance is
#                  currently weighted 4x higher since distance probability is a
#                  lot more spread out.
# calculateProbabilities(20604112202,"commercial","car")
calculateProbabilities <- function(SA1_id,destination_category,mode) {
  # SA1_id=20604112202
  # destination_category="commercial"
  # mode="car"
  
  #index <- distanceMatrixIndex %>%
  #  filter(sa1_main16 == SA1_id) %>%
  index <- distanceMatrixIndex_dt[.(as.numeric(SA1_id))] %>%
    pull(index)
  distances <-data.frame(index=1:nrow(distanceMatrix),
                         distance=distanceMatrix[index,]) %>%
    inner_join(distanceMatrixIndex, by=c("index"="index")) %>%
    pull(distance)
  
  modeMean <- NULL
  modeSD <- NULL
  filteredset<-SA1_attributed_dt[.(as.numeric(SA1_id))]
  if(mode=="walk"){
    modeMean <- filteredset$walk_mean
    modeSD <- filteredset$walk_sd
  } else if(mode=="car"){
    modeMean <- filteredset$car_mean
    modeSD <- filteredset$car_sd
  } else if(mode=="pt"){
    modeMean <- filteredset$pt_mean
    modeSD <- filteredset$pt_sd
  } else if(mode=="bike"){
    modeMean <- filteredset$bike_mean
    modeSD <- filteredset$bike_sd
  }
  
  attractionProbability <- SA1_attributed[,match(destination_category,colnames(SA1_attributed))]
  # unneeded now since probabilities are already rescaled
  # attractionProbDensity <- SA1_attributed[,match(destination_category,colnames(SA1_attributed))] %>%
  #   rescale(to=c(0,1))
  # attractionProbability <- attractionProbDensity/sum(attractionProbDensity, na.rm=TRUE) #normalising here so the sum of the probabilities equals 1

  #distProbDensity <- dnorm(distances,mean=modeMean,sd=modeSD)
  #distProbDensity[is.na(attractionProbDensity)] <- NA # We aren't considering regions with no valid destination types
  #distProbability <- distProbDensity/sum(distProbDensity, na.rm=TRUE) # normalising here so the sum of the probabilities equals 1

  # alternative way to compute distance probabilities for SA1s clipped to a much smaller set
  # within 2 standard deviations of the mode mean - Dhi, 21/Feb/20
  dd<-distances 
  dd[dd<(modeMean-(2*modeSD)) | (dd>modeMean+(2*modeSD))]<- NA # discard anything >2SDs either side
  dd[is.na(attractionProbability)] <- NA # discard regions with no valid destination types
  if (sum(!is.na(dd)) == 0) return(NULL) # return NULL if nothing is left
  if(sum(!is.na(dd)) == 1) { # if only one possible destination
    dd[!is.na(dd)]<-1
  } else {
    #  changed this to a z-score based method - Alan, 22/Jun/20
    dd<-(2-abs((dd-modeMean)/modeSD))
    # dd<-(max(dd, na.rm=TRUE)-dd)/max(dd, na.rm=TRUE) # prob of visiting based on distance
    dd<-dd/sum(dd, na.rm=TRUE)
  }
  distProbability<-dd

  # distComparison <- data.frame(sa1=SA1_attributed$sa1_main16,
  #                              distances,
  #                              dd,
  #                              dhi = (max(dd, na.rm = TRUE) - dd) / max(dd, na.rm = TRUE),
  #                              z_score = 2 - abs((dd - modeMean) / modeSD),
  #                              norm = dnorm(dd, mean = modeMean, sd = modeSD)
  # )
  # distComparison <- distComparison %>%
  #   mutate(dhi = dhi / sum(distComparison$dhi,na.rm=TRUE),
  #          z_score = z_score / sum(distComparison$z_score,na.rm=TRUE),
  #          norm = norm / sum(distComparison$norm,na.rm=TRUE))
  
  # I've set distance probability to 4x more important than destination 
  # attraction. This is arbitrary.
  multiplier=1 #  changed this from 4 to 1 - Dhi, 21/Feb/20
  combinedDensity <- multiplier*distProbability+attractionProbability
  combinedProbability <- combinedDensity/sum(combinedDensity, na.rm=TRUE) # normalising here so the sum of the probabilities equals 1
  probabilityDF <- data.frame(sa1_maincode_2016=SA1_attributed$sa1_maincode_2016,
                              distProb=distProbability,
                              attractProb=attractionProbability,
                              combinedProb=combinedProbability) %>%
                              filter(!is.na(combinedProb))
  return(probabilityDF)
}

# This will be made more detailed later, and actually take destination category
# into account.
# chooseMode(20604112202,"commercial")
chooseMode <- function(SA1_id,destination_category) {
  # SA1_id=20604112202
  # destination_category="commercial"

  # a list of the four mode probabilities for this SA1
  modeProbability <- SA1_attributed_dt[.(as.numeric(SA1_id))] %>%
    dplyr::select(walk_proportion:car_proportion) %>%
    unlist()
  
  modeProbabilityDF <- data.frame(mode=c("walk","bike","pt","car"),
                                  modeProbability,
                                  stringsAsFactors=FALSE)
  mode<-sample(modeProbabilityDF$mode, size=1,
                prob=modeProbabilityDF$modeProbability)
  return(mode)
}

# Assuming the transport mode is restricted, this will find a destination SA1
# findLocationKnownMode(20604112202,"commercial","car")
findLocationKnownMode <- function(SA1_id,destination_category,mode) {
  #cat(paste0("\nSA1_id=[",SA1_id,"] destination_category=[",destination_category,"] mode=[",mode,"]\n"))
  probabilityDF <- calculateProbabilities(SA1_id,destination_category,mode)
  #cat(str(probabilityDF))
  if(is.null(probabilityDF)) return(NULL)
  if(length(probabilityDF$sa1_maincode_2016)==1) {
    destinationSA1<-probabilityDF$sa1_maincode_2016
  } else {
    destinationSA1 <- sample(probabilityDF$sa1_maincode_2016, size=1,
                           prob=probabilityDF$combinedProb)
  }
  return(c(mode,destinationSA1))
}

# Find a destination SA1 given a source SA1 and destination category
# findLocation(20604112202,"commercial")
findLocation <- function(SA1_id,destination_category) {
  return(findLocationKnownMode(SA1_id,destination_category,chooseMode(SA1_id,destination_category)))
}


# Determine the chances of returning home for a given destination and transport mode
# getReturnProbability(20604112202,20604112210,"car")
getReturnProbability <- function(source_SA1,destination_SA1,mode) {
  # source_SA1=20607113903
  # destination_SA1=20803119308
  # mode="car"
  probabilityDF <- calculateProbabilities(destination_SA1,"home",mode)
  sourceProb <- probabilityDF %>%
    filter(sa1_maincode_2016==source_SA1) %>%
    pull(distProb) # Note that we only use the distance probability here, not
                   # the combined probability.
  # sourceProb only returns regions within 2sd of the mean, so if the 
  # destination is too far away, we need to manually set the probability to zero
  if(length(sourceProb)==0) (sourceProb=0)
  sourceProb <- sourceProb*nrow(probabilityDF)
  # multiplying by the number of possible regions to give the proportion of
  # choosing that region, where > 1 is more likely than choosing the region
  # completely at random.
  # The idea being that a value > 1 means that it's suitable.
  return(sourceProb)
}

# Assign coordinates to a location within a specified SA1 with a specified category 
# getAddressCoordinates(20604112202,"commercial")
# getAddressCoordinates(21005144422,"home")

getAddressCoordinates <- function(SA1_id,destination_category) {
  # SA1_id=21005144422
  # destination_category="home"
  #potentialAddresses <- addresses %>%
  #  filter(sa1_main16==SA1_id & category==destination_category) %>%
  #  dplyr::mutate(id=row_number())
  potentialAddresses <- addresses_dt[.(SA1_id),]
  potentialAddresses <- potentialAddresses[potentialAddresses$category==destination_category,] %>%
    dplyr::mutate(id=row_number())
  if(nrow(potentialAddresses)==0) {
    # if no suitable destinations are found, default to the centroid of the SA1 region
    return(sa1_centroids_dt[.(SA1_id), .(x,y)]%>%unlist())
  }
  # return(NULL);
  address_id <- sample(potentialAddresses$id, size=1,
                    prob=potentialAddresses$count)
  address_coordinates <- potentialAddresses %>%
    filter(id==address_id) %>%
    dplyr::select(X,Y) %>%
    unlist()
  return(address_coordinates)
}

# Returns the distance between two regions
calcDistance <- function(from_sa1,to_sa1) {
  index1 <- distanceMatrixIndex_dt[.(as.numeric(from_sa1))] %>%
    pull(index)
  index2 <- distanceMatrixIndex_dt[.(as.numeric(to_sa1))] %>%
    pull(index)
  return(distanceMatrix[index1,index2])
}

# Takes a plan with completed SA1 locations and turns them into a series of
# lines where the non-spatial data is for the destination.
# Need to supply a plan and an output file location. I recommend using the 
# .sqlite extension instead of shapefiles.
# planToSpatial(read.csv("output/5.locate/plan.csv"),'output/5.locate/plan.sqlite')
planToSpatial <- function(pp,fileLocation) {
  
  ppp <- pp %>%
    mutate(SA1_MAINCODE_2016=as.numeric(SA1_MAINCODE_2016)) %>%
    # Need the previous SA1 region
    mutate(prev_sa1=lag(SA1_MAINCODE_2016)) %>%
    # Ignore the first entries for a person as they won't have a valid prev SA1
    filter(!is.na(ArrivingMode)) %>%
    inner_join(sa1_centroids, by=c("prev_sa1"="sa1_maincode_2016")) %>%
    inner_join(sa1_centroids, by=c("SA1_MAINCODE_2016"="sa1_maincode_2016")) %>%
    # turn the two SA1 centroids into line geometry
    mutate(GEOMETRY=paste0("LINESTRING(",x.x," ",y.x,",",x.y," ",y.y,")")) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355) %>%
    dplyr::select(PlanId,Activity,StartBin,EndBin,AgentId,SA1_MAINCODE_2016,
                  LocationType,ArrivingMode,Distance)
  # Write the spatial dataframe to file
  st_write(ppp,fileLocation,delete_dsn=TRUE)
}

# Takes a plan with places and turns them into a series of
# lines where the non-spatial data is for the destination.
# Need to supply a plan and an output file location. I recommend using the 
# .sqlite extension instead of shapefiles.
# placeToSpatial(read.csv("output/6.place/plan.csv"),'output/6.place/plan.sqlite')
placeToSpatial <- function(pp,fileLocation) {
  # pp=read.csv("output/6.place/plan.csv")
  # fileLocation='output/6.place/plan.sqlite'
  ppp <- pp %>%
    # Ignore the first entries for a person as they won't have a valid previous location
    # turn the two SA1 centroids into line geometry
    mutate(GEOMETRY=paste0("LINESTRING(",lag(x)," ",lag(y),",",x," ",y,")")) %>%
    filter(!is.na(ArrivingMode)) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355) # %>%
    # some legs end up at the same address, this would remove them
    # filter(st_is_valid(.))
  # Write the spatial dataframe to file
  st_write(ppp,fileLocation,delete_layer=TRUE,layer="lines")
  
  ppp2 <- pp %>%
    # Ignore the first entries for a person as they won't have a valid previous location
    # turn the two SA1 centroids into line geometry
    mutate(GEOMETRY=paste0("POINT(",x," ",y,")")) %>%
    filter(!is.na(ArrivingMode)) %>%
    st_as_sf(wkt = "GEOMETRY", crs = 28355)
  st_write(ppp2,fileLocation,delete_layer=TRUE,layer="points")
}

# EXAMPLES

# A dataframe of suitable homes for each SA1 along with the total number of 
# unique addresses.
#suitableHomes <- addresses %>%
#  filter(category=="home") %>%
#  group_by(sa1_main16) %>%
#  summarise(count=sum(count)) %>%
#  ungroup()

# Here, we're finding a commercial destination starting in SA1 20604112202
#test <- findLocation(20604112202,"commercial")

# We then try to find the probability of returning to this destination.
# Could do a loop with findLocation to iterate until this is > 1.
#returnProb <- getReturnProbability(20604112202,test[2],"home",test[1])

# Assign our locations coordinates. This will break if there's no addresses
# for your specified category within the SA1 region!!!
#originCoordinates <- getAddressCoordinates(20604112202,"home")
#destinationCoordinates <- getAddressCoordinates(test[2],"commercial")



