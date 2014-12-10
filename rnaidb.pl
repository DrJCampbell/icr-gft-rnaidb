#!/usr/bin/perl -w
# rnaidb.pl - CGI UI for RNAi database

use strict;
use CGI;
use CGI qw( :standard );
use CGI::Carp qw ( fatalsToBrowser );
use DBI;
use Digest::MD5 qw ( md5 md5_hex md5_base64 );
use FileHandle;
# for new file upload - fixes the error :- use string ("test_plateconf.txt") as a symbol ref while "strict refs" in use at...
no strict 'refs';
# to check if an error is due to dbi or not
use Data::Dumper;

# Get the name of the script from $0
$0 =~ /([^\/]+)$/;

my $script_name = $1;


## stuff to configure when moving... ##

my $users_file = './users.txt';
my $temp_file_path = '/tmp/tmp.csv';
my $sqldb_name = 'RNAi_analysis_database';
my $sqldb_host = 'localhost';
my $sqldb_port = '3306';
my $sqldb_user = 'internal';
my $sqldb_pass = '1nt3rnal';

## Declare variables globally ##

my $ISOGENIC_SET;
my $ADD_NEW_FILES_LINK = "http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1";

#my $username;
#my $password;
 
$| = 1;
#$|++;

#STDOUT->autoflush(1);
#STDERR->autoflush(1);

# These are needed to allow file uploads
# whilst reducing the risk of attack (someone
# uploading a huge file and filling the disk)
$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX = 1024 * 1000;
# $CGI::POST_MAX limits the max size of a post in bytes
# Note that most of the XLS files from the plate reader
# are below 500 KB

# security config
my $num_hash_itts = 500;
my $auth_code_salt = "1IwaCauw4Lxum6WU5hM8";
# The $auth_code_salt should be read in from
# a file that is generated if it doesn't exist

# HTML strings used in pages:

my $page_header = "<html>
				   <head>
				   <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
				   <title>GFT RNAi database</title>
				   <link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
				   <meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
				   </head>
				   <body>
				   <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   <a href=\"http://gft.icr.ac.uk\"><img src=\"http://www.jambell.com/sample_tracking/ICR_GFTRNAiDB_logo_placeholder.png\" width=415px height=160px></a>
				   <p>
				   <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   </p>";

# HTML strings used in add new screen:

my $tissue_file = "/home/agulati/data/screen_data/tissue_type.txt";
my $tissue_list;
my $t_l;
open IN, "< $tissue_file"
  or die "Cannot open $tissue_file:$!\n";

while (<IN>) {
  if ($_ =~ /^ADRENAL/) {
    $t_l = $tissue_list;
  }
}
$tissue_list = $_;
chomp $tissue_list;
close IN;

my $cell_line_file = "/home/agulati/data/screen_data/cell_lines.txt";
my $cell_line_list;
my $c_l;
open IN, "< $cell_line_file"
  or die "Cannot open $cell_line_file:$!\n";
while (<IN>) {
  if ($_ =~ /^1321N1/) {
    $c_l = $cell_line_list;
  }
}
$cell_line_list = $_;
chomp $cell_line_list;
close IN;

my $page_header_for_add_new_screen_sub = "<html>
				   						  <head>
				   						  <meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" />
				   						  <title>GFT RNAi database</title>
				   						  <link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
				   						  <meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" />
				   						  <link rel=\"stylesheet\" href=\"http://code.jquery.com/ui/1.11.1/themes/smoothness/jquery-ui.css\">
				    					  <script src=\"http://code.jquery.com/jquery-1.10.2.js\"></script>
				   						  <script src=\"http://code.jquery.com/ui/1.11.1/jquery-ui.js\"></script>
				   						  <script>
										   \$(function() {
	  									  var availableTissues = $tissue_list;
									      var availableCellLines = $cell_line_list;
										    \$( \"#tissues\" ).autocomplete ({
										    source: availableTissues
										    });
										    \$( \"#celllines\" ).autocomplete ({
										    source: availableCellLines
										    });
										  });									  
										  function make_tissues_Blank() {
										    var a = document.getElementById( \"tissues\" );
										    a.value = \"\";
										    }
										  function make_cellLines_Blank() {
										    var b = document.getElementById( \"celllines\" );
										    b.value = \"\";
										  }    
										  function enableText() {
										    if(document.addNewScreen.is_isogenic.checked) {
										      document.addNewScreen.gene_name_if_isogenic.disabled = false;
										      document.addNewScreen.isogenicSet.disabled = false;
										      document.addNewScreen.name_of_set_if_isogenic.disabled = false;
										      document.addNewScreen.isogenic_mutant_description.disabled = false;
										      document.addNewScreen.method_of_isogenic_knockdown.disabled = false; 
										    }
										    else {
										      document.addNewScreen.gene_name_if_isogenic.disabled = true;
										      document.addNewScreen.isogenicSet.disabled = true;
										      document.addNewScreen.name_of_set_if_isogenic.disabled = true;
										      document.addNewScreen.isogenic_mutant_description.disabled = true;
										      document.addNewScreen.method_of_isogenic_knockdown.disabled = true;
										    }
										  } 
										  function make_geneName_Blank() {
										    var c = document.getElementById( \"geneName\" );
										    c.value = \"\";
										  } 
										  function make_isogenic_Set_Blank() {
										    var d = document.getElementById( \"isogenic_Set\" );
										    d.value = \"\";
										  } 
										  function make_isogenicDescription_Blank() {
										    var e = document.getElementById( \"isogenicDescription\" );
										    e.value = \"\";
										  } 
										  function make_isogenicKnockdown_Blank() {
										    var f = document.getElementById( \"isogenicKnockdown\" );
										    f.value = \"\";
										  }  
										  function make_notes_Blank() {
										    var g = document.getElementById( \"NoteS\" );
										    g.value = \"\";
										  }  
										  </script>
				   						  </head>
				   						  <body>
				   						  <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   						  <a href=\"http://gft.icr.ac.uk\"><img src=\"http://www.jambell.com/sample_tracking/ICR_GFTRNAiDB_logo_placeholder.png\" width=415px height=160px></a>
				   						  <p>
				   						  <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   						  </p>";
				   
my $page_footer = "</div> <!-- end Main --></div> 
				   <!-- end Box -->
				   </body>
				   </html>";

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
my $login_key = $q -> cookie ( "login_key" );

# if we got a cookie, is it valid?
#my $user = &authenticate_login_key($login_key);


# connect to the database
my $dsn = "DBI:mysql:database=$sqldb_name;host=$sqldb_host;port=$sqldb_port";
my $dbh = DBI -> connect ( $dsn, $sqldb_user, $sqldb_pass, { RaiseError => 0, AutoCommit => 1 } )
  or die "Cannot connect to database: " . $DBI::errstr;
  

# Decide what to do based on the params passed to the script
if( $q -> param ( "logout" ) ) {
  &logout ( $q );
}
elsif ( $q -> param( "show_all_screens" )) {
  &show_all_screens ( $q );
}
elsif ( $q -> param( "add_new_screen" )) {
  &add_new_screen ( $q );
}
elsif ( $q -> param( "save_new_screen" )) {
  &save_new_screen ( $q );
}
elsif ( $q -> param( "add_new_files" )) {
  &add_new_files ( $q );
}
elsif ( $q -> param( "save_new_uploaded_plateconf_file" )) {
  &save_new_uploaded_plateconf_file ( $q );
}
elsif ( $q -> param ( "save_new_uploaded_platelist_file" )) {
  &save_new_uploaded_platelist_file ( $q );
}
elsif ( $q -> param ( "save_new_uploaded_templib_file" )) {
  &save_new_uploaded_templib_file ( $q );
}
elsif ( $q -> param ( "configure_export" )) {
  &configure_export ( $q );
}
elsif ( $q -> param ( "show_qc" )) {
  &show_qc ( $q );
}
elsif ( $q -> param ( "run_export" )) {
  &run_export ( $q );
}
else {
 &home ( $q );
}


# home sub for debugging

# ===================
# subroutine for home
# ===================

sub home { 
  print $q -> header ( "text/html" );
#  my $user = $q -> param('user');
  print "$page_header";

  # read data from database and output
  # summary info about all screens

  print "<h1>Hello:</h1>";
  if ( defined ( $login_key ) ) {
    print "got cookie $login_key<br />";
  }
  else {
    print "Where's my cookie?"
  }
  
  print "<p>";
  print "<p>Connected to the RNAi_analysis_database</p>";
  print "</p>";
 
  print "$page_footer";
  print $q -> end_html;
}


# ================================
# subroutine for adding new screen
# ================================

sub add_new_screen {
  print $q -> header ( "text/html" );
  my $user = $q -> param( 'user' );
  print "$page_header_for_add_new_screen_sub";
  print "<h1>Add new screen:</h1>";
  
  print $q -> start_multipart_form ( -method => "POST",
  									 -name => "addNewScreen" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  ## print a message if the new plateconf has been successfully uploaded and saved to the server ##
  
  my $file_upload_message = $q -> param ( "file_upload_message" );
  
  #$file_upload_message = shift;
  if ( defined ( $file_upload_message ) ) {
    print "<div id=\"Message\"><p><b>$file_upload_message</b></p></div>";
  }
  
  print $cell_line_list;
  print $tissue_list;
  
  ##
  ## add main screen info here ##
  ## 
 
  print "<p><b>General screen information:</b></p>";
  print "<p>";
 
  ## get the CTG excel file ##
  
  print "<p>Plate excel file:<br />";
  
  print $q -> filefield ( -name => 'uploaded_excel_file',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file" );
  print "</p>";

  ## get the existing plateconf filenames from the database and display them in the popup menu ##
  
  my $query = "SELECT Plateconf_file_location FROM Plateconf_file_path";
  my $query_handle = $dbh -> prepare( $query );
    				   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
    #or die "SQL Error: ".$query_handle->errstr();
  
  my $plateconf_path;
  my $plateconf_file_dest;
  my $plateconf_name;
  my @plateconf_path;
  
  while ( $plateconf_path = $query_handle -> fetchrow_array ){
    $plateconf_file_dest = $plateconf_path;
    $plateconf_file_dest =~ s/.*\///;
    $plateconf_name = $plateconf_file_dest;
    $plateconf_name =~ s{\.[^.]+$}{};
    
    push ( @plateconf_path, $plateconf_name );
  }
  #$query_handle -> finish();
  unshift( @plateconf_path, "Please select" );
  print "<p>Plateconf file:<br />";
  
  print $q -> popup_menu ( -name => 'plate_conf',
  						  -value => \@plateconf_path,
  						  -default => 'Please select',
  						  -id => "pconf_file" );							    		  
  print " - OR";
  #link to the form for adding new plateconf file 
  print "<p>";
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1#new_plate_conf_file\"> Add new plateconf file</a>";
  print "</p>";
  print "</p>";

  ## get the existing platelist filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Platelist_file_location FROM Platelist_file_path";
  $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
    #or die "SQL Error: " . $query_handle -> errstr();
    
  my $platelist_path;
  my $platelist_file_dest;
  my $platelist_name;
  my @platelist_path;
  
  while ( $platelist_path = $query_handle -> fetchrow_array ) {
    $platelist_file_dest = $platelist_path;
    $platelist_file_dest =~ s/.*\///;
    $platelist_name = $platelist_file_dest;
    $platelist_name =~ s{\.[^.]+$}{};
    push ( @platelist_path, $platelist_name );
  }
  #$query_handle -> finish();
  unshift ( @platelist_path, "Please select" );
  
  print "<p>Platelist file:<br />";
  
  print $q -> popup_menu ( -name => 'plate_list',
  						  -value => \@platelist_path,
   						  -default => 'Please select',
   						  -id => "plist_file" );
  
  print " - OR";
  #link to the form for adding new platelist file 
  print "<p>";  
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1#new_plate_list_file\">Add new platelist file</a>";
  print "</p>";  
  print "</p>";  	
  		
  ## get the existing template library filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Template_library_file_location FROM Template_library_file_path";
  $query_handle = $dbh -> prepare ( $query );
   					#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
    #or die "SQL Error: " . $query_handle -> errstr();
  
  my $templib_path;
  my $templib_file_dest;
  my $templib_name;
  my @templib_path;
  
  while ( $templib_path = $query_handle -> fetchrow_array ) {
    $templib_file_dest = $templib_path;
    $templib_file_dest =~ s/.*\///;
    $templib_name = $templib_file_dest;
    $templib_name =~ s{\.[^.]+$}{};
    push ( @templib_path, $templib_name );
  }
 # $query_handle -> finish();
  unshift( @templib_path, "Please select" );
  
  
  print "<p>Template library:<br />";
  
  print $q -> popup_menu ( -name => 'template_library',
  						  -value => \@templib_path,
   						  -default => 'Please select',
   						  -id => "tlib_file" );
  
  print " - OR";
  #link to the form for adding new template library file 
  print "<p>";  	
  print "<a href = \"http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1#new_plate_library_file\"> Add new template library file</a>";
  print "</p>";
  print "</p>";

  ## get new tissue type ##
  
  print "Tissue of origin:<br />";
  print $q -> textfield ( -name => "tissue_type",
                          -value => 'Please select',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_tissues_Blank()",
                          -id => "tissues" );
  print "</p><p>";

  ## get the cell line name ##
  
  print "Cell line name:<br />";
  print $q -> textfield ( -name => "cell_line_name",
                          -value => 'Enter cell line name',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_cellLines_Blank()",
                          -id => "celllines" );
  print "</p><p>";

  ## get the current date ##
  
  my ( $sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst ) = localtime ( time );
  $year += 1900;
  $mon ++;
  my $date = sprintf ( "%04u-%02u-%02u",$year,$mon,$mday ); # set this to current date using localtime()
  print "</p><p>";
  print "Date of screen:<br />";
  print $q -> textfield ( -name => "date_of_run",
                          -value => $date,
                          -size => "30",
                          -maxlength => "45" );
  print "</p><p>";
  
  ## get the user (who is logged in?) ##
  
  print "Operator:<br />";
  print $q -> textfield ( -name => "operator",
                          -value => $user,
                          -size => "30",
                          -maxlength => "45",
                          -id => "OperatoR");

  print "</p><p>Transfection reagent:<br/>"; 
    
  ## get the transfection_reagent name from the database ##
  
  my @transfection_reagent = ( "Please select", "Lipofectamine 2000", "Lipofectamine 3000", "Lipofectamine RNAi max", "Dharmafect 3", "Dharmafect 4", "Oligofectamine", "Effectene" ); 
  print $q -> popup_menu ( -name => 'transfection_reagent',
  						   -value => \@transfection_reagent,
  						   -default => 'Please select',
  						   -id => "reagent" );
  
  ## get the instrument name from the database ##
  
  print "</p><p>Instrument:<br />";
  
  my @instrument = ( "Please select", "1S10", "1C11" ); 
  print $q -> popup_menu ( -name => 'instrument',
  					       -value => \@instrument,
  						   -default => 'Please select',
  						   -id => "InstrumenT" );

  print "</td>\n";

  # ======================
  # add isogenic info here
  # ======================

  print "<td align=left valign=top>\n";
  
  print "<p><b>Isogenic screens:</b></p>";

  ## checkbox for isogenic screen ##

  print "<p>";
  
  print $q -> checkbox( -name=>'is_isogenic',
    					-checked=>0,
    					-onclick=>"enableText()",
   					    -value=>'ON',
    					-label=>'this is an isogenic screen' );

  print "</p><p>";
  
  ## enter modified gene name ##
  
  print "Modified gene name:<br />";
  print $q -> textfield ( -name => "gene_name_if_isogenic",
                          -value => 'Enter gene name',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_geneName_Blank()",
                          -id => "geneName",
                          -disabled );
  
  print "</p><p>";
   
 ## get the existing isogenic sets from the database and display them in the popup menu ##
 
 $ISOGENIC_SET = $dbh -> selectcol_arrayref ( "SELECT Name_of_set_if_isogenic FROM Name_of_set_if_isogenic WHERE Name_of_set_if_isogenic != 'NA'" )
                   or die "Cannot prepare: " . $dbh->errstr();
 unshift( $ISOGENIC_SET, "Please select" );
 
  print "<p>";

  print "<p>Select isogenic set:<br />";
    
  print $q -> popup_menu (-name =>'isogenicSet',
  						  -value => $ISOGENIC_SET,
   	                      -default =>'Please select',
   	                      -disabled );

  print " - OR";
  print "<p>";
  print "</p>";  
  
  ## enter isogenic set name ##
  
  print "Enter isogenic set:<br />";
  print $q -> textfield ( -name => "name_of_set_if_isogenic",
                          -value => 'Enter isogenic set name',                         
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_isogenic_Set_Blank()",
                          -id => "isogenic_Set",
                          -disabled );
                          
  print "</p><p>";
   
  ## get isogenic mutant description ##
  
  print "Isogenic description:<br />";
  print $q -> textfield ( -name => "isogenic_mutant_description",
                          -value => 'e.g. parental',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_isogenicDescription_Blank()",
                          -id => "isogenicDescription",
                          -disabled );
  
  print "</p><p>";  
  
  ## get method of isogenic knockout ##
  
  print "Method of isogenic mutation:<br />";
  print $q -> textfield ( -name => "method_of_isogenic_knockdown",
                          -value => 'e.g. ZFN or shRNA',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_isogenicKnockdown_Blank()",
                          -id => "isogenicKnockdown",
                          -disabled );
   
  print "</p><p>";
  print "</td>\n";                        
  
  # =========================
  # add drug screen info here
  # =========================

  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  print "<td align=left valign=top>\n";
  
  print "<p><b>Drug screens:</b></p>";

  ## checkbox for drug screen ##

  print "<p>";
  
  print $q -> checkbox( -name=>'is_drug_screen',
    					-checked=>0,
   					    -value=>'ON',
    					-label=>'this is a drug screen' );

  print "</p><p>";
  
  ##  select control from dropdown menu ##
  
  print "<p>";
  
  my @CONTROL = ( "Please select", "DMSO", "DNS" ); # this should be read from a text file or from the SQL database
  print "Control:<br />";
  print $q -> popup_menu( -name => 'Control',
  					      -value => \@CONTROL,
  						  -default => 'Please select' );
  print "</p>";
  
  ## çompound used ##
  
  print "<p>";
  
  print "Compound:<br />";
  print $q -> textfield ( -name => "compound",
                          -value => 'e.g. drug A',
                          -size => "30",
                          -maxlength => "45" );
  
  print "</p>";
                          
  ## concentration ##
  
  print "<p>";
  
  print "Concentration:<br />";
  print $q -> textfield ( -name => "concentration",
                          -value => 'e.g. 100 ng',
                          -size => "30",
                          -maxlength => "45" ); 
                          
  print "</p>";
  
  ## dosing regime ##
  
  print "<p>";
  
  print "Dosing regime:<br />";
  print $q -> textfield ( -name => "dosing regime",
                          -value => 'e.g. 24 hrs after transfection',
                          -size => "30",
                          -maxlength => "45" ); 
    
  print "</p>";                       
                                                            
  ## put notes text field for drug screen ##

 #print "<td align=left valign=centre>\n";
  
  print "<p></p>";
  print "</p></p>";
  print "Notes about the drug screen:<br />";
  print $q -> textarea ( -name => "drug_screen_notes",
                         -default => 'write notes for drug screen',
                         -rows => "8",
                         -columns => "40" );                              
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n"; 
  
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";
  print "</td>\n";                  
  
  ## put notes text field for new screen and submit button here ##
  
  print "<tr colspan=2>\n";
  print "<td align=left valign=top>\n";

  ## Enter information to store in the Description.txt file ##

  print "<p>";
  print "Notes about this screen:<br />";
  print $q -> textarea ( -name => "notes",
                         -default => 'write notes for Description.txt',
                         -rows => "8",
                         -columns => "40",
                         -onClick => "make_notes_Blank()",
                         -id => "NoteS" );
  print "</p>";                       
  ## submit the form ##
                                                
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Analyse and save results\" name=\"save_new_screen\" />";
  print "</p>";
  
  ## button for viewing all screens ##
  
  #print "<p>";
  #print "<input type=\"submit\" id=\"show_all_screens\" value=\"Show all analysed RNAi screens\" name=\"show_all_screens\" />";
  #print "</p>";
  
  print "</td>\n";
  
  print "</tr>\n";
  
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;
                                                                          
} #end of add_new_screen subroutine


  # =================================================================================
  # Subroutine for downloading/uploading new/edited plateconf/platelist/library files
  # =================================================================================

sub add_new_files {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Add new file(s):</h1>";
  
  ## Downloading/uploading plateconf file ##
  
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_conf_file\"><p><b>Upload new plateconf file:</b></p>";
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
  
  print $q -> filefield ( -name=>'new_uploaded_plateconf_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
  
  ## enter new plateconf file name ##
  
  print "<p>Enter new plateconf file name:<br />";
  print "<p></p>";
  
  print $q -> textfield ( -name => "new_plateconf_filename",
                          -value => 'e.g. plateconf_384_ver_02',
                          -size => "30",
                          -maxlength => "45" );

  print "<p></p>";
  
  print"<p><div id=\"Note\">NOTE: Please make sure that the name of the new uploaded plateconf file is unique and different from the names of existing plateconf files. The words in the filename must be joined with an underscore ( _ ). For example, an edited 'Plateconf_384' file can be renamed as 'Plateconf_384_ver_02' or 'Plateconf_384_edited_Aug-2014'.</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user ## a way to have web forms to remember previous information 
  
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
  
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_list_file\"><p><b>Upload new platelist file:</b></p>";
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
  
  print $q -> filefield ( -name=>"new_uploaded_platelist_file",
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
  
  ## enter new platelist file name ##
  
  print "<p>Enter new platelist file name:<br />";
  print "<p></p>";
   
  print $q -> textfield ( -name => "new_platelist_filename",
                          -value => 'e.g. platelist_384_ver_02',
                          -size => "30",
                          -maxlength => "45" ); 
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

  print "<a name=\"new_plate_library_file\"><p><b>Upload new template library file:</b></p>";
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
                         -maxlength=>256 );
  print "</p>";
  
  #enter new template library file name
  print "<p>Enter new template library file name:<br />";
  print "<p></p>";

  print $q -> textfield ( -name => "new_templib_filename",
                          -value => 'e.g. KS_TS_DR_x_y_z_template', 
                          -size => "30",
                          -maxlength => "45" );  
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

sub save_new_screen {
  print $q -> header ( "text/html" );
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
  my $sicon1 = $q -> param( "sicon1_empty" );
  my $sicon2 = $q -> param( "sicon2_empty" );
  my $allstar = $q -> param( "allstar_empty" );
  my $excelFile = $q->param( "uploaded_excel_file" ); 
  
  ################################################[[[get params to check the previous page is working as expected]]]
  
  ################################################[[[my $tmp_file_path = "/home/agulati/data/tmp_file";]]]

  ## match plateconf name, selected from the drop down menu, to the file and store it in a variable ##
  
  my $plateconf = $q -> param( "plate_conf" );
  my $plateconf_file_path;
  my $plateconf_target;
  
  ## match platelist name, selected from the drop down menu, to the file and store it in a variable ##   
      
  my $platelist = $q -> param( "plate_list" );
  my $platelist_file_path;
  my $platelist_target;
  my $platelist_tmp_file;
  my $platelist_prefix;

  ## match templib name, selected from the drop down menu, to the file and store it in a variable ##

  my $templib = $q -> param( "template_library" );
  my $templib_file_path;
  my $templib_target;
  
  ## New screen directory - name and location ##
  
  my $screen_dir_name = $q -> param( "screen_dir_name" );
  my $screenDescription_filename;
  my $guide_file;
  
  if ( not defined ( $screen_dir_name ) ) {
    $screen_dir_name = $tissue_type."_".$cell_line_name."_".$templib."_".$date_of_run;
  }
  my $screenDir_path = "/home/agulati/data/screen_data";
  my $file_path = "$screenDir_path/$screen_dir_name";
  
  if (( -e $file_path ) && ( $sicon1 ne 'ON' ) && ( $sicon2 ne 'ON' ) && ( $allstar ne 'ON' )) {
     die "Cannot make new RNAi screen directory $screen_dir_name in $screenDir_path: $!"; 
   }
  
  if ( ! -e $file_path ) {
    mkdir( "$file_path" );
    `chmod -R 777 $file_path`;
    `chown -R agulati:agulati $file_path`;
      
    print "<p><div id=\"Note\">Created new screen directory...</div></p>";
    
    ## add screen directory name as prefix to all the filenames in the selected platelist file ##

    $plateconf_file_path = "/home/agulati/data/plate_conf_folder/".$plateconf.".txt";
    $plateconf_target = $file_path."/".$screen_dir_name."_".$plateconf.".txt";
    `cp $plateconf_file_path $plateconf_target`;
    
    print "<p><div id=\"Note\">Selected plateconf file saved in the new screen directory...</div></p>";  
  
    ## match platelist name, selected from the drop down menu, to the file and store it in a variable ##   
      
    $platelist_file_path = "/home/agulati/data/plate_list_folder/".$platelist.".txt";
    $platelist_target = $file_path."/".$screen_dir_name."_".$platelist.".txt";
    `cp $platelist_file_path $platelist_target`;
    $platelist_tmp_file = $file_path."/tmp_platelist_file.txt";
    
    print "<p><div id=\"Note\">Selected platelist file saved in the new screen directory...</div></p>";  
  
    $platelist_prefix = $screen_dir_name."_";
  
    open IN, "< $platelist_target"
      or die "Cannot open $platelist_target:$!\n";
    open OUT, "> $platelist_tmp_file"
      or die "Cannot open $platelist_tmp_file:$!\n";
    while (<IN>) {
      if ($_ =~ /^Filename/) {
        print OUT $_;
      }
      else{
        print OUT $platelist_prefix.$_;
      }
    }
    close IN;
    close OUT; 
    `mv $platelist_tmp_file $platelist_target`;
    
    ## match templib name, selected from the drop down menu, to the file and store it in a variable ##

    $templib_file_path = "/home/agulati/data/template_library_folder/".$templib.".txt";
    $templib_target = $file_path."/".$screen_dir_name."_".$templib.".txt"; 
    `cp $templib_file_path $templib_target`; 
    
    print "<p><div id=\"Note\">Selected template library file saved in the new screen directory...</div></p>";  
  
  ############################################[[[probably need to copy $temp_file_path somewhere safe and give it to an R script to convert]]]
  
    ## Upload excel file and save it to new screen directory ##
  
    my $lightweight_fh  = $q -> upload ( 'uploaded_excel_file' );
    #unless ( $excelFile =~ /(xls)$/ ) {
    #  `rm -r $file_path`;
    #  print "<div id=\"Message\"><p>ERROR: Please upload a valid excel file for analysis.</p></div>";
    #  print "<p>Deleted new screen directory: $screen_dir_name.</p>";
     # die "Please upload a valid excel file for analysis.";
      
    #}

    my $target = $file_path."/".$excelFile;
    # undef may be returned if it's not a valid file handle
  
    if ( defined $lightweight_fh ) {
    # Upgrade the handle to one compatible with IO::Handle:
      my $io_handle = $lightweight_fh->handle;
 
      open ( $excelFile,'>',$target )
        or die "Cannot move $excelFile to $target:$!\n";
      
      my $bytesread = undef;
      my $buffer = undef;
    
      while ( $bytesread = $io_handle -> read ( $buffer,1024 ) ) {
        print $excelFile $buffer
          or die "Error writing '$target' : $!";
      }
      close $excelFile
        or die "Error writing '$target' : $!";
      }
      #else {
       # `rm -r $file_path`;
       # die "Please upload the excel file.";
      #}
    
      ## rename uploaded excel file ##
      my $new_xls_file = rename ( $file_path."/".$excelFile, $file_path."/".$screen_dir_name.".xls" ) or die "Cannot rename $excelFile :$!";
      
      print "<p>";
      print "<p><div id=\"Note\">Renamed excel file saved in the screen directory...</div></p>";
      print "</p>"; 
    
  ###############################################[[[either copy the platelist/palteconf/library etc to the new screen folder or use symlinks to point to the templates]]]
  
    ## write $notes to a 'Description.txt' file ##
  
    my $descripFile = $file_path."/".$screen_dir_name."_Description.txt";
    open NOTES, "> $descripFile" 
      or die "Cannot write notes to $descripFile:$!\n";
    print NOTES $notes;
    $screenDescription_filename = $screen_dir_name."_Description.txt";
    close NOTES;
    
    print "<p><div id=\"Note\">Created 'Description.txt' file in the new screen directory...</div></p>";  
  
    ## Add new screen info to Guide file ##
  
    $guide_file = $screen_dir_name."_guide_file.txt";
  
    open GUIDEFILE, '>', $file_path."/".$guide_file 
      or die "Cannot open $file_path:$!\n";
    
    print GUIDEFILE 
      "Cell_line\t", 
      "Datapath\t", 
      "Template_library_file\t", 
      "Platelist_file\t", 
      "Plateconf_file\t", 
      "Descrip_file\t", 
      "report_html\t", 
      "zscore_file\t", 
      "summary_file\t", 
      "zprime_file\t", 
      "reportdir_file\t", 
      "xls_file\t", 
      "qc_file\t", 
      "corr_file\n"; 
  
    print GUIDEFILE 
      "$cell_line_name\t", 
      "$file_path\t", 
      "$templib_target\t", 
      "$platelist_target\t", 
      "$plateconf_target\t", 
      "$screenDescription_filename\t", 
      "TRUE\t", 
      "$screen_dir_name"."_zscores.txt\t", 
      "$screen_dir_name"."_summary.txt\t", 
      "$screen_dir_name"."_zprime.txt\t", 
      "$screen_dir_name"."_reportdir\t", 
      "$screen_dir_name".".xls\t", 
      "$screen_dir_name"."_controls_qc.png\t", 
      "$screen_dir_name"."_corr.txt\n";  
  
    print "<p><div id=\"Note\">Created guide file...</div></p>";
    print "<p><div id=\"Note\">Analysing...</div></p>"; 
      
    close (GUIDEFILE); 
    }
    
  ## Reanalysis ##
    
    if (( -e $file_path ) && ( $sicon1 eq 'ON' )) {
      @ARGV = glob ( $file_path."/".$screen_dir_name."_".$plateconf.".txt" );
      $^I = "";
      while ( <> ) {
        s/(\s)siCON1([\n\r])/$1empty$2/g;
        print;
      }
      print "<p><div id=\"Note\">Reanalysing with updated plateconf file...</div></p>"; 
    }
    if (( -e $file_path ) && ( $sicon2 eq 'ON' )) {
      @ARGV = glob ( $file_path."/".$screen_dir_name."_".$plateconf.".txt" );
      $^I = "";
      while ( <> ) {
        s/(\s)siCON2([\n\r])/$1empty$2/g;
        print;
      }
      print "<p><div id=\"Note\">Reanalysing with updated plateconf file...</div></p>"; 
    }
    if (( -e $file_path ) && ( $allstar eq 'ON' )) {
      @ARGV = glob ( $file_path."/".$screen_dir_name."_".$plateconf.".txt" );
      $^I = "";
      while ( <> ) {
        s/(\s)allstar([\n\r])/$1empty$2/g;
        print;
      }
    print "<p><div id=\"Note\">Reanalysing with updated plateconf file...</div></p>"; 
    }
  
  my $guide = $guide_file;
  
  ##  run RNAi screen analysis scripts by calling R ##  
  
  my $run_analysis_scripts = `cd $file_path && R --vanilla < /home/agulati/scripts/run_analysis_script.R`;
   
  ####[[[Alternatively :- my $run_analysis_scripts = system("R --vanilla < /home/agulati/scripts/run_analysis_script.R"); ####]]]

  ## rename index.html file and copy it to the /var/www/html/RNAi_screen_analysis_report_folders ##

  my $rnai_screen_report_original_path = $file_path."/".$screen_dir_name."_reportdir";
  my $rnai_screen_report_original_file = $rnai_screen_report_original_path."/"."index.html";
  
  my $rnai_screen_report_renamed_file = $rnai_screen_report_original_path."/".$screen_dir_name."_index.html";
  `cp $rnai_screen_report_original_file $rnai_screen_report_renamed_file`;
  
  my $rnai_screen_report_new_path = "/usr/local/www/html/RNAi_screen_analysis_report_folders";
  `cp -r $rnai_screen_report_original_path $rnai_screen_report_new_path`;
  
  ## Display the link to screen analysis report on the save new screen page ##
  
  my $rnai_screen_link_to_report = "http://gft.icr.ac.uk/RNAi_screen_analysis_report_folders/".$screen_dir_name."_reportdir/";
 
  ## copy the file with qc plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $rnai_screen_qc_original_path = $file_path."/".$screen_dir_name."_controls_qc.png"; 
  my $rnai_screen_qc_new_path = "/usr/local/www/html/RNAi_screen_analysis_qc_plots";
  `cp -r $rnai_screen_qc_original_path $rnai_screen_qc_new_path`;
  
  ## Display the link to screen analysis qc plots on the save new screen page ##
  
  my $rnai_screen_link_to_qc_plots = "http://gft.icr.ac.uk/RNAi_screen_analysis_qc_plots/".$screen_dir_name."_controls_qc.png";
  
  #return $rnai_screen_link_to_qc_plots;
  
  my $zPrime = $file_path."/".$screen_dir_name."_zprime.txt";
  
  ## Capture zprime value in a variable ##
  
  my $zp_value = '';
  open IN, "< $zPrime" 
    or die "Cannot read z-prime values from $zPrime: $!\n";
  my $rep_count = 0;
  while(<IN>) {
    if ($_ =~ /Channel/) {
      next;
    }
    my $value = $_;
    chomp $value;
    #round off to the zprime values to two decimal places
    $value = sprintf "%.2f", $value;
    #count number of plate replicates and write the calculated zprime for each replicate
    $rep_count ++;
    $zp_value = $zp_value . "Rep" . $rep_count . "(" . $value  . "),";
  }
  close IN; 
  
  print "<p>";
  print "<p><div id=\"Note\">Generated QC plots...</div></p>";
  print "</p>";
  
  print "<p>";
  print "<p><div id=\"Note\">Calculated correlation coefficient...</div></p>";
  print "</p>";
  
  # =====================
  # Populate the database
  # =====================
  
  ## 1. Store user info in the database ##
 
 # open ( FILE, "/usr/lib/cgi-bin/users.txt" )
    # or die "Cannot open /usr/lib/cgi-bin/users.txt:$!\n";
  
  #foreach my $line ( <FILE> ) {
  #  chomp $line;
  #  my ( $username, $password ) = split( /\t/,$line );
    
   # $query_handle = $dbh -> do ( "INSERT INTO User_info (
	#User_info_ID, 
    #Username, 
   # Password) 
  #  VALUES (
 #   DEFAULT, 
#    '$username', 
 #   '$password' ) ");
    
    #$query_handle = $dbh -> prepare ( $query );
       					#or die "Cannot prepare: " . $dbh -> errstr();
  #$query_handle -> execute()
    #or die "SQL Error: " . $query_handle -> errstr();
    #$query_handle -> finish();
  #}
  #close FILE;
  
  ## 2. Store new isogenic set entered by the user into the database ##
  
  #first check if the screen is isogenic and then check if the user hasn't selected a set from the drop down menu
  
  my $is_isogenic_screen;
  
  if ($is_isogenic eq 'ON') {
    $is_isogenic_screen = "YES";
    if ( $ISOGENIC_SET eq "Please select" ) {
      my $query = $dbh -> do ( "INSERT INTO Name_of_set_if_isogenic ( 
        					   Name_of_set_if_isogenic) 
        					   VALUES (
        					   '$new_isogenic_set' )" );
      my $query_handle = $dbh -> prepare ( $query );
   					      # or die "Cannot prepare: " . $dbh -> errstr();
      $query_handle -> execute();
        #or die "SQL Error: ".$query_handle -> errstr();    
      $ISOGENIC_SET = $new_isogenic_set;
      #$query_handle->finish();
    }
  }
  else {
    $is_isogenic_screen = "NO";
    $gene_name_if_isogenic = "NA";
    $isogenic_mutant_description = "NA";
    $method_of_isogenic_knockdown = "NA";
    $ISOGENIC_SET = "NA";
    $new_isogenic_set = "NA";
  }  

  ## 3. Store new Rnai screen metadata in the database ##
  
  my $query = $dbh -> do( "INSERT INTO 
                          Rnai_screen_info (      
						  Cell_line,    
						  Rnai_screen_name,    
						  Date_of_run,    
						  Operator,    
						  Is_isogenic,    
						  Gene_name_if_isogenic,    
						  Isogenic_mutant_description,    
						  Method_of_isogenic_knockdown,    
						  Rnai_template_library,    
						  Plate_list_file_name,    
						  Plate_conf_file_name,   
						  Rnai_screen_link_to_report,
						  Rnai_screen_link_to_qc_plots,
						  Zprime,  
						  Notes,   
						  Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID, 
						  Instrument_used_Instrument_used_ID,   
						  Tissue_type_Tissue_type_ID,    
						  Transfection_reagent_used_Transfection_reagent_used_ID,    
						  Template_library_file_path_Template_library_file_path_ID,
						  Plateconf_file_path_Plateconf_file_path_ID,
						  Platelist_file_path_Platelist_file_path_ID,
						  Template_library_Template_library_ID ) 
						  SELECT 
						  '$cell_line_name',
						  '$screen_dir_name',
						  '$date_of_run', 
						  '$operator',
						  '$is_isogenic_screen',
						  '$gene_name_if_isogenic',
						  '$isogenic_mutant_description',
						  '$method_of_isogenic_knockdown',
						  '$templib',
						  '$platelist',
						  '$plateconf',
						  '$rnai_screen_link_to_report',
						  '$rnai_screen_link_to_qc_plots',
						  '$zp_value',
						  '$notes', 
						  ( SELECT Name_of_set_if_isogenic_ID FROM Name_of_set_if_isogenic WHERE Name_of_set_if_isogenic = '$ISOGENIC_SET' ), 
						  ( SELECT Instrument_used_ID FROM Instrument_used WHERE Instrument_name = '$instrument' ),
						  ( SELECT Tissue_type_ID FROM Tissue_type WHERE Tissue_of_origin = '$tissue_type' ), 
						  ( SELECT Transfection_reagent_used_ID FROM Transfection_reagent_used WHERE Transfection_reagent = '$transfection_reagent' ), 
						  ( SELECT Template_library_file_path_ID FROM Template_library_file_path WHERE Template_library_file_location = '$templib_file_path' ),
						  ( SELECT Plateconf_file_path_ID FROM Plateconf_file_path WHERE Plateconf_file_location = '$plateconf_file_path' ),
						  ( SELECT Platelist_file_path_ID FROM Platelist_file_path WHERE Platelist_file_location = '$platelist_file_path' ),
						  ( SELECT Template_library_ID FROM Template_library WHERE Template_library_name = '$templib' )");
  
  my $query_handle = $dbh->prepare( $query );
   					    #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute(); 
    #or die "SQL Error: " . $query_handle -> errstr();
  #if ($test) {
    #print "works";
  #}
  #else {
   # print "error";
  #}
  #capture the last row ID for the rnai screen info table in the database
  my $last_rnai_screen_info_id = $dbh -> { mysql_insertid };
  #$query_handle -> finish();
  
  ## 4. Store excel file in the database ##
  
  ######### COMMENTED OUT TEMPORARILY #########
  
  #open ( FILE, $file_path."/".$screen_dir_name.".txt" )
    #or die "Cannot open the xls2txt file:$!\n";
  
  #foreach my $line( <FILE> ){
   # chomp $line;
    #my ( $plate_number_xls_file, 
    #$well_number_xls_file, 
    #$raw_score_xls_file ) = split ( /\t/,$line );
    
    #my $query = $dbh -> do ( "INSERT INTO Plate_excel_file_as_text (
    #Plate_excel_file_as_text_ID, 
    #Plate_number_xls_file, 
    #Well_number_xls_file, 
    #Raw_score_xls_file,
    #Rnai_screen_info_Rnai_screen_info_ID ) 
    #VALUES (
    #DEFAULT, 
    #'$plate_number_xls_file', 
    #'$well_number_xls_file', 
    #'$raw_score_xls_file',
    #'$last_rnai_screen_info_id' ) ");
    
    #$query_handle = $dbh -> prepare ( $query );
       				    #or die "Cannot prepare: " . $dbh->errstr();
  #$query_handle -> execute()
    #or die "SQL Error: ".$query_handle -> errstr();
    #$query_handle -> finish();
  #}
  #close FILE;
  
  ## 5. Store file with zscores in the database ##
  
  #Remove the header in zscore file#  
  my $zscores_file_complete = $file_path."/".$screen_dir_name."_zscores.txt";
  my $zscores_file_wo_header = $file_path."/".$screen_dir_name."_zscores_wo_header.txt";
  `cat $zscores_file_complete | grep -v ^Compound > $zscores_file_wo_header`;
  
  open (FILE, $zscores_file_wo_header);
  foreach my $line(<FILE>) {
    chomp $line;
    my ($compound, 
    $plate_number_for_zscore, 
    $well_number_for_zscore, 
    $zscore) = split(/\t/,$line);
    
    my $query = $dbh -> do ("INSERT INTO Zscores_result (
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
  my $summary_file_complete = $file_path."/".$screen_dir_name."_summary.txt"; 
  my $summary_file_wo_header = $file_path."/".$screen_dir_name."_summary_wo_header.txt";
  `cat $summary_file_complete | grep -v ^plate > $summary_file_wo_header`;
  
  open (FILE, $summary_file_wo_header);
  foreach my $line(<FILE>) {
    chomp $line;
    my ($plate_number_for_summary, 
    $position, 
    $zscore_summary, 
    $well_number_for_summary, 
    $well_anno, 
    $final_well_anno, 
    $raw_r1_ch1, 
    $raw_r2_ch1, 
    $raw_r3_ch1, 
    $median_ch1, 
    $average_ch1, 
    $raw_plate_median_r1_ch1, 
    $raw_plate_median_r2_ch1, 
    $raw_plate_median_r3_ch1, 
    $normalized_r1_ch1, 
    $normalized_r2_ch1, 
    $normalized_r3_ch1, 
    $gene_symbol_summary,
    $entrez_gene_id_summary) = split(/\t/, $line);
  
    my $query = $dbh -> do("INSERT INTO Summary_of_result(
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
    Gene_symbol_summary, 
    Entrez_gene_id_summary, 
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
    '$gene_symbol_summary', 
    '$entrez_gene_id_summary', 
    '$last_rnai_screen_info_id', 
    (SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$templib')");
	
    my $query_handle = $dbh -> prepare($query);
    $query_handle -> execute();
  }
  
  close FILE;
  
  print "<p>";
  print "<p><div id=\"Note\">Stored screen results in the database...</div></p>";
  print "</p>";
 
  print "<p></p>";
 
  print "<p><b>ANALYSIS DONE</b></p>";
  
  print "<b>RNAi screen name: $screen_dir_name</b>";
  
  print "<p></p>";
  
  print "<p>";
  print "<a href = \"$rnai_screen_link_to_report\">View cellHTS2 analysis report </a>";
  print "<p>";
  
  print "<p>";
  print "<a href=\"$rnai_screen_link_to_qc_plots\">View QC plot </a>";
  print "</p>"; 
  
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
  
  my $lightweight_fh = $q -> upload ( 'new_uploaded_plateconf_file' );
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
  my $new_plateconf_filename = $q -> param ( "new_plateconf_filename" );
  
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
  else {
    $set_plateconf_error = 0;
    my $new_plateconf_filename_wo_spaces = $new_plateconf_filename;
    $new_plateconf_filename_wo_spaces =~ s/\s+/_/g;
    my $new_plateconf_file_basename = $new_plateconf_filename_wo_spaces;
    $new_plateconf_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_plateconf_file_renamed = $new_plateconf_file_basename.".txt";    
    
    $target = $plateconf_folder."/".$new_plateconf_file_renamed;
    my $tmpfile_path = $plateconf_folder."/tmpfile.txt";
    
    # undef may be returned if it's not a valid file handle
    if ( defined $lightweight_fh ) {
      # Upgrade the handle to one compatible with IO::Handle
      my $io_handle = $lightweight_fh->handle;
    
      #save the uploaded file on the server
      open ( $new_plateconf_file_renamed,'>', $target )
        or die "Cannot move $new_plateconf_file_renamed to $target:$!\n";
      if ( $new_plateconf_file_renamed ) {
        $set_plateconf_error = undef;
      }
      else { 
        $set_plateconf_error = 4;
        $processing_status = 1;
      }	    
      my $bytesread = undef;
      my $buffer = undef;
      while ( $bytesread = $io_handle -> read ( $buffer,1024 ) ) {
        my $print_plateconf = print $new_plateconf_file_renamed $buffer;
        if ( $print_plateconf ) {
          $set_plateconf_error = undef;
        }
        else {
          $set_plateconf_error = 5;
          $processing_status = 1;
        }
      }
      close $new_plateconf_file_renamed;
      #check the current position of the filehandle and set a flag if it's still in the file
      if ( tell( $new_plateconf_file_renamed ) ne -1 ) { 
       $set_plateconf_error = 6;
       $processing_status = 1;
      }   
    }
    #reformat the uploaded file
    `chmod 777 $target`;
    `tr '\r' '\n' < $target > $tmpfile_path`;
    `cp $tmpfile_path $target`;
    open IN, "< $tmpfile_path"
      or die "Cannot open $tmpfile_path:$!\n";
    open OUT, ">$target"
      or die "Cannot open $target:$!\n";
    while ( <IN> ){
      if( /\S/ ){
        print OUT $_;
        }
      }
    close IN;
    close OUT;
   
    my $query = $dbh -> do ( "INSERT INTO Plateconf_file_path (
      					  Plateconf_file_location )
     					  VALUES (
      					  '$target' )" );
    my $query_handle = $dbh -> prepare ( $query );
       					 #or die "Cannot prepare: " . $dbh -> errstr();
    $query_handle -> execute();
      #or die "SQL Error: ".$query_handle -> errstr();
    if ( $query_handle ) {
      $set_plateconf_error = undef;
      #$PLATECONF_FILE_PATH = $target;
    }
    else {
      $set_plateconf_error = 7;
      $processing_status = 1;
    }
   # $query_handle -> finish();
    #print $q->redirect (-uri=>"http://www.gft.icr.ac.uk/cgi-bin/$script_name?add_new_screen=1");
  
  } #end of else statement loop
  
  my $warning_message_plateconf_1 = "ERROR: Cannot open $target";
  my $warning_message_plateconf_2 = "ERROR: Error writing $target";
  my $warning_message_plateconf_3 = "ERROR: Cannot close $target";
  my $warning_message_plateconf_4 = "ERROR: Couldn't execute sql statement for adding new plateconf file location to the database";
  
  my $file_upload_message = $q -> param ( -name => 'file_upload_message',
  			  							  -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );

  if ( $processing_status == 0 && $set_plateconf_error == 0 ) {
      #my $message = "NOTE: Successfully added new plateconf file: $new_plateconf_file_renamed. It can now be selected for analysis from the dropdown menu.";
      &add_new_screen( $file_upload_message );
      #&add_new_screen; 
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 1 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_plateconf_1</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 2 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_plateconf_2</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 3 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_plateconf_3</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 4 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_1</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 5 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_2</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 6 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_3</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_plateconf_error == 7 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_plateconf_4</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  print $q -> hidden ( -name => 'file_upload_message',
  					   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_plateconf_file subroutine 
  
  
  # ================================
  # Save new uploaded platelist file
  # ================================

sub save_new_uploaded_platelist_file {

  my $lightweight_fh  = $q -> upload ( 'new_uploaded_platelist_file' );
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
  my $new_platelist_filename = $q -> param ( "new_platelist_filename" );
  
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
    if ( defined $lightweight_fh ) {
      # Upgrade the handle to one compatible with IO::Handle:
      my $io_handle = $lightweight_fh -> handle;

      #save the uploaded file on the server
      open ( $new_platelist_file_renamed,'>',$target )
        or die "Cannot move $new_platelist_file_renamed to $target:$!\n";
      if ( $new_platelist_file_renamed ) {
        $set_platelist_error = undef;
      }
      else { 
        $set_platelist_error = 4;
        $processing_status = 1;
      }	    
      my $bytesread = undef;
      my $buffer = undef;
      while ( $bytesread = $io_handle -> read ( $buffer,1024 )) {
        my $print_platelist = print $new_platelist_file_renamed $buffer;
        if ( $print_platelist ) {
          $set_platelist_error = undef;
        }
        else {
          $set_platelist_error = 5;
          $processing_status = 1;
        }  
      }
      close $new_platelist_file_renamed;
      #check the current position of the filehandle and set a flag if it's still in the file
      if ( tell ( $new_platelist_file_renamed ) ne -1 ) { 
          $set_platelist_error = 6;
          $processing_status = 1;
      }
    }
    #reformat the uploaded file
    `chmod 777 $target`;
    `tr '\r' '\n'  < $target > $tmpfile_path`;
    open IN, "<$tmpfile_path"
      or die "Cannot open $tmpfile_path:$!\n";
    open OUT, "> $target"
      or die "Cannot open $target:$!\n";
    while ( <IN> ) {
      if( /\S/ ) {
        print OUT $_;
        }
      }
    close IN;
    close OUT;
    
   # `cp $tmpfile_path $target`;
  
    my $query = $dbh -> do ( "INSERT INTO 
                             Platelist_file_path (
      					     Platelist_file_location )
      					     VALUES (
      					     '$target' )");
    my $query_handle = $dbh -> prepare ( $query );
   					     #or die "Cannot prepare: " . $dbh -> errstr();
    $query_handle -> execute();
      #or die "SQL Error: ".$query_handle -> errstr();
    if ( $query_handle ) {
      $set_platelist_error = undef;
      #$PLATELIST_FILE_PATH = $target;
    }
    else {
      $set_platelist_error = 7;
      $processing_status = 1;
    }
   # $query_handle -> finish();
   } #end of else loop
  
  my $warning_message_platelist_1 = "ERROR: Cannot open $target";
  my $warning_message_platelist_2 = "ERROR: Error writing $target";
  my $warning_message_platelist_3 = "ERROR: Cannot close $target";
  my $warning_message_platelist_4 = "ERROR: Couldn't execute sql statement for adding new platelist file location to the database";
  
  my $file_upload_message = $q -> param ( -name => 'file_upload_message',
  			  							  -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
  
  if ( $processing_status == 0 && $set_platelist_error == 0 ) {
      &add_new_screen($file_upload_message); 
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 1 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_platelist_1</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 2 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_platelist_2</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 3 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_platelist_3</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>"; 
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 4 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_1</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 5 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_2</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 6 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_3</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_platelist_error == 7 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_platelist_4</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  print $q -> hidden ( -name => 'file_upload_message',
  					   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_platelist_file subroutine
  
  
  # ================================
  # Save new uploaded library file
  # ================================
       
sub save_new_uploaded_templib_file {

  my $lightweight_fh  = $q -> upload( 'new_uploaded_templib_file' );
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
  my $new_templib_filename = $q->param( "new_templib_filename" );
  
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
    if ( defined $lightweight_fh ) {
      # Upgrade the handle to one compatible with IO::Handle:
      my $io_handle = $lightweight_fh->handle;
      
      #save the uploaded file on the server
      open ( $new_templib_file_renamed,'>',$target )
        or die "Cannot move $new_templib_file_renamed to $target:$!\n";
      if ( $new_templib_file_renamed ) {
        $set_templib_error = undef;
     }
      else { 
        $set_templib_error = 4;
        $processing_status = 1;
      }	      
      my $bytesread = undef;
      my $buffer = undef;
      while ( $bytesread = $io_handle->read( $buffer,1024 ) ) {
        my $print_templib = print $new_templib_file_renamed $buffer;
        if ( $print_templib ) {
          $set_templib_error = undef;
        }
        else {
          $set_templib_error = 5;
          $processing_status = 1;
        } 
      }
      close $new_templib_file_renamed;
      #check the current position of the filehandle and set a flag if it's still in the file
      if ( tell ( $new_templib_file_renamed ) ne -1 ) { 
        $set_templib_error = 6;
        $processing_status = 1;
      }    
    }
    #reformat the uploaded file
    `chmod 777 $target`;
    `tr '\r' '\n'  < $target > $tmpfile_path`;
    open IN, "< $tmpfile_path"
      or die "Cannot open $tmpfile_path:$!\n";
    open OUT, "> $target"
      or die "Cannot open $target:$!\n";
    while ( <IN> ) {
      if( /\S/ ) {
        print OUT $_;
        }
      }
    close IN;
    close OUT;
  
    my $query = $dbh -> do ( "INSERT INTO 
                             Template_library_file_path (
      					     Template_library_file_location)
      					     VALUES (
      					     '$target' )" );
    my $query_handle = $dbh->prepare( $query );
       					 #or die "Cannot prepare: " . $dbh -> errstr();
    $query_handle -> execute();
      #or die "SQL Error: " . $query_handle -> errstr();
    if ($ query_handle ) {
      $set_templib_error = undef;
      #$TEMPLIB_FILE_PATH = $target;
    }
    else {
      $set_templib_error = 7;
      $processing_status = 1;
    }
    #$query_handle -> finish();
  } #end of else loop
  
  my $warning_message_templib_1 = "ERROR: Cannot open $target";
  my $warning_message_templib_2 = "ERROR: Error writing $target";
  my $warning_message_templib_3 = "ERROR: Cannot close $target";
  my $warning_message_templib_4 = "ERROR: Couldn't execute sql statement for adding new template library file location to the database";
  
  my $file_upload_message = $q -> param( -name => 'file_upload_message',
  			  							-value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
  
  if ( $processing_status == 0 && $set_templib_error == 0 ) {
      &add_new_screen( $file_upload_message ); 
  }
  elsif ($ processing_status == 1 && $set_templib_error == 1 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_templib_1</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_templib_error == 2 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_templib_2</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_templib_error == 3 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$error_message_templib_3</b></p></div>";
    print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_templib_error == 4 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<p><b><div id=\"Message\">$warning_message_templib_1</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_templib_error == 5 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_templib_2</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_templib_error == 6 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_templib_3</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  elsif ( $processing_status == 1 && $set_templib_error == 7 ) {
    
    print $q -> header ( "text/html" );
    print "$page_header";
  
    print "<div id=\"Message\"><p><b>$warning_message_templib_4</b></p></div>";
  
    print "$page_footer";
    print $q -> end_html;
  }
  print $q -> hidden ( -name => 'file_upload_message',
  					   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_templib_file subroutine
  

# ==================================
# Subroutine for showing all screens
# ==================================
 
sub show_all_screens { 
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Available screens:</h1>";
    
  print "<table>";
 
  my $query = "SELECT
			  r.Rnai_screen_name,
			  t.Tissue_of_origin,
		      r.Cell_line, 
			  r.Date_of_run,
			  r.Operator,
			  i.Instrument_name,
			  u.Transfection_reagent,
			  r.Rnai_template_library,
			  r.Plate_list_file_name,
			  r.Plate_conf_file_name,
			  r.Is_isogenic,
			  r.Gene_name_if_isogenic,
			  (SELECT n.Name_of_set_if_isogenic FROM Name_of_set_if_isogenic n WHERE n.Name_of_set_if_isogenic = 'NA'),
		      r.Isogenic_mutant_description,
			  r.Method_of_isogenic_knockdown,
			  r.Rnai_screen_link_to_report,
			  r.Zprime FROM
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
			  r.Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID = '9' GROUP BY
			  r.Rnai_screen_info_ID UNION ALL 
			  SELECT
			  r.Rnai_screen_name,
			  t.Tissue_of_origin,
			  r.Cell_line,
			  r.Date_of_run,
			  r.Operator,
			  i.Instrument_name,
			  u.Transfection_reagent,
			  r.Rnai_template_library,
			  r.Plate_list_file_name,
			  r.Plate_conf_file_name,
			  r.Is_isogenic,
			  r.Gene_name_if_isogenic,
			  n.Name_of_set_if_isogenic,
			  r.Isogenic_mutant_description,
			  r.Method_of_isogenic_knockdown,
			  r.Rnai_screen_link_to_report, 
			  r.Zprime FROM
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
			  n.Name_of_set_if_isogenic_ID != '9' AND
			  r.Name_of_set_if_isogenic_Name_of_set_if_isogenic_ID = n.Name_of_set_if_isogenic_ID GROUP BY 
			  r.Rnai_screen_info_ID";
    
  my $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
   # or die "SQL Error: ".$query_handle -> errstr();
  
  print "<td align=left valign=top>\n";
  
  print "<th>";
  print "RNAi screen name";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "Tissue of origin";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "Cell line";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Date of run";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "Operator";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "Instrument name";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "Transfection reagent";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Rnai library name";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Platelist file name";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 

  print "<th>";
  print "Plateconf file name";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  

  print "<th>";
  print "Is isogenic or not";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Gene name if isogenic";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Name of set if isogenic";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
   
  print "<th>";
  print "Isogenic mutant description";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Method of isogenic knockdown";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Link to cellHTS2 analysis report";
  print "</th>";
  
  print "<th>";
  print "Link to QC plots";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";  
  
  print "<th>";
  print "Zprime";
  print "</th>"; 
  
  print "</td>";
 
  while ( my @row = $query_handle -> fetchrow_array ) {
  
    print "<tr>";
    
    print "<td align=left valign=top>\n";
    
    print "<td>";
    print "$row[0]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";  
    
    print "<td>";
    print "$row[1]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";  
    
    print "<td>";
    print "$row[2]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[3]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[4]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[5]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[6]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
     
    print "<td>";
    print "$row[7]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[8]";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";
   
    print "<td>";
    print "$row[9]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[10]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";  
    
    print "<td>";
    print "$row[11]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[12]";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[13]";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[14]";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
   
    print "<td>";
    print "<a href=\"$row[15]\" >Analysis report</a>";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "<a href=\"http://gft.icr.ac.uk/cgi-bin/$script_name?show_qc=1\&screen_dir_name=$row[0]\&plate_conf=$row[9]\">QC</a>";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "$row[16]";
    print "</td>"; 
    
    print "</td>";
    
    print "</tr>";

  } #end of while loop
  
 # $query_handle -> finish();

  print "</table>";
 
  print "$page_footer";
  print $q -> end_html;

} #end of show_all_screens subroutine


# =================================
# Subroutine for configuring export
# =================================

sub configure_export {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Configure export:</h1>";

  ## retrieve library_gene names from the database and save them in a hash ##
  
  my $query = ( "SELECT 
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
				CONCAT( Sub_lib, '_', Gene_symbol_templib )" );
  
  my $query_handle = $dbh -> prepare ( $query );
   					 #  or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
   # or die "SQL Error: ".$query_handle -> errstr();
 # print "<table>";
  
  my %lib_gene_h;
  my @lib_genes;
  my $lib_gene;
  
  while ( @lib_genes = $query_handle -> fetchrow_array ) {
  
    $lib_gene_h { $lib_genes[0] } = 2;
    
  }
  #$query_handle -> finish();

  ## retrieve cell lines from the database and save them in a hash ##
  
  my $query = ( "SELECT 
   				r.Cell_line FROM 
   				Rnai_screen_info r, 
   				Summary_of_result s, 
  				Template_library t WHERE
   				r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND 
   				r.Template_library_Template_library_ID = t.Template_library_ID GROUP BY 
   				r. Rnai_screen_info_ID" );
   
  my $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
    #or die "SQL Error: " . $query_handle -> errstr();
  
  my %cell_line_h;
  my @cell_lines;
  my $cell_line;
  while ( @cell_lines = $query_handle -> fetchrow_array ) {
 
    $cell_line_h{ $cell_lines[0] } = 3; 
    
  } 
  #$query_handle -> finish();
  
  ## retrieve zscores for each cell line from the database and save them in a hash ##
  
  my $query = ( "SELECT
    			CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib),
    			r.Cell_line, 
    			s.Zscore_summary FROM 
				Rnai_screen_info r, 
				Summary_of_result s, 
				Template_library_file l WHERE 
				r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND
				r.Template_library_Template_library_ID = s.Template_library_Template_library_ID AND 
				CONCAT(l.Sub_lib, '_', l.Gene_symbol_templib) = CONCAT(l.Sub_lib, '_', s.Gene_symbol_summary) AND
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
				s.Summary_of_result_ID" );
  
  my $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
   # or die "SQL Error: " . $query_handle -> errstr();
  my %zscore_h;
  my @zscores;
 
  @lib_genes = keys %lib_gene_h;
  @cell_lines = keys %cell_line_h; 
  
  open OUT, "> /home/agulati/data/screen_data/Rnai_screen_analysis_configure_export.txt"
    or die "Cannot open /home/agulati/data/screen_data/Rnai_screen_analysis_configure_export.txt:$!\n";
  my @header = sort @lib_genes;
  print OUT "CELL LINE/TARGET\t"."@header\t";
  print OUT "\n";
  
  while ( @zscores = $query_handle -> fetchrow_array ) {
    $zscore_h { $zscores[0].$zscores[1] } = $zscores[2];
  }
 # $query_handle->finish();
  
  foreach $cell_line ( @cell_lines ) {
    print OUT "$cell_line\t";
    foreach $lib_gene ( sort @lib_genes ) {
      if ( exists ( $zscore_h { $lib_gene.$cell_line } ) ) {
        print OUT "$zscore_h{$lib_gene.$cell_line}\t"; 
      }
      else {
        print OUT "NA\t";
      }
    }
    print OUT "\n";
  }

  close OUT;
  
  my $configure_export_file_path = "/home/agulati/data/screen_data/Rnai_screen_analysis_configure_export.txt";
  
  my $configure_export_new_file_path = "/usr/local/www/html/RNAi_screen_analysis_configure_export";
  `cp $configure_export_file_path $configure_export_new_file_path`;
  
  my $link_to_configure_export_file = "http://gft.icr.ac.uk/RNAi_screen_analysis_configure_export/";
  
  print "<p>";
  print "<a href = \"$link_to_configure_export_file\">Click here to download the file with analysis results for all the RNAi screens analysed.</a>";
  print "</p>";
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of configure_export subroutine

# ======================
# Subroutine for show_qc
# ======================

sub show_qc {

  print $q -> header ( "text/html" );
  print "$page_header";
 
  print $q -> start_multipart_form ( -method=>"POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<h1>RNAi screen quality:</h1>";
  
  my $screen_dir_name = $q -> param ( "screen_dir_name" );
  my $plateconf = $q -> param ( "plate_conf" );
  
  #print "<p>";
  print "<b>Screen name: $screen_dir_name</b>";
  #print "</p>";
  
  my $show_qc_page = "http://gft.icr.ac.uk/RNAi_screen_analysis_qc_plots/".$screen_dir_name."_controls_qc.png";
  
  print "<p>";
  print "<img src=\"$show_qc_page\" alt=\"QC plots:\">";
  print "</p>";

  my $coco_file = "/home/agulati/data/screen_data/".$screen_dir_name."/".$screen_dir_name."_corr.txt";
  
  open ( IN, "< $coco_file" )
    or die "Cannot open $coco_file:$!\n";
  while ( <IN> ) {
    if ($_ =~ /Min/) {
      next;
    }
    my $line = $_;
    #print $line;
    my( $coco_min, $coco_max ) = split(/\t/, $line);
    $coco_min = sprintf "%.4f", $coco_min;
    $coco_max = sprintf "%.4f", $coco_max;

    print "<p></p>";
    print "<p></p>";
    
    print "<b>Pearson's correlation:</b>";
    
    print "<p></p>";
    
    print "<table>";
    
    print "<th>";
    print "Min correlation";
    print "</th>";
    
    print "<th>";
    print "     ";
    print "</th>";
    
    print "<th>";
    print "    ";
    print "</th>"; 
    
    print "<th>";
    print "Max correlation";
    print "</th>";
    
    print "<tr>";
    
    print "<td>";
    print "$coco_min";
    print "</td>";
    
    print "<td>";
    print "     ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "$coco_max";
    print "</td>";
    
    print "</tr>";
    
    print "</table>";

  }
  close IN;
  
  print "</td>";
  
  print "<td align=left valign=top>\n";
  
  print "<p>";
  print "<h1>Reanalysis:</h1>";
  print "<b>Modify plateconf file for reanalysis:</b>";
  print "</p>";
  
  ## replace 'siCON1' with 'empty' ##

  print "<p><p>";
  
  print $q -> checkbox( -name => 'sicon1_empty',
    					-checked => 0,
   					    -value => 'ON',
    					-label => 'remove siCON1' );

  print "</p></p>";
  
  ## replace 'siCON2' with 'empty' ##
  
  print "<p>";
  
  print $q -> checkbox( -name => 'sicon2_empty',
    					-checked => 0,
   					    -value => 'ON',
    					-label => 'remove siCON2' );

  print "</p>";
  
  ## replace 'allstar' with 'empty' ##
  
  print "<p>";
  
  print $q -> checkbox( -name => 'allstar_empty',
    					-checked => 0,
   					    -value => 'ON',
    					-label => 'remove allstar' );

  print "</p>";
  
  print $q -> hidden ( -name => 'screen_dir_name',
  					   -value => $screen_dir_name );
  					  
  print $q -> hidden ( -name => 'plate_conf',
  					   -value => $plateconf );				  
  
 ## submit the updated plateconf file for re-analysis ##
                                                
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Reanalyse\" name=\"save_new_screen\"/>";
  print "</p>"; 
  
  print "</td>";
  print "</tr>\n";
  print "</table>";
  
  
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;
  
} #end of show_qc subroutine 


##########################################################################################


sub run_export {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Your data:</h1>";
  
  # recieve data from configure_export
  # and output data as a text file
  
  print "$page_footer";
  print $q -> end_html;
}


##########################################################################################


sub add_new_user {
  # get user, pass and oneTimePass, hash user.pass and store
  # set a cookie then redirect to view_all_projects
  my $q = shift;
  my $user = $q -> param ('user');
  my $pass = $q -> param ('pass');
#  my $auth_code = $q -> param ('auth_code');
    
#  my $correct_auth_code = md5_hex($user . $auth_code_salt);
#  die "Failed login...\n" unless $auth_code eq $correct_auth_code;
  
  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/) {
    &login("username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters");
    exit(1);
  }
  unless($pass =~ /^.{1,4096}$/) {
    &login("password must not exceed 4096 characters");
  }
  
  my $user_pass_hash = md5_hex($user . $pass . $auth_code_salt);
  for(my $i = 0; $i <= $num_hash_itts; $i ++) {
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
  
sub authenticate_login_key {
  my $login_key = shift;
  open USERS, "< ./users.txt" or die "can't open the file with the list of user names: $!\n";

#
#
#  print "OPENED USERS FILE...<br>";
#
#
#

  my $user = undef;
  while (<USERS>) {
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
    chomp($stored_hash);
    if ($stored_hash eq /$login_key/){$user = $stored_user;}
  }
  close USERS;
  &login() unless defined($user);
  return $user;  
}
 
sub authenticate_user {
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
    -url => "/cgi-bin/$script_name?add_new_screen=1",
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
    -url => "/cgi-bin/$script_name",
    -cookie => $cookie
    );

  exit(0);
}



