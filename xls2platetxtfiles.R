
#setwd( "/home/agulati/data/New_screens_from_July_2014_onwards/Breast_BT549_KS_TS_384_template_2014-07-01" )

#setwd(datapath)

xls2platelist<-function(xls, datapath){
  # Lots of stuff to go in here:
	require(gdata)
	mydata<-read.xls(xls,1)

	#if (!file.exists(datapath)){
	#	dir.create(datapath)
#	}
	
	plates<-unique(mydata$Plate)

	
	for (plate in plates){
#		temp<-mydata[mydata$Plate==plate,c(2,4,7)] changed with to cols 1(plate), 3(well), 6(value)
		temp<-mydata[mydata$Plate==plate,c(1,3,6)]
		#filename<-paste(datapath,"/",my.prefix,"_P",plate,".txt", sep="")
    		filename<-paste(my.prefix,"_P",plate,".txt", sep="")
		#cat(filename,"\t", plate,
		write.table(temp, file=filename, col.names=FALSE, row.names=FALSE, quote=FALSE, sep="\t")
	}
}

my.file<-list.files(pattern="xls")
my.prefix<-substr((my.file),1,nchar(my.file) - 4)
