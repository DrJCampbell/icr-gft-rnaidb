
#setwd( "/home/agulati/data/New_screens_from_July_2014_onwards/Breast_BT549_KS_TS_384_template_2014-07-01" )

#setwd(datapath)

xls2txt_file<-function(xls, datapath){

  # Lots of stuff to go in here:
	require(gdata)
	mydata<-read.xls(xls,1)

	#if (!file.exists(datapath)){
	#	dir.create(datapath)
#	}
	
#	plates<-mydata$Plate

	
#	for (plate in plates){
		#temp<-mydata[mydata$Plate==plates,c(1,3,6)]
    		temp<-mydata[,c(1,3,6)]
		#filename<-paste(my.prefix,plates,".txt", sep="")
		filename<-paste(my.prefix,".txt",sep="")
		write.table(temp, file=filename, col.names=FALSE, row.names=FALSE, quote=FALSE, sep="\t")
#	}
}

my.file<-list.files(pattern="xls")
my.prefix<-substr((my.file),1,nchar(my.file) - 4)
