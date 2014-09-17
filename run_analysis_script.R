#
# call zScreen
#

#setwd( "/home/agulati/data/New_screens_from_July_2014_onwards/Breast_BT549_KS_TS_384_template_2014-07-01" )
#getwd()

source( "/home/agulati/scripts/xls2platetxtfiles.R" )
source( "/home/agulati/scripts/zScreen.R" )
source( "/home/agulati/scripts/xls2txt_file.R" )

#
# Get the guide file with information on new screen 
#

guideFile<-list.files(pattern="^.*guide_file.*.txt$")

## check for the correct guide file ##

write.table(guideFile, file="/home/agulati/scripts/res.txt", sep="\t")

#guide <- read.table("/home/agulati/data/New_screens_from_July_2014_onwards/Breast_BT549_KS_TS_384_template_2014-07-01/Breast_BT549_KS_TS_384_template_2014-07-01_guide_file.txt", header=TRUE, sep="\t", stringsAsFactors=FALSE)
guide = read.table( guideFile, header=TRUE, sep="\t", stringsAsFactors=FALSE )

Xls=guide$xls_file
Datapath=guide$Datapath
Cell_line=guide$Cell_line
Negcontrols="neg"
Poscontrols="pos"
Annotationfile=guide$Template_library_file
DescripFile=guide$Descrip_file		
Platelist=guide$Platelist_file
Plateconf=guide$Plateconf_file
ReportHTML=guide$report_html
ZscoreName=guide$zscore_file
SummaryName=guide$summary_file
ZprimeName=guide$zprime_file
ReportdirName=guide$reportdir_file

#
# function for xls2platelistfiles conversion
#

res_1 <- xls2platelist(
datapath=Datapath,
xls=Xls)

#
# function for cellHTS2 analysis
#

res_2 <- zScreen(
name=Cell_line,
datapath=Datapath,
poscontrols=Poscontrols,
negcontrols=Negcontrols,
descripFile=DescripFile,
annotationfile=Annotationfile,
reportHTML=ReportHTML,
plateconf=Plateconf,
platelist=Platelist,
replicate_summary="median",
zscoreName=ZscoreName,
summaryName=SummaryName,
zprimeName=ZprimeName,
reportdirName=ReportdirName
)

res_3 <- xls2txt_file(datapath=Datapath,xls=Xls)
