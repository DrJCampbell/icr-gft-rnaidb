#!/usr/bin/perl -w
# rnaidb.pl - CGI UI for RNAi database

use strict;
use CGI;
use CGI qw( :standard );
use CGI::Carp qw ( fatalsToBrowser );
use DBI;
use Digest::MD5 qw ( md5 md5_hex md5_base64 );
use FileHandle;
use File::Copy qw(copy);
use File::Copy qw(move);
use File::Path qw(rmtree);

# for new file upload - fixes the error :- use string ("test_plateconf.txt") as a symbol ref while "strict refs" in use at...
no strict 'refs';
# to check if an error is due to dbi or not
use Data::Dumper;

# Get the name of the script from $0
$0 =~ /([^\/]+)$/;

my $script_name = $1;
my $conf_file = $script_name;
$conf_file =~ s/pl$/conf/;

## stuff to configure when moving... ##

my $users_file = './users.txt';
my $temp_file_path = '/tmp/tmp.csv';

# These are the basic set of options
my %configures = &get_configures_hash($conf_file);

sub get_configures_hash{
        my $configures = shift;
        my %configures;
        open RES, "< $configures" or die "Can't read list of configures from file:\n$configures\n$!\n";
        while(<RES>){
                next if /^(#|[\n\r])/;
                my ($key, $value);
                if(/^([^\t]+)\t+([^\t]+)/){
                        $key = $1;
                        $value = $2;
                }
                chomp($value);
                if(exists($configures{$key})){die "configure: $key is duplicated in the configures file $configures\n\nYou need to fix that to continue\n";}
                $configures{$key} = $value;
        }
        return %configures;
}
my $sqldb_name = $configures{'sqldb_name'};
my $sqldb_host = $configures{'sqldb_host'};
my $sqldb_port = $configures{'sqldb_port'};
my $sqldb_user = $configures{'sqldb_user'};
my $sqldb_pass = $configures{'sqldb_pass'};

## Declare variables globally ##

my $ISOGENIC_SET;
my $ADD_NEW_FILES_LINK = $configures{'hostname'} . "cgi-bin/$script_name?add_new_files=1";

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
				   <a href=$configures{'hostname'}><img src=\"http://www.jambell.com/sample_tracking/ICR_GFTRNAiDB_logo_placeholder.png\" width=415px height=160px></a>
				   <p>
				   <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				   <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   </p>";

# HTML strings used in add new screen:

#my $tissue_file = $configures{'screenDir_path'} . "tissue_type.txt";
#my $tissue_list;
#my $t_l;
#open IN, "< $tissue_file"
  #or die "Cannot open $tissue_file:$!\n";

#while (<IN>) {
  #if ($_ =~ /^ADRENAL/) {
    #$t_l = $tissue_list;
 # }
#}
#$tissue_list = $_;
#chomp $tissue_list;
#close IN;

#my $cell_line_file = $configures{'screenDir_path'}. "cell_lines.txt";
#my $cell_line_list;
#my $c_l;
#open IN, "< $cell_line_file"
  #or die "Cannot open $cell_line_file:$!\n";
#while (<IN>) {
  #if ($_ =~ /^1321N1/) {
   # $c_l = $cell_line_list;
  #}
#}
#$cell_line_list = $_;
#chomp $cell_line_list;
#close IN;
 

				   						 				   						  				   
my $page_footer = "</div> <!-- end Main --></div> 
				   <!-- end Box -->
				   </body>
				   </html>";

#$ISOGENIC_SET = $q -> param( "isogenicSet" );
 # my $tissue_type = $q -> param( "tissue_type" );
 # my $cell_line_name = $q -> param( "cell_line_name" );
 # my $date_of_run = $q -> param( "date_of_run" );
 # my $operator = $q -> param( "operator" );
 # my $transfection_reagent = $q -> param( "transfection_reagent" );
 # my $instrument = $q -> param( "instrument" );
 # my $is_isogenic = $q -> param( "is_isogenic" );
 # my $gene_name_if_isogenic = $q -> param( "gene_name_if_isogenic" );
 # my $new_isogenic_set = $q ->  param( "name_of_set_if_isogenic" );
#  my $isogenic_mutant_description = $q -> param( "isogenic_mutant_description" );
 # my $method_of_isogenic_knockdown = $q -> param( "method_of_isogenic_knockdown" );

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
  #if ( defined ( $login_key ) ) {
  #  print "got cookie $login_key<br />";
  #}
  #else {
  #  print "Where's my cookie?"
  #}
  
  if ($script_name =~ "devel")
  {
  	print "<p>This is the test version.</p>";
  	print "<p>Data will be deleted.</p>";
  }
  else
  {
  	print "<p>This is the working version.</p>";
  	print "<p>If you are not sure how to use it, please try the test version.</p>"; 	
  }
  
  #print "<p>";
  #print "<p>Configname is $conf_file</p>";
  #print "</p>";
  
  #print "<p>";
  #print "<p>Connected to the database $sqldb_name</p>";
  #print "</p>";
  
  print "$page_footer";
  print $q -> end_html;
}


# ================================
# subroutine for adding new screen
# ================================

sub add_new_screen {
  print $q -> header ( "text/html" );
  my $user = $q -> param( 'user' );
  my $page_header_for_add_new_screen_sub1 = "<html>
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
											   var availableTissues = [";
 my $page_header_for_add_new_screen_sub2=  "\$( \"#tissues\" ).autocomplete ({
										    source: availableTissues
										    });
										    \$( \"#celllines\" ).autocomplete ({
										    source: availableCellLines
										    });
										  });									  
										  function make_tissues_Blank() {
										    var a = document.getElementById( \"tissues\" );
										    if (a.value == \"Enter tissue type\")
										    {
										    	a.value = \"\";
										    }
										  }
										  function make_cellLines_Blank() {
										    var b = document.getElementById( \"celllines\" );
										    if (b.value ==\"Enter cell line name\")
										    {
										    	b.value = \"\";
										    }
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
										    if(c.value == \"Enter gene name\")
										    {
										    	c.value = \"\";
										    }
										  } 
										  function make_isogenic_Set_Blank() {
										    var d = document.getElementById( \"isogenic_Set\" );
										    if (d.value == \"Enter isogenic set name\")
										    {
										    	d.value = \"\";
										    }
										  } 
										  function make_isogenicDescription_Blank() {
										    var e = document.getElementById( \"isogenicDescription\" );
										    if (e.value == \"e.g. parental\")
										    {
										    	e.value = \"\";
										    }
										  } 
										  function make_isogenicKnockdown_Blank() {
										    var f = document.getElementById( \"isogenicKnockdown\" );
										    if (f.value = \"e.g. ZFN or shRNA\")
										    {
										    	f.value = \"\";
										    }
										  }  
										  function make_notes_Blank() {
										    var g = document.getElementById( \"NoteS\" );
										    if (g.value == \"write notes for Description.txt\")
										    {
										    	g.value = \"\";
										    }
										  }  
										  function checkForm ( form ) {
										    if ( document.addNewScreen.uploaded_excel_file.value == '') {
										      alert ( \"Please select an Excel data file.\" );
										      return false;
										    }
										    
										    if ( document.addNewScreen.plate_conf.selectedIndex == 0 ) {
										      alert ( \"Please select plateconf file.\" );
										      return false;
										    }
										    if ( document.addNewScreen.plate_list.selectedIndex == 0 ) {
										      alert ( \"Please select platelist file.\" );
										      return false;
										    }
										    if ( document.addNewScreen.template_library.selectedIndex == 0 ) {
										      alert ( \"Please select template library file.\" );
										      return false;
										    }
										    if (( form[\"tissue_type\"].value == \"Enter tissue type\") || ( form[\"tissue_type\"].value == \"\")) {
										      alert ( \"Please enter tissue type.\" );
										      return false;
										    } 
										    if (( form[\"cell_line_name\"].value == \"Enter cell line name\") || ( form[\"cell_line_name\"].value == \"\")) {
										      alert ( \"Please enter cell line name.\" );
										      return false;
										    }
										    if ( form[\"operator\"].value == \"\" ) {
										      alert ( \"Please enter your name.\" );
										      return false;
										    }
										    if ( document.addNewScreen.transfection_reagent.selectedIndex == 0 ) {
										      alert ( \"Please select transfection reagent used for this screen.\" );
										      return false;
										    }
										    if ( document.addNewScreen.instrument.selectedIndex == 0 ) {
										      alert ( \"Please select instrument used for this screen.\" );
										      return false;
										    } 
										    var answer = confirm(\"Please make sure the data are correct. The data will be saved in the database and cannot be easily changed. Click OK button to proceed.\")
										  	return answer;
										  }
										  </script>
				   						  </head>
				   						  <body>
				   						  <div id=\"Box\"></div><div id=\"MainFullWidth\">
				   						  <a href=$configures{'hostname'}><img src=\"http://www.jambell.com/sample_tracking/ICR_GFTRNAiDB_logo_placeholder.png\" width=415px height=160px></a>
				   						  <p>
				   						  <a href=\"/cgi-bin/$script_name?add_new_screen=1\">Add new screen</a>\&nbsp;\&nbsp;
				    					  <a href=\"/cgi-bin/$script_name?show_all_screens=1\">Show all screens</a>\&nbsp;\&nbsp;
				   						  <a href=\"/cgi-bin/$script_name?configure_export=1\">Configure export</a>\&nbsp;\&nbsp;
				   						  </p>";
				   						  
  print "$page_header_for_add_new_screen_sub1";
  ## get the existing tissue type from the database ##
  my $tissueType;
  my @tissueType;
  
  my $query = "SELECT Tissue_of_origin FROM Tissue_type order by Tissue_of_origin";
  my $query_handle = $dbh -> prepare ( $query );
     				#or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle->execute();
  
  while ( $tissueType = $query_handle -> fetchrow_array ){
    push ( @tissueType, $tissueType );  
  }

  my $number_of_tissue_type = scalar @tissueType;
  my $i = undef;
  for ($i = 0; $i < $number_of_tissue_type-1; $i++)
  {
  	print "\"$tissueType[$i]\",\n";
  }
  print "\"$tissueType[$i]\"];\n";
  
  print "var availableCellLines = [";
  
  my $cellLineName;
  my @cellLineName;
 
  $query = "SELECT Cell_line_name FROM Cell_line order by Cell_line_name";
  $query_handle = $dbh -> prepare ( $query );
  $query_handle->execute();

  while ( $cellLineName = $query_handle -> fetchrow_array ){  
    push ( @cellLineName, $cellLineName );
  }
  my $number_of_cell_line = scalar @cellLineName;
  for ($i = 0; $i < $number_of_cell_line-1; $i++)
  {
  	print "\"$cellLineName[$i]\",\n";
  }
  print "\"$cellLineName[$i]\"];\n";
   
  print "$page_header_for_add_new_screen_sub2";
  
  print "<h2>Add new screen:</h2><p></p>";
  
  print $q -> start_multipart_form ( -method => "POST",
  									 -name => "addNewScreen",
  									 -onSubmit => "return checkForm( this )" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  ## print a message if the new plateconf has been successfully uploaded and saved to the server ##
  
  my $file_upload_message = $q -> param ( "file_upload_message" );
  
  #$file_upload_message = shift;
  if ( defined ( $file_upload_message ) ) {
    print "<div id=\"Message\"><p><b>$file_upload_message</b></p></div>";
  }

  ##
  ## add main screen info here ##
  ## 
 
  print "<p><b>General screen information:</b></p>";
  print "<p>";
 
  ## get the CTG excel file ##
  
  print "<p>Plate excel file(s):<br />";
  #print "<p>";
  
  print $q -> filefield ( -name => 'uploaded_excel_file',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file" );
  print "<br />";
  #print "<p>";
 
  print $q -> filefield ( -name => 'uploaded_excel_file2',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file2" );
  print "<br />";
  print $q -> filefield ( -name => 'uploaded_excel_file3',
                         -default => 'starting value',
                         -size => 35,
                         -maxlength => 256,
                         -id => "xls_file3" );
  print "<br />";

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
  
  print "<p>Plate list file:<br />";
  
  print $q -> popup_menu ( -name => 'plate_list',
  						  -value => \@platelist_path,
   						  -default => 'Please select',
   						  -id => "plist_file" );
  
  print " - OR <br />";
  
   ## View old Platelist file ## 
  my $plate_list_download_link = $configures{'hostname'} . $configures{'platelist_folder'}; 
  print "    ";
  print "<a href=\"$plate_list_download_link\">View existing plate list files</a>";
  
  print " - OR<br />";
  
  #link to the form for adding new platelist file 
  ##### http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1\#add_new_platelist_file ---- does not allow navigation to add_new_plateconf_file/add_new_platelist_file/add_new_plate_library_file pages
  #print "<p>";  
  print "<a href =" . $configures{'hostname'} .  "cgi-bin/$script_name?add_new_files=1\">Add new plate list file</a>";
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
  
  
  print "<p>Template library file:<br />";
  
  print $q -> popup_menu ( -name => 'template_library',
  						  -value => \@templib_path,
   						  -default => 'Please select',
   						  -id => "tlib_file" );
  
  print " - OR<br />";
  
  ## View old template library ## 
  my $template_library_download_link = $configures{'hostname'} . $configures{'templib_folder'}; 
  print "    ";
  print "<a href=\"$template_library_download_link\">View existing template library files</a>";
  
  print " - OR<br />";
  
  #link to the form for adding new template library file
  ##### http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1\#add_new_plate_library_file ---- does not allow navigation to add_new_plateconf_file/add_new_platelist_file/add_new_plate_library_file pages 
  #print "<p>";  	
  print "<a href =" . $configures{'hostname'} .  "cgi-bin/$script_name?add_new_files=1\"> Add new template library file</a>";
  print "</p>";
  print "</p>";
  
  ## get the existing plateconf filenames from the database and display them in the popup menu ##
  
  $query = "SELECT Plateconf_file_location FROM Plateconf_file_path";
  $query_handle = $dbh -> prepare( $query );
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
  print "<p>Plate configure file:<br />";
  
  print $q -> popup_menu ( -name => 'plate_conf',
  						  -value => \@plateconf_path,
  						  -default => 'Please select',
  						  -id => "pconf_file" );							    		  
  print " - OR<br />";
  
  ## View old Plateconf file ## 
  my $plate_conf_download_link = $configures{'hostname'} . $configures{'plateconf_folder'}; 
  print "    ";
  print "<a href=\"$plate_conf_download_link\">View existing plate configure files</a>";
  
  print " - OR<br />";
  
  #link to the form for adding new plateconf file 
  ##### http://gft.icr.ac.uk/cgi-bin/$script_name?add_new_files=1\#add_new_plateconf_file ---- does not allow navigation to add_new_plateconf_file/add_new_platelist_file/add_new_plate_library_file pages
  #print "<p>";
  print "<a href =" . $configures{'hostname'} . "cgi-bin/$script_name?add_new_files=1\"> Add new plate configure file</a>";
  print "</p>";
  
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
  
  print "</td>\n";
  
  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  print "</td>\n";
  
  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  
  print "Cell line name:<br />";
  print $q -> textfield ( -name => "cell_line_name",
                          -value => 'Enter cell line name',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_cellLines_Blank()",
                          -id => "celllines" );
  print "</p><p>";
  
  print "Tissue of origin:<br />";
  print $q -> textfield ( -name => "tissue_type",
                          -value => 'Enter tissue type',
                          -size => "30",
                          -maxlength => "45",
                          -onClick => "make_tissues_Blank()",
                          -id => "tissues" );
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
  print "<p><b>Analyse and save results:</b><br />";
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Analyse and save results\" name=\"save_new_screen\" />";
  print "</p>";

  print "</td>\n";

  # ======================
  # add isogenic info here
  # ======================
  print "<td align=left valign=top>\n"; 
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  print "</td>\n";
  
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
  print "<p><b>&nbsp&nbsp&nbsp&nbsp&nbsp</b></p>";
  print "</td>\n";
  
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
  
  #print "<p>";
  
  #my @CONTROL = ( "Please select", "DMSO", "DNS" ); # this should be read from a text file or from the SQL database
  #print "Control:<br />";
  #print $q -> popup_menu( -name => 'Control',
  #					      -value => \@CONTROL,
  #						  -default => 'Please select' );
  #print "</p>";
  
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
  #print "Notes about the drug screen:<br />";
  #print $q -> textarea ( -name => "drug_screen_notes",
  #                      -default => 'write notes for drug screen',
  #                       -rows => "8",
  #                       -columns => "40" );                              
  print "</td>\n";
                    
  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;
                                                                          
} #end of add_new_screen subroutine


  # =================================================================================
  # Subroutine for downloading/uploading new plateconf/platelist/library files
  # =================================================================================

sub add_new_files {
  print $q -> header ( "text/html" );
  print "$page_header";
  print "<h1>Add new file(s):</h1>";
  

  
  ## Downloading/uploading platelist file ## 
  
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_list_file\"><p><b>Upload new plate list file:</b>";
  print " - OR  ";
 
  ## download old Platelist file ##
 
  my $plate_list_download_link = $configures{'hostname'} . $configures{'platelist_folder'};

  #print "<p><div id=\"Note\">NOTE: For downloading existing platelist files, click on the link below.</div></p>";
  
  #print "<p>";
  print "<a href=\"$plate_list_download_link\">View existing plate list files</a>";
  print "</p>";
  
  ## get new platelist file ##
  
  #print "<p>Upload new platelist file:<br />";
  #print "<p></p>";
  
  print $q -> filefield ( -name=>"new_uploaded_platelist_file",
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
  
  ## enter new platelist file name ##
  
  #print "<p>Enter new platelist file name:<br />";
  #print "<p></p>";
   
  #print $q -> textfield ( -name => "new_platelist_filename",
  #                        -value => 'e.g. platelist_p9_v2',
  #                       -size => "30",
  #                        -maxlength => "45" ); 
  #print "<p></p>";
  
  #print"<p><div id=\"Note\">NOTE: The name of the new uploaded plate list file should be different from the names of existing platelist files. The words in the filename must be joined with an underscore ( _ ).</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user-a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_platelist_file',
  					   -default=>'save_new_uploaded_platelist_file' );
  
  ## submit newly uploaded plateconf file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_platelist_file\" value=\"Save the uploaded plate list file\" name=\"save_new_uploaded_platelist_file\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
  print $q -> end_multipart_form(); 
  
  ## Downloading/uploading template library file ## 
  
  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_library_file\"><p><b>Upload new template library file:</b>";
  print " - OR  ";
 
  ## download old template library file ##
 
  my $library_download_link = $configures{'hostname'} . $configures{'templib_folder'};
  
  #print "<p><div id=\"Note\">NOTE: For downloading the library file for editing, right click on the relevant link below and select the 'Save Link As...' option for saving the file on your computer.</div></p>";
  
  #print "<p>";
  print "<a href=\"$library_download_link\">View existing template library files</a>";
  print "</p>";
  
  ## get new template library file ##
  		  
  #print "<p>Upload new template library file:<br />";
  #print "<p></p>";
    
  print $q -> filefield( -name=>'new_uploaded_templib_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
    
  #enter new template library file name
  #print "<p>Enter new template library file name:<br />";
  #print "<p></p>";

  #print $q -> textfield ( -name => "new_templib_filename",
  #                        -value => 'e.g. KS_TS_CGC_WNT_384_template', 
  #                        -size => "30",
  #                        -maxlength => "45" );  
  #print "<p></p>";
  
  #print"<p><div id=\"Note\">NOTE: The name of the new uploaded library file should be different from the names of the existing library files. The words in the filename must be joined with an underscore ( _ ).</div></p>";
  
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
  
    ## Downloading/uploading plateconf file ##
  
  print $q -> start_multipart_form ( -method => "POST" ); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";

  print "<a name=\"new_plate_conf_file\"><p><b>Upload new plate configure file:</b>";
  #print "<p>";
 
  ## download old Plateconf file ##
 
  my $plate_conf_download_link = $configures{'hostname'} . $configures{'plateconf_folder'};
  
  #print "<div id=\"Note\"><p>NOTE: For downloading existing plateconf files, click on the link below.</p></div>";
  print " - OR  ";
  #print "<p>";
  print "<a href=\"$plate_conf_download_link\">View existing plate configure files</a>";
  print "</p>";
  
  ## get new Plateconf file ##
  
  #print "<p>Upload new plateconf file:<br />";
  #print "<p></p>";
  
  print $q -> filefield ( -name=>'new_uploaded_plateconf_file',
                         -default=>'starting value',
                         -size=>35,
                         -maxlength=>256 );
  print "</p>";
  
  ## enter new plateconf file name ##
  
  #print "<p>Enter new plateconf file name:<br />";
  #print "<p></p>";
  
  #print $q -> textfield ( -name => "new_plateconf_filename",
  #                        -value => 'e.g. KS_TS_CGC_WNT_384_plateconf',
  #                        -size => "30",
  #                        -maxlength => "45" );

  #print "<p></p>";
  
  #print"<p><div id=\"Note\">NOTE: The name of the new uploaded plate configure file should be different from the names of existing plate conf files. The words in the filename must be joined with an underscore ( _ ).</div></p>";
  
  ## create a hidden field ##
  #hidden fields pass information along with the user-entered input that is not to be manipulated by the user ## a way to have web forms to remember previous information 
  
  print $q -> hidden ( -name=>'save_new_uploaded_plateconf_file',
  					   -default=>'save_new_uploaded_plateconf_file' );
  
  ## submit the form for uploading plateconf file ##
  
  print "<p>";
  print "<input type=\"submit\" id=\"save_new_uploaded_plateconf_file\" value=\"Save the uploaded plate configure file\" name=\"save_new_uploaded_plateconf_file\" />";
  print "</p>";
  
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
  my $is_drug_screen = $q -> param ( "is_drug_screen" );
  my $gene_name_if_isogenic = $q -> param( "gene_name_if_isogenic" );
  my $new_isogenic_set = $q ->  param( "name_of_set_if_isogenic" );
  my $isogenic_mutant_description = $q -> param( "isogenic_mutant_description" );
  my $method_of_isogenic_knockdown = $q -> param( "method_of_isogenic_knockdown" );
  my $compound = $q -> param( "compound" );
  my $compound_concentration = $q -> param( "concentration" );
  my $dosing_regime = $q -> param( "dosing regime" );
  my $notes = $q -> param( "notes" );
  my $sicon1 = $q -> param( "sicon1_empty" );
  my $sicon2 = $q -> param( "sicon2_empty" );
  my $allstar = $q -> param( "allstar_empty" );
  my $xls_files;
  
  ##################Check cell line name and tissue of origin
  	$tissue_type = uc $tissue_type;
  	$cell_line_name = uc $cell_line_name;
  	$tissue_type =~ s/^\s+//g;
	$tissue_type =~ s/[^A-Z0-9_]*//g;
	$cell_line_name =~ s/^\s+//g;
	$cell_line_name =~ s/[^A-Z0-9]*//g;
		  		
	my $query = "SELECT Tissue_type_Tissue_type_ID FROM Cell_line where Cell_line_name= '$cell_line_name'";
	my $query_handle = $dbh -> prepare ( $query );
	$query_handle->execute();
	my $tissue_type_tissue_type_id = $query_handle -> fetchrow_array;
	if (defined ($tissue_type_tissue_type_id))
	{	
		$query = "SELECT Tissue_of_origin FROM Tissue_type where Tissue_type_ID = $tissue_type_tissue_type_id";
		$query_handle = $dbh -> prepare ( $query );
		$query_handle->execute();
		my $tissue_type_in_data_base = $query_handle -> fetchrow_array;

		if ($tissue_type ne $tissue_type_in_data_base)
		{
			my $message = "Error: The tissue of origin you entered for cell line $cell_line_name was $tissue_type. It is $tissue_type_in_data_base in the database. Please check!";
			print "<div id=\"Message\"><p><b>$message</b></p></div>";  
			print "$page_footer";
			print $q -> end_html;
			return;
		}
	} else
	{
        $query = "select Tissue_type_ID from Tissue_type where Tissue_of_origin = '$tissue_type'";
        $query_handle = $dbh -> prepare ( $query );
		$query_handle->execute();
		my $tissue_type_id = $query_handle -> fetchrow_array;
        if (!defined ($tissue_type_id))
        {
			$query = "INSERT into Tissue_type (Tissue_of_origin) values ('$tissue_type')";
			$query_handle = $dbh -> prepare ( $query );
			$query_handle->execute();
			$query = "select Tissue_type_ID from Tissue_type where Tissue_of_origin = '$tissue_type'";
        	$query_handle = $dbh -> prepare ( $query );
			$query_handle->execute();
			$tissue_type_id = $query_handle -> fetchrow_array;
        }
		
		$query = "INSERT into Cell_line (Cell_line_name, Tissue_type_Tissue_type_ID) values ('$cell_line_name', '$tissue_type_id')";
		$query_handle = $dbh -> prepare ( $query );
		$query_handle->execute();
		my $message = "New cell line and corresponding tissue of origin have been added to the database.";
		print "<div id=\"Message\"><p><b>$message</b></p></div>";
	}
  
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
    if ($is_isogenic eq 'ON')
    {
    	$screen_dir_name = "IS" . "_" . $tissue_type . "_" . $cell_line_name . "_" . $templib . "_" . $gene_name_if_isogenic . "_" . $date_of_run;
    }
    if ($is_drug_screen eq 'ON')
    {
    	$screen_dir_name = "DS" . "_" . $tissue_type . "_" . $cell_line_name . "_" . $templib . "_" . $compound . "_" . $date_of_run;
    }
  }
  my $screenDir_path = $configures{'screenDir_path'};
  my $file_path = "$screenDir_path/$screen_dir_name";
  
  if (( -e $file_path ) && ( $sicon1 ne 'ON' ) && ( $sicon2 ne 'ON' ) && ( $allstar ne 'ON' )) {
     	#die "Cannot make new RNAi screen directory $screen_dir_name in $screenDir_path: $!";
  		my $message = "A screen with the same name already exists. Cannot make new RNAi screen directory $screen_dir_name in $screenDir_path";
  		print "<div id=\"Message\"><p><b>$message</b></p></div>";
  		return;
   }
  
  if ( ! -e $file_path ) {
    mkdir( "$file_path" );
    `chmod -R 777 $file_path`;
    `chown -R agulati:agulati $file_path`;
      
    print "<p><div id=\"Note\">Created new screen directory...</div></p>";
    
    ## add screen directory name as prefix to all the filenames in the selected platelist file ##

    $plateconf_file_path = $configures{'WebDocumentRoot'} . $configures{'plateconf_folder'}.$plateconf.".txt";
    $plateconf_target = $file_path."/".$screen_dir_name."_".$plateconf.".txt";
    copy $plateconf_file_path, $plateconf_target;
    
    #print "<p><div id=\"Note\">Selected plateconf file saved in the new screen directory...</div></p>";  
  
    ## match platelist name, selected from the drop down menu, to the file and store it in a variable ##   
      
    $platelist_file_path = $configures{'WebDocumentRoot'} . $configures{'platelist_folder'}.$platelist.".txt";
    $platelist_target = $file_path."/".$screen_dir_name."_".$platelist.".txt";
    copy $platelist_file_path, $platelist_target;
    $platelist_tmp_file = $file_path."/tmp_platelist_file.txt";
    
    #print "<p><div id=\"Note\">Selected platelist file saved in the new screen directory...</div></p>";  
  
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
    move $platelist_tmp_file, $platelist_target;
    
    ## match templib name, selected from the drop down menu, to the file and store it in a variable ##

    $templib_file_path = $configures{'WebDocumentRoot'} . $configures{'templib_folder'}.$templib.".txt";
    $templib_target = $file_path."/".$screen_dir_name."_".$templib.".txt"; 
    copy $templib_file_path, $templib_target; 
    
    #print "<p><div id=\"Note\">Selected template library file saved in the new screen directory...</div></p>";  
  
  ############################################[[[probably need to copy $temp_file_path somewhere safe and give it to an R script to convert]]]
  
    ## Upload excel file and save it to new screen directory ##
    foreach my $excel_filefield ('uploaded_excel_file', 'uploaded_excel_file2', 'uploaded_excel_file3')
    { 
    	my $lightweight_fh  = $q -> upload ( $excel_filefield );	
		my $tmpfile = $file_path . "/tmpfile.xls";
    	
    	# undef may be returned if it's not a valid file handle  
    	if ( defined $lightweight_fh ) 
    	{
    		my $excelFile = $q->param( $excel_filefield );
    		if ( !($excelFile =~ /xls$/) ){
				print "<div id=\"Message\"><p>ERROR: You uploaded $excelFile. Please upload a valid excel file.</p></div>";
				rmtree $file_path;
				return;
			}
		
    		# Upgrade the handle to one compatible with IO::Handle:
      		my $io_handle = $lightweight_fh->handle;
 			my $fh = undef;
      		open ( $fh, '>', $tmpfile )
        		or die "Cannot upload $excelFile:$!\n";
      
      		my $bytesread = undef;
      		my $buffer = undef;
    
      		while ( $bytesread = $io_handle -> read ( $buffer,1024 ) ) 
      		{
        		print $fh $buffer
          		or die "Error writing '$tmpfile' : $!";
      		}
      		close $fh
        		or die "Error writing '$tmpfile' : $!";
        		 
      		## rename uploaded excel file ##
      		my $new_excel_filename_wo_spaces = $excelFile;
    		$new_excel_filename_wo_spaces =~ s/\s+/_/g;
    		my $target = $file_path . "/". $new_excel_filename_wo_spaces;
      		move ($tmpfile, $target) or die "Cannot rename $tmpfile :$!";
      		if (!defined($xls_files))
      		{
      			$xls_files = $new_excel_filename_wo_spaces;
      		}
      		else
      		{
      			$xls_files = $xls_files . " " . $new_excel_filename_wo_spaces;
      		}
    	}
    }
    
    #print "<p>";
    #print "<p><div id=\"Note\">Renamed excel file(s) saved in the screen directory...</div></p>";
    #print "</p>"; 
    
  ###############################################[[[either copy the platelist/palteconf/library etc to the new screen folder or use symlinks to point to the templates]]]
  
    ## write $notes to a 'Description.txt' file ##
  
    my $descripFile = $file_path."/".$screen_dir_name."_Description.txt";
    open NOTES, "> $descripFile" 
      or die "Cannot write notes to $descripFile:$!\n";
    print NOTES $notes;
    $screenDescription_filename = $screen_dir_name."_Description.txt";
    close NOTES;
    
    #print "<p><div id=\"Note\">Created 'Description.txt' file in the new screen directory...</div></p>";  
  
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
      "plot_1_file\t", 
      "plot_2_file\t",
      "plot_3_file\t",
      "corr_file\t",
      "separate_zprime_file\n"; 
  
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
      "$xls_files\t", 
      "$screen_dir_name"."_controls_qc.png\t",
      "$screen_dir_name"."_qc_plot_file_1.png\t",
      "$screen_dir_name"."_qc_plot_file_2.png\t",
      "$screen_dir_name"."_qc_plot_file_3.png\t", 
      "$screen_dir_name"."_corr.txt\t",
      "$screen_dir_name"."_separate_zprime.txt";  
  
    #print "<p><div id=\"Note\">Created guide file...</div></p>";
    print "<p><div id=\"Note\">Analysing...</div></p>"; 
      
    close (GUIDEFILE); 
    }
    
  ## Reanalysis ##
    
    if (( -e $file_path ) && ( $sicon1 eq 'ON' )) {
      @ARGV = glob ( $file_path."/".$screen_dir_name."_".$plateconf.".txt" );
      $^I = "";
      while ( <> ) {
        s/(\s)siCON1([\n\r])/$1empty$2/gi;
        print;
      }
      print "<p><div id=\"Note\">Reanalysing with updated plateconf file...</div></p>"; 
    }
    if (( -e $file_path ) && ( $sicon2 eq 'ON' )) {
      @ARGV = glob ( $file_path."/".$screen_dir_name."_".$plateconf.".txt" );
      $^I = "";
      while ( <> ) {
        s/(\s)siCON2([\n\r])/$1empty$2/gi;
        print;
      }
      print "<p><div id=\"Note\">Reanalysing with updated plateconf file...</div></p>"; 
    }
    if (( -e $file_path ) && ( $allstar eq 'ON' )) {
      @ARGV = glob ( $file_path."/".$screen_dir_name."_".$plateconf.".txt" );
      $^I = "";
      while ( <> ) {
        s/(\s)allstar([\n\r])/$1empty$2/gi;
        print;
      }
    print "<p><div id=\"Note\">Reanalysing with updated plateconf file...</div></p>"; 
    }
  
  my $guide = $guide_file;
  
  ##  run RNAi screen analysis scripts by calling R ##  
  
  my $run_analysis_scripts = `cd $file_path && R --vanilla < $configures{'run_analysis_script'}`;
   
  ####[[[Alternatively :- my $run_analysis_scripts = system("R --vanilla < /home/agulati/scripts/run_analysis_script.R"); ####]]]

  ## rename index.html file and copy it to the /var/www/html/RNAi_screen_analysis_report_folders ##

  my $rnai_screen_report_original_path = $file_path."/".$screen_dir_name."_reportdir";
  my $rnai_screen_report_original_file = $rnai_screen_report_original_path."/"."index.html";
  
  my $rnai_screen_report_renamed_file = $rnai_screen_report_original_path."/".$screen_dir_name."_index.html";
  `cp $rnai_screen_report_original_file $rnai_screen_report_renamed_file`;
  
  my $rnai_screen_report_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_report_new_path'};
  `cp -r $rnai_screen_report_original_path $rnai_screen_report_new_path`;
  
  ## Display the link to screen analysis report on the save new screen page ##
  
  my $rnai_screen_link_to_report = $configures{'hostname'} . $configures{'rnai_screen_report_new_path'} . $screen_dir_name."_reportdir/";
 
  ## copy the file with qc plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $rnai_screen_qc_original_path = $file_path."/".$screen_dir_name."_controls_qc.png"; 
  my $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $rnai_screen_qc_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with rep1 vs rep2 scatter plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $scatter_plot_1_original_path = $file_path."/".$screen_dir_name."_qc_plot_file_1.png"; 
  $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $scatter_plot_1_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with rep2 vs rep3 scatter plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $scatter_plot_2_original_path = $file_path."/".$screen_dir_name."_qc_plot_file_2.png"; 
  $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $scatter_plot_2_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with rep1 vs rep3 scatter plots to the /usr/local/www/html/RNAi_screen_analysis_qc_plots ##
  
  my $scatter_plot_3_original_path = $file_path."/".$screen_dir_name."_qc_plot_file_3.png"; 
  $rnai_screen_qc_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_qc_new_path'};
  `cp -r $scatter_plot_3_original_path $rnai_screen_qc_new_path`;
  
  ## copy the file with correlation coefficients for the reps to the /usr/local/www/html/RNAi_screen_analysis_correlation_folder ##
  
  my $rnai_screen_corr_original_path = $file_path."/".$screen_dir_name."_corr.txt"; 		
  my $rnai_screen_corr_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_corr_new_path'}; 		
  `cp -r $rnai_screen_corr_original_path $rnai_screen_corr_new_path`;
  
  ## copy the file with correlation coefficients for the reps to the /usr/local/www/html/RNAi_screen_analysis_separate_zprime_folder ##
  
  my $rnai_screen_sep_zprime_original_path = $file_path."/" . $screen_dir_name . "_separate_zprime.txt"; 		
  my $rnai_screen_sep_zprime_new_path = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_sep_zprime_new_path'}; 		
  `cp -r $rnai_screen_sep_zprime_original_path $rnai_screen_sep_zprime_new_path`;
  
  ## Display the link to screen analysis qc plots on the save new screen page ##
  
  my $rnai_screen_link_to_qc_plots = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_controls_qc.png";
  
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
  
  #print "<p>";
  #print "<p><div id=\"Note\">Generated QC plots...</div></p>";
  #print "</p>";
  
  #print "<p>";
  #print "<p><div id=\"Note\">Calculated correlation coefficient...</div></p>";
  #print "</p>";
  
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
      my $query = "INSERT INTO Name_of_set_if_isogenic ( 
        					   Name_of_set_if_isogenic) 
        					   VALUES (
        					   '$new_isogenic_set' )";
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
  
  if ($is_drug_screen eq 'ON')
  {
  	$is_drug_screen = "YES";
  }
  else
  {
  	$is_drug_screen = "NO";
  }

  ## 3. Store new Rnai screen metadata in the database ##
  
  $query = "INSERT INTO Rnai_screen_info (      
						  Cell_line,    
						  Rnai_screen_name,    
						  Date_of_run,    
						  Operator,    
						  Is_isogenic,    
						  Gene_name_if_isogenic,    
						  Isogenic_mutant_description,    
						  Method_of_isogenic_knockdown,
						  Compound,
						  Compound_concentration,   
						  Dosing_regime,
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
						  Template_library_Template_library_ID 
						  ) 
						  SELECT 
						  	'$cell_line_name',
						  	'$screen_dir_name',
						  	'$date_of_run', 
						  	'$operator',
						  	'$is_isogenic_screen',
						  	'$gene_name_if_isogenic',
						  	'$isogenic_mutant_description',
						  	'$method_of_isogenic_knockdown',
						  	'$compound',
						  	'$compound_concentration',
						  	'$dosing_regime',
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
						  	( SELECT Template_library_ID FROM Template_library WHERE Template_library_name = '$templib' )";
  
  $query_handle = $dbh->prepare( $query );
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
    #chomp $line;
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
       	###########or die "Cannot prepare: " . $dbh->errstr();
  #$query_handle -> execute();
        ###########or die "SQL Error: ".$query_handle -> errstr();
    #$query_handle -> finish();
  #}
  #close FILE;
  
  ## 5. Store file with zscores in the database ##
  
  #Remove the header in zscore file#  
  #my $zscores_file_complete = $file_path."/".$screen_dir_name."_zscores.txt";
  #my $zscores_file_wo_header = $file_path."/".$screen_dir_name."_zscores_wo_header.txt";
  #`cat $zscores_file_complete | grep -v ^Compound > $zscores_file_wo_header`;
  
  #open (FILE, $zscores_file_complete);
  #my $line = <FILE>; #skip the first line
  #while ($line = <FILE>) {
    #chomp $line;
    #my ($compound, 
    #$plate_number_for_zscore, 
    #$well_number_for_zscore, 
    #$zscore) = split(/\t/,$line);
    
    #my $query = "INSERT INTO Zscores_result (
	#						  Compound, 
	#						  Plate_number_for_zscore, 
	#						  Well_number_for_zscore,
	#						  Zscore,
	#						  Rnai_screen_info_Rnai_screen_info_ID,
	#						  Template_library_Template_library_ID) 
	#						  SELECT 
	#						  '$compound', 
	#						  '$plate_number_for_zscore',
	#						  '$well_number_for_zscore', 
	#						  '$zscore',
	#						  '$last_rnai_screen_info_id',
	#						  (SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$templib')";
    #my $query_handle = $dbh->prepare($query);
    #$query_handle -> execute();
  #}
  #close FILE;
  
  ## 6. Store file with summary of result in the database ##
  
  #Remove the header in summary file#
  my $summary_file_complete = $file_path."/".$screen_dir_name."_summary.txt"; 
  #my $summary_file_wo_header = $file_path."/".$screen_dir_name."_summary_wo_header.txt";
  #`cat $summary_file_complete | grep -v ^plate > $summary_file_wo_header`;
  
  open (FILE, $summary_file_complete);
  my $line = <FILE>; #skip the header
  while ( $line = <FILE> ) {
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
  
    my $query = "INSERT INTO Summary_of_result(
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
    Template_library_Template_library_ID
    ) 
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
    (SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$templib')";
	
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
  print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_qc=1\&screen_dir_name=$screen_dir_name\&plate_conf=$plateconf\">QC</a>";
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
  	my $plateconf_folder = $configures{'WebDocumentRoot'} . $configures{'plateconf_folder'};
  	my $target= "";
  	my $new_plateconf_file_renamed; 
  	#my $new_plateconf_filename = $q -> param ( "new_plateconf_filename" );
  
  	if ( !$new_uploaded_plateconf_file ) {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: Please upload a plateconf file.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	return;
  	}
  	
  	if ( !($new_uploaded_plateconf_file =~ /\.txt$/) ) {
    	my $message = "ERROR: You uploaded $new_uploaded_plateconf_file. Please upload a valid text file with extension .txt.";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
  
    my $new_plateconf_filename_wo_spaces = $new_uploaded_plateconf_file;
    $new_plateconf_filename_wo_spaces =~ s/\.txt$//;
    $new_plateconf_filename_wo_spaces =~ s/\s+/_/g;
    my $new_plateconf_file_basename = $new_plateconf_filename_wo_spaces;
    $new_plateconf_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_plateconf_file_renamed = $new_plateconf_file_basename.".txt";
    
    $target = $plateconf_folder."/".$new_plateconf_file_renamed;
    if (-e $target)
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	my $message = "The plate configure file name has been used previously. Please check!";
		print "<div id=\"Message\"><p><b>$message</b></p></div>";		  
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
  		return; 
    }
    
    my $query = "SELECT Plateconf_file_path.Plateconf_file_path_ID FROM Plateconf_file_path  WHERE Plateconf_file_location = '$target'";
    my $query_handle = $dbh->prepare( $query );
	$query_handle->execute() or die "Cannot execute mysql statement: $DBI::errstr";
	my $plateconf_file_path_id = $query_handle->fetchrow_array();
	if(defined($plateconf_file_path_id))
	{
		my $message = "The plate configure file name $new_plateconf_file_basename has been used before. Please give a different name.";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    	print "$page_footer";
    	print $q -> end_html;
    	return;
	}
    
    my $tmpfile_path1 = $plateconf_folder."/tmpfile1.txt";
    my $tmpfile_path2 = $plateconf_folder."/tmpfile2.txt";
        
    # undef may be returned if it's not a valid file handle
    if ( !defined $lightweight_fh ) {
    	my $message = "ERROR: The plate configure file cannot be loaded";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
            
   	# Upgrade the handle to one compatible with IO::Handle
	my $io_handle = $lightweight_fh->handle;
    
	#save the uploaded file on the server
	my $fh = undef;
	open ( $fh,'>', $tmpfile_path1 )
        	or die "Cannot upload the plate configure file:$!\n";
	if ( !$fh ) {
    	my $message = "ERROR: Cannot open temporary file $tmpfile_path1";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
		return;
	}
		    
	my $bytesread = undef;
	my $buffer = undef;
	while ( $bytesread = $io_handle -> read ( $buffer,1024 ) ) {
     	my $print_plateconf = print $fh $buffer;
     	if ( !$print_plateconf ) {  
    		print $q -> header ( "text/html" );
    		print "$page_header";
  			my $message = "ERROR: Error writing temporary file $tmpfile_path1";
    		print "<div id=\"Message\"><p><b>$message</b></p></div>";
    		print "$page_footer";
    		print $q -> end_html;
    		return;
      	}
 	}
	close $fh;
    
    #reformat the uploaded file
    `tr '\r' '\n'  < $tmpfile_path1  > $tmpfile_path2`;
    unlink $tmpfile_path1;
    
    open IN, "<$tmpfile_path2"
      or die "Cannot open $tmpfile_path2:$!\n";
    
    my $firstLine = <IN>;
    if( !($firstLine =~ "^Wells") )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The first line of the plate configure file should begin with \"Wells\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    
    my $secondLine = <IN>;
    if( !($secondLine =~ "^Plates") )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The second line of the plate configure file should begin with \"Plates\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    
    my $thirdLine = <IN>;
  	my $OK = ($thirdLine =~ "^Plate\t") && ($thirdLine =~ "\tWell\t") && ($thirdLine =~ "\tContent") ;
    if( !$OK )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The third line of the plate configure file should be \"Plate\", \"Well\", \"Content\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    
    close IN;
   	    
    $query = "INSERT INTO Plateconf_file_path (
      					  Plateconf_file_location )
     					  VALUES (
      					  '$target' )";
   	$query_handle = $dbh -> prepare ( $query );
       					 #or die "Cannot prepare: " . $dbh -> errstr();
    $query_handle -> execute();
      #or die "SQL Error: ".$query_handle -> errstr();
    if ( !$query_handle ) {  
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: Couldn't execute sql statement for adding new plateconf file location to the database";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
    	return;
    }
    
    move $tmpfile_path2, $target;
    
    my $message = "Plate configure file uploaded successfully! It can now be selected for analysis from the drop down menu.";    
    print $q -> header ( "text/html" );
    print "$page_header"; 
    print "<div id=\"Message\"><p><b>$message</b></p></div>";
  	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    print "$page_footer";
    print $q -> end_html;
    return;
    
   	# $query_handle -> finish();
    #print $q->redirect (-uri=>"http://www.gft.icr.ac.uk/cgi-bin/$script_name?add_new_screen=1"); 
  	#my $file_upload_message = $q -> param ( -name => 'file_upload_message',
  	#		  							  -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' ); 
   	#&add_new_screen( $file_upload_message );  
  	#print $q -> hidden ( -name => 'file_upload_message',
  	#				   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_plateconf_file subroutine 
  
  
  # ================================
  # Save new uploaded platelist file
  # ================================

sub save_new_uploaded_platelist_file {
  	my $lightweight_fh  = $q -> upload ( 'new_uploaded_platelist_file' );
  	my $new_uploaded_platelist_file = $q -> param( "new_uploaded_platelist_file" );
  	my $platelist_folder = $configures{'WebDocumentRoot'} . $configures{'platelist_folder'};
  	my $target = "";
  	my $new_platelist_file_renamed;
  
  	if ( !$new_uploaded_platelist_file) {
  		my $message = "ERROR: Please upload a platelist file";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;
  	}
  	
  	if ( !($new_uploaded_platelist_file =~ /\.txt$/) ) {
    	my $message = "ERROR: You uploaded $new_uploaded_platelist_file. Please upload a valid text file with extension .txt.";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
  
    my $tmpfile_path1 = $platelist_folder."/tmpfile1.txt";
    my $tmpfile_path2 = $platelist_folder."/tmpfile2.txt";
      
    if ( !defined $lightweight_fh ) {
    	my $message = "ERROR: The platelist file cannot be loaded";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
		
	# Upgrade the handle to one compatible with IO::Handle:
    my $io_handle = $lightweight_fh -> handle;

	#save the uploaded file in tmpfile.txt on the server
	my $fh = undef;
	open ( $fh, '>', $tmpfile_path1 )
        	or die "Cannot upload the platelist file:$!\n";
	if ( !defined($fh) ) {
    	my $message = "ERROR: Cannot open temporary file tmpfile1.txt";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>"; 
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path1;
    	return;
    }	    
	
	my $bytesread = undef;
	my $buffer = undef;
	while ( $bytesread = $io_handle -> read ( $buffer,1024 )) {
		my $print_platelist = print $fh $buffer;
		my $message = "ERROR: Error writing temporary file tmpfile1.txt";
       	if ( !$print_platelist ) {  
    		print $q -> header ( "text/html" );
    		print "$page_header"; 
    		print "<div id=\"Message\"><p><b>$message</b></p></div>";
  			print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>"; 
    		print "$page_footer";
    		print $q -> end_html;
    		close $fh;
    		unlink $tmpfile_path1;
  			return;
        }  
    }
    close $fh;
    
    #reformat the uploaded file
    `tr '\r' '\n'  < $tmpfile_path1  > $tmpfile_path2`;
    unlink $tmpfile_path1;

    open IN, "<$tmpfile_path2"
      or die "Cannot open $tmpfile_path2:$!\n";
    
    my $firstLine = <IN>;
    my $number_of_plates = 0;
    if( ($firstLine =~ "^Filename\t") && ($firstLine =~ "\tPlate\t") &&($firstLine =~ "\tReplicate") )
    {
    	$number_of_plates = 0;
    }
    else
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The column names of the plate list file should be \"Filename\", \"Plate\", \"Replicate\"";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2; 
  		return;  	
    }
    
    my $secondLine = <IN>;
    chomp $secondLine;
    my $thirdLine = <IN>;
    chomp $thirdLine;
    my @secondLine = split(/\t/,$secondLine);
    my @thirdLine = split(/\t/,$thirdLine);
	my $version = 0;
	if ($secondLine[1]==$thirdLine[1])
	{
		$version = 1;
	}
	
	if ($secondLine[2]==$thirdLine[2])
	{
		$version = 2;
	}
	
    if( ($secondLine =~ "^P1.txt\t") && ($thirdLine =~ "^P2.txt\t") )
    {
    	$number_of_plates = $number_of_plates + 2;
    }
    else
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The filenames of the plate list file should be P1.txt, P2.txt, etc.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
        
    while ( <IN> ) {
      if( /\S/ ) {
      		$number_of_plates = $number_of_plates + 1;
        }
      }
    close IN;
    
    my $new_platelist_file_basename = "platelist_p$number_of_plates" . "_v$version";   	
   	$new_platelist_file_renamed = $new_platelist_file_basename.".txt";    
    $target = $platelist_folder."/".$new_platelist_file_renamed;
    
    if (-e $target)
    {
    	unlink $tmpfile_path2;
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	my $message = "The platelist file has " . $number_of_plates . " plates.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	$message = "It is probably identical to " . $new_platelist_file_renamed . ". Please check!";
		print "<div id=\"Message\"><p><b>$message</b></p></div>";		  
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
  		return; 
    }
  	   
    my $query = "INSERT INTO Platelist_file_path (Platelist_file_location ) VALUES ('$target' )";
    my $query_handle = $dbh -> prepare ( $query );
    $query_handle -> execute();
    if ( !$query_handle ) {   	
    	my $message = "ERROR: Couldn't execute sql statement for adding new plate list file location to the database";    
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
  		print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
      	return;
    }
    
    move $tmpfile_path2, $target;
    
    my $message = "Plate list file uploaded successfully! It is renamed as ". $new_platelist_file_renamed . ". It can now be selected for analysis from the drop down menu.";    
    print $q -> header ( "text/html" );
    print "$page_header"; 
    print "<div id=\"Message\"><p><b>$message</b></p></div>";
  	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    print "$page_footer";
    print $q -> end_html;
    return;
    
	#my $file_upload_message = $q -> param ( -name => 'file_upload_message',
  	#		  							  -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
  
	#&add_new_screen($file_upload_message);
  	#print $q -> hidden ( -name => 'file_upload_message',
  	#				   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
} #end of save_new_uploaded_platelist_file subroutine
  
  
  # ================================
  # Save new uploaded library file
  # ================================
       
sub save_new_uploaded_templib_file {
  	my $lightweight_fh  = $q -> upload( 'new_uploaded_templib_file' );
  	my $new_uploaded_templib_file = $q -> param( "new_uploaded_templib_file" );
  	my $templib_folder = $configures{'WebDocumentRoot'} . $configures{'templib_folder'};
  	my $target = "";
  	my $new_templib_file_renamed;
  
  	if ( !$new_uploaded_templib_file ) {
  		my $message = "ERROR: Please upload a template library file"; 
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    	print "$page_footer";
    	print $q -> end_html;
    	return;
  	}
  	
  	if ( !($new_uploaded_templib_file =~ /\.txt$/) ) {
    	my $message = "ERROR: You uploaded $new_uploaded_templib_file. Please upload a valid text file with extension .txt.";
    	print $q -> header ( "text/html" );
    	print "$page_header"; 
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
  	  	 	
  	my $tmpfile_path1 = $templib_folder . "/tmpfile1.txt";
    my $tmpfile_path2 = $templib_folder . "/tmpfile2.txt";

    my $new_templib_filename_wo_spaces = $new_uploaded_templib_file;
    $new_templib_filename_wo_spaces =~ s/\.txt$//;
    $new_templib_filename_wo_spaces =~ s/\s+/_/g;
    my $new_templib_file_basename = $new_templib_filename_wo_spaces;
    $new_templib_file_basename =~ s/[^A-Za-z0-9_-]*//g;
    $new_templib_file_renamed = $new_templib_file_basename.".txt";
       
    $target = $templib_folder."/".$new_templib_file_renamed;
    
    my $query = "SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$new_templib_file_basename'";
    my $query_handle = $dbh->prepare( $query );
	$query_handle->execute() or die "Cannot execute mysql statement: $DBI::errstr";
	my $template_library_id = $query_handle->fetchrow_array();
	if(defined($template_library_id))
	{
		my $message = "The template library name $new_templib_file_basename has been used before. Please give a different name.";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";
    	print "$page_footer";
    	print $q -> end_html;
    	return;
	}
	
	if (-e $target)
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	my $message = "The template file name has been used before. Please give a different name.";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";	  
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";   
    	print "$page_footer";
    	print $q -> end_html;
  		return; 
    }

    if ( !defined $lightweight_fh ) {
    	my $message = "ERROR: The template library file cannot be loaded";
    	print $q -> header ( "text/html" );
    	print "$page_header";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    	print "$page_footer";
    	print $q -> end_html;
    	return;   	
    }
    
   	# Upgrade the handle to one compatible with IO::Handle:
	my $io_handle = $lightweight_fh->handle;
      
	#save the uploaded file in tmpfile1.txt on the server
	my $fh = undef;
	open ( $fh,'>', $tmpfile_path1 )
      	or die "Cannot upload the template file:$!\n";
  	if ( !$fh ) 
  	{    
    	my $message = "ERROR: Cannot open temporary file $tmpfile_path1";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<p><b><div id=\"Message\">$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
		return;
	}	     
	 
	my $bytesread = undef;
	my $buffer = undef;
	while ( $bytesread = $io_handle->read( $buffer,1024 ) ) 
	{
		my $print_templib = print $fh $buffer;
     	if ( !$print_templib ) {
          	my $message = "ERROR: Error writing temporary file $tmpfile_path1";
    		print $q -> header ( "text/html" );
    		print "$page_header"; 
    		print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    		print "$page_footer";
    		print $q -> end_html;
    		return;
       	} 
   	}
	close $fh;
	
	#reformat the uploaded file
    `tr '\r' '\n'  < $tmpfile_path1  > $tmpfile_path2`;
    unlink $tmpfile_path1;

   	open IN, "<$tmpfile_path2"
      or die "Cannot open $tmpfile_path2:$!\n";
    
   	my $firstLine = <IN>;
   	my $OK = ($firstLine =~ "^Plate\t") && ($firstLine =~ "\tWell\t") && ($firstLine =~ "\tGeneID\t") && ($firstLine =~ "\tEntrez_gene_ID\t") && ($firstLine =~ "\tsublib");
    if( !$OK )
    {
    	print $q -> header ( "text/html" );
    	print "$page_header";
  		my $message = "ERROR: The column names of the template library file should be \"Plate\", \"Well\", \"GeneID\", \"Entrez_gene_ID\" and \"sublib\" ";
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";
    	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";     	 
    	print "$page_footer";
    	print $q -> end_html;
    	close IN;
    	unlink $tmpfile_path2;
  		return;  	
    }
    		
 	$query = "INSERT INTO Template_library_file_path (Template_library_file_location) VALUES ('$target' )";
    $query_handle = $dbh->prepare( $query );
    $query_handle -> execute();
      #or die "SQL Error: " . $query_handle -> errstr();
    if ( !$query_handle ) {
      	my $message = "ERROR: Couldn't execute sql statement for adding new template library file location to the database";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>";  
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
    	return;
    }
    
    $query = "INSERT INTO Template_library (Template_library_name) VALUES ('$new_templib_file_basename')";
   	$query_handle = $dbh->prepare( $query );
    $query_handle -> execute();
    if ( !$query_handle ) {
      	my $message = "ERROR: Couldn't execute sql statement for adding new template library name to the database";
    	print $q -> header ( "text/html" );
    	print "$page_header";  
    	print "<div id=\"Message\"><p><b>$message</b></p></div>"; 
    	print "$page_footer";
    	print $q -> end_html;
    	unlink $tmpfile_path2;
    	return;
    }
    
    $query = "SELECT Template_library.Template_library_ID FROM Template_library WHERE Template_library_name = '$new_templib_file_basename'";
    $query_handle = $dbh->prepare( $query );
	$query_handle->execute() or die "Cannot execute sql statement: $DBI::errstr";
	$template_library_id = $query_handle->fetchrow_array();
    		
    # follow http://stackoverflow.com/questions/13671195/working-perl-ascript-now-says-dbdmysqldb-do-failed-you-have-an-error-in-yo
    $query = "INSERT INTO Template_library_file (
							  Plate_templib, 
							  Well_templib,
							  Gene_symbol_templib,
							  Entrez_gene_id_templib,
							  Sub_lib,
							  Template_library_Template_library_ID) 
							  VALUES( ?, ?, ?, ?, ?, ?)";
    $query_handle = $dbh->prepare($query);
    my $line = undef;
    while ( <IN> ) 
    {
		if( /\S/ ) 
		{
			$line = $_;
        	chomp $line;
    		my ($plate, $well, $gene_symbol, $entrez_gene_id, $sublib) = split(/\t/,$line);  
    		
    		$query_handle -> execute($plate, $well, $gene_symbol, $entrez_gene_id, $sublib, $template_library_id);
    		if ( !$query_handle ) {
      			my $message = "ERROR: Couldn't execute sql statement for adding new template library data to the database";
    			print $q -> header ( "text/html" );
    			print "$page_header";  
    			print "<div id=\"Message\"><p><b>$message</b></p></div>";
    			print "<p> Plate: $plate</p>";
    			print "<p> Well: $well</p>";
    			print "<p> Gene Symbol: $gene_symbol</p>";
    			if(!defined($gene_symbol))
    			{
    				print "<p> variable gene_symbol not defined</p>";
    			}
    			else
    			{
    				print "<p> variable gene_symbol is defined</p>";
    			}
    			print "<p> Entrez gene ID: $entrez_gene_id</p>";
    			if(!defined($gene_symbol))
    			{
    				print "<p> variable entrez_gene_id not defined</p>";
    			}
    			else
    			{
    				print "<p> variable entrez_gene_id is defined</p>";
    			}
  				print "<p> Sublib: $sublib</p>";
  				if(!defined($sublib))
    			{
    				print "<p> variable sublib not defined</p>";
    			}
    			else
    			{
    				print "<p> variable sublib is defined</p>";
    			}
  				print "<p> Template_library_name: $new_templib_file_basename</p>";
    			print "$page_footer";
    			print $q -> end_html;
    			unlink $tmpfile_path2;
    			return;
    		}        	
        }
    }
    close IN;
    move $tmpfile_path2, $target;
    
    my $message = "Template library file uploaded successfully! It can now be selected for analysis from the drop down menu.";    
    print $q -> header ( "text/html" );
    print "$page_header"; 
    print "<div id=\"Message\"><p><b>$message</b></p></div>";
  	print "<a href=\"$ADD_NEW_FILES_LINK\">Back</a>";  
    print "$page_footer";
    print $q -> end_html;
    return;
    
  	#my $file_upload_message = $q -> param( -name => 'file_upload_message',
  	#		  							-value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
  			  							
    #&add_new_screen( $file_upload_message ); 
  	#print $q -> hidden ( -name => 'file_upload_message',
  	#				   -value => 'File uploaded successfully! It can now be selected for analysis from the drop down menu.' );
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
			  r.Compound,
			  r.Compound_concentration,
			  r.Dosing_regime,
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
			  r.Compound,
			  r.Compound_concentration,
			  r.Dosing_regime,
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
			  r.Rnai_screen_info_ID order by Date_of_run DESC";
    
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
  print "Compound";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
  print "<th>";
  print "Compound concentration";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>";
  
  print "<th>";
  print "    ";
  print "</th>"; 
  
   print "<th>";
  print "Dosing regime";
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
  
  #print "<th>";
  #print "Zprime";
  #print "</th>"; 
  
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
    print "$row[15]";
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
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
     print "<td>";
    print "$row[17]";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
   
    print "<td>";
    print "<a href=\"$row[18]\" >Analysis report</a>";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    print "<td>";
    print "<a href=" . $configures{'hostname'} . "cgi-bin/$script_name?show_qc=1\&screen_dir_name=$row[0]\&plate_conf=$row[9]\">QC</a>";
    print "</td>"; 
    
    print "<td>";
    print "    ";
    print "</td>";
    
    print "<td>";
    print "    ";
    print "</td>"; 
    
    #print "<td>";
    #print "$row[16]";
    #print "</td>"; 
    
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
  
  $query = ( "SELECT 
   				r.Cell_line FROM 
   				Rnai_screen_info r, 
   				Summary_of_result s, 
  				Template_library t WHERE
   				r.Rnai_screen_info_ID = s.Rnai_screen_info_Rnai_screen_info_ID AND 
   				r.Template_library_Template_library_ID = t.Template_library_ID GROUP BY 
   				r. Rnai_screen_info_ID" );
   
  $query_handle = $dbh -> prepare ( $query );
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
  
  $query = ( "SELECT
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
  
  $query_handle = $dbh -> prepare ( $query );
   					   #or die "Cannot prepare: " . $dbh -> errstr();
  $query_handle -> execute();
   # or die "SQL Error: " . $query_handle -> errstr();
  my %zscore_h;
  my @zscores;
 
  @lib_genes = keys %lib_gene_h;
  @cell_lines = keys %cell_line_h; 
  
  open OUT, "> ". $configures{'screenDir_path'} . "Rnai_screen_analysis_configure_export.txt"
    or die "Cannot open" .  $configures{'screenDir_path'} . "Rnai_screen_analysis_configure_export.txt:$!\n";
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
  
  my $configure_export_file_path = $configures{'screenDir_path'} . "Rnai_screen_analysis_configure_export.txt";
  
  my $configure_export_new_file_path = $configures{'WebDocumentRoot'} . $configures{'configure_export_new_file_path'};
  `cp $configure_export_file_path $configure_export_new_file_path`;
  
  my $link_to_configure_export_file = $configures{'hostname'} . "RNAi_screen_analysis_configure_export/";
  
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
  
  print "<b>Screen name: $screen_dir_name</b>";

  
  my $show_qc_page = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_controls_qc.png";
  my $scatter_plot_1 = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_qc_plot_file_1.png";
  my $scatter_plot_2 = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_qc_plot_file_2.png";
  my $scatter_plot_3 = $configures{'hostname'} . $configures{'rnai_screen_qc_new_path'} . $screen_dir_name . "_qc_plot_file_3.png";
  
  print "<p>";
  print "<img src=\"$show_qc_page\" alt=\"QC plots:\">";
  print "</p>"; 
  
  print "</td>";
  
	##display separate zprime values
	print "<td align=left valign=top>\n";
  
	my $sep_zprime_file = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_sep_zprime_new_path'} . $screen_dir_name . "_separate_zprime.txt";
	print "<p></p>";
	print "<p></p>";
	print "<h2>Zprimes with sicon1, sicon2 or allstar as negative and plk1 as positive controls:</h2>";
	print "<p></p>";
  
	print "<table>";
	print "<th>";
	print "Replicates";
	print "</th>";
    
	print "<th>";
	print "sicon1";
	print "</th>";
	
	print "<th>";
	print "sicon2";
	print "</th>";
    
	print "<th>";
	print "allstar";
	print "</th>"; 
    
  
  	open ( IN, "< $sep_zprime_file" )
    	or die "Cannot open $sep_zprime_file:$!\n";
  	while ( <IN> ) {
    	if ($_ =~ /zp_sicon1/) {
      		next;
    	}
    	my $line = $_;
    	#print $line;
		my( $replicates, $zp_sicon1, $zp_sicon2, $zp_allstar ) = split(/\t/, $line);
    	$zp_sicon1 = sprintf "%.2f", $zp_sicon1;
    	$zp_sicon2 = sprintf "%.2f", $zp_sicon2;
    	$zp_allstar = sprintf "%.2f", $zp_allstar;
      
    	print "<tr>";
    
    	print "<td>";
    	$replicates=~ s/\"//g;
    	print $replicates;
    	print "</td>";
    
    	print "<td align=right>";
    	print $zp_sicon1;
    	print "</td>";
    
    	print "<td align=right>";
    	print $zp_sicon2;
    	print "</td>";
    
    	print "<td align=right>";
    	print $zp_allstar;
    	print "</td>";
    
    	print "</tr>";
  	}
  	close IN;
  	
   	print "</table>";
   	
   	print "<p></p>";
   	print "<p></p>";
   	print "<p></p>";
    
    print "<h2>Pearson's correlation among normalized data of replicates:</h2>";
    
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
    
   	my $coco_file = $configures{'WebDocumentRoot'} . $configures{'rnai_screen_corr_new_path'} . $screen_dir_name . "_corr.txt";
  
  	open ( IN, "< $coco_file" )
    	or die "Cannot open $coco_file:$!\n";
 	while ( <IN> ) {
    	if ($_ =~ /Min/) {
      		next;
    	}
    	my $line = $_;
    	#print $line;
    	my( $coco_min, $coco_max ) = split(/\t/, $line);
    	$coco_min = sprintf "%.2f", $coco_min;
    	$coco_max = sprintf "%.2f", $coco_max;
    
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
    
    print "<p></p>";
  	print "<p></p>";
  	print "<p></p>";
    
    print "<h2>Scatterplots showing correlation between replicates:</h2>";
    
    print "<p></p>";
     
    print "<table>";
    
    print "<img src=\"$scatter_plot_1\" alt=\"Rep1 vs Rep2:\"> &nbsp;&nbsp;&nbsp;&nbsp;";
 
   
    print "<img src=\"$scatter_plot_2\" alt=\"Rep2 vs Rep3:\"> &nbsp;&nbsp;&nbsp;&nbsp;";
   
    print "<img src=\"$scatter_plot_3\" alt=\"Rep1 vs Rep3:\">";
    
    print "</td>";

  
  #print "<td align=left valign=top>\n";
  #print "<p>";
  #print "<h1>Reanalysis:</h1>";
  #print "<b>Modify plateconf file for reanalysis:</b>";
  #print "</p>";
  
  ## replace 'siCON1' with 'empty' ##

  #print "<p><p>";
  
  #print $q -> checkbox( -name => 'sicon1_empty',
  #  					-checked => 0,
  # 					    -value => 'ON',
  #  					-label => 'remove siCON1' );

  #print "</p></p>";
  
  ## replace 'siCON2' with 'empty' ##
  
  #print "<p>";
  
  #print $q -> checkbox( -name => 'sicon2_empty',
  #  					-checked => 0,
  # 					    -value => 'ON',
  #  					-label => 'remove siCON2' );

  #print "</p>";
  
  ## replace 'allstar' with 'empty' ##
  
  #print "<p>";
  
  #print $q -> checkbox( -name => 'allstar_empty',
  #  					-checked => 0,
  # 					    -value => 'ON',
  #  					-label => 'remove allstar' );

  #print "</p>";
  
  #print $q -> hidden ( -name => 'screen_dir_name',
  #					   -value => $screen_dir_name );
  					  
  #print $q -> hidden ( -name => 'plate_conf',
  #					   -value => $plateconf );				  
  
 ## submit the updated plateconf file for re-analysis ##
                                                
  #print "<p>";
  #print "<input type=\"submit\" id=\"save_new_screen\" value=\"Reanalyse\" name=\"save_new_screen\"/>";
  #print "</p>"; 
  
  #print "</td>";
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
    );
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



