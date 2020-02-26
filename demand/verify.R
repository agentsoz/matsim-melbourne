library(ggplot2)
setupDir<-"./setup"

# Read in the time bins
binCols<-3:50
csv<-paste0(setupDir,'/vista_2012_18_extracted_activities_weekday_time_bins.csv.gz')
gz1 <- gzfile(csv,'rt')
bins<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
close(gz1)

binsize<-length(binCols)
binSizeInMins<-floor(60*24)/binsize
binStartMins<-seq(0,binsize-1)*binSizeInMins
binEndMins<-binStartMins+binSizeInMins-1


# Read in the generated activities
csv<-'mel_0.01/mel_0.01.acts.csv.gz'
gz1 <- gzfile(csv,'rt')
acts<-read.csv(gz1,header = T,sep=',',stringsAsFactors = F,strip.white = T)
close(gz1)

groups<-unique(bins$Activity.Group)
groups<-groups[groups!="Mode Change" & groups !="With Someone"]

pp<-data.frame(matrix(0, nrow = binsize*length(groups), ncol = 4))
colnames(pp)<-c("Activity", "Bin", "Expected", "Actual")
rowid<-1
for (act in groups) {
  # Home Morning activity end times
  e<-as.numeric(bins[bins$Activity.Group==act & bins$Activity.Stat=="Act.Start.Time.Prob",binCols])
  df<-acts[acts$act_type==act,]$start_min
  a<-as.vector(table(cut(df, breaks=c(binStartMins, last(binEndMins)), include.lowest = TRUE)))
  a<-a/sum(a)
  shift<-(rowid-1)*binsize
  pp[shift+(1:binsize),"Activity"]<-rep(act,binsize)
  pp[shift+(1:binsize),"Bin"]<-1:binsize
  pp[shift+(1:binsize),"Expected"]<-e
  pp[shift+(1:binsize),"Actual"]<-a
  rowid<-rowid+1
}

gg<-ggplot(pp, aes(x=Expected, y=Actual)) + 
  geom_abline(aes(colour='red', slope = 1, intercept=0)) +
  geom_point(colour = 'blue', fill='blue', size=3, shape=21, alpha=0.3) + 
  theme(legend.position="none") + theme(plot.title = element_text(hjust = 0.5)) +
  ggtitle(paste0('Activity Start Time Probabilities in ',binSizeInMins,'-Min Bins')) +
  facet_wrap(~Activity, scales="free", ncol=2)
ggsave("analysis.act.start.pdf", gg, width=8.5, height=11)
