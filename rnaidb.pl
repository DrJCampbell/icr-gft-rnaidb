#!/usr/bin/perl -w
# rnaidb.pl - CGI UI for RNAi database
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);

# stuff to configure when moving...
my $users_file = './users.txt';
my $temp_file_path = '/home/jambell/www/www/sample_tracking/uploads/tmp.csv';
my $sqldb_name = 'my_db';
my $sqldb_host = 'localhost';
my $sqldb_port = '3306';
my $sqldb_user = 'myName';
my $sqldb_pass = 'P455w0rd';
my $server = 'gft.icr.ac.uk';
my $server_path = '/cgi-bin/rnaidb';

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
# Header html
my $page_header = "<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /><title>GFT RNAi database</title><link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"http://www.jambell.com/css/rnaidb.css\" /><meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" /></head><body><div id=\"Box\"></div><div id=\"MainFullWidth\"><a href=\"http://gft.icr.ac.uk\"><img src=\"logo_placeholder_noLeftBorder.png\" width=415px height=160px></a>";
my $page_footer = "</div> <!-- end Main --></div> <!-- end Box --></body></html>";

my $q = new CGI;
my $login_key = $q -> cookie("login_key");

# The query needs to pass one of these authentications
# or it's back to the login page.
#
if ($q -> param( "add_new_user" )){
# data sent from login page.
# should include user, pass and a one-time key
  &add_new_user ( $q );
}
elsif (defined($login_key)){
# the usual thing that should happen.
# we get a cookie back and want to see
# who it matches to.
  &authenticate_login_key ($login_key);
}
elsif($q -> param( "authenticate_user" )){
# sent from the login form
# need to hash $user.$pass (x times)
# check it against the stored value
# set a cookie and redirect to here
  &authenticate_user($q);
}
else{
# login form plus create new account form.
  &login;
  exit(0);
}



# connect to the database
my $dsn = "DBI:mysql:database=$sqldb_name;host=$sqldb_host;port=$sqldb_port";
my $dbh = DBI->connect($dsn, $sqldb_user, $sqldb_pass, { RaiseError => 1, AutoCommit => 0 })
  or die "Cannot connect to database: " . $DBI::errstr;

# Decide what to do based on the params passed to the script
if ($q -> param( "show_all_screens" )){
  &show_all_screens ( $q );
}
elsif ($q -> param( "add_new_screen" )){
  &add_new_screen ( $q );
}
elsif ($q -> param( "save_new_screen" )){
  &save_new_screen ( $q );
}
elsif ($q -> param( "configure_export" )){
  &configure_export ( $q );
}
elsif ($q -> param( "run_export" )){
  &run_export ( $q );
}
elsif ($q -> param( "home" )){
  &home ( $q );
}
elsif ($q -> param( "set_thermo" )){
  &set_thermonuclear ( $q );
}
elsif ($q -> param( "go_thermo" )){		# REMOVE THIS
  &go_thermonuclear ( $q );				# FROM PRODUCTION
}										# CODE...
elsif ($q -> param( "create_tables" )){
  &create_tables ( $q );
}
else{
 &login ( $q );
}

#
# Subs...
#


sub add_new_screen{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Add new screen:</h1>";


  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  # =========================
  # add main screen info here
  # =========================
  
  # get the CTG excel file
  print $q -> filefield(-name=>'uploaded_file',
                        -default=>'starting value',
                        -size=>35,
                        -maxlength=>256);

  # get the tissue
  my @tissues = ("Please select", "BREAST", "LARGE_INTESTINE"); # this should be read from a text file or from the SQL database
  print $q -> popup_menu(
  	-name => 'tissue_type',
  	-values => \@tissues,
  	-default => 'Please select',
  	);
  
  # get the cell line name
  print "Cell line name:<br />";
  print $q -> textfield ( -name => "cell_line_name",
                          -value => 'Enter cell line name',
                          -size => "30",
                          -maxlength => "45");

  # get the screen name
  print "Screen name:<br />";
  print $q -> textfield ( -name => "screen_name",
                          -value => 'Enter screen name',
                          -size => "30",
                          -maxlength => "100");
  
  # get the date
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  $mon = ++;
  my $date = sprintf(%04u-%02u-%02u,$year,$mon,$mday); # set this to current date using localtime()

  print "Date of screen:<br />";
  print $q -> textfield ( -name => "date_of_run",
                          -value => $date,
                          -size => "30",
                          -maxlength => "45");
  

  # get the user (who is logged in?)
  print "Operator:<br />";
  print $q -> textfield ( -name => "operator",
                          -value => $user,
                          -size => "30",
                          -maxlength => "45");
  
  # get the transfection_reagent
  my @transfection_reagent = ("Please select", "Lipofectamine", "Bleach"); # this should be read from a text file or from the SQL database
  print $q -> popup_menu(
  	-name => 'transfection_reagent',
  	-values => \@transfection_reagent,
  	-default => 'Please select',
  	);
  
  # get the intsrument
  my @instrument = ("Please select", "Inst_1", "Inst_2"); # this should be read from a text file or from the SQL database
  print $q -> popup_menu(
  	-name => 'instrument',
  	-values => \@instrument,
  	-default => 'Please select',
  	);

  print "</td>\n";


  # ======================
  # add isogenic info here
  # ======================

  print "<td align=left valign=top>\n";
  
  print "<h2>Information for isogenic screens</h2><br />";

  # is the screen isogenic

  print $q -> checkbox(
  	-name=>'is_isogenic',
    -checked=>0,
    -value=>'ON',
    -label=>'this is an isogenic screen');
  
  # which gene was modified
  print "Modified gene name:<br />";
  print $q -> textfield ( -name => "gene_name_if_isogenic",
                          -value => 'Enter gene name',
                          -size => "30",
                          -maxlength => "45");
  
  # what isogenic set is this part of
  print "Isogenic set:<br />";
  print $q -> textfield ( -name => "name_of_set_if_isogenic",
                          -value => 'Isogenic set name',
                          -size => "30",
                          -maxlength => "45");

  # get isogenic mutant description (i.e. parental etc)
  print "Isogenic description:<br />";
  print $q -> textfield ( -name => "isogenic_mutant_description",
                          -value => 'e.g. parental',
                          -size => "30",
                          -maxlength => "45");
  
  # get method of isogenic knockout etc
  print "Method of isogenic mutation:<br />";
  print $q -> textfield ( -name => "method_of_isogenic_knockdown",
                          -value => 'e.g. ZFN or shRNA',
                          -size => "30",
                          -maxlength => "45");

  
  print "</td>\n";
  print "</tr>\n";

  
  # ===========================================
  # put notes text field and submit button here
  # ===========================================

  print "<tr colspan=2>\n";
  print "<td align=left valign=top>\n";

  print "Notes about this screen:<br />";
  print $q -> textfield ( -name => "notes",
                          -default => 'optional notes go here',
                          -rows => "8",
                          -columns => "60");
  
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Save this project\" name=\"save_new_screen\" />";

  
  print "</td>\n";
  print "</tr>\n";
  print "</table>\n";

  print $q -> end_multipart_form(); 
  
  print "$page_footer";
  print $q -> end_html;

}

sub save_new_screen{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Saving new screen data:</h1>";

  my $lightweight_fh  = $q->upload('uploaded_file');
  
  # undef may be returned if it's not a valid file handle
  if (defined $lightweight_fh) {
    # Upgrade the handle to one compatible with IO::Handle:
    my $io_handle = $lightweight_fh->handle;

    open (OUTFILE,'>',$temp_file_path);
    my $bytesread = undef;
    my $buffer = undef;
    while ($bytesread = $io_handle->read($buffer,1024)) {
      print OUTFILE $buffer;
    }
    close OUTFILE;
  }
  
  # get params to check the previous page is working as expected
#  my $uploaded_file = $q -> param( "uploaded_file" );
  my $tissue_type = $q -> param( "tissue_type" );
  my $cell_line_name = $q -> param( "cell_line_name" );
  my $screen_name = $q -> param( "screen_name" );
  my $date_of_run = $q -> param( "date_of_run" );
  my $operator = $q -> param( "operator" );
  my $transfection_reagent = $q -> param( "transfection_reagent" );
  my $instrument = $q -> param( "instrument" );
  my $is_isogenic = $q -> param( "is_isogenic" );
  my $gene_name_if_isogenic = $q -> param( "gene_name_if_isogenic" );
  my $name_of_set_if_isogenic = $q -> param( "name_of_set_if_isogenic" );
  my $isogenic_mutant_description = $q -> param( "isogenic_mutant_description" );
  my $method_of_isogenic_knockdown = $q -> param( "method_of_isogenic_knockdown" );
  my $notes = $q -> param( "notes " );
  
  
  # probably need to copy $temp_file_path somewhere safe and give it to an R script to convert
  # process the data received from add_new_screen
  
  # Lots of stuff to go in here:
  
  # call R to convert xls file to plate files
  
  # enter data into SQL database
  
  # call R to run cellHTS2
  
  # store URL for HTML report in database
  
  # store z-score and QC in database
  
  # print a done message and re-direct to another page.
  
  print "$page_footer";
  print $q -> end_html;
}

sub show_all_screens{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Available screens:</h1>";
  
  # read data from database and output
  # summary info about all screens
  
  print "$page_footer";
  print $q -> end_html;
}

sub configure_export{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Export options:</h1>";
  
  # display a page with some
  # export options and a button
  # to run the export
  
  print "$page_footer";
  print $q -> end_html;
}

sub run_export{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Your data:</h1>";
  
  # recieve data from configure_export
  # and output data as a text file
  
  print "$page_footer";
  print $q -> end_html;
}

sub home{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>Gene Function Team RNAi Database:</h1>";
  
  # present a hope page
  
  print "$page_footer";
  print $q -> end_html;
}


###########################


sub add_new_user{
  # get user, pass and oneTimePass, hash user.pass and store
  # set a cookie then redirect to view_all_projects
  my $q = shift;
  my $user = $q -> param ('user');
  my $pass = $q -> param ('pass');
#  my $auth_code = $q -> param ('auth_code');
    
  #my $correct_auth_code = md5_hex($user . $auth_code_salt);
  #die "Failed login...\n" unless $auth_code eq $correct_auth_code;
  
#  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/){
#    &login("username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters");
#    exit(1);
#  }
#  unless($pass =~ /^.{1,4096}$/){
#    &login("password must not exceed 4096 characters - and yes, it get's hashed :)");
#  }
  
  my $user_pass_hash = md5_hex($user . $pass);
#  for(my $i = 0; $i <= $num_hash_itts; $i ++){
#    my $user_pass_hash = md5_hex($user_pass_hash);
#  }
  open USERS, ">> ./users.txt" or warn "can't append to the file with user names file: $!\n";
  print "$user\t$user_pass_hash\n";
  close USERS;
  
  &set_cookie($user_pass_hash);
  exit(0);
}
  
sub authenticate_login_key{
  my $login_key = shift;
  open USERS, "< ./users.txt" or die "can't open the file with the list of user names: $!\n";
  my $login_OK = 0;
  my $user = undef;
  while (<USERS>){
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
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
#  unless($user =~ /^([A-Za-z0-9\._+]{1,1024})$/){
#    die "username must be alphanumeric (plus dots and underscores) and must not exceed 1024 characters";
#    exit(1);
#  }
#  unless($pass =~ /^.{1,4096}$/){
#    die "password must not exceed 4096 characters - and yes, it get's hashed :)";
#  }

#  my $user_pass_hash = md5_hex($user . $pass);
  my $user_pass_hash = md5_hex($pass);
#  for(my $i = 0; $i <= $num_hash_itts; $i ++){
#    my $user_pass_hash = md5_hex($user_pass_hash);
#  }
  open USERS, "< ./users.txt" or die "can't open the file with the list of user names: $!\n";
  my $login_OK = 0;
  while (<USERS>){
    my ($stored_user, $stored_hash) = split(/[\t ]+/);
    $login_OK = 1 if $stored_hash =~ /$user_pass_hash/;
  }
  close USERS;
  if ($login_OK == 1){
    return $user;
  }
  else{
    &login("Login failed - please check your username and password are correct");
    exit(1);
  }
}
 
sub login{
  my $message = shift;
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>GFT RNAi Database</h1>\n";
  print "<p>$message</p>\n" if defined $message;
  print "<table width = 100%><tr><td align=left valign=top><b>Please log in:</b><br>";
  print $q -> startform (-method=>'POST');
  print $q -> p ( "username: &nbsp; &nbsp;");
  print $q -> textfield (-name => "user", -size => 12);
  print $q -> p ( "Password: &nbsp;&nbsp;");
  print $q -> password_field (-name => "pass", -size => 20);
  print "&nbsp;";
  print "<p>Please note - this site uses cookies...</p>\n";
  print $q -> submit (-name => "authenticate_user", -value => "login...");
  print $q -> endform;
  print "</td><td align=left valign=top><b>Create a new account:</b><br>";
  print $q -> startform (-method=>'POST');
  print $q -> p ( "username: &nbsp; &nbsp;");
  print $q -> textfield (-name => "user", -size => 12);
  print $q -> p ( "Password: &nbsp;&nbsp;");
  print $q -> password_field (-name => "pass", -size => 20);
  print $q -> p ( "Authentication code: &nbsp;&nbsp;");
  print $q -> textfield (-name => "auth_code", -size => 20);
  print "&nbsp;";
  print $q -> submit (-name => "add_new_user", -value => "create new account");
  print $q -> endform;
  print "</td></tr></table></div>";
  print $q -> end_html;
  exit(0);
}

sub set_cookie{
  my $login_key = shift;
  print $q -> header ("text/html");
  print "$page_header";

  my $cookie = $q -> cookie( -name => "login_key",
                             -value => $login_key
                             );
#  print $q -> redirect( -url => "/cgi-bin/rnaidb/rnaidb.pl?view_all_projects=TRUE",
#                        -cookie => $cookie
#                        );
  print $q -> redirect( -url => "/cgi-bin/rnaidb/rnaidb.pl?view_all_projects=TRUE"); # for debugging

exit(0);
}

  
  
  

# =-=-=-=-=-=-=-=-=-=--=-=-=-=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--= #
# Soubroutine below are for development only and should be removed from production code
# their purpose is to make it easy to COMPLETELY TRASH THE DATABASES with only so much
# as a login. They should be removed to standalone shell scripts for initial DB config.
# =-=-=-=-=-=-=-=-=-=--=-=-=-=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--=-=-=--= #
  
  
sub set_thermo{  
  print $q -> header ("text/html");
  print "$page_header";
  print "<H1>Nuke all database tables!</h1>";
  print "clicking the button below will re-create all empty tables in the database...";
  print "<form method=\"post\">";
  print "<input type=\"submit\" id=\"go_thermonulcear\" value=\"create empty database\" name=\"go_thermonuclear\" />";
#  print $q -> hidden (-name => "user", -value => "$user");
#  print $q -> hidden (-name => "pass", -value => "$pass");
  print "</form>";
  
}

sub go_thermo{

  print $q -> header ("text/html");
  print "$page_header";
  
  # begin dropping tables
# my @tables = qw(aliquots analyses lib_id lib_preps ngs_runs patients projects reports samples xeno_models xeno_results);
  my @tables = qw( aliquots analyses lib_preps ngs_runs patients projects reports samples xeno_models xeno_results );
  
  my $sql = '';
  my $sth = '';
  foreach my $table (@tables){
    $sql = "DROP TABLE $table;";
    $sth = $dbh->prepare($sql)
     or die "Cannot prepare: " . $dbh->errstr();
    $sth->execute() or die "Cannot execute command: " . $sth->errstr();
    $sth->finish();
    print "<p>removed $table</p>\n";
  }

  &create_tables;
}
  
sub create_tables{
  my $q = shift;
  my $sql = '';
  my $sth = '';  
  # re-create empty tables...
 
  $sql = qq`
CREATE TABLE projects (
proj_id int,
title varchar(255),
owner_name varchar(255),
owner_email varchar(255),
owner_other_contacts varchar(512),
project_folder varchar(1024)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created projects</p>\n";
  
  
  $sql = qq`
CREATE TABLE patients (
pat_id int,
proj_id int,
dob varchar(255),
gender varchar(255),
notes_file varchar(1024)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created patients</p>\n";

  $sql = qq`
CREATE TABLE samples (
samp_id int,
pat_id int,
proj_id int,
description varchar(255),
site varchar(255),
assayed_conc_pg_per_ul int
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created samples</p>\n";

  $sql = qq`
CREATE TABLE aliquots (
aliq_id int,
samp_id int,
pat_id int,
proj_id int,
location varchar(255),
amount varchar(255)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created aliquots</p>\n";

  $sql = qq`
CREATE TABLE lib_preps (
lib_id int,
aliq_id int,
samp_id int,
pat_id int,
proj_id int,
type varchar(255),
barcode varchar(255),
capture varchar(255),
capture_kit varchar(255),
amount varchar(255),
library_prep_date varchar(255)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created lib_preps</p>\n";

  $sql = qq`
CREATE TABLE ngs_runs (
ngs_id int,
lib_id int,
aliq_id int,
samp_id int,
pat_id int,
proj_id int,
lane varchar(255),
flowcell varchar(255),
platform varchar(255),
machine varchar(255),
recipe varchar(255),
run_folder varchar(1024)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created ngs_runs</p>\n";

  $sql = qq`
CREATE TABLE analyses (
anal_id int,
lib_id int,
aliq_id int,
samp_id int,
pat_id int,
proj_id int,
sample_info varchar(1024),
analysis_config varchar(1024),
resources varchar(1024),
data_analysis_folder varchar(1024)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created analyses</p>\n";

  $sql = qq`
CREATE TABLE xeno_models (
xeno_id int,
aliq_id int,
samp_id int,
pat_id int,
proj_id int,
strain varchar(255),
site varchar(255),
date_xeno_transplant varchar(255),
date_collected varchar(255)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created xeno_models</p>\n";

  $sql = qq`
CREATE TABLE xeno_results (
xenres_id int
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created xeno_results</p>\n";

  $sql = qq`
CREATE TABLE reports (
report_id int,
proj_id int,
rep_version int,
rep_path varchar(1024),
rep_status varchar(255)
);`;
  $sth = $dbh->prepare($sql)
    or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  print "<p>created reports</p>\n";
  
  
  $dbh->disconnect();  
#  &view_all_projects($q);
  
}
