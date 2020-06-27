assignActivityAreasAndTravelModes <-function(censuscsv, vistacsv, matchcsv, outdir, outcsv, writeInterval) {

  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes
  
  suppressPackageStartupMessages(library(dplyr))
  suppressPackageStartupMessages(library(stringi))
  source('util.R', local=TRUE)
  
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
  
  nextModeAndSa1 <- function(fromSA1, toLocType, currentMode, allowModeChange) {
    if (is.na(currentMode) || is.null(currentMode) || allowModeChange) { # mode can change if last activity was home
      df<-findLocation(fromSA1, toLocType)
    } else {
      df<-findLocationKnownMode(fromSA1, toLocType, currentMode)
    }
    return(df)
  }
  
  # nextModeAndSa1WithReturn(20607113903, 20701115539, "education", "car", FALSE)
  nextModeAndSa1WithReturn <- function(homeSA1, fromSA1, toLocType, currentMode, allowModeChange) {
    df<-NULL
    returnProb <- 0
    for (i in 1:10){
      if (is.na(currentMode) || is.null(currentMode) || allowModeChange) { # mode can change if last activity was home
        df<-findLocation(fromSA1, toLocType)
      } else {
        df<-findLocationKnownMode(fromSA1, toLocType, currentMode)
      }
      if (length(df) > 1) {
        # df[2] = potential destination SA1, df[1] = potential travel mode
        returnProb <- getReturnProbability(homeSA1,df[2],df[1])
      }
      # cat(paste0("\ndf1: ",df[1]," df2: ",df[2],", returnProb: ",returnProb,"\n"))
      if (returnProb > 1) (return(df))
    }
    # cat(paste0("\nno suitable regions found, using one with a return probability of ",returnProb,"\n"))
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

  # set.seed(20200406) # for when we want to have the same LocationType each time
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
    mutate(ArrivingMode=NA) %>%
    mutate(Distance=NA)

  echo('Assigning home SA1 locations\n')
  plans[plans$SA1_MAINCODE_2016!="",]$SA1_MAINCODE_2016<-
    apply(plans[plans$SA1_MAINCODE_2016!="",], 1, function(x) {
    persons[persons$AgentId==x["AgentId"],]$SA1_MAINCODE_2016
  })

  echo('Assigning activities\' SA1s and travel modes (can take a while)\n')
  write.table(plans[FALSE,], file=outcsv, append=FALSE, row.names=FALSE, sep = ',')
  discarded<-persons[FALSE,]
  doutfile<-paste0(outdir, '/persons.discarded.csv')
  write.table(discarded, file=doutfile, append=FALSE, row.names=FALSE, sep = ',')
  wplans<-NULL
  # pp<-plans[1:95,] # just the first 10 plans
  pp<-plans
  i=0
  homeSA1=NA
  processed<-0; ndiscarded<-0
  # set.seed(20200406)
  while(i<nrow(pp)) {
    i<-i+1
    # cat(paste0(i,"\n"))
    startOfDay<- i==1 || (pp[i,]$PlanId != pp[i-1,]$PlanId && 
                          pp[i,]$LocationType=="home")
    endOfDay<- i==nrow(pp) || (pp[i,]$AgentId != pp[i+1,]$AgentId)
      
    if(startOfDay) {
      homeSA1<-pp[i,]$SA1_MAINCODE_2016 # used for calculating return probabilities
      # nothing to do since home SA1s are already assigned; just save and continue
      wplans<-rbind(wplans, pp[i,])
    } else {
      # changed pp[i,] to pp[i-1,] since it's the 2nd entry with a mode (1st has no arriving mode)
      allowModeChange<- !startOfDay && !endOfDay && pp[i-1,]$LocationType=="home" # allow mode change at home during the day
      # SA1_MAINCODE_2016 and ArrivingMode should be using the previous leg's value
      # modeAndSa1<-nextModeAndSa1(as.numeric(pp[i-1,]$SA1_MAINCODE_2016), pp[i,]$LocationType, pp[i-1,]$ArrivingMode, allowModeChange)
      
      # incorporating return propability into destination selection
      modeAndSa1<-nextModeAndSa1WithReturn(homeSA1,as.numeric(pp[i-1,]$SA1_MAINCODE_2016), pp[i,]$LocationType, pp[i-1,]$ArrivingMode, allowModeChange)
      if(!is.null(modeAndSa1)) {
        # assign the mode and SA1
        pp[i,]$ArrivingMode<-modeAndSa1[1]
        # Need to keep the home SA1
        if(pp[i,]$SA1_MAINCODE_2016 != homeSA1) {
          pp[i,]$SA1_MAINCODE_2016<-modeAndSa1[2]
        }
        # add in the distance between the regions
        pp[i,]$Distance <- calcDistance(pp[i-1,]$SA1_MAINCODE_2016,pp[i,]$SA1_MAINCODE_2016)
        # add it to our list
        wplans<-rbind(wplans, pp[i,])
      } else {
        # failed to find a suitable SA1/mode for this activity, so will just discard this person
        person<-persons[persons$AgentId==pp[i,]$AgentId,]
        discarded<-rbind(discarded,person)
        # mark all modes for this plan with 'x' (will delete these later)
        pp[pp$PlanId==pp[i,]$PlanId,]$ArrivingMode<-'x'
        # cat(paste0("\n","found an error at line ",i,"\n"))
        # move to the first row of the next plan
        i<-as.numeric(last(rownames(pp[pp$PlanId==pp[i,]$PlanId,])))
      }
    }
    # record progress for each person
    if(i==nrow(pp) || pp[i,]$AgentId != pp[i+1,]$AgentId) {
      processed<-processed+1
      if(is.null(modeAndSa1)) {
        printProgress(processed, 'x')
      } else {
        printProgress(processed, '.')
      }
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
  censuscsv<-'output/2.sample/sample.csv.gz'
  vistacsv<-'output/3.plan/plan.csv'
  matchcsv<-'output/4.match/match.csv.gz'
  outdir<-'output/5.locate'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  outcsv<-paste0(outdir,'/plan.csv')
  writeInterval <- 100 # write to file every so many plans
  
  assignActivityAreasAndTravelModes(censuscsv, vistacsv, matchcsv, outdir, outcsv, writeInterval)
  planToSpatial(read.csv("output/5.locate/plan.csv"),'output/5.locate/plan.sqlite')
  
  # only run if you have access to the full VISTA dataset
  # source('locateVISTA.R', local=TRUE)
}