assignActivityAreasAndTravelModes <-function(censuscsv, vistacsv, matchcsv, outdir, outcsv, writeInterval) {

  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes
  
  suppressPackageStartupMessages(library(dplyr))
  suppressPackageStartupMessages(library(stringi))

  source('util.R')
  
  echo("Loading locations database\n")
  source('locations.R')
  
  # internal function to replace activity tags with location tags
  replaceActivityWithLocationTags<-function (tc) {
    # convert activity-based tags to location-based tags (from SA1_attributes.sqlite) being:
    # Home* -> home
    # Work -> work
    # Study -> education
    # Shop -> commercial
    # Personal -> commercial
    # Social/Recreational -> commercial,park
    # Pickup/Dropoff/Deliver -> work,education,commercial,park (but not home)
    # Other -> work,education,commercial,park (but not home)
    tc<-replace(tc, tc=="Home", "home")
    tc<-replace(tc, tc=="Home Morning", "home")
    tc<-replace(tc, tc=="Home Daytime", "home")
    tc<-replace(tc, tc=="Home Night", "home")
    tc<-replace(tc, tc=="Work", "work")
    tc<-replace(tc, tc=="Study", "education")
    tc<-replace(tc, tc=="Shop", "commercial")
    tc<-replace(tc, tc=="Personal", "commercial")
    # KISS: replace 'With Someone' with Other for now
    tc<-replace(tc, tc=="With Someone", "Other")
    # KISS: assuming Social/Recreational is equally likely to occur in commercial or park locations ; improve later on
    tc<-as.vector(sapply(tc, function(x) replace(x, x=="Social/Recreational", sample(c("commercial","park"), 1))))
    # KISS: assuming Pickup/Dropoff/Deliver is equally likely to occur in any location; improve later on
    tc<-as.vector(sapply(tc, function(x) replace(x, x=="Pickup/Dropoff/Deliver", sample(c("work","education","commercial","park"), 1))))
    # KISS: assuming Other is equally likely to occur in any location; improve later on; improve later on
    tc<-as.vector(sapply(tc, function(x) replace(x, x=="Other", sample(c("work","education","commercial","park"), 1))))
    return(tc)
  }
  
  nextModeAndSa1 <- function(fromSA1, toLocType, currentMode) {
    if (is.na(currentMode) || is.null(currentMode) || toLocType=="home") { # mode can change if last activity was home
      df<-findLocation(fromSA1, toLocType)
    } else {
      df<-findLocationKnownMode(fromSA1, toLocType, currentMode)
    }
    return(df)
  }
  
  # Read in the persons
  gz1<-gzfile(censuscsv, 'rt')
  echo(paste0('Loading ABS census-like persons from ', censuscsv, '\n'))
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)

  
  # Read in the plans
  gz1<-gzfile(vistacsv, 'rt')
  echo(paste0('Loading VISTA-like plans from ', vistacsv, '\n'))
  origplans<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  # Read in the matches
  gz1<-gzfile(matchcsv, 'rt')
  echo(paste0('Loading matched plans to persons from ', matchcsv, '\n'))
  matches<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)

  
  plans<- origplans %>%
    # Remove all plans that are not matched
    filter(PlanId %in% matches$PlanId) %>% 
    # Assign matched PersonId (very fast since we assume row number equals Id number)
    mutate(AgentId = matches[as.numeric(PlanId),]$AgentId) %>%
    # Tag home SA1 with PersonId
    mutate(SA1_MAINCODE_2016 = ifelse(grepl("Home", Activity), AgentId, "")) %>%
    # Add location type tag
    mutate(LocationType=replaceActivityWithLocationTags(Activity)) %>%
    # Add a column for mode taken from last activity to this
    mutate(ArrivingMode=NA)

  echo('Assigning home SA1 locations\n')
  plans[plans$SA1_MAINCODE_2016!="",]$SA1_MAINCODE_2016<-
    apply(plans[plans$SA1_MAINCODE_2016!="",], 1, function(x) {
    persons[persons$AgentId==x["AgentId"],]$SA1_MAINCODE_2016
  })

  echo('Assigning activities\' SA1s and travel modes (can take a while)\n')
  wplans<-plans[1,]
  write.table(wplans, file=outcsv, append=FALSE, row.names=FALSE, sep = ',')
  discarded<-persons[FALSE,]
  doutfile<-paste0(outdir, '/persons.discarded.csv')
  write.table(discarded, file=doutfile, append=FALSE, row.names=FALSE, sep = ',')
  pp<-plans
  i=1
  processed<-0; ndiscarded<-0
  while(i<nrow(pp)) {
    i<-i+1
    # skip home start locations as we have already assigned their SA1
    if(pp[i,]$LocationType=="home" && pp[i,]$PlanId != pp[i-1,]$PlanId) next 
    modeAndSa1<-nextModeAndSa1(as.numeric(pp[i-1,]$SA1_MAINCODE_2016), pp[i,]$LocationType, pp[i-1,]$ArrivingMode)
    if(!is.null(modeAndSa1)) {
      # assign the mode and SA1
      pp[i,]$ArrivingMode<-ifelse(is.null(modeAndSa1),NA,modeAndSa1[1])
      pp[i,]$SA1_MAINCODE_2016<-ifelse(is.null(modeAndSa1),NA,modeAndSa1[2])
      if(i==nrow(pp) || pp[i,]$PlanId != pp[i+1,]$PlanId) {
        processed<-processed+1
        printProgress(processed, '.')
      }
      # add it to our list
      wplans<-rbind(wplans, pp[i,])
    } else {
      # failed to find a suitable SA1/mode for this activity, so will just discard this person
      person<-persons[persons$AgentId==pp[i,]$AgentId,]
      discarded<-rbind(discarded,person)
      # make all modes for this plan with 'x' (will delete these later)
      pp[pp$PlanId==pp[i,]$PlanId,]$ArrivingMode<-'x'
      # move to the first rown of the next plan
      i<-as.numeric(rownames(last(pp[pp$PlanId==pp[i,]$PlanId,])))
      # report error
      processed<-processed+1
      printProgress(processed, 'x')
    }
    # write it out at regular intervals
    if (processed%%writeInterval==0 || i==nrow(pp)) {
      write.table(wplans, file=outcsv, append=TRUE, row.names=FALSE, col.names=FALSE, sep = ',')
      wplans<-wplans[FALSE,] # remove all rows
      if(nrow(discarded)>0) {
        ndiscarded<-ndiscarded + nrow(discarded)
        write.table(discarded, file=doutfile, append=TRUE, row.names=FALSE, col.names=FALSE, sep = ',')
        discarded<-discarded[FALSE,]
      }
    }
  }
  cat('\n')
  echo(paste0('Wrote ',(processed-ndiscarded),' plans to ', outcsv , '\n'))
  echo(paste0('Wrote ',ndiscarded,' discarded persons to ', doutfile , '\n'))
  
}

# example usage
runexample<- function() {
  censuscsv<-'output/2.sample/sample.0.1.csv.gz'
  vistacsv<-'output/3.plan/plan.5000.csv'
  matchcsv<-'output/4.match/match.csv.gz'
  outdir<-'output/5.locate'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  outcsv<-paste0(outdir,'/plan.csv')
  writeInterval <- 100 # write to file every so many plans
  
  assignActivityAreasAndTravelModes(censuscsv, vistacsv, matchcsv, outdir, outcsv, writeInterval)
}