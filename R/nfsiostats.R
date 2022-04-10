library(tidyverse)
setwd("H:/Oracle Pbs/oracle_problems/Data/Krn Perfs DWH/")
dfNfsIoPrd010=read_csv("nfsiostats_20220223.csv",col_names = TRUE)
head(dfNfsIoPrd010)
# separate read/writes
dfNfsWritePrd010=dfNfsIoPrd010 %>% filter(type=="write")
dfNfsWritePrd010$num_row <- seq.int(nrow(dfNfsWritePrd010)) 
head(dfNfsWritePrd010)
summary(dfNfsWritePrd010$avg_exe_ms)

dfNfsReadsPrd010=dfNfsIoPrd010 %>% filter(type=="read")
dfNfsReadsPrd010$num_row <- seq.int(nrow(dfNfsReadsPrd010)) 
head(dfNfsReadsPrd010)
summary(dfNfsReadsPrd010$avg_exe_ms)



plot(dfNfsReadsPrd010$`kB_s`)
summary(dfNfsReadsPrd010$`kB_s`)
dfNfsIORWPrd010=merge(x=dfNfsReadsPrd010,y=dfNfsWritePrd010,by="num_row")
head(dfNfsIORWPrd010)
dfNfsIORWPrd010$total_KB_sec <- with(dfNfsIORWPrd010,op_s.x*kB_op.x+op_s.y*kB_op.y)
summary(dfNfsIORWPrd010$total_KB_sec)
summary(avg_exe_ms.x)
