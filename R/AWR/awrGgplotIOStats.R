library(tidyverse)
setwd("H:/Data/Oracle/Krn/20220408_IO_Perfs")
dfIoStats=read_csv("rw_stats_krn_p000.csv",col_names = TRUE,show_col_types = FALSE)
head(dfIoStatsPrd010)

dfIoStatsfiltered <- dfIoStats %>% filter(readb_sec != 'NA')
head(dfIoStatsfiltered)

ggplot(dfIoStatsfiltered, aes(x = date, y = iobytes_sec, fill = instance)) +
  geom_col(position = "dodge")

ggplot(dfIoStatsfiltered, aes(x = date, y = iobytes_sec, fill = instance)) + ggtitle("IO By DB in Bytes/s") +
  geom_area(position = "dodge")
