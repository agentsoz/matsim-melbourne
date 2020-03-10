assignLocationsToActivities <- function(plancsv, outcsv, writeInterval) {

  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes
  
  source('util.R', local=TRUE)
  
  echo("Loading locations database\n")
  source('locations.R')
  
  # Read in the plans
  gz1<-gzfile(plancsv, 'rt')
  echo(paste0('Loading VISTA-like plans from ', plancsv, '\n'))
  plans<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  echo('Assigning coordinates to activities in SA1s (can take a while)\n')
  pp<-plans
  pp$x<-0; pp$y<-0
  wplans<-pp[FALSE,]
  write.table(wplans, file=outcsv, append=FALSE, row.names=FALSE, sep = ',')
  processed<-0
  i=0
  homexy<-NA; workxy<-NA
  while(i<nrow(pp)) {
    i<-i+1
    if(is.na(homexy) && pp[i,]$LocationType=="home") {
      homexy <- getAddressCoordinates(as.numeric(pp[i,]$SA1_MAINCODE_2016), pp[i,]$LocationType)
    }
    if(is.na(workxy) && pp[i,]$LocationType=="work") {
      workxy <- getAddressCoordinates(as.numeric(pp[i,]$SA1_MAINCODE_2016), pp[i,]$LocationType)
    }
    if(pp[i,]$LocationType=="home") {
      pp[i,]$x <- homexy[1]
      pp[i,]$y <- homexy[2]
    } else if(pp[i,]$LocationType=="work") {
      pp[i,]$x <- workxy[1]
      pp[i,]$y <- workxy[2]
    } else {
      xy<-getAddressCoordinates(as.numeric(pp[i,]$SA1_MAINCODE_2016), pp[i,]$LocationType)
      pp[i,]$x<-xy[1]
      pp[i,]$y<-xy[2]
    }
    wplans<-rbind(wplans, pp[i,])
    # record progress for each person
    if(i==nrow(pp) || pp[i,]$AgentId != pp[i+1,]$AgentId) {
      processed<-processed+1
      printProgress(processed, '.')
    }
    # write it out at regular intervals
    if (processed%%writeInterval==0 || i==nrow(pp)) {
      write.table(wplans, file=outcsv, append=TRUE, row.names=FALSE, col.names=FALSE, sep = ',')
      wplans<-wplans[FALSE,] # remove all rows
    }
  }
  cat('\n')
  echo(paste0('Wrote ',processed,' plans to ', outcsv , '\n'))
}


# example usage
runexample<- function() {
  plancsv<-'output/5.locate/plan.csv'
  outdir<-'output/6.place'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  outcsv<-paste0(outdir,'/plan.csv')
  writeInterval <- 100 # write to file every so many plans
  
  assignLocationsToActivities(plancsv, outcsv, writeInterval)
}