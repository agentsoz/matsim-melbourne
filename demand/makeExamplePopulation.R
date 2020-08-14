run<-function(percent, num) {
 
  # set any global options
  
  # see https://www.tidyverse.org/blog/2020/05/dplyr-1-0-0-last-minute-additions/
  options(dplyr.summarise.inform = FALSE)
  
  # create the output dir
  outdir<-'output'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  
  # run the activity-based population synthesis steps
  sink(paste0(outdir,"/makeExamplePopulation.log"), append=FALSE, split=TRUE) # sink to both console and log file
  tryCatch({
    source('setup.R', local=TRUE); runexample()
    source('sample.R', local=TRUE); runexample(percent)
    source('plan.R', local=TRUE); runexample(num)
    source('match.R', local=TRUE); runexample()
    source('locate.R', local=TRUE); runexample()
    source('place.R', local=TRUE); runexample()
    source('time.R', local=TRUE); runexample()
    source('xml.R', local=TRUE); runexample()
  },
  finally = {
    sink() # end the diversion
  })
}

runexample<-function() {
  run(0.1, 5000) # 0.1% sample population
}

runtest<-function() {
  run(0.01, 500) # 0.01% sample population
}

