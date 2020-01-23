source('sample2016.R')
source('util2016.R')
sampleSize<- 0.001 # in percent, so ~4k persons
outfile<-paste0('mel2016_',sampleSize,'.csv.gz')
sampleMelbourne2016Population(sampleSize, outfile) # create the sample
assignSa1Maincode(outfile, outfile, 'data/sa1_2016_aust.csv.gz') # add SA1 maincode (overwriting outfile)
