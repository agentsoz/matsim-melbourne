# Matches ABS census-like persons to VISTA-like plans
match<-function(censuscsv, vistacsv, outcsv) {
  
  source('util.R')
  
  # Read in the persons
  gz1<-gzfile(censuscsv, 'rt')
  echo(paste0('Loading ABS census-like persons from ', censuscsv, '\n'))
  persons<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  # Read in the plans
  gz1<-gzfile(vistacsv, 'rt')
  echo(paste0('Loading VISTA-like plans from ', vistacsv, '\n'))
  plans<-read.csv(gz1, header=T, stringsAsFactors=F, strip.white=T)
  close(gz1)
  
  # TODO: to be replaced with demographics based matching
  echo(paste0('Matching census-like persons toVISTA-like plans\n'))
  size<-min(nrow(persons), nrow(plans))
  match<-data.frame(PersonId=persons[1:size,]$AgentId, PlanId=plans[1:size,]$Id)
  gz1<-gzfile(outcsv, 'wt')
  write.table(match, file=gz1, append=FALSE, row.names=FALSE, sep = ',')
  close(gz1)
  echo(paste0('Wrote ', outcsv, '\n'))
}

# example usage
runexample<- function() {
  censuscsv<-'output/2.sample/sample.0.1.csv.gz'
  vistacsv<-'output/3.plan/plan.5000.csv'
  outdir<-'output/4.match'
  dir.create(outdir, showWarnings = FALSE, recursive=TRUE)
  outcsv<-paste0(outdir,'/match.csv.gz')
  match(censuscsv, vistacsv, outcsv)
}  
