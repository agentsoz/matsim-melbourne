# Usage example:
# make2016MATSimMelbournePopulation(0.0001, "mel2016_0.0001") # build a 0.0001% sapopulation for Melbourne 
#
make2016MATSimMelbournePopulation<-function(sampleSize, outfileprefix) {

  library(stringr)
  source('util2016.R', local=TRUE)
  source('sample2016.R', local=TRUE)
  source('vista2016.R', local=TRUE)
  source('markov2016.R', local=TRUE)
  source('locations2016.R', local=TRUE)
  source('matsimXML.R', local=TRUE)
  
  options(scipen=999) # disable scientific notation for more readible filenames with small sample sizes
  
  # Function to pre-process some data; need only be run once
  setup<-function() {
    
    # Logging function
    echo<- function(msg) {
      cat(paste0(as.character(Sys.time()), ' | ', msg))  
    }
    if (!file.exists('./data/vista_2012_16_v1_sa1_csv.zip.dir/VISTA_2012_16_v1_SA1_CSV/T_VISTA12_16_SA1_V1.csv')) {
      echo(paste0('Some required files are missing in the ./data directory. ',
                  'Please see ./data/README.md\n'))
      return(FALSE)
    }
    
    # Extract VISTA activities and save separately into weekday and weekend activities
    vista_csv <- './data/vista_2012_16_v1_sa1_csv.zip.dir/VISTA_2012_16_v1_SA1_CSV/T_VISTA12_16_SA1_V1.csv'
    out_weekday_activities_csv_gz <- './vista_2012_16_extracted_activities_weekday.csv.gz'
    out_weekend_activities_csv_gz <- './vista_2012_16_extracted_activities_weekend.csv.gz'
    echo(paste0('Extracting VISTA weekday/end activities from ', vista_csv, ' (can take a while)\n'))
    extract_and_write_activities_from(vista_csv, out_weekday_activities_csv_gz, out_weekend_activities_csv_gz)
    echo(paste0('Wrote ', out_weekday_activities_csv_gz, ' and ', out_weekend_activities_csv_gz,'\n'))
    
    # Simplify some activitiy classes to activity groups
    echo(paste0('Grouping some VISTA activities\n'))
    simplify_activities_and_create_groups(out_weekday_activities_csv_gz)
    echo(paste0('Updated ', out_weekday_activities_csv_gz,'\n'))
    simplify_activities_and_create_groups(out_weekend_activities_csv_gz)
    echo(paste0('Updated ', out_weekend_activities_csv_gz,'\n'))
    
    # Create markov chain model for trip chains
    prefix<-'./vista_2012_16_extracted_activities_weekday'
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
    echo('Setup complete.\n')
    return(TRUE)
  }
  
  # Function to create activities and legs from given trip chain
  createActivitiesAndLegs <- function(person, tc, tcacts) {
    # get a person and determine its home SA1 and coordinates
    home_sa1<-as.character(person$SA1_MAINCODE_2016)
    home_xy<-getAddressCoordinates(home_sa1,"home")
    if(is.null(home_xy)) return(NULL)
    
    # data frames for storing this person's activities and connecting legs
    acts<-data.frame(act_id=NA, act_type=NA, sa1=NA, x=NA, y=NA, loc_type=NA, end_hhmmss=NA)
    legs<-data.frame(origin_act_id=NA,mode=NA,dest_act_id=NA)
    
    # first activity is always home
    if (tc[1] != "home") stop(paste0('First activity in trip chain must be `home` but was `',tc[1],'`'))
    acts[1,]$act_id<-1
    acts[1,]$act_type<-tcacts[1]
    acts[1,]$loc_type<-tc[1]
    acts[1,]$sa1<-home_sa1
    acts[1,]$x<-home_xy[1]
    acts[1,]$y<-home_xy[2]
    acts[1,]$end_hhmmss<-"06:00:00" # TODO: set sensible end times
    # determine the SA1 and coordinartes for the remaining activites
    mode<-NULL
    work_sa1<-NULL; work_xy<-NULL
    for(i in 2:length(tc)) {
      acts[i,]$act_id<-i
      acts[i,]$act_type<-tcacts[i]
      acts[i,]$loc_type<-tc[i]
      # determine SA1 for this activity type given last SA1
      if (is.null(mode) || tc[i-1]=="home") { # mode can change if last activity was home
        df<-findLocation(acts[i-1,]$sa1,acts[i,]$loc_type)
      } else {
        df<-findLocationKnownMode(acts[i-1,]$sa1, acts[i,]$loc_type, mode)
      }
      # assign the SA1 and coords
      if(tc[i]=="home") { # re-use home SA1 and coords
        acts[i,]$sa1<-home_sa1 
        acts[i,]$x<-home_xy[1]
        acts[i,]$y<-home_xy[2]
      } else if(tc[i]=="work" && !is.null(work_sa1)) { # re-use work SA1 and coords
        acts[i,]$sa1<-work_sa1
        acts[i,]$x<-work_xy[1]
        acts[i,]$y<-work_xy[2]
      } else {
        acts[i,]$sa1<-df[2]
        xy<-getAddressCoordinates(acts[i,]$sa1,acts[i,]$loc_type)
        if(is.null(xy)) return(NULL)
        acts[i,]$x<-xy[1]
        acts[i,]$y<-xy[2]
        # if this is a work activity then also save its SA1 and XY coordinates for future re-use
        if(tc[i]=="work" && is.null(work_sa1)) {
          work_sa1<-df[2]
          work_xy<-xy
        }
      }
      
      # TODO: assign sensible end times for activities
      acts[i,]$end_hhmmss<-paste0(
        str_pad(6+i,2,pad="0"),":", # using activitiy id to define end hour past 6am
        str_pad(sample(seq(0,59),1),2,pad="0"),":", # random minutes in that hour
        str_pad(sample(seq(0,59),1),2,pad="0")) # random seconds in that minute
      
      # save the leg
      mode=df[1]
      legs[i-1,]$origin_act_id<-acts[i-1,]$act_id
      legs[i-1,]$dest_act_id<-acts[i,]$act_id
      legs[i-1,]$mode<-mode
    }
    rownames(acts)<-seq(1:nrow(acts))
    rownames(legs)<-seq(1:nrow(legs))
    return(list(acts,legs))
  }
  
  echo<- function(msg) {
    cat(paste0(as.character(Sys.time()), ' | ', msg))  
  }
  
  
  printProgress<-function(row, char) {
    if((row-1)%%50==0) echo('')
    cat(char)
    if(row%%10==0) cat('|')
    if(row%%50==0) cat(paste0(' ', row,'\n'))
  }
  
  ## start here
  
  # save log
  sink(paste0(outfileprefix,".log"), append=FALSE, split=TRUE) # sink to both console and log file
  
  # one-off setup
  if (!file.exists('./vista_2012_16_extracted_activities_weekday_markov_chain_model.rds')) {
    if(!setup()) { # setup failed
      sink() # end the diversion
      return(NULL)
    }
  }
  
  # Create a desired sample of the Melbourne 2016 population (persons with census attributes)
  popnfile<-paste0(outfileprefix,'.sample.csv.gz')
  sampleMelbourne2016Population(sampleSize, popnfile) # create the sample
  
  # Fix their home location SA1 code (convert from SA1_7DIGCODE to SA1_MAINCODE_2016)
  echo(paste0('Assigning SA1_MAINCODE_2016 to persons in ', popnfile, ' (can take a while)\n'))
  assignSa1Maincode(popnfile, popnfile, 'data/sa1_2016_aust.csv.gz') # overwriting outfile
  echo(paste0('Updated ', popnfile,'\n'))
  
  # Read in the persons
  gz1<-gzfile(popnfile, 'rt')
  echo(paste0('Loading census-like persons from ', popnfile, '\n'))
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  # Read the markov chain model for activity chains
  modelfile<-'./vista_2012_16_extracted_activities_weekday_markov_chain_model.rds'
  echo(paste0('Loading markov chain model from ', modelfile, '\n'))
  mc<-readRDS(modelfile)
  
  # Start MATSim population XML
  doc <- newXMLDoc()
  popn<-newXMLNode("population", doc=doc)
  # Create the activities and legs
  echo(paste0('Generating VISTA-like activities and trips for ', nrow(persons), ' census-like persons (can take a while)\n'))
  discarded<-persons[FALSE,]
  allpax<-NULL; allacts<-NULL; alllegs<-NULL;
  for (row in 1:nrow(persons)) {
    error=FALSE
    # get the person
    p<-persons[row,]
    pid<-row-1
    
    # generate a trip chain for this person
    tc<-generateActivityChain(mc,null)
    # For any chain with 'With Someone' discard and start again as we do not care about generating secondary persons
    while("With Someone" %in% tc) {
      tc<-generateActivityChain(mc, null)
    }
    # KISS: Discarding trip chains with 'Mode Change' for now; improve later on
    while("Mode Change" %in% tc) {
      tc<-generateActivityChain(mc, null)
    }
    # TODO: remove successive home activities
    # ...
    # Replace activity tags with location tags
    tclocs<-replaceActivityWithLocationTags(tc)
    # build activities and legs for the person
    df<-createActivitiesAndLegs(p, tclocs, tc)
    
    if(is.null(df)) { 
      # can be NULL sometimes if type of location required for some activiy in chain cannot be found in given SA1
      discarded<-rbind(discarded,p)
      error=TRUE
      printProgress(row,'x')
    } else {
      acts<-df[[1]]
      legs<-df[[2]]
      # also save all persons, activities, and legs for outputting to CSV
      if (is.null(allacts)) allacts<-acts[FALSE,]
      if (is.null(alllegs)) alllegs<-legs[FALSE,]
      allacts<-rbind(allacts,cbind(personId=pid,acts));
      alllegs<-rbind(alllegs,cbind(personId=pid,legs));
      allpax<-rbind(allpax,cbind(personId=pid,p));
      # generate MATSim XML for this person
      pp<-generateMATSimPersonXML(pid, p, acts, legs)
      # attach person XML node to the population
      addChildren(popn,pp)
      printProgress(row,'.')
    }
  }
  cat('\n')
  echo(paste0('Finished generating ',nrow(persons)-nrow(discarded),'/',nrow(persons),' persons\n'))
  if(nrow(discarded)>0) {
    outfile<-paste0(outfileprefix,'.discarded.csv.gz')
    write.csv(discarded, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
    echo(paste0('Wrote discarded persons to ', outfile , '\n'))
  }
  outfile<-paste0(outfileprefix,'.pax.csv.gz')
  write.csv(allpax, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
  echo(paste0('Wrote persons to ', outfile , '\n'))
  outfile<-paste0(outfileprefix,'.acts.csv.gz')
  write.csv(allacts, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
  echo(paste0('Wrote activities to ', outfile , '\n'))
  outfile<-paste0(outfileprefix,'.legs.csv.gz')
  write.csv(alllegs, file=gzfile(outfile), quote=TRUE, row.names = FALSE)
  echo(paste0('Wrote trips to ', outfile, '\n'))
  outfile<-paste0(outfileprefix,'.xml')
  echo(paste0('Saving MATSim population to ', outfile, '\n'))
  # save using cat since direct save using saveXML loses formatting
  cat(saveXML(doc, 
              prefix=paste0('<?xml version="1.0" encoding="utf-8"?>\n',
                            '<!DOCTYPE population SYSTEM "http://www.matsim.org/files/dtd/population_v6.dtd">')),
      file=outfile)
  echo(paste0('All done (see ', outfileprefix,'.log)\n'))
  sink() # end the diversion
  
}

