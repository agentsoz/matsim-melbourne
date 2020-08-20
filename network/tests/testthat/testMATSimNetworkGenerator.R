source("../../MATSimNetworkGenerator.R")
library(tools)

context("Network generation")

test_that("MATSim Melbourne network (.sqlite) is generated", {
  wd<-getwd()
  setwd('../..')
  makeMatsimNetwork(F,20,F,F,F,F,T)
  setwd(wd)
  actual<-'../../generatedNetworks/MATSimMelbNetwork.sqlite'
  expect_true(file.exists(actual))
  
  # FIXME: output comparison is not reproducible, gives different values each time
  # expected<-'../expectations/MATSimMelbNetwork.sqlite'
  # expect_equal(as.vector(md5sum(expected)), as.vector(md5sum(actual)))
  
})