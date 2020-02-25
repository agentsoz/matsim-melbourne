# Usage example:
# makeMATSimMelbournePopulation(0.0001, "mel_0.1") # build a 0.1% sample population for Melbourne
#
makeMATSimMelbournePopulation<-function(sampleSize, outdir, outfileprefix) {

  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes

  # Function to pre-process some data; need only be run once
  setup<-function(setupDir) {

    dir.create(setupDir, showWarnings = FALSE)

    # Logging function
    echo<- function(msg) {
      cat(paste0(as.character(Sys.time()), ' | ', msg))
    }
    if (!file.exists('data/VISTA_12_18_CSV.zip.dir/T_VISTA1218_V1.csv')) {
      echo(paste0('Some required files are missing in the ./data directory. ',
                  'Please see ./data/README.md\n'))
      return(FALSE)
    }

    # Extract VISTA activities and save separately into weekday and weekend activities
    vista_csv <- 'data/VISTA_12_18_CSV.zip.dir/T_VISTA1218_V1.csv'
    out_weekday_activities_csv_gz <- paste0(setupDir,'/vista_2012_18_extracted_activities_weekday.csv.gz')
    out_weekend_activities_csv_gz <- paste0(setupDir,'/vista_2012_18_extracted_activities_weekend.csv.gz')
    echo(paste0('Extracting VISTA weekday/end activities from ', vista_csv, ' (can take a while)\n'))
    extract_and_write_activities_from(vista_csv, out_weekday_activities_csv_gz, out_weekend_activities_csv_gz)
    echo(paste0('Wrote ', out_weekday_activities_csv_gz, ' and ', out_weekend_activities_csv_gz,'\n'))

    # Simplify some activitiy classes to activity groups
    echo(paste0('Grouping some VISTA activities\n'))
    simplify_activities_and_create_groups(out_weekday_activities_csv_gz)
    echo(paste0('Updated ', out_weekday_activities_csv_gz,'\n'))
    simplify_activities_and_create_groups(out_weekend_activities_csv_gz)
    echo(paste0('Updated ', out_weekend_activities_csv_gz,'\n'))

    # Write out the activity probabilitities by time bins
    binsize<-48 # 30-min bins
    echo(paste0('Extracting VISTA weekday/end activities times into ',binsize,' bins (can take a while)\n'))
    out_weekday_activities_time_bins_csv_gz<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday_time_bins.csv.gz')
    out_weekend_activities_time_bins_csv_gz<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekend_time_bins.csv.gz')
    extract_and_write_activities_time_bins(
      out_weekday_activities_csv_gz,
      out_weekday_activities_time_bins_csv_gz,
      binsize)
    extract_and_write_activities_time_bins(
      out_weekend_activities_csv_gz,
      out_weekend_activities_time_bins_csv_gz,
      binsize)
    echo(paste0('Wrote ', out_weekday_activities_time_bins_csv_gz, ' and ', out_weekend_activities_time_bins_csv_gz,'\n'))

    # Create markov chain model for trip chains
    prefix<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday')
    infile<-paste0(prefix,'.csv.gz')
    outfile<-paste0(prefix,'_markov_chain_model.rds')
    pdffile<-paste0(prefix,'_markov_chain_model.pdf')

    echo(paste0('Generating markov chain model of VISTA activities from ', infile, ' (can take a while)\n'))
    mc<-create_markov_chain_model('Weekday Activities',infile)
    saveRDS(mc, file = outfile)
    pdf(pdffile,width=8.5,height=8.5, paper="special")
    plot(mc,col=heat.colors(20))
    graphics.off()
    echo(paste0('Wrote markov chain model to ', outfile, '\n'))
    echo(paste0('Wrote model visualisation to ', pdffile, '\n'))
    echo('Setup complete\n')
    return(TRUE)
  }

  selectIndexFromProbabilities <-function(vv) {
    vv<-vv/sum(vv) # normalise to 1
    v<-data.frame(t(apply(vv,1,cumsum))) # cumulative sum to 1
    roll<-runif(1)
    select<-match(TRUE,v>roll) # pick the first col that is higher than the dice roll
    return(select)
  }

  toHHMMSS <- function(secs) {
    h<-secs %/% (60*60)
    m<-(secs - (h*60*60)) %/% 60
    s<-secs - (h*60*60) - (m*60)
    hhmmss<-paste0(str_pad(h,2,pad="0"),":",
                   str_pad(m,2,pad="0"),":",
                   str_pad(s,2,pad="0"))
    return(hhmmss)
  }

  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))
  }


  printProgress<-function(row, char) {
    if((row-1)%%100==0) echo('')
    cat(char)
    if(row%%10==0) cat('|')
    if(row%%100==0) cat(paste0(' ', row,'\n'))
  }


  createActivitiesAndLegs <-function(mc, bins, person) {

    nextActAndLocType <- function(lastActTag) {
      if (is.null(lastActTag)) {
        actTag<-"Home Morning"
      } else {
        actTag<-rmarkovchain(n=1,mc,t0=lastActTag)
        while(actTag=="With Someone" # don't care about secondary persons
              || actTag=="Mode Change" # ignore mode change for now, improve later
              #      || (actTag=="Home Daytime" && lastTag=="Home Morning") # remove successive home activities
              #      || (actTag=="Home Daytime" && lastTag=="Home Daytime") # remove successive home activities
              #      || (actTag=="Home Night" && lastTag=="Home Daytime") # remove successive home activities
        ) {
          actTag<-rmarkovchain(n=1,mc,t0=lastActTag)
        }
      }
      locTag<-replaceActivityWithLocationTags(actTag)
      return(list(actTag, locTag))
    }

    nextModeAndSa1 <- function(fromSA1, toLocType, currentMode) {
      if (is.null(currentMode) || toLocType=="home") { # mode can change if last activity was home
        df<-findLocation(fromSA1, toLocType)
      } else {
        df<-findLocationKnownMode(fromSA1, toLocType, mode)
      }
      return(df)
    }

    sampleStartTimeInMinsFromTimeBins<-function(bins, actTag) {
      probs<-bins[bins$Activity.Group==actTag & bins$Activity.Stat=="Act.Start.Time.Prob",]
      probs<-probs[3:length(probs)]
      select<-selectIndexFromProbabilities(probs)
      mins<-60*24*((select-1)/length(probs))
      binSizeInMins<-floor(60*24)/length(probs)
      actTime<-mins+sample(1:binSizeInMins, 1)
      return(actTime)
    }

    sampleDurationInMinsFromTimeBins<-function(bins, actTag, startTimeInMins) {
      means<-bins[bins$Activity.Group==actTag & bins$Activity.Stat=="Act.Duration.Mins.Mean",]
      sigmas<-bins[bins$Activity.Group==actTag & bins$Activity.Stat=="Act.Duration.Mins.Sigma",]
      duration<-0
      binLength<-length(means)-2
      if(length(means)>3 && length(sigmas)>3) {
        means<-means[,3:length(means)]
        sigmas<-sigmas[,3:length(sigmas)]
        binIndex<-1+startTimeInMins%/%length(means)
        binIndex<-min(max(0,binIndex), binLength) # FIXME: startTimeInMins is sometimes out of range
        mean<-means[1,binIndex]
        sigma<-sigmas[1,binIndex]
        duration<-abs(round(rnorm(1,mean,sigma))) # WARNING: taking abs will change the distribution
      }
      return(duration)
    }

    # determine  home SA1 and coordinates
    home_sa1<-as.character(person$SA1_MAINCODE_2016)
    home_xy<-getAddressCoordinates(as.numeric(home_sa1),"home")
    if(is.null(home_xy)) {
      # can be NULL sometimes if type of location required for some activiy cannot be found in given SA1
      return(NULL) # cannot continue without a home location
    }

    # data frames for storing this person's activities and connecting legs
    acts<-data.frame(act_id=NA, act_type=NA, sa1=NA, x=NA, y=NA, loc_type=NA,
                     start_min=NA, end_min=NA, start_hhmmss=NA, end_hhmmss=NA)
    legs<-data.frame(origin_act_id=NA,mode=NA,dest_act_id=NA)

    # Start at home
    r=1
    acts[r,]$act_id<-r
    acts[r,]$act_type<-"Home Morning"
    acts[r,]$loc_type<-"home"
    acts[r,]$sa1<-home_sa1
    acts[r,]$x<-home_xy[1]
    acts[r,]$y<-home_xy[2]
    acts[r,]$start_min<-0
    acts[r,]$end_min<-acts[r,]$start_min + sampleDurationInMinsFromTimeBins(bins, acts[r,]$act_type, acts[r,]$start_min)

    mode<-NULL # current transport mode
    tries<-0
    while(r==0 || acts[r,]$act_type != "Home Night") {
      r<-r+1
      if(r==1) {
        # resample the end time of the Home Morning activity;
        # we can end up here if we were unable to sequence subsequent activities after several tries
        acts[r,]$end_min<-acts[r,]$start_min + sampleDurationInMinsFromTimeBins(bins, acts[r,]$act_type, acts[r,]$start_min)
        next
      }
      acts[r,]$act_id<-r
      df<-nextActAndLocType(acts[r-1,]$act_type)
      acts[r,]$act_type<-df[[1]]
      acts[r,]$loc_type<-df[[2]]
      #cat(paste0("\n1 r=",r," sa=",acts[r-1,]$sa1, " loc=", acts[r,]$loc_type, " mode=[", mode, "]"))
      modeAndSa1<-nextModeAndSa1(acts[r-1,]$sa1, acts[r,]$loc_type, mode)
      if(is.null(modeAndSa1)) {
        mode<-NULL;
        acts[r,]$sa1<-NULL
      } else {
        mode<-modeAndSa1[1]
        acts[r,]$sa1<-modeAndSa1[2]
      }
      acts[r,]$x<-0
      acts[r,]$y<-0
      acts[r,]$start_min<-acts[r-1,]$end_min + sample(1:(ncol(bins)-2),1)
      acts[r,]$end_min<-acts[r,]$start_min + sampleDurationInMinsFromTimeBins(bins, acts[r,]$act_type, acts[r,]$start_min)
      if(acts[r,]$act_type == "Home Night") acts[r,]$end_min<-(60*24)-1
      # try again if start time is before end time of last activity (not always fixable)
      if (is.null(modeAndSa1) || (acts[r,]$start_min <= acts[r-1,]$end_min)) {
        tries<- tries+1
        if (tries>=5) {
          # if we have tried enough times and failed to sequence this activity following the previous one
          # then it might be time to backtrack and pick a different previous activity, since this
          # combination might just happen to be very unlikely as per the activity start/end time distributions,
          # even though this sequence was picked by the markov probability model.
          acts<-acts[-c(r),] # delete this activity
          r<-max(0,r-2) # backtrack to previous activity
          tries<-0
        } else {
          r<-r-1
        }
      }
    }
    for(r in 1:nrow(acts)) {
      # assign hhmmss time
      acts[r,]$start_hhmmss<-toHHMMSS((acts[r,]$start_min*60)+sample(0:59, 1))
      acts[r,]$end_hhmmss<-toHHMMSS((acts[r,]$end_min*60)+sample(0:59, 1))
      # save the leg
      if(r>1) {
        legs[r-1,]$origin_act_id<-acts[r-1,]$act_id
        legs[r-1,]$dest_act_id<-acts[r,]$act_id
        legs[r-1,]$mode<-mode
      }
    }
  return(list(acts,legs))
  }

  assignLocationsToActivities <-function(acts,legs) {
    work_sa1<-NULL; work_xy<-NULL
    for(r in 2:nrow(acts)) {
      mode<-legs[r-1,]$mode
      # assign the SA1 and coords
      if(acts[r,]$loc_type=="home") { # re-use home SA1 and coords
        acts[r,]$sa1<-acts[1,]$sa1
        acts[r,]$x<-acts[1,]$x
        acts[r,]$y<-acts[1,]$y
      } else if(acts[r,]$loc_type=="work" && !is.null(work_sa1)) { # re-use work SA1 and coords
        acts[r,]$sa1<-work_sa1
        acts[r,]$x<-work_xy[1]
        acts[r,]$y<-work_xy[2]
      } else {
        xy<-getAddressCoordinates(as.numeric(acts[r,]$sa1), acts[r,]$loc_type)
        if(is.null(xy)) return(NULL)
        acts[r,]$x<-xy[1]
        acts[r,]$y<-xy[2]
        # if this is a work activity then also save its SA1 and XY coordinates for future re-use
        if(acts[r,]$loc_type=="work" && is.null(work_sa1)) {
          work_sa1<-acts[r,]$sa1
          work_xy<-xy
        }
      }
    }
    return(list(acts,legs))
  }

  # compile some functions for speedup
  library(compiler)
  toHHMMSS<-cmpfun(toHHMMSS)
  selectIndexFromProbabilities<-cmpfun(selectIndexFromProbabilities)
  createActivitiesAndLegs<-cmpfun(createActivitiesAndLegs)
  echo<-cmpfun(echo)
  printProgress<-cmpfun(printProgress)

  ## start here

  # save log
  sink(paste0(outfileprefix,".log"), append=FALSE, split=TRUE) # sink to both console and log file

  # load functions and data
  echo('Initialising\n')
  library(stringr)
  library(profvis)
  source('util.R', local=TRUE)
  source('sample.R', local=TRUE)
  source('vista.R', local=TRUE)
  source('markov.R', local=TRUE)
  source('locations.R', local=TRUE)
  source('matsimXML.R', local=TRUE)

  # one-off setup
  setupDir<-"./setup"
  if (!dir.exists(setupDir)) {
    echo(paste0('Pre-processing data into ',setupDir,'\n'))

    if(!setup(setupDir)) { # setup failed
      sink() # end the diversion
      return(NULL)
    }
  } else {
    echo(paste0('Found setup directory ',setupDir,', so will use it\n'))
  }

  popnfile<-paste0(outdir,'/',outfileprefix,'.sample.csv.gz')
  if (!file.exists(popnfile)) {
    # Create the output dir
    echo(paste0('Creating output directory ', outdir, '\n'))
    dir.create(outdir, showWarnings = FALSE, recursive = TRUE, mode = "0777")

    # Create a desired sample of the Melbourne 2016 population (persons with census attributes)
    sampleMelbourne2016Population(sampleSize, popnfile) # create the sample

    # Fix their home location SA1 code (convert from SA1_7DIGCODE to SA1_MAINCODE_2016)
    echo(paste0('Assigning SA1_MAINCODE_2016 to persons in ', popnfile, ' (can take a while)\n'))
    assignSa1Maincode(popnfile, popnfile, 'data/sa1_2016_aust.csv.gz') # overwriting outfile
    echo(paste0('Updated ', popnfile,'\n'))
  } else {
    echo(paste0('Found ', popnfile,', so will use it\n'))
  }

  # Read in the persons
  gz1<-gzfile(popnfile, 'rt')
  echo(paste0('Loading census-like persons from ', popnfile, '\n'))
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)

  # Read the markov chain model for activity chains
  modelfile<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday_markov_chain_model.rds')
  echo(paste0('Loading markov chain model from ', modelfile, '\n'))
  mc<-readRDS(modelfile)

  # Read in the time bins
  csv<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday_time_bins.csv.gz')
  gz1 <- gzfile(csv,'rt')
  bins<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
  close(gz1)

  # Start profiling
  #Rprof(paste0(outdir,'/',outfileprefix,'.prof.out'))
  #library(profvis); profvis({

  # Start MATSim population XML
  popnWriteInterval<-100 # must be greater than 0
  popnWriteBuffer=list()
  popnout<-paste0(outdir, '/', outfileprefix,'.xml')
  echo(paste0('Saving MATSim population to ', popnfile, '\n'))
  str=c(
    '<?xml version="1.0" encoding="utf-8"?>',
    '<!DOCTYPE population SYSTEM "http://www.matsim.org/files/dtd/population_v6.dtd">',
    '<population>'
  )
  cat(str,file=popnout, sep="\n")

  # Create the activities and legs
  echo(paste0('Generating VISTA-like activities and trips for ', nrow(persons), ' census-like persons (can take a while)\n'))
  discarded<-persons[FALSE,]
  allpax<-NULL; allacts<-NULL; alllegs<-NULL;
  for (row in 1:nrow(persons)) {
    # get the person
    person<-persons[row,]
    pid<-row-1

    # create activities and legs
    df<-createActivitiesAndLegs(mc, bins, person)
    if(is.null(df)) {
      discarded<-rbind(discarded,person)
      printProgress(row,'x')
      next # continue to next person if we could not create activities and legs
    }
    acts<-df[[1]]
    legs<-df[[2]]
    df<-assignLocationsToActivities(acts,legs)
    if(is.null(df)) {
      discarded<-rbind(discarded,person)
      printProgress(row,'x')
      next # continue to next person if we could not assign locations
    }
    acts<-df[[1]]
    legs<-df[[2]]
    # also save all persons, activities, and legs for outputting to CSV
    if (is.null(allacts)) allacts<-acts[FALSE,]
    if (is.null(alllegs)) alllegs<-legs[FALSE,]
    allacts<-rbind(allacts,cbind(personId=pid,acts));
    alllegs<-rbind(alllegs,cbind(personId=pid,legs));
    allpax<-rbind(allpax,cbind(personId=pid,person));

    # generate MATSim XML for this person
    popnWriteBuffer[[1+((row-1)%%popnWriteInterval)]]<-generateMATSimPersonXML(pid, person, acts, legs)
    # and write it out at regular intervals
    if (row%%popnWriteInterval==0 || row==nrow(persons)) {
      lapply(popnWriteBuffer, function(x, file, append, sep) {
        if (!is.null(x)) {
          cat(saveXML(x), file=file, append=append, sep=sep)
        }
      }, file=popnout, append=TRUE, sep="\n")
      popnWriteBuffer=list() # clear the buffer after writing it out
    }

    # report progress
    printProgress(row,'.')
  }
  cat('\n')
  echo(paste0('Finished generating ',nrow(persons)-nrow(discarded),'/',nrow(persons),' persons\n'))

  # close off the population XML
  cat('</population>',file=popnout, append=TRUE,sep="\n")

  # Stop profiling
  #}) # end profvis
  #Rprof(NULL)

  if(nrow(discarded)>0) {
    outfile<-paste0(outdir, '/', outfileprefix,'.discarded.csv.gz')
    write.csv(discarded, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
    echo(paste0('Wrote ',nrow(discarded),' discarded persons to ', outfile , '\n'))
  }
  outfile<-paste0(outdir, '/', outfileprefix,'.pax.csv.gz')
  write.csv(allpax, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
  echo(paste0('Wrote ',nrow(allpax),' persons to ', outfile , '\n'))
  outfile<-paste0(outdir, '/', outfileprefix,'.acts.csv.gz')
  write.csv(allacts, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
  echo(paste0('Wrote activities to ', outfile , '\n'))
  outfile<-paste0(outdir, '/', outfileprefix,'.legs.csv.gz')
  write.csv(alllegs, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
  echo(paste0('Wrote trips to ', outfile, '\n'))
  echo(paste0('All done (see ', outfileprefix,'.log)\n'))
  sink() # end the diversion

}
