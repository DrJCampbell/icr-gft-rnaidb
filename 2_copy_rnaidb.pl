#!/usr/bin/perl -w
# rnaidb.pl - CGI UI for RNAi database

use strict;
use CGI;
use CGI qw( :standard );
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);
# for new file upload - fixes the error - use string ("test_plateconf.txt") as a symbol ref while "strict refs" in use at...
no strict 'refs';
# to check if an error is due to dbi or not
use Data::Dumper;
use LWP::Simple;
#use File::Fetch;

## stuff to configure when moving... ##

my $users_file = './users.txt';
my $temp_file_path = '/tmp/tmp.csv';
my $sqldb_name = 'RNAi_analysis_database';
my $sqldb_host = 'localhost';
my $sqldb_port = '3306';
my $sqldb_user = 'internal';
my $sqldb_pass = '1nt3rnal';

## Declare variables globally ##

my $SCREEN_DIR_NAME;
my $FILE_PATH;
my $ISOGENIC_SET;
my $RNAi_SCREEN_QUALITY_CONTROL = "OK";
my $ADD_NEW_FILES_LINK = "http://gft.icr.ac.uk/cgi-bin/2_copy_rnaidb.pl?add_new_files=1";

#my $username;
#my $password;

# These are needed to allow file uploads
# whilst reducing the risk of attack (someone
# uploading a huge file and filling the disk)
$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX = 1024 * 500;
# $CGI::POST_MAX limits the max size of a post in bytes
# Note that most of the XLS files from the plate reader
# are below 500 KB

# security config
my $num_hash_itts = 500;
my $auth_code_salt = "1IwaCauw4Lxum6WU5hM8";
# The $auth_code_salt should be read in from
# a file that is generated if it doesn't exist


# HTML strings used in pages:
my $page_header = "<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /><title>GFT RNAi database</title><link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" /><meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" /></head><body><div id=\"Box\"></div><div id=\"MainFullWidth\"><a href=\"http://gft.icr.ac.uk\"><img src=\"http://www.jambell.com/sample_tracking/ICR_GFTRNAiDB_logo_placeholder.png\" width=415px height=160px></a>";
my $page_footer = "</div> <!-- end Main --></div> <!-- end Box --></body></html>";

# == config over, code below == #

# make a new CGI object
my $q = new CGI;

# This line may need to be moved in the future
# it allows us to create a hash to add to the 
# users.txt file...
#if ($q -> param( "authenticate_user" )){
#  &authenticate_user ( $q );
#}
#elsif ($q -> param( "add_new_user" )){
#  &add_new_user ( $q );
#}
#elsif ($q -> param( "login" )){
#  &login ( $q );
#}

# either get a cookie or go to login page and exit
#my $login_key = $q -> cookie("login_key") || &login($q) && exit(0);
my $login_key = $q -> cookie("login_key");

# if we got a cookie, is it valid?
#my $user = &authenticate_login_key($login_key);


# connect to the database
my $dsn = "DBI:mysql:database=$sqldb_name;host=$sqldb_host;port=$sqldb_port";
my $dbh = DBI->connect($dsn, $sqldb_user, $sqldb_pass, { RaiseError => 0, AutoCommit => 1 })
  or die "Cannot connect to database: " . $DBI::errstr;
  

# Decide what to do based on the params passed to the script
if($q -> param( "logout" )){
  &logout ( $q );
}
elsif ($q -> param( "show_all_screens" )){
  &show_all_screens ( $q );
}
elsif ($q -> param( "add_new_screen" )){
  &add_new_screen ( $q );
}
elsif ($q -> param( "save_new_screen" )){
  &save_new_screen ( $q );
}
elsif ($q-> param( "add_new_files" )){
  &add_new_files ( $q );
}
elsif ($q-> param( "save_new_uploaded_plateconf_file" )){
  &save_new_uploaded_plateconf_file ( $q );
}
elsif ($q-> param( "save_new_uploaded_platelist_file" )){
  &save_new_uploaded_platelist_file ( $q );
}
elsif ($q-> param( "save_new_uploaded_templib_file" )){
  &save_new_uploaded_templib_file ( $q );
}
elsif ($q -> param( "configure_export" )){
  &configure_export ( $q );
}
elsif ($q -> param( "test_configure_export" )){
  &test_configure_export ( $q );
}
elsif ($q -> param( "run_export" )){
  &run_export ( $q );
}
else{
 &home ( $q );
}


# home sub for debugging

# ===================
# subroutine for home
# ===================

sub home{ 
  print $q -> header (
    -type => "text/html"
    );
#  my $user = $q -> param('user');
  print "$page_header";
  print "<h1>Hello:</h1>";

  # read data from database and output
  # summary info about all screens

  if(defined($login_key)){
    print "got cookie $login_key<br />";
  }
  else{
    print "Where's my cookie?"
  }
  
  print "<p>";
  print "<p>Connected to the RNAi_analysis_database</p>";
  print "</p>";
  
  print "<p>";
  print "Go to ";
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/2_copy_rnaidb.pl?add_new_screen=1\">'Add new screen'</a>";
  print " page for entering information on new RNAi screen(s) and analyzing";
  print "</p>";
 
  print "$page_footer";
  print $q -> end_html;
}


# ================================
# subroutine for adding new screen
# ================================

sub add_new_screen{
  print $q -> header ("text/html");
  my $user = $q -> param('user');
  print "$page_header";
  print "<h1>Add new screen:</h1>";
  
  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  ## print a message if a new plateconf/platelist/library file has been successfully uploaded and saved to the server ##
  
 my $no_message = $q -> param(-name => 'no_message',
  			  							-value => '');
 
 # my $message = shift;
 # if ( defined($message)) {
  #  print "<div id=\"Message\"><p><b>$message</b></p></div>";
  my $file_upload_message = shift;
  if ( defined($file_upload_message)) {
    print "<div id=\"Message\"><p><b>$file_upload_message</b></p></div>";
  }
  else {
    print $no_message;
  }
  
  # =========================
  # add main screen info here
  # =========================
 
  print "<p><b>General screen information:</b></p>";
  print "<p>";
 
  ## get the CTG excel file ##
  
  print "<p>Plate excel file:<br />";
  
  print $q -> filefield( -name=>'uploaded_excel_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256);
  print "</p>";

  ## get the existing plateconf filenames from the database and display them in the popup menu ##
  
  my $query = "SELECT Plateconf_file_location FROM Plateconf_file_path";
  my $query_handle = $dbh->prepare($query);
  $query_handle->execute();
  
  my $plateconf_path;
  my $plateconf_file_dest;
  my $plateconf_name;
  my @plateconf_path;
  while ($plateconf_path = $query_handle->fetchrow_array){
    #push (@PLATECONF_FILE_PATH, $plateconf_path);
    $plateconf_file_dest = $plateconf_path;
    $plateconf_file_dest =~ s/.*\///;
    $plateconf_name = $plateconf_file_dest;
    $plateconf_name =~ s{\.[^.]+$}{};
    
    push (@plateconf_path, $plateconf_name);
  }
  #join("\n", @plateconf_path);
  unshift(@plateconf_path, "Please select");
  print "<p>Plateconf file:<br />";
  
  print $q -> popup_menu( -name=>'plate_conf',
  						  -value=>\@plateconf_path,
  						  -default=>'Please select');							    		  
  print " - OR";
  #link for the form for adding new plateconf file 
  print "<p>";
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/2_copy_rnaidb.pl?add_new_files=1\"> Add new plateconf file</a>";
  print "</p>";
  print "</p>";

  ## get the existing platelist filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Platelist_file_location FROM Platelist_file_path";
  $query_handle = $dbh->prepare($query);
  $query_handle->execute();
  
  my $platelist_path;
  my $platelist_file_dest;
  my $platelist_name;
  my @platelist_path;
  while ($platelist_path = $query_handle->fetchrow_array){
    #push (@PLATELIST_FILE_PATH, $platelist_path);
    $platelist_file_dest = $platelist_path;
    $platelist_file_dest =~ s/.*\///;
    $platelist_name = $platelist_file_dest;
    $platelist_name =~ s{\.[^.]+$}{};
    push (@platelist_path, $platelist_name);
  }
  
  #join("\n", @platelist_path);
  unshift(@platelist_path, "Please select");
  
  print "<p>Platelist file:<br />";
  
  print $q -> popup_menu( -name=>'plate_list',
  						  -value=>\@platelist_path,
   						  -default=>'Please select');
  
  print " - OR";
  #link for the form for adding new platelist file 
  print "<p>";  
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/2_copy_rnaidb.pl?add_new_files=1\">Add new platelist file</a>";
  print "</p>";  
  print "</p>";  	
  		
  ## get the existing template library filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Template_library_file_location FROM Template_library_file_path";
  $query_handle = $dbh->prepare($query);
  $query_handle->execute();
  
  my $templib_path;
  my $templib_file_dest;
  my $templib_name;
  my @templib_path;
  while ($templib_path = $query_handle->fetchrow_array){
    #push (@TEMPLIB_FILE_PATH, $templib_path);
    $templib_file_dest = $templib_path;
    $templib_file_dest =~ s/.*\///;
    $templib_name = $templib_file_dest;
    $templib_name =~ s{\.[^.]+$}{};
    push (@templib_path, $templib_name);
  }
  
  #join("\n", @templib_path);
  unshift(@templib_path, "Please select");
  
  print "<p>Template library:<br />";
  
  print $q -> popup_menu( -name => 'template_library',
  						  -value => \@templib_path,
   						  -default => 'Please select');
  
  print " - OR";
  #link for the form for adding new template library file 
  print "<p>";  	
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/2_copy_rnaidb.pl?add_new_files=1\"> Add new template library file</a>";
  print "</p>";
  print "</p>";

  ## get the tissue type from the database ##
  
  my @tissues = ("Please select", "Breast", "Large_intestine", "Head_and_neck", "Pancreatic", "Ovarian", "Endometrium"); 

  print "<p>Tissue of origin:<br />";
  
  print $q -> popup_menu(-name =>'tissue_type',
  						 -value => \@tissues,
   	                     -default =>'Please select');

  print "</p><p>";

  ## get the cell line name ##
  
  print "Cell line name:<br />";
  print $q -> textfield ( -name => "cell_line_name",
                          -value => 'Enter cell line name',
                          -size => "30",
                          -maxlength => "45");
  print "</p><p>";

  ## get the current date ##
  
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  $mon ++;
  my $date = sprintf("%04u-%02u-%02u",$year,$mon,$mday); # set this to current date using localtime()
  print "</p><p>";
  print "Date of screen:<br />";
  print $q -> textfield ( -name => "date_of_run",
                          -value => $date,
                          -size => "30",
                          -maxlength => "45");
  print "</p><p>";
  
  ## get the user (who is logged in?) ##
  
  print "Operator:<br />";
  print $q -> textfield ( -name => "operator",
                          -value => $user,
                          -size => "30",
                          -maxlength => "45");

  print "</p><p>Transfection reagent:<br />"; 
    
  ## get the transfection_reagent name from the database ##
  
  my @transfection_reagent = ("Please select", "Lipofectamine", "Bleach"); 
  print $q -> popup_menu( -name => 'transfection_reagent',
  						  -value => \@transfection_reagent,
  						  -default => 'Please select');
  
  ## get the instrument name from the database ##
  
  print "</p><p>Instrument:<br />";
  
  my @instrument = ("Please select", "Inst_1", "Inst_2"); 
  print $q -> popup_menu( -name => 'instrument',
  					      -values => \@instrument,
  						  -default => 'Please select');

  print "</td>\n";

  # ======================
  # add isogenic info here
  # ======================

  print "<td align=left valign=top>\n";
  
  print "<p><b>Isogenic screens:</b></p>";

  ## is the screen isogenic ##

  print "<p>";
  
  print $q -> checkbox( -name=>'is_isogenic',
    					-checked=>0,
   					    -value=>'ON',
    					-label=>'this is an isogenic screen');

  print "</p><p>";
  
  ## which gene was modified ##
  
  print "Modified gene name:<br />";
  print $q -> textfield ( -name => "gene_name_if_isogenic",
                          -value => 'Enter gene name',
                          -size => "30",
                          -maxlength => "45");
  
  print "</p><p>";
   
 ## get the existing isogenic sets from the database and display them in the popup menu ##
 
 $ISOGENIC_SET = $dbh->selectcol_arrayref("SELECT Name_of_set_if_isogenic FROM Name_of_set_if_isogenic WHERE Name_of_set_if_isogenic != 'NA'");
 unshift($ISOGENIC_SET, "Please select");
 
  print "<p>";

  print "<p>Select isogenic set:<br />";
    
  print $q -> popup_menu(-name =>'isogenicSet',
  						 -value => $ISOGENIC_SET,
   	                     -default =>'Please select');

  print " - OR";
  print "<p>";
  print "</p>";  
  
  ## what isogenic set is this part of ##
  
  print "Enter isogenic set:<br />";
  print $q -> textfield ( -name => "name_of_set_if_isogenic",
                          -value => 'Enter isogenic set name',
                          -size => "30",
                          -maxlength => "45");
                          
  print "</p><p>";
   
  ## get isogenic mutant description (i.e. parental etc) ##
  
  print "Isogenic description:<br />";
  print $q -> textfield ( -name => "isogenic_mutant_description",
                          -value => 'e.g. parental',
                          -size => "30",
                          -maxlength => "45");
  
  print "</p><p>";  
  
  ## get method of isogenic knockout etc ##
  
  print "Method of isogenic mutation:<br />";
  print $q -> textfield ( -name => "method_of_isogenic_knockdown",
                          -value => 'e.g. ZFN or shRNA',
                          -size => "30",
                          -maxlength => "45");
   
  print "</p><p>";
  print "</td>\n";                        
  
  # =========================
  # add drug screen info here
  # =========================

  print "<td align=left valign=top>\n";
  
  print "<p><b>Drug screens:</b></p>";

  ## is this a drug screen ##

  print "<p>";
  
  print $q -> checkbox( -name=>'is_drug_screen',
    					-checked=>0,
   					    -value=>'ON',
    					-label=>'this is a drug screen');

  print "</p><p>";
  
  ##  Select control from dropdown menu ##
  
  print "<p>";
  
  my @CONTROL = ("Please select", "DMSO", "DNS"); # this should be read from a text file or from the SQL database
  print "Control:<br />";
  print $q -> popup_menu( -name => 'Control',
  					      -value => \@CONTROL,
  						  -default => 'Please select');
  print "</p>";
  
  ## çompound used ##
  
  print "<p>";
  
  print "Compound:<br />";
  print $q -> textfield ( -name => "compound",
                          -value => 'e.g. drug A',
                          -size => "30",
                          -maxlength => "45");
  
  print "</p>";
                          
  ## concentration ##
  
  print "<p>";
  
  print "Concentration:<br />";
  print $q -> textfield ( -name => "concentration",
                          -value => 'e.g. 100 ng',
                          -size => "30",
                          -maxlength => "45"); 
                          
  print "</p>";
  
  ## dosing regime ##
  
  print "<p>";
  
  print "Dosing regime:<br />";
  print $q -> textfield ( -name => "dosing regime",
                          -value => 'e.g. 24 hrs after transfection',
                          -size => "30",
                          -maxlength => "45"); 
    
  print "</p>";                       
  print "</td>\n";                       
                                              
  # ====================================
  # put notes text field for drug screen
  # ====================================

  print "<td align=left valign=bottom>\n";
  
  print "<p>";
  print "Notes about the drug screen:<br />";
  print $q -> textarea ( -name => "drug_screen_notes",
                         -default => 'write notes for drug screen',
                         -rows => "8",
                         -columns => "40");     
                          
  print "</p>";
  print "</td>\n";
                                                                    
  # ==========================================================
  # put notes text field for new screen and submit button here
  # ==========================================================

  print "<tr colspan=2>\n";
  print "<td align=left valign=top>\n";

  ## Enter information to store in the Description.txt ##

  print "<p>";
  print "Notes about this screen:<br />";
  print $q -> textarea ( -name => "notes",
                         -default => 'write notes for Description.txt',
                         -rows => "8",
                         -columns => "40");
                         
  ## submit the form ##
                                                
  print "</p><p>";
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Save new screen information and analysis results\" name=\"save_new_screen\" />";
  print "</p>";
  
  ## button for viewing all screens ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"show_all_screens\" value=\"Show all analysed RNAi screens\" name=\"show_all_screens\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;
                                                                          
} #end of add_new_screen subroutine


  # =================================================================================
  # Subroutine for downloading/uploading new/edited plateconf/platelist/library files
  # =================================================================================

sub add_new_files{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Add new file(s):</h1>";
  
  ## Downloading/uploading plateconf file ##
  
  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<p><b>Upload new plateconf file:</b></p>";
  print "<p>";
 
  ## download old Plateconf file ##
 
  my $plate_conf_384_download_link = "http://gft.icr.ac.uk/plate_conf_folder/plateconf_384.txt";
  my $plate_conf_96_download_link = "http://gft.icr.ac.uk/plate_conf_folder/plateconf_96.txt";

  print "<div id=\"Note\"><p>NOTE: For downloading the plateconf file, right click on the relevant link below and select the 'Save Link As...' option for saving the file on your computer.</p></div>";
  
  print "<p>";
  print "<a href=\"$plate_conf_384_download_link\">Download the 384-well plate conf file for editing</a>";
  print "     -  OR";
  print "</p>";
  
  print "<p>";
  print "<a href=\"$plate_conf_96_download_link\">Download the 96-well plate conf file for editing</a>";
  print "</p>";
  print "<p></p>";
  
  ## get new Plateconf file ##
  
  print "<p>Upload edited plateconf file:<br />";
  print "<p></p>";
  
  print $q -> filefield( -name=>'new_uploaded_plateconf_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256);
  print "</p>";
  
  ## enter new plateconf file name ##
  
  print "<p>Enter new plateconf file name:<br />";
  print "<p></p>";
  
  print $q -> textfield ( -name => "new_plateconf_filename",
                          -value => 'e.g. plateconf_384_ver_02',
                          -size => "30",
                          -maxlength => "45");

  print "<p></p>";
  
  print"<p><div id=\"Note\">NOTE: Please make sure that the name of the new uploaded plateconf file is unique and different from the names of existing plateconf files. The words in the filename must be joined with an underscore ( _ ). For example, an edited 'Plateconf_384' file can be renamed as 'Plateconf_384_ver_02' or 'Plateconf_384_edited_Aug-2014'.</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user-a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_plateconf_file',
  					   -default=>'save_new_uploaded_plateconf_file' );
  
  ## submit the form for uploading plateconf file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_plateconf_file\" value=\"Save the uploaded plateconf file\" name=\"save_new_uploaded_plateconf_file\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form(); 
  
  ## Downloading/uploading platelist file ## 
  
  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<p><b>Upload new platelist file:</b></p>";
  print "<p>";
 
  ## download old Platelist file ##
 
  my $plate_list_384_download_link = "http://gft.icr.ac.uk/plate_list_folder/platelist_384.txt";
  my $plate_list_96_download_link = "http://gft.icr.ac.uk/plate_list_folder/platelist_96.txt";

  print "<p><div id=\"Note\">NOTE: For downloading the platelist file, right click on the relevant link and select the 'Save Link As...' option for saving the file on your computer.</div></p>";
  
  print "<p>";
  print "<a href=\"$plate_list_384_download_link\">Download the 384-well plate list file for editing</a>";
  print "     -  OR";
  print "</p>";
  
  print "<p>";
  print "<a href=\"$plate_list_96_download_link\">Download the 96-well plate list file for editing</a>";
  print "</p>";
  print "<p></p>";
  
  ## get new platelist file ##
  
  print "<p>Upload new platelist file:<br />";
  print "<p></p>";
  
  print $q -> filefield( -name=>"new_uploaded_platelist_file",
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256);
  print "</p>";
  
  ## enter new platelist file name ##
  
  print "<p>Enter new platelist file name:<br />";
  print "<p></p>";
   
  print $q -> textfield ( -name => "new_platelist_filename",
                          -value => 'e.g. platelist_384_ver_02',
                          -size => "30",
                          -maxlength => "45"); 
  print "<p></p>";
  
  print"<p><div id=\"Note\">NOTE: Please make sure that the name of the new uploaded platelist file is unique and different from the names of existing platelist files. The words in the filename must be joined with an underscore ( _ ). For example, an edited 'Platelist_384' file can be renamed as 'Platelist_384_ver_02' or 'Platelist_edited_384_Aug-2014'.</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user-a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_platelist_file',
  					   -default=>'save_new_uploaded_platelist_file' );
  
  ## submit newly uploaded plateconf file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_platelist_file\" value=\"Save the uploaded platelist file\" name=\"save_new_uploaded_platelist_file\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form(); 
  
  ## Downloading/uploading template library file ## 
  
  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<p><b>Upload new template library file:</b></p>";
  print "<p>";
 
  ## download old template library file ##
 
  my $kinome_library_download_link = "http://gft.icr.ac.uk/template_library_folder/Kinome_template.txt";
  my $KS_TS_384_library_download_link = "http://gft.icr.ac.uk/template_library_folder/KS_TS_384_template.txt";
  my $KS_TS_DR_384_library_download_link = "http://gft.icr.ac.uk/template_library_folder/KS_TS_DR_384_template.txt";
  my $KS_TS_MT_PH_for_panc_template_library_download_link = "http://gft.icr.ac.uk/template_library_folder/KS_TS_DR_MT_PH_for_panc_template.txt";

  print "<p><div id=\"Note\">NOTE: For downloading the library file for editing, right click on the relevant link below and select the 'Save Link As...' option for saving the file on your computer.</div></p>";
  
  print "<p>";
  print "<a href=\"$kinome_library_download_link\">Download the Kinome library file for editing</a>";
  print "     -  OR";
  print "</p>";
  
  print "<p>";
  print "<a href=\"$KS_TS_384_library_download_link\">Download the KS_TS_384 library file for editing</a>";
  print "     -  OR";
  print "</p>";
  
  print "<p>";
  print "<a href=\"$KS_TS_DR_384_library_download_link\">Download the KS_TS_DR_384 library file for editing</a>";
  print "     -  OR";
  print "</p>";
  
  print "<p>";
  print "<a href=\"$KS_TS_MT_PH_for_panc_template_library_download_link\">Download the KS_TS_DR_MT_PH_384 library file for editing</a>";
  print "</p>";
  print "<p></p>";

  ## get new template library file ##
  
  print "<p>Upload edited template library file:<br />";
  print "<p></p>";
  
  print $q -> filefield( -name=>'new_uploaded_templib_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256);
  print "</p>";
  
  #enter new template library file name
  print "<p>Enter new template library file name:<br />";
  print "<p></p>";

  print $q -> textfield ( -name => "new_templib_filename",
                          -value => 'e.g. KS_TS_DR_x_y_z_template', 
                          -size => "30",
                          -maxlength => "45");  
  print "<p></p>";
  
  print"<p><div id=\"Note\">NOTE: Please make sure that the name of the new uploaded library file is unique and different from the names of the existing library files. The words in the filename must be joined with an underscore ( _ ). For example, an edited 'Kinome_template' file can be renamed as 'Kinome_template_ver_02' and a new library file can be named as 'KS_TS_DR_x_y_z_template'.</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user-a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_templib_file',
  					   -default=>'save_new_uploaded_templib_file' );

  ## submit newly uploaded template library file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_templib_file\" value=\"Save the uploaded template library file\" name=\"save_new_uploaded_templib_file\" />";
  print "</p>";
  
  print "<tr colspan=2>\n";
  print "<td align=left valign=top>\n";

  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form();
  
  print "$page_footer";
  print $q -> end_html; 
  
} #end of add_new_files subroutine


# ================================
# Subroutine for saving new screen
# ================================

sub save_new_screen{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Saving new screen data:</h1>";
  
  $ISOGENIC_SET = $q -> param( "isogenicSet" );
  my $tissue_type = $q -> param( "tissue_type" );
  my $cell_line_name = $q -> param( "cell_line_name" );
  my $date_of_run = $q -> param( "date_of_run" );
  my $operator = $q -> param( "operator" );
  my $transfection_reagent = $q -> param( "transfection_reagent" );
  my $instrument = $q -> param( "instrument" );
  my $is_isogenic = $q -> param( "is_isogenic" );
  my $gene_name_if_isogenic = $q -> param( "gene_name_if_isogenic" );
  my $new_isogenic_set = $q ->  param( "name_of_set_if_isogenic" );
  my $isogenic_mutant_description = $q -> param( "isogenic_mutant_description" );
  my $method_of_isogenic_knockdown = $q -> param( "method_of_isogenic_knockdown" );
  my $notes = $q -> param( "notes" );
  
  ################################################[[[get params to check the previous page is working as expected]]]
  
  ################################################[[[my $tmp_file_path = "/home/agulati/data/tmp_file";]]]
  
  my $plateconf = $q -> param( "plate_conf" );
  my $plateconf_file_path = "/home/agulati/data/plate_conf_folder/".$plateconf.".txt";

  ## try to match $templatelibrary to a file path ##

  my $templib = $q -> param( "template_library" );
  my $templib_file_path = "/home/agulati/data/template_library_folder/".$templib.".txt";

  ## try to match $platelist to a file path ##   
      
  my $platelist = $q -> param( "plate_list" );
  my $platelist_file_path = "/home/agulati/data/plate_list_folder/".$platelist.".txt";
  
  ## make new screen directory ##
  
  my $screenDir_path = "/home/agulati/data/New_screens_from_July_2014_onwards"; 
  $SCREEN_DIR_NAME = $tissue_type."_".$cell_line_name."_".$templib."_".$date_of_run;
  $FILE_PATH = "$screenDir_path/$SCREEN_DIR_NAME";

  if(! -e "$FILE_PATH"){mkdir("$FILE_PATH") && `chmod -R 777 $FILE_PATH` && `chown -R agulati:agulati $FILE_PATH`}
    
  else{
    die "Cannot make new directory $SCREEN_DIR_NAME in $screenDir_path: $!";
  }  
  
  print "<p>Created new screen directory: $SCREEN_DIR_NAME...</p>"; 
  
  my $platelist_target = $FILE_PATH."/".$SCREEN_DIR_NAME."_".$platelist.".txt";
  my $plateconf_target = $FILE_PATH."/".$SCREEN_DIR_NAME."_".$plateconf.".txt";
  my $templib_target = $FILE_PATH."/".$SCREEN_DIR_NAME."_".$templib.".txt";
  
  ## copy selected plateconf file to the screen directory ##

  print "<p>Selected Platelist file saved in the new screen directory...</p>";  
  
  my $prefix = $SCREEN_DIR_NAME."_";
  
  open IN, "<$platelist_file_path";
  open OUT, ">/home/agulati/data/plate_list_folder/tmp_platelist_file.txt";
  while (<IN>)
  {
    if ($_ =~ /^Filename/)
    {
      print OUT $_;
    }
    else
    {
      print OUT $prefix.$_;
    }
  }
  close IN;
  close OUT; 
   
  `cp /home/agulati/data/plate_list_folder/tmp_platelist_file.txt $platelist_target`; 
  `cp $plateconf_file_path $plateconf_target`;
  `cp $templib_file_path $templib_target`;     
  
  ############################################[[[probably need to copy $temp_file_path somewhere safe and give it to an R script to convert]]]
  
  ## Upload excel file and save it to new screen directory ##
  
  my $lightweight_fh  = $q->upload('uploaded_excel_file');
  my $excelFile = $q->param( "uploaded_excel_file" );
  my $target = $FILE_PATH."/".$excelFile;
  # undef may be returned if it's not a valid file handle
  
  if (defined $lightweight_fh) {
  # Upgrade the handle to one compatible with IO::Handle:
    my $io_handle = $lightweight_fh->handle;
 
    open ($excelFile,'>',$target)
      or die "Cannot open '$target':$!";
      print "<p>Uploaded Excel file saved to the new screen directory...</p>";
    
    my $bytesread = undef;
    my $buffer = undef;
    while ($bytesread = $io_handle->read($buffer,1024)) {
      print $excelFile $buffer
        or die "Error writing '$target' : $!";
    }
    close $excelFile
      or die "Error writing '$target' : $!";
    }
    
    ## rename uploaded excel file ##
    
    my $new_xls_file = rename($FILE_PATH."/".$excelFile, $FILE_PATH."/".$SCREEN_DIR_NAME.".xls") or die "Cannot rename $excelFile :$!";
    
    print "<p>";
    print "<p>Excel file renamed...</p>";
    print "</p>"; 
    
  ###############################################[[[either copy the platelist/palteconf/library etc to the new screen folder or use symlinks to point to the templates]]]
  
  ## write $notes to a 'Description.txt' file ##
  
  my $descripFile = $FILE_PATH."/".$SCREEN_DIR_NAME."_Description.txt";
  open NOTES, "> $descripFile" or die "Can't write notes file to ... :$!\n";
    print NOTES $notes;
    my $screenDescription_filename = $SCREEN_DIR_NAME."_Description.txt";
  close NOTES;
  
  ## Add new screen info to Guide file ##
  
  my $guide_file = $SCREEN_DIR_NAME."_guide_file.txt";
  
  open GUIDEFILE, '>', $FILE_PATH."/".$guide_file or die "Can't open $FILE_PATH";
    
  print GUIDEFILE "ID\t", "Cell_line\t", "Datapath\t", "Template_library_file\t", "Platelist_file\t", "Plateconf_file\t", "Descrip_file\t", "report_html\t", "zscore_file\t", "summary_file\t", "zprime_file\t", "reportdir_file\t", "xls_file\n"; 
  print GUIDEFILE "1\t", "$cell_line_name\t", "$FILE_PATH\t", "$templib_target\t", "$platelist_target\t", "$plateconf_target\t", "$screenDescription_filename\t", "TRUE\t", "$SCREEN_DIR_NAME"."_zscores.txt\t", "$SCREEN_DIR_NAME"."_summary.txt\t", "$SCREEN_DIR_NAME"."_zprime.txt\t", "$SCREEN_DIR_NAME"."_reportdir\t", "$SCREEN_DIR_NAME".".xls\n";   
  print "<p>Guide file created: $guide_file...</p>"; 
      
  close (GUIDEFILE); 
  
  my $guide = $guide_file;
  
  ##  run RNAi screen analysis scripts by calling R ##  
  
  my $run_analysis_scripts = `cd $FILE_PATH && R --vanilla < /home/agulati/scripts/run_analysis_script.R`;
   
  ####[[[my $run_analysis_scripts = system("R --vanilla < /home/agulati/scripts/run_analysis_script.R");]]]

  ## rename index.html file and copy it to the /var/www/html... directory ##

  my $rnai_screen_report_original_path = $FILE_PATH."/".$SCREEN_DIR_NAME."_reportdir";
  my $rnai_screen_report_original_file = $rnai_screen_report_original_path."/"."index.html";
  
  my $rnai_screen_report_renamed_file = $rnai_screen_report_original_path."/".$SCREEN_DIR_NAME."_index.html";
  `cp $rnai_screen_report_original_file $rnai_screen_report_renamed_file`;
  
  my $rnai_screen_report_new_path = "/usr/local/www/html/RNAi_screen_analysis_report_folders";
  `cp -r $rnai_screen_report_original_path $rnai_screen_report_new_path`;
  
  ## Display the link to screen analysis report on the save new screen page ##
  
  my $rnai_screen_link_to_report = "http://gft.icr.ac.uk/RNAi_screen_analysis_report_folders/".$SCREEN_DIR_NAME."_reportdir/";
 
  print "<p>";
  print "<p>Result files of analyzed RNAi screens stored in the database...</p>";
  print "</p>";
  
  print "<p>";
  print "<p>ANALYSIS COMPLETE</p>";
  print "</p>";
  
  print "View analysis report for the screen: ";
  print "<a href = \"$rnai_screen_link_to_report\">'$SCREEN_DIR_NAME'</a>";
  print "</p>";
 
  print "<p>";
  print "<input type=\"submit\" id=\"show_all_screens\" value=\"Show all analysed RNAi screens\" name=\"show_all_screens\" />";
  print "</p>";
  
  print "<p>";
  print "<input type=\"submit\" id=\"test_configure_export\" value=\"Show all results\" name=\"test_configure_export\" />";
  print "</p>";
  
  # =====================
  # Populate the database
  # =====================
  
  ## declare variables locally ##
  my $line; 
  
  my $is_isogenic_screen;
  
  my $plate_number_xls_file;
  my $well_number_xls_file;
  my $raw_score_xls_file;

  my $compound;
  my $plate_number_for_zscore;
  my $well_number_for_zscore;
  my $zscore;

  my $plate_number_for_summary;
  my $position;
  my $zscore_summary; 
  my $well_number_for_summary; 
  my $well_anno;
  my $final_well_anno;
  my $raw_r1_ch1;
  my $raw_r2_ch1;
  my $raw_r3_ch1;
  my $median_ch1;
  my $average_ch1;
  my $raw_plate_median_r1_ch1;
  my $raw_plate_median_r2_ch1; 
  my $raw_plate_median_r3_ch1;
  my $normalized_r1_ch1;
  my $normalized_r2_ch1;
  my $normalized_r3_ch1;
  my $gene_id_summary;
  my $precursor_summary;
  
  ## 1. Store user info in the database ##
 
 # open (FILE, "/usr/lib/cgi-bin/users.txt");
  
  #foreach $line(<FILE>){
  #  chomp $line;
  #  ($username, $password) = split(/\t/,$line);
    
   # $query_handle = $dbh->do("INSERT INTO User_info (
	#User_info_ID, 
    #Username, 
   # Password) 
  #  VALUES (
 #   DEFAULT, 
#    '$username', 
 #   '$password')");
    
    #$query_handle = $dbh->prepare($query);
    #$query_handle -> execute();
  #}
  #close FILE;
  
  ## 2. Store New isogenic set entered by the user into the database ##
  
  #first check if the screen isogenic and then check if the user hasn't selected a set from the drop down menu
  
  if ($is_isogenic eq 'ON'){
    $is_isogenic_screen = "YES";
    if($ISOGENIC_SET eq "Please select"){
      my $query = $dbh->do("INSERT INTO Name_of_set_if_isogenic ( 
        Name_of_set_if_isogenic) 
        VALUES (
        '$new_isogenic_set')");
        my $query_handle = $dbh->prepare($query);
        $query_handle -> execute();
        $ISOGENIC_SET = $new_isogenic_set;
    } 
  }
  else{
    $is_isogenic_screen = "NO";
    $gene_name_if_isogenic = "NA";
    $isogenic_mutant_description = "NA";
    $method_of_isogenic_knockdown = "NA";
    $ISOGENIC_SET = "NA";
    $new_isogenic_set = "NA";
  }  

  ## 3. Store new Rnai screen metadata in the database ##
  
  my $query = $dbh->do("INSERT INTO Rnai_screen_info (      
    Cell_line,    
    Rnai_screen_name,    
    Date_of_run,    
    Operator,    
    Is_isogenic,    
    Gene_name_if_isogenic,    
    Isogenic_mutant_description,    
    Method_of_isogenic_knockdown,    
    Rnai_screen_quality_control,    
    Rnai_template_library,    
    Plate_list_file_name,    
    Plate_conf_file_name,   
    Rnai_screen_link_to_report,  
    Notes,   
    Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID, 
    Instrument_used_Instrument_used_ID,   
    Tissue_type_Tissue_type_ID,    
    Transfection_reagent_used_Transfection_reagent_used_ID,    
    Template_library_file_path_Template_library_file_path_ID,
    Plateconf_file_path_Plateconf_file_path_ID,
    Platelist_file_path_Platelist_file_path_ID,
    Template_library_Template_library_ID) 
    SELECT 
    '$cell_line_name',
    '$SCREEN_DIR_NAME',
    '$date_of_run', 
    '$operator',
    '$is_isogenic_screen',
    '$gene_name_if_isogenic',
    '$isogenic_mutant_description',
    '$method_of_isogenic_knockdown',
    '$RNAi_SCREEN_QUALITY_CONTROL',
    '$templib',
    '$platelist',
    '$plateconf',
    '$rnai_screen_link_to_report',
    '$notes', 
    (SELECT Name_of_set_if_isogenic_ID FROM Name_of_set_if_isogenic WHERE Name_of_set_if_isogenic = '$ISOGENIC_SET'), 
    (SELECT Instrument_used_ID FROM Instrument_used WHERE Instrument_name = '$instrument'),
    (SELECT Tissue_type_ID FROM Tissue_type WHERE Tissue_of_origin = '$tissue_type'), 
    (SELECT Transfection_reagent_used_ID FROM Transfection_reagent_used WHERE Transfection_reagent = '$transfection_reagent'), 
    (SELECT Template_library_file_path_ID FROM Template_library_file_path WHERE Template_library_file_location = '$templib_file_path'),
    (SELECT Plateconf_file_path_ID FROM Plateconf_file_path WHERE Plateconf_file_location = '$plateconf_file_path'),
    (SELECT Platelist_file_path_ID FROM Platelist_file_path WHERE Platelist_file_location = '$platelist_file_path'),
    (SELECT Template_library_ID FROM Template_library WHERE Template_library_name = '$templib')");
  
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  my $last_rnai_screen_info_id = $dbh->{mysql_insertid};
  
  ## 4. Store excel file in the database ##
  
  ######### COMMENTED OUT TEMPORARILY #########
  
  #open (FILE, $FILE_PATH."/".$SCREEN_DIR_NAME.".txt");
  
  #foreach $line(<FILE>){
   # chomp $line;
    #($plate_number_xls_file, $well_number_xls_file, $raw_score_xls_file) = split(/\t/,$line);
    
    #$query_handle = $dbh->do("INSERT INTO Plate_excel_file_as_text (
    #Plate_excel_file_as_text_ID, 
    #Plate_number_xls_file, 
    #Well_number_xls_file, 
    #Raw_score_xls_file,
    #Rnai_screen_info_Rnai_screen_info_ID) 
    #VALUES (
    #DEFAULT, 
    #'$plate_number_xls_file', 
    #'$well_number_xls_file', 
    #'$raw_score_xls_file',
    #'$last_rnai_screen_info_id')");
    
    #$query_handle = $dbh->prepare($query);
    #$query_handle -> execute();
  #}
  #close FILE;
  
  ## 5. Store file with zscores in the database ##
  
  #Remove the header in zscore file#  
  my $zscores_file_complete = $FILE_PATH."/".$SCREEN_DIR_NAME."_zscores.txt";
  my $zscores_file_complete_wo_header = $FILE_PATH."/".$SCREEN_DIR_NAME."_zscores_wo_header.txt";
  #my $tmp_file_for_zscores = "/home/agulati/data/tmp_file_for_zscores.txt";
  #`sudo touch /home/agulati/data/Temp_zscores/temp_zscores.txt`;
  `chmod 777 /home/agulati/data/Temp_zscores/temp_zscores.txt`;
  `chown agulati:agulati /home/agulati/data/Temp_zscores/temp_zscores.txt`;
  my $tmp_file_for_zscores = "/home/agulati/data/Temp_zscores/temp_zscores.txt";
  
  #`chmod -R 777 $tmp_file_for_zscores`;
  #`chown -R agulati:agulati $tmp_file_for_zscores`;
  `cat $zscores_file_complete | grep -v ^Compound > $tmp_file_for_zscores | mv $tmp_file_for_zscores $zscores_file_complete_wo_header`;
  
  open (FILE, $zscores_file_complete_wo_header);
  foreach $line(<FILE>){
    chomp $line;
    ($compound, $plate_number_for_zscore, $well_number_for_zscore, $zscore) = split(/\t/,$line);
    
    my $query = $dbh->do("INSERT INTO Zscores_result(
      Compound, 
      Plate_number_for_zscore, 
      Well_number_for_zscore,
      Zscore,
      Rnai_screen_info_Rnai_screen_info_ID,
      Template_library_Template_library_ID) 
      SELECT 
      '$compound', 
      '$plate_number_for_zscore',
      '$well_number_for_zscore', 
      '$zscore',
      '$last_rnai_screen_info_id',
      (SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$templib')");
    my $query_handle = $dbh->prepare($query);
    $query_handle -> execute();
  }
  close FILE;
  
  ## 6. Store file with summary of result in the database ##
  
  #Remove the header in summary file#
  my $summary_file_complete = $FILE_PATH."/".$SCREEN_DIR_NAME."_summary.txt"; 
  my $summary_file_complete_wo_header = $FILE_PATH."/".$SCREEN_DIR_NAME."_summary_wo_header.txt";
  #`sudo touch /home/agulati/data/Temp_summary_result/temp_summary.txt`;
  `chmod 777 /home/agulati/data/Temp_summary_result/temp_summary.txt`;
  `chown agulati:agulati /home/agulati/data/Temp_summary_result/temp_summary.txt`;
  my $tmp_file_for_summary = "/home/agulati/data/Temp_summary_result/temp_summary.txt";
  
  #`chmod -R 777 $tmp_file_for_summary`;
  #`chown -R agulati:agulati $tmp_file_for_summary`;
  `cat $summary_file_complete | grep -v ^plate > $tmp_file_for_summary | mv $tmp_file_for_summary $summary_file_complete_wo_header`;
  
  open (FILE, $summary_file_complete_wo_header);
  foreach $line(<FILE>){
    chomp $line;
    ($plate_number_for_summary, $position, $zscore_summary, $well_number_for_summary, $well_anno, $final_well_anno, $raw_r1_ch1, $raw_r2_ch1, $raw_r3_ch1, $median_ch1, $average_ch1, $raw_plate_median_r1_ch1, $raw_plate_median_r2_ch1, $raw_plate_median_r3_ch1, $normalized_r1_ch1, $normalized_r2_ch1, $normalized_r3_ch1, $gene_id_summary, $precursor_summary) = split(/\t/,$line);
    
    my $query = $dbh->do("INSERT INTO Summary_of_result (
      Plate_number_for_summary,
      Position,
      Zscore_summary, 
      Well_number_for_summary,
      Well_anno,
      Final_well_anno,
      Raw_r1_ch1,
      Raw_r2_ch1,
      Raw_r3_ch1,
      Median_ch1,
      Average_ch1,
      Raw_plate_median_r1_ch1,
      Raw_plate_median_r2_ch1,
      Raw_plate_median_r3_ch1,
      Normalized_r1_ch1,
      Normalized_r2_ch1,
      Normalized_r3_ch1,
      Gene_id_summary,
      Precursor_summary,
      Rnai_screen_info_Rnai_screen_info_ID, 
      Template_library_Template_library_ID) 
      SELECT 
      '$plate_number_for_summary',
	  '$position',
	  '$zscore_summary', 
	  '$well_number_for_summary', 
	  '$well_anno',
      '$final_well_anno',
	  '$raw_r1_ch1',
	  '$raw_r2_ch1',
	  '$raw_r3_ch1',
	  '$median_ch1',
	  '$average_ch1',
	  '$raw_plate_median_r1_ch1',
	  '$raw_plate_median_r2_ch1', 
	  '$raw_plate_median_r3_ch1',
	  '$normalized_r1_ch1',
	  '$normalized_r2_ch1',
	  '$normalized_r3_ch1',
	  '$gene_id_summary',
 	  '$precursor_summary',
      '$last_rnai_screen_info_id',
      (SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$templib')");
    
    my $query_handle = $dbh->prepare($query);
    $query_handle -> execute();
  }
  
  close FILE;
  
  print "$page_footer";
  print $q -> end_html;

}

  ############### TO DO:
  ############### enter data into SQL database 
  ############### store URL for HTML report in database
  ############### store z-score and QC in database
  ############### print a done message and re-direct to another page


  # ================================
  # Save new uploaded plateconf file
  # ================================

sub save_new_uploaded_plateconf_file {
  
  my $lightweight_fh = $q->upload('new_uploaded_plateconf_file');
  my $new_uploaded_plateconf_file = $q -> param( "new_uploaded_plateconf_file" );
  my $plateconf_folder = "/home/agulati/data/plate_conf_folder";
  my $target= "";
  my $new_plateconf_file_renamed;
  
  my $error_message_plateconf_1 = "ERROR: Please upload a plateconf file and enter a suitable name for the file.";
  my $error_message_plateconf_2 = "ERROR: Please enter a suitable name for the uploaded plateconf file and upload the plateconf file again if needed."; 
  my $error_message_plateconf_3 = "ERROR: Please upload a plateconf file and enter a suitable plateconf file name again if needed.";
  
  my $set_plateconf_error = undef;
  my $processing_status = undef;
  
  #rename the newly uploaded plateconf file
  my $new_plateconf_filename = $q->param("new_plateconf_filename");
  
  if ( !$new_uploaded_plateconf_file && $new_plateconf_filename eq "e.g. plateconf_384_ver_02" ) {
    #displayErrorMessage($q, $error_message_templib);
    $set_plateconf_error = 1;
    $processing_status = 1;
  }
  elsif ( $new_uploaded_plateconf_file && $new_plateconf_filename eq "e.g. plateconf_384_ver_02" ) {
    $set_plateconf_error = 2;
    $processing_status = 1;
  }
  elsif ( !$new_uploaded_plateconf_file && $new_plateconf_filename ne "e.g. plateconf_384_ver_02" ) {
    $set_plateconf_error = 3;
    $processing_status = 1;
  }
  else{
    $set_plateconf_error = 0;
    my $new_plateconf_filename_wo_spaces = $new_plateconf_filename;
    $new_plateconf_filename_wo_spaces =~ s/\s+/_/g;
    my $new_plateconf_file_basename = $new_plateconf_filename_wo_spaces;
    $new_plateconf_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_plateconf_file_renamed = $new_plateconf_file_basename.".txt";    
    
    $target = $plateconf_folder."/".$new_plateconf_file_renamed;
    my $tmpfile_path = $plateconf_folder."/tmpfile.txt";
    
    # undef may be returned if it's not a valid file handle
    if (defined $lightweight_fh) {
      # Upgrade the handle to one compatible with IO::Handle
      my $io_handle = $lightweight_fh->handle;
    
      #save the uploaded file on the server
      open ($new_plateconf_file_renamed,'>', $target);
      if ($new_plateconf_file_renamed) {
        $set_plateconf_error = undef;
      }
      else { 
        $set_plateconf_error = 4;
        $processing_status = 1;
      }	    
      my $bytesread = undef;
      my $buffer = undef;
      while ($bytesread = $io_handle->read($buffer,1024)) {
        my $print_plateconf = print $new_plateconf_file_renamed $buffer;
        if ($print_plateconf) {
          $set_plateconf_error = undef;
        }
        else {
          $set_plateconf_error = 5;
          $processing_status = 1;
        }
      }
      close $new_plateconf_file_renamed;
      #check the current position of the filehandle and set a flag if it's still in the file
      if (tell($new_plateconf_file_renamed) ne -1) { 
       $set_plateconf_error = 6;
       $processing_status = 1;
      }   
    }
    #reformat the uploaded file
    `chmod 777 $target`;
    `tr '\r' '\n' < $target > $tmpfile_path`;
    `cp $tmpfile_path $target`;
    open IN, "<$tmpfile_path";
    open OUT, ">$target";
    while (<IN>){
      if(/\S/){
        print OUT $_;
        }
      }
    close IN;
    close OUT;
   
    my $query = $dbh->do("INSERT INTO Plateconf_file_path (
      Plateconf_file_location)
      VALUES (
      '$target')");
    my $query_handle = $dbh->prepare($query);
    $query_handle -> execute();
    if ($query_handle) {
      $set_plateconf_error = undef;
      #$PLATECONF_FILE_PATH = $target;
    }
    else {
      $set_plateconf_error = 7;
      $processing_status = 1;
    }
    
    #print $q->redirect (-uri=>"http://www.gft.icr.ac.uk/cgi-bin/2_copy_rnaidb.pl?add_new_screen=1");
  
    #if ($set_plateconf_error == 1 || $set_plateconf_error == 2 || $set_plateconf_error == 3 || $set_plateconf_error == 4 || $set_plateconf_error == 5 || $set_plateconf_error == 6 || $set_plateconf_error == 7) {
     # $processing_status = 1;
    #}
    
  } #end of else statement loop
  
  my $warning_message_plateconf_1 = "ERROR: Cannot open $target";
  my $warning_message_plateconf_2 = "ERROR: Error writing $target";
  my $warning_message_plateconf_3 = "ERROR: Cannot close $target";
  my $warning_message_plateconf_4 = "ERROR: Couldn't execute sql statement for adding new plateconf file location to the database";
  
  my $file_upload_message = $q -> param(-name => 'file_upload_message',
  			  							-value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.');

  if ($processing_status == 0 && $set_plateconf_error == 0) {
      #my $message = "NOTE: Successfully added new plateconf file: $new_plateconf_file_renamed. It can now be selected for analysis from the dropdown menu.";
      &add_new_screen($file_upload_message); 
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 1) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_plateconf_1</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 2) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_plateconf_2</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 3) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_plateconf_3</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 4) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_1</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 5) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_2</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 6) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_3</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_plateconf_error == 7) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_4</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
} #end of save_new_uploaded_plateconf_file subroutine 
  
  
  # ================================
  # Save new uploaded platelist file
  # ================================

sub save_new_uploaded_platelist_file{

  my $lightweight_fh  = $q->upload('new_uploaded_platelist_file');
  my $new_uploaded_platelist_file = $q -> param( "new_uploaded_platelist_file" );
  my $platelist_folder = "/home/agulati/data/plate_list_folder";
  my $target = "";
  my $new_platelist_file_renamed;
  
  my $error_message_platelist_1 = "ERROR: Please upload a platelist file and enter a suitable name for the file";
  my $error_message_platelist_2 = "ERROR: Please enter a suitable name for the uploaded platelist file and upload the platelist file again if needed"; 
  my $error_message_platelist_3 = "ERROR: Please upload a platelist file and enter a suitable platelist file name again if needed";
  
  my $set_platelist_error = undef;
  my $processing_status = undef;
       
  #rename the newly uploaded plateconf file
  my $new_platelist_filename = $q->param("new_platelist_filename");
  
  if ( !$new_uploaded_platelist_file && $new_platelist_filename eq "e.g. platelist_384_ver_02" ) {
    $set_platelist_error = 1;
    $processing_status = 1;
  }
  elsif ( $new_uploaded_platelist_file && $new_platelist_filename eq "e.g. platelist_384_ver_02" ) {
    $set_platelist_error = 2;
    $processing_status = 1;
  }
  elsif ( !$new_uploaded_platelist_file && $new_platelist_filename ne "e.g. platelist_384_ver_02" ) {
    $set_platelist_error = 3;
    $processing_status = 1;
  }
  else{
    $set_platelist_error = 0;
    my $new_platelist_filename_wo_spaces = $new_platelist_filename;
    $new_platelist_filename_wo_spaces =~ s/\s+/_/g;
    my $new_platelist_file_basename = $new_platelist_filename_wo_spaces;
    $new_platelist_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_platelist_file_renamed = $new_platelist_file_basename.".txt";
    
    $target = $platelist_folder."/".$new_platelist_file_renamed;
    my $tmpfile_path = $platelist_folder."/tmpfile.txt";
   
    # undef may be returned if it's not a valid file handle
    if (defined $lightweight_fh) {
      # Upgrade the handle to one compatible with IO::Handle:
      my $io_handle = $lightweight_fh->handle;

      #save the uploaded file on the server
      open ($new_platelist_file_renamed,'>',$target);
      if ($new_platelist_file_renamed) {
        $set_platelist_error = undef;
      }
      else { 
        $set_platelist_error = 4;
        $processing_status = 1;
      }	    
      my $bytesread = undef;
      my $buffer = undef;
      while ($bytesread = $io_handle->read($buffer,1024)) {
        my $print_platelist = print $new_platelist_file_renamed $buffer;
        if ($print_platelist) {
          $set_platelist_error = undef;
        }
        else {
          $set_platelist_error = 5;
          $processing_status = 1;
        }  
      }
      close $new_platelist_file_renamed;
      #check the current position of the filehandle and set a flag if it's still in the file
      if (tell($new_platelist_file_renamed) ne -1) { 
          $set_platelist_error = 6;
          $processing_status = 1;
      }
    }
    #reformat the uploaded file
    `chmod 777 $target`;
    `tr '\r' '\n'  < $target > $tmpfile_path`;
    open IN, "<$tmpfile_path";
    open OUT, ">$target";
    while (<IN>){
      if(/\S/){
        print OUT $_;
        }
      }
    close IN;
    close OUT;
    
   # `cp $tmpfile_path $target`;
  
    my $query = $dbh->do("INSERT INTO Platelist_file_path (
      Platelist_file_location)
      VALUES (
      '$target')");
    my $query_handle = $dbh->prepare($query);
    $query_handle -> execute();
    if ($query_handle) {
      $set_platelist_error = undef;
      #$PLATELIST_FILE_PATH = $target;
    }
    else {
      $set_platelist_error = 7;
      $processing_status = 1;
    }
   } #end of else loop
  
  my $warning_message_platelist_1 = "ERROR: Cannot open $target";
  my $warning_message_platelist_2 = "ERROR: Error writing $target";
  my $warning_message_platelist_3 = "ERROR: Cannot close $target";
  my $warning_message_platelist_4 = "ERROR: Couldn't execute sql statement for adding new platelist file location to the database";
  
  my $file_upload_message = $q -> param(-name => 'file_upload_message',
  			  							-value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.');

  
  if ($processing_status == 0 && $set_platelist_error == 0) {
      #my $message = "NOTE: Successfully added new platelist file: $new_platelist_file_renamed. It can now be selected for analysis from the dropdown menu.";
      &add_new_screen($file_upload_message); 
  }
  elsif ($processing_status == 1 && $set_platelist_error == 1) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_platelist_1</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_platelist_error == 2) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_platelist_2</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_platelist_error == 3) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_platelist_3</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>"; 
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_platelist_error == 4) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_1</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_platelist_error == 5) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_2</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_platelist_error == 6) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_3</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_platelist_error == 7) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_4</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
} #end of save_new_uploaded_platelist_file subroutine
  
  
  # ================================
  # Save new uploaded library file
  # ================================
       
sub save_new_uploaded_templib_file{

  my $lightweight_fh  = $q->upload('new_uploaded_templib_file');
  my $new_uploaded_templib_file = $q -> param( "new_uploaded_templib_file" );
  my $templib_folder = "/home/agulati/data/template_library_folder";
  my $target = "";
  my $new_templib_file_renamed;
  
  my $error_message_templib_1 = "ERROR: Please upload a template library file and enter a suitable name for the file";
  my $error_message_templib_2 = "ERROR: Please enter a suitable name for the uploaded template library file and upload the template library file again if needed"; 
  my $error_message_templib_3 = "ERROR: Please upload a template library file and enter a suitable template library file name again if needed";
  
  my $set_templib_error = undef;
  my $processing_status = undef;
  
  #rename the newly uploaded plateconf file
  my $new_templib_filename = $q->param("new_templib_filename");
  
  if ( !$new_uploaded_templib_file && $new_templib_filename eq "e.g. KS_TS_DR_x_y_z_template" ) {
    $set_templib_error = 1;
    $processing_status = 1;
  }
  elsif ( $new_uploaded_templib_file && $new_templib_filename eq "e.g. KS_TS_DR_x_y_z_template" ) {
    $set_templib_error = 2;
    $processing_status = 1;
  }
  elsif ( !$new_uploaded_templib_file && $new_templib_filename ne "e.g. KS_TS_DR_x_y_z_template") {
    $set_templib_error = 3;
    $processing_status = 1;
  }
  else{
    $set_templib_error = 0;
    my $new_templib_filename_wo_spaces = $new_templib_filename;
    $new_templib_filename_wo_spaces =~ s/\s+/_/g;
    my $new_templib_file_basename = $new_templib_filename_wo_spaces;
    $new_templib_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_templib_file_renamed = $new_templib_file_basename.".txt";
    
    $target = $templib_folder."/".$new_templib_file_renamed;
    my $tmpfile_path = $templib_folder."/tmpfile.txt";  

    # undef may be returned if it's not a valid file handle
    if (defined $lightweight_fh) {
      # Upgrade the handle to one compatible with IO::Handle:
      my $io_handle = $lightweight_fh->handle;
      
      #save the uploaded file on the server
      open ($new_templib_file_renamed,'>',$target);
      if ($new_templib_file_renamed) {
        $set_templib_error = undef;
        #$TEMPLIB_FILE_PATH = $target;
     }
      else { 
        $set_templib_error = 4;
        $processing_status = 1;
      }	      
      my $bytesread = undef;
      my $buffer = undef;
      while ($bytesread = $io_handle->read($buffer,1024)) {
        my $print_templib = print $new_templib_file_renamed $buffer;
        if ($print_templib) {
          $set_templib_error = undef;
        }
        else {
          $set_templib_error = 5;
          $processing_status = 1;
        } 
      }
      close $new_templib_file_renamed;
      #check the current position of the filehandle and set a flag if it's still in the file
      if (tell($new_templib_file_renamed) ne -1) { 
        $set_templib_error = 6;
        $processing_status = 1;
      }    
    }
    #reformat the uploaded file
    `chmod 777 $target`;
    `tr '\r' '\n'  < $target > $tmpfile_path`;
    open IN, "< $tmpfile_path";
    open OUT, "> $target";
    while (<IN>){
      if(/\S/){
        print OUT $_;
        }
      }
    close IN;
    close OUT;
  
    my $query = $dbh->do("INSERT INTO Template_library_file_path (
      Template_library_file_location)
      VALUES (
      '$target')");
    my $query_handle = $dbh->prepare($query);
    $query_handle -> execute();
    if ($query_handle) {
      $set_templib_error = undef;
      #$TEMPLIB_FILE_PATH = $target;
    }
    else {
      $set_templib_error = 7;
      $processing_status = 1;
    }
  } #end of else loop
  
  my $warning_message_templib_1 = "ERROR: Cannot open $target";
  my $warning_message_templib_2 = "ERROR: Error writing $target";
  my $warning_message_templib_3 = "ERROR: Cannot close $target";
  my $warning_message_templib_4 = "ERROR: Couldn't execute sql statement for adding new template library file location to the database";
  
  my $file_upload_message = $q -> param(-name => 'file_upload_message',
  			  							-value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.');
  
  if ($processing_status == 0 && $set_templib_error == 0) {
      #my $message = "NOTE: Successfully added new template library file: $new_templib_file_renamed. It can now be selected for analysis from the dropdown menu.";
      &add_new_screen($file_upload_message); 
  }
  elsif ($processing_status == 1 && $set_templib_error == 1) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_templib_1</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_templib_error == 2) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_templib_2</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_templib_error == 3) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_templib_3</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_templib_error == 4) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<p><b><div id=\"Message\">$warning_message_templib_1</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_templib_error == 5) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_templib_2</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_templib_error == 6) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_templib_3</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ($processing_status == 1 && $set_templib_error == 7) {
    
    print $q -> header ("text/html");
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_templib_4</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
} #end of save_new_uploaded_templib_file subroutine
  

# ==================================
# Subroutine for showing all screens
# ==================================
 
sub show_all_screens{ 
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Available screens:</h1>";
  
  #my $query = "SELECT
   # Rnai_screen_info.Rnai_screen_info_ID,
   # Rnai_screen_info.Rnai_screen_name,
   # Rnai_screen_info.Cell_line,
   # Tissue_type.Tissue_of_origin,
   # Rnai_screen_info.Operator,
   # Rnai_screen_info.Date_of_run,
   # Transfection_reagent_used.Transfection_reagent,
   # Rnai_screen_info.Rnai_template_library,
   # Rnai_screen_info.Plate_list_file_name,
  #  Rnai_screen_info.Plate_conf_file_name,
  #  Instrument_used.Instrument_name,
  #  Rnai_screen_info.Is_isogenic,
  #  Rnai_screen_info.Gene_name_if_isogenic,
  #  (SELECT Name_of_set_if_isogenic.Name_of_set_if_isogenic FROM Name_of_set_if_isogenic WHERE Name_of_set_if_isogenic.Name_of_set_if_isogenic = 'NA' AND Name_of_set_if_isogenic.Name_of_set_if_isogenic_ID = '4' UNION ALL
  #  SELECT Name_of_set_if_isogenic.Name_of_set_if_isogenic FROM Name_of_set_if_isogenic, Rnai_screen_info WHERE Name_of_set_if_isogenic.Name_of_set_if_isogenic_ID = Rnai_screen_info.Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID),
  #  Rnai_screen_info.Isogenic_mutant_description,
  #  Rnai_screen_info.Method_of_isogenic_knockdown,
  #  Rnai_screen_info.Rnai_screen_quality_control,
  #  Rnai_screen_info.Rnai_screen_link_to_report FROM
  #  Rnai_screen_info,
  #  Transfection_reagent_used,
  #  Instrument_used,
  #  Tissue_type WHERE
  #  Rnai_screen_info.Transfection_reagent_used_Transfection_reagent_used_ID = Transfection_reagent_used.Transfection_reagent_used_ID AND
  #  Rnai_screen_info.Instrument_used_Instrument_used_ID = Instrument_used.Instrument_used_ID AND
  #  Rnai_screen_info.Tissue_type_Tissue_type_ID = Tissue_type.Tissue_type_ID GROUP BY
  #  Rnai_screen_info.Rnai_screen_info_ID";
  
   my $query = "SELECT
    r.Rnai_screen_info_ID,
    r.Rnai_screen_name,
    r.Cell_line,
    t.Tissue_of_origin,
    r.Operator,
    r.Date_of_run,
    u.Transfection_reagent,
    r.Rnai_template_library,
    r.Plate_list_file_name,
    r.Plate_conf_file_name,
    i.Instrument_name,
    r.Is_isogenic,
    r.Gene_name_if_isogenic,
    (SELECT n.Name_of_set_if_isogenic FROM Name_of_set_if_isogenic n WHERE n.Name_of_set_if_isogenic = 'NA'),
    r.Isogenic_mutant_description,
    r.Method_of_isogenic_knockdown,
    r.Rnai_screen_quality_control,
    r.Rnai_screen_link_to_report FROM
    Rnai_screen_info r,
    Transfection_reagent_used u,
    Instrument_used i,
    Tissue_type t,
    Name_of_set_if_isogenic n WHERE
    r.Transfection_reagent_used_Transfection_reagent_used_ID = u.Transfection_reagent_used_ID AND
    r.Instrument_used_Instrument_used_ID = i.Instrument_used_ID AND
    r.Tissue_type_Tissue_type_ID = t.Tissue_type_ID AND
    r.Is_isogenic = 'NO' AND
    r.Gene_name_if_isogenic = 'NA' AND
    r.Isogenic_mutant_description = 'NA' AND
    r.Method_of_isogenic_knockdown = 'NA' AND
    r.Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID = '4' GROUP BY
    r.Rnai_screen_info_ID UNION ALL SELECT
    r.Rnai_screen_info_ID,
    r.Rnai_screen_name,
    r.Cell_line,
    t.Tissue_of_origin,
    r.Operator,
    r.Date_of_run,
    u.Transfection_reagent,
    r.Rnai_template_library,
    r.Plate_list_file_name,
    r.Plate_conf_file_name,
    i.Instrument_name,
    r.Is_isogenic,
    r.Gene_name_if_isogenic,
    n.Name_of_set_if_isogenic,
    r.Isogenic_mutant_description,
    r.Method_of_isogenic_knockdown,
    r.Rnai_screen_quality_control,
    r.Rnai_screen_link_to_report FROM
    Rnai_screen_info r,
    Transfection_reagent_used u,
    Instrument_used i,
    Tissue_type t,
    Name_of_set_if_isogenic n WHERE
    r.Transfection_reagent_used_Transfection_reagent_used_ID = u.Transfection_reagent_used_ID AND
    r.Instrument_used_Instrument_used_ID = i.Instrument_used_ID AND
    r.Tissue_type_Tissue_type_ID = t.Tissue_type_ID AND
    r.Is_isogenic = 'YES' AND
    r.Gene_name_if_isogenic != 'NA' AND
    r.Isogenic_mutant_description != 'NA' AND
    r.Method_of_isogenic_knockdown != 'NA' AND
    n.Name_of_set_if_isogenic_ID != '4' AND
    r.Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID = n.Name_of_set_if_isogenic_ID GROUP BY 
    r.Rnai_screen_info_ID";
    
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
    
  print "<table>";
  
  print "<th>";
  print "RNAi screen number";
  print "</th>";
  
  print "<th>";
  print "RNAi screen name";
  print "</th>";
  
  print "<th>";
  print "Cell line name";
  print "</th>";
  
  print "<th>";
  print "Tissue of origin";
  print "</th>";

  print "<th>";
  print "Operator";
  print "</th>";
  
  print "<th>";
  print "Date of run";
  print "</th>";
  
  print "<th>";
  print "Transfection reagent";
  print "</th>";
  
  print "<th>";
  print "Rnai_library name";
  print "</th>";
  
  print "<th>";
  print "Platelist file name";
  print "</th>";

  print "<th>";
  print "Plateconf file name";
  print "</th>";

  print "<th>";
  print "Instrument name";
  print "</th>";

  print "<th>";
  print "Is isogenic or not";
  print "</th>";
  
  print "<th>";
  print "Gene name if isogenic";
  print "</th>";
  
  print "<th>";
  print "Name of set if isogenic";
  print "</th>";
   
  print "<th>";
  print "Isogenic mutant description";
  print "</th>";
  
  print "<th>";
  print "Method of isogenic knockdown";
  print "</th>";
  
  print "<th>";
  print "RNAi screen quality control";
  print "</th>";
  
  print "<th>";
  print "Link to report";
  print "</th>";
 
  while (my @row = $query_handle->fetchrow_array){
  
    print "<tr>";
   # print join("\t", @row), "\n";
    
    print "<td>";
    print "$row[0]";
    print "</td>"; 
    
    print "<td>";
    print "$row[1]";
    print "</td>"; 
    
    print "<td>";
    print "$row[2]";
    print "</td>"; 
    
    print "<td>";
    print "$row[3]";
    print "</td>"; 
    
    print "<td>";
    print "$row[4]";
    print "</td>"; 
    
    print "<td>";
    print "$row[5]";
    print "</td>"; 
    
    print "<td>";
    print "$row[6]";
    print "</td>"; 
     
    print "<td>";
    print "$row[7]";
    print "</td>"; 
    
    print "<td>";
    print "$row[8]";
    print "</td>"; 
    
    print "<td>";
    print "$row[9]";
    print "</td>"; 
    
    print "<td>";
    print "$row[10]";
    print "</td>"; 
    
    print "<td>";
    print "$row[11]";
    print "</td>"; 
    
    print "<td>";
    print "$row[12]";
    print "</td>"; 
    
    print "<td>";
    print "$row[13]";
    print "</td>";
    
    print "<td>";
    print "$row[14]";
    print "</td>";
    
    print "<td>";
    print "$row[15]";
    print "</td>"; 
    
    print "<td>";
    print "$row[16]";
    print "</td>";   
    
    print "<td>";
    print "<a href=\"$row[17]\" >'$row[17]'</a>";
    print "</td>"; 
    
    print "</tr>";

  } #end of while loop
  
  print "</table>";
 
  print "$page_footer";
  print $q -> end_html;

} #end of show_all_screens subroutine


# =======================
# Test configure export
# =======================

sub test_configure_export{
  print $q -> header("text/html");
  print "$page_header";
  print "<h1>Test_configure_export:</h1>";
  
  #print "<table>";
  #print "<th>";
  #print ;
  #print "</th>";
  #print "</table>";

  ## retrieve library_gene names from the database and save them in a hash ##
  
  my $query = ("SELECT 
    CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib) FROM 
    Template_library_file l WHERE 
    l.Gene_symbol_templib IS NOT NULL AND        
    l.Gene_symbol_templib != 'unknown' AND            
    l.Gene_symbol_templib != 'sicon1' AND            
    l.Gene_symbol_templib != 'plk1' AND           
    l.Gene_symbol_templib != 'Plk1' AND
    l.Gene_symbol_templib != 'siPLK1' AND            
    l.Gene_symbol_templib != 'MOCK' AND            
    l.Gene_symbol_templib != 'sicon2' AND            
    l.Gene_symbol_templib != 'siCON2' AND           
    l.Gene_symbol_templib != 'allSTAR' AND            
    l.Gene_symbol_templib != 'siCON1' AND            
    l.Gene_symbol_templib != 'allstar' AND            
    l.Gene_symbol_templib != 'empty' AND            
    l.Gene_symbol_templib != 'NULL' AND
    l.Sub_lib IS NOT NULL GROUP BY  
    CONCAT(Sub_lib, '_', Gene_symbol_templib)");
  
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  
 # print "<table>";
  
  my %lib_gene_h;
  my @lib_genes;
  my $lib_gene;
  
  while (@lib_genes = $query_handle->fetchrow_array){
  
    $lib_gene_h{$lib_genes[0]} = 2;
    
  }
 #   print "<th>";
 #   print %lib_gene_h;
 #   print "</th>";

 # print "</table>";
    
  ## retrieve cell lines from the database and save them in a hash ##
  
  my $query = ("SELECT 
   r.Cell_line FROM 
   Rnai_screen_info r, 
   Summary_of_result s, 
   Template_library t WHERE
   r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND 
   r.Template_library_Template_library_ID = t.Template_library_ID GROUP BY 
   r. Rnai_screen_info_ID");
   
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  
  my %cell_line_h;
  my @cell_lines;
  my $cell_line;
  while (@cell_lines = $query_handle->fetchrow_array){
 
    $cell_line_h{$cell_lines[0]} = 3; 
    
 } 
  
  ## retrieve zscores for each cell line from the database and save them in a hash ##
  
  my $query = ("SELECT
    CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib),
    r.Cell_line, 
    s.Zscore_summary FROM 
    Rnai_screen_info r, 
    Summary_of_result s, 
    Template_library_file l WHERE 
    r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND
    r.Template_library_Template_library_ID = s.Template_library_Template_library_ID AND 
    CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib) = CONCAT(l.Sub_lib, '_', s.Gene_id_summary) AND
    s.Zscore_summary != 'NA' AND
    l.Gene_symbol_templib IS NOT NULL AND        
    l.Gene_symbol_templib != 'unknown' AND           
    l.Gene_symbol_templib != 'sicon1' AND           
    l.Gene_symbol_templib != 'plk1' AND           
    l.Gene_symbol_templib != 'Plk1' AND
    l.Gene_symbol_templib != 'siPLK1' AND             
    l.Gene_symbol_templib != 'MOCK' AND          
    l.Gene_symbol_templib != 'sicon2' AND           
    l.Gene_symbol_templib != 'siCON2' AND           
    l.Gene_symbol_templib != 'allSTAR' AND            
    l.Gene_symbol_templib != 'siCON1' AND            
    l.Gene_symbol_templib != 'allstar' AND           
    l.Gene_symbol_templib != 'empty' AND            
    l.Gene_symbol_templib != 'NULL' AND
    l.Sub_lib IS NOT NULL GROUP BY 
    s.Summary_of_result_ID");
  
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();

  my %zscore_h;
  my @zscores;
 
  @lib_genes = keys %lib_gene_h;
  @cell_lines = keys %cell_line_h; 
  
  open OUT, "> /home/agulati/data/New_screens_from_July_2014_onwards/configure_export.txt";
  my @header = sort @lib_genes;
  print OUT "CELL LINE/TARGET\t"."@header\t";
  print OUT "\n";
  
  while (@zscores = $query_handle->fetchrow_array){
    $zscore_h{$zscores[0].$zscores[1]} = $zscores[2];
  }
  foreach $cell_line(@cell_lines){
    print OUT "$cell_line\t";
    foreach $lib_gene(sort @lib_genes){
      if (exists ($zscore_h{$lib_gene.$cell_line})){
        print OUT "$zscore_h{$lib_gene.$cell_line}\t"; 
      }
      else {
        print OUT "NA\t";
      }
    }
  }
  print "\n";
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of test_configure_export subroutine


# =================================
# Subroutine for configuring export  
# =================================

sub configure_export{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Export options:</h1>";
  
  # display a page with some
  # export options and a button
  # to run the export
  
  ## retrieve zscores for each cell line from the database and save them in a hash ##
  
  my $query = ("SELECT 
    s.Zscore_summary FROM 
    Rnai_screen_info r, 
    Summary_of_result s, 
    Template_library_file l WHERE 
    r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND
    r.Template_library_Template_library_ID = s.Template_library_Template_library_ID AND 
    CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib) = CONCAT(l.Sub_lib, '_', s.Gene_id_summary) AND
    s.Zscore_summary != 'NA' AND
    l.Gene_symbol_templib IS NOT NULL AND        
    l.Gene_symbol_templib != 'unknown' AND           
    l.Gene_symbol_templib != 'sicon1' AND           
    l.Gene_symbol_templib != 'plk1' AND           
    l.Gene_symbol_templib != 'Plk1' AND
    l.Gene_symbol_templib != 'siPLK1' AND             
    l.Gene_symbol_templib != 'MOCK' AND          
    l.Gene_symbol_templib != 'sicon2' AND           
    l.Gene_symbol_templib != 'siCON2' AND           
    l.Gene_symbol_templib != 'allSTAR' AND            
    l.Gene_symbol_templib != 'siCON1' AND            
    l.Gene_symbol_templib != 'allstar' AND           
    l.Gene_symbol_templib != 'empty' AND            
    l.Gene_symbol_templib != 'NULL' AND
    l.Sub_lib IS NOT NULL GROUP BY 
    s.Summary_of_result_ID");
  
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  
  #print "<table>";
  
  my %zscore = ();
  my @zscores;
  my $zscore;
  while (my @row = $query_handle->fetchrow_array){
    push(@zscores, @row);
    #@zscores = keys %zscores; 
  }
 foreach $zscore(@zscores){
   #$zscores{$zscore} = 4;
      #print "<th>";
      #print $zscores{$zscore};
      $zscore = $zscore; 
  }
  
  ## retrieve library_gene names from the database and save them in an array ##
  
  my $query = ("SELECT 
    CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib) FROM 
    Template_library_file l WHERE 
    l.Gene_symbol_templib IS NOT NULL AND        
    l.Gene_symbol_templib != 'unknown' AND            
    l.Gene_symbol_templib != 'sicon1' AND            
    l.Gene_symbol_templib != 'plk1' AND           
    l.Gene_symbol_templib != 'Plk1' AND
    l.Gene_symbol_templib != 'siPLK1' AND            
    l.Gene_symbol_templib != 'MOCK' AND            
    l.Gene_symbol_templib != 'sicon2' AND            
    l.Gene_symbol_templib != 'siCON2' AND           
    l.Gene_symbol_templib != 'allSTAR' AND            
    l.Gene_symbol_templib != 'siCON1' AND            
    l.Gene_symbol_templib != 'allstar' AND            
    l.Gene_symbol_templib != 'empty' AND            
    l.Gene_symbol_templib != 'NULL' AND
    l.Sub_lib IS NOT NULL GROUP BY  
    CONCAT(Sub_lib, '_', Gene_symbol_templib)");
  
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  
  print "<table>";
  
  my %lib_genes = ();
  my @lib_genes;
  my $lib_genes;
  while ($lib_genes = $query_handle->fetchrow_hashref){ 
    for (keys %$lib_genes){
    
      print "<th>";
      print "$zscore{$$lib_genes{$_}}\n";
      print "</th>";
    }
  }
 #foreach $lib_gene(@lib_genes){
   #$lib_genes{$lib_gene} = 1;
   #print "<th>";
   #print $lib_genes{$lib_gene};
   #print "</th>";
  #}
 
  #  $hash{$lib_genes} = $zscores;
  #print "</table>";
  #@lib_genes = keys %hash;
  #@zscores = values %hash;
  
  #foreach $lib_genes(keys %hash){
    #$zscores = $hash{$lib_genes};
    #if(exists($hash{$lib_genes})){  
      #print "<th>";
      #print "$hash{$lib_genes}";
      #print $zscores;
      #print "</th>";
    #}
    #else {
      #print "<th>";
      #print "NA";
      #print "</th>";
    #}
  #}
  
  ## retrieve cell lines from the database and save them in a hash ##
  
  my $query = ("SELECT 
   r.Cell_line FROM 
   Rnai_screen_info r, 
   Summary_of_result s, 
   Template_library t WHERE
   r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND 
   r.Template_library_Template_library_ID = t. Template_library_ID GROUP BY 
   r. Rnai_screen_info_ID");
   
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  
  #print "<table>";
  
  my %cell_lines = ();
  my @cell_lines;
  my $cell_line;
  
  while (my @row = $query_handle->fetchrow_array){
    push(@cell_lines, @row);
    #@cell_lines = keys %cell_lines; 
  }
  foreach $cell_line(@cell_lines){
    $cell_lines{$cell_line} = 2;
      #print "<th>";
      #print $cell_lines{$cell_line};
      #print "</th>";
  } 
  
  ## retrieve library_gene for each cell line from the database and save them in a hash ##
  
  my $query = ("SELECT 
    CONCAT(l.Sub_lib, '_', s.Gene_id_summary) FROM 
    Rnai_screen_info r, 
    Summary_of_result s, 
    Template_library_file l WHERE 
    r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND
    r.Template_library_Template_library_ID = s.Template_library_Template_library_ID AND 
    CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib) = CONCAT(l.Sub_lib, '_', s.Gene_id_summary) AND
    s.Zscore_summary != 'NA' AND
    l.Gene_symbol_templib IS NOT NULL AND        
    l.Gene_symbol_templib != 'unknown' AND           
    l.Gene_symbol_templib != 'sicon1' AND           
    l.Gene_symbol_templib != 'plk1' AND           
    l.Gene_symbol_templib != 'Plk1' AND
    l.Gene_symbol_templib != 'siPLK1' AND             
    l.Gene_symbol_templib != 'MOCK' AND          
    l.Gene_symbol_templib != 'sicon2' AND           
    l.Gene_symbol_templib != 'siCON2' AND           
    l.Gene_symbol_templib != 'allSTAR' AND            
    l.Gene_symbol_templib != 'siCON1' AND            
    l.Gene_symbol_templib != 'allstar' AND           
    l.Gene_symbol_templib != 'empty' AND            
    l.Gene_symbol_templib != 'NULL' AND
    l.Sub_lib IS NOT NULL GROUP BY 
    s.Summary_of_result_ID");
  
  my $query_handle = $dbh->prepare($query);
  $query_handle -> execute();
  
  #print "<table>";
  
  my %genes = ();
  my @genes;
  my $gene;
  while (my @row = $query_handle->fetchrow_array){
    push(@genes, @row); 
    #@genes = keys %genes;
  }
  foreach $gene(@genes){
    $genes{$gene} = 3;
      #print "<th>";
     # print $genes{$gene};
      #print "</th>";
  } 
  
  ##########################################################
  ###################################
  ##########################################################
  
  #print "<th>";
 # print @zscores;
 # print "</th>";
  
 #foreach $zscore(@zscores){
   #$zscores{$zscore} = 4;
      #print "<th>";
      #print $zscores{$zscore};
      #print "</th>";
  #} 
  
  my %hash = ();
  #my $i;
  #$hash{$lib_genes} = $zscores;
  #my @lib_genes = keys %hash;
 # $hash{$lib_gene}{$cell_line} = $zscore;
  
  #for($i = 0; $i <= $lib_gene; $i++){
    #$hash{$lib_gene[i]} = $zscore[i];
    
  #foreach $lib_gene(@lib_genes){
    #if(exists ($zscores{$lib_gene})){
      #print "<th>";
      #print $hash{$lib_gene}{$cell_line};
      #print "</th>";
    #}
  #}   
  
  my $i;
  my $j;
  #my %hash = ();
  #for $i(0..$#genes){
  #for($i = 0; $i <= $#genes; $i++){
    #$hash{$genes[i]} = $zscores[i];
    #keys (%hash) = @genes;
    #values (%hash) = @zscores;
   # $genes = @genes;
    #$hash{$genes} = $zscores;
    #$zscores = @zscores;
  my $lib_genes;  
  for($i = 0; $i <= keys(@lib_genes); $i++){
    #for($j = 0; $j <= keys %cell_lines; $j++){ 
        #$hash{$cell_lines[j]}{$genes[i]} = $zscores[i][j];
    #$hash{$gene[i]} = $zscore[i];
      #} 
    #} 
    #print "<th>"; 
    #print %hash;
    #print $lib_genes{$i};
    #print "</th>";
    #next;
  
  #foreach $genes($hash){
    #if(exists($zscores{$genes})){
      
    #}
   # else{
     # print "<th>"; 
    #  print "NA\t";
    #  print "</th>"; 
   # } 
 }
 # print "</table>";
  
  print "</table>";
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of configure_export subroutine


sub run_export{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Your data:</h1>";
  
  # recieve data from configure_export
  # and output data as a text file
  
  print "$page_footer";
  print $q -> end_html;
}


#################################################################################################################


sub add_new_user{
  # get user, pass and oneTimePass, hash user.pass and store
  # set a cookie then redirect to view_all_projects
  my $q = shift;
  my $user = $q -> param ('user');
  my $pass = $q -> param ('pass');
#  my $auth_code = $q -> param ('auth_code');
    
#  my $correct_auth_code = md5_hex($user . $auth_code_salt);
#  die "Failed login...\n" unless $auth_code eq $correct_auth_code;
  
  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/){
    &login("username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters");
    exit(1);
  }
  unless($pass =~ /^.{1,4096}$/){
    &login("password must not exceed 4096 characters");
  }
  
  my $user_pass_hash = md5_hex($user . $pass . $auth_code_salt);
  for(my $i = 0; $i <= $num_hash_itts; $i ++){
    my $user_pass_hash = md5_hex($user_pass_hash);
  }
  #open USERS, ">> ./users.txt" or warn "can't append to the file with user names file: $!\n";
  #print "$user\t$user_pass_hash\n";
  #close USERS;

#  &set_cookie($user_pass_hash);

  print $q -> header("text/html");
  print $q -> start_html();
  print "<h1>New User:</h1>";
  print "$user<br>$user_pass_hash<br>";
  print $q -> end_html();
  exit(0);
}
  
sub authenticate_login_key{
  my $login_key = shift;
  open USERS, "< ./users.txt" or die "can't open the file with the list of user names: $!\n";

#
#
#  print "OPENED USERS FILE...<br>";
#
#
#

  my $user = undef;
  while (<USERS>){
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
    chomp($stored_hash);
    if ($stored_hash eq /$login_key/){$user = $stored_user;}
  }
  close USERS;
  &login() unless defined($user);
  return $user;  
}
 
sub authenticate_user{
  my $q = shift;
  my $user = $q -> param('user');
  my $pass = $q -> param('pass');
  my $login_message = $q -> param('login_message');
  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/){
    die "username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters";
    exit(1);
  }
  unless($pass =~ /^.{1,4096}$/){
    die "password must not exceed 4096 characters";
  }
  my $user_pass_hash = md5_hex($user . $pass . $auth_code_salt);
  for(my $i = 0; $i <= $num_hash_itts; $i ++){
    my $user_pass_hash = md5_hex($user_pass_hash);
  }
  open USERS, "< /usr/lib/cgi-bin/users.txt" or die "can't open the file with the list of user names: $!\n";
  
#
#
#  print "OPENED USERS FILE...<br>";
#
#
#
  
  my $login_OK = 0;
  while (<USERS>){
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
    chomp($stored_hash);
    $login_OK = 1 if $stored_hash =~ /$user_pass_hash/;
  }
  close USERS;
  if ($login_OK == 1){
    &set_cookie($user_pass_hash);
    return $user;
  }
  else{
    $q -> param(
      -name => "login_message",
      -value => "Login failed - please check your username and password are correct"
    )
    &login($q);
    exit(1);
  }
}


sub login{
  my $message = $q -> param('login_message');
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>GFT RNAi Database login:</h1>\n";
  print "<p>$message</p>\n" if defined $message;
  print "<table width = 100%><tr><td align=left valign=top>";
  print $q -> startform (-method=>'POST');
  print "<p>";
  print "<b>Please log in:</b>";
  print "</p>";
  print "Username: &nbsp;&nbsp;";
  print $q -> textfield (-name => "user", -size => 20);
  print "</p>";
  print "<p>";
  print "Password: &nbsp;&nbsp;";
  print $q -> password_field (-name => "pass", -size => 20);
  print "</p>";
  print "<p>Please note - this site uses cookies...</p>\n";
  print $q -> submit (-name => "authenticate_user", -value => "login...");
  print $q -> endform;
  print "<hr />";
  print "<p>";
  print "<b>Or create a new account:</b><br>";
  print "</p>";
  print $q -> startform (-method=>'POST');
  print "<p>";
  print "username: &nbsp;&nbsp;";
  print $q -> textfield (-name => "user", -size => 20);
  print "</p>";
  print "<p>";
  print "Password: &nbsp;&nbsp;";
  print $q -> password_field (-name => "pass", -size => 20);
  print "</p>";
  print "<p>";
  print "Authentication code: &nbsp;&nbsp;";
  print $q -> textfield (-name => "auth_code", -size => 20);
  print "</p>";
  print "&nbsp;";
  print $q -> submit (-name => "add_new_user", -value => "create new account");
  print $q -> endform;
  print "</td></tr></table></div>";
  print $q -> end_html;
  exit(0);
}

sub set_cookie{
  my $login_key = shift;

  my $cookie = $q -> cookie( -name => "login_key",
                             -value => $login_key
                             );

  print $q -> redirect(
    -url => "/cgi-bin/2_copy_rnaidb.pl?add_new_screen=1",
    -cookie => $cookie
    );
  exit(0);
}

sub logout{

  my $cookie = $q -> cookie( -name => "login_key",
                             -value => "Expired",
                             -expires => "-1d"
                             );

  print $q -> redirect(
    -url => "/cgi-bin/2_copy_rnaidb.pl",
    -cookie => $cookie
    );

  exit(0);
}



