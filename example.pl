#!/usr/bin/perl -w
# code stubs with extra comments

# These 'use' statements are called Pragamas
# strict is always recommended. It checks you
# have declared variables before use.
# CGI and DBI are essential for this app
# CGI::Carp is used to send perl errors to the browser (nice)
# Digest seems to be used for hashing passwords (with crypto salt)
# I don't think we need LWP for this app...
use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use LWP::UserAgent;

# stuff to configure when moving...
my $users_file = './users.txt';
my $sqldb_name = 'my_db';
my $sqldb_host = 'localhost';
my $sqldb_port = '3306';
my $sqldb_user = 'myName';
my $sqldb_pass = 'P455w0rd';
my $server = '.server.com';
my $server_path = '/cgi-bin/rnaidb';

# These are needed to allow file uploads
# whilst reducing the risk of attack (someone
# uploading a huge file and filling the disk)
$CGI::DISABLE_UPLOADS = 0;
$CGI::POST_MAX = 204_800;


# security config
my $num_hash_itts = 0;
my $auth_code_salt = "1IwaCauw4Lxum6WU5hM8";
# The $auth_code_salt should be read in from
# a file that is generated if it doesn't exist


# HTML strings used in pages:
# Header html
my $page_header = "<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /><title>GFT RNAi database</title><link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" /><meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" /></head><body><div id=\"Box\"></div><div id=\"MainFullWidth\"><a href=\"/cgi-bin/PLEASE_PUT_A_PROPER_PATH_IN_HERE__________.pl?view_all_projects=TRUE\"><img src=\"/PLEASE_PUT_A_PROPER_PATH_IN_HERE__________/logo_placeholder_noLeftBorder.png\" width=415px height=160px></a>";
# css stub: <link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" />
my $page_footer = "</div> <!-- end Main --></div> <!-- end Box --></body></html>";

my $q = new CGI;
my $login_key = $q -> cookie("login_key");

# LOGIN DISSABLED FOR TESTING 
# ***************************
# The query needs to pass one of these authentications
# or it's back to the login page.
#
#if ($q -> param( "add_new_user" )){
  # data sent from login page.
  # should include user, pass and a one-time key
#  &add_new_user ( $q );
#}
#elsif (defined($login_key)){
  # the usual thing that should happen.
  # we get a cookie back and want to see
  # who it matches to.
#  &authenticate_login_key ($login_key);
#}
#elsif($q -> param( "authenticate_user" )){
  # sent from the login form
  # need to hash $user.$pass (x times)
  # check it against the stored value
  # set a cookie and redirect to here
#  &authenticate_user($q);
#}
#else{
  # login form plus create new account form.
#  &login;
#  exit(0);
#}



# connect to the database
my $dsn = "DBI:mysql:database=$sqldb_name;host=$sqldb_host;port=$sqldb_port";
my $dbh = DBI->connect($dsn, $sqldb_user, $sqldb_pass, { RaiseError => 1, AutoCommit => 0 })
  or die "Cannot connect to database: " . $DBI::errstr;

# Decide what to do based on the params passed to the script
if ($q -> param( "view_project" )){
  &view_project ( $q );
}
elsif ($q -> param( "add_project" )){
  &add_project ( $q );
}
elsif ($q -> param( "save_project" )){
  &save_project ( $q );
}
elsif ($q -> param( "save_project_from_file" )){
  &save_project_from_file ( $q );
}
elsif ($q -> param( "add_patient" )){
  &add_patient ( $q );
}
elsif ($q -> param( "view_sample" )){
  &view_sample ( $q );
}
elsif ($q -> param( "add_sample" )){
  &add_sample ( $q );
}
elsif ($q -> param( "add_aliquot" )){
  &add_project ( $q );
}
elsif ($q -> param( "set_thermo" )){
  &set_thermonuclear ( $q );
}
elsif ($q -> param( "go_thermo" )){
  &go_thermonuclear ( $q );
}
elsif ($q -> param( "create_tables" )){
  &create_tables ( $q );
}
elsif ($q -> param( "view_all_projects" )){
  &view_all_projects ( $q );
}
else{
 &login ( $q );
}

#
# Subs...
#

# view_screens - show summary of all screens in database
# get_new_screen - create page with form to collect new screen data
# save_new_screen - recieve data from get_new_screen page and process
# export_data - define what is needed and write data/files as tsv or similar
#
# error handing...


sub view_all_projects{
  print $q -> header ("text/html");
  print "$page_header";
  print "<h1>TPU projects:</h1>";

  # button to create a new project
  print "<form method=\"post\">";
  print "<input type=\"submit\" id=\"add_project\" value=\"add a new project\" name=\"add_project\" />";
  print "</form>";  

  # print a table with the current projects...  
  print "<form method=\"post\">";
  print "<table cellpadding=10 align=\"left\"><tr><th align=\"left\">project id</th><th align=\"left\">title</th><th align=\"left\">owner</th><th align=\"left\">email</th><th align=\"left\">contacts</th><th align=\"left\">project folder</th>";  

  my $sql = 'SELECT * FROM projects;';
  my $sth = $dbh->prepare($sql)
   or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  my @row = ();
  while(@row = $sth->fetchrow_array()){
    my @record = @row;
    my $proj_id = shift(@record);
    print "<tr><td><input type=\"submit\" id=\"$proj_id\" value=\"$proj_id\" name=\"view_project\" />";
    my $table_row = join("</td><td>",@record);
    $table_row = "<td>" . $table_row . "</td></tr>";
    print "$table_row";
  }
  print "</table>";
  print "</form>";
  print $q -> end_html;

  # moved this from just after the execute command whilst debugging...
  $dbh->disconnect();
}

sub add_project{
  print $q -> header ("text/html");
  print "$page_header";
  
  # get the max id value and add 1
  my $sql = 'SELECT MAX( proj_id ) FROM projects;';
  my $sth = $dbh->prepare($sql)
   or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  my @row = $sth->fetchrow_array;
  my $proj_id = $row[0] + 1 if $row[0] =~ /\d+/;
  
  print "<h1>Create a new project:</h1>";

  
  # This table layout is pretty crude. Also bad for screen readers etc... Div tags layed out with css would improve it.
  
  print "<table cellpadding=10 align=\"left\"><tr><td align=\"left\" valign=\"top\">"; # <<< START TABLE
  
  print "<h2>File upload method:</h2>";  

  print "</td><td align=\"left\" valign=\"top\" colspan=\"2\">"; # <<< NEXT TABLE DATA
  
  print "<h2>Fill-in form method:</h2>";

  print "</td></tr><tr><td align=\"left\" valign=\"top\">"; # <<< NEXT TABLE ROW + DATA
  
  print "<ul><li>Download a <a href=\"/sample_tracking/project_template.csv\">project template</a></li><li>Open it in Excel (CSV format)</li><li>Add info for the project(s)</li><li>Upload it.</li></ul><br /><br />";
    
  print $q -> start_multipart_form(-method=>"POST");  
  print $q -> filefield(-name=>'uploaded_file',
                        -default=>'starting value',
                        -size=>35,
                        -maxlength=>256);
  print "<br /><br />";
  print $q -> submit(-name=>'save_project_from_file',
                     -value=>'Upload completed project file');
  print $q -> end_multipart_form();
  
  print "</td><td align=\"left\" valign=\"top\">"; # <<< NEXT TABLE DATA

  print "<form method=\"post\">";  

  print "id:<br />";
  print $q -> textfield ( -name => "proj_id",
                          -value => $proj_id,
                          -size => "3",
                          -maxlength => "5");
  print "<br /><br />";
  print "title:<br />";
  print $q -> textfield ( -name => "title",
                          -value => "",
                          -size => "20",
                          -maxlength => "256");
  print "<br /><br />";

  print "owner:<br />";
  print $q -> textfield ( -name => "owner",
                          -value => "",
                          -size => "15",
                          -maxlength => "256");
  print "<br /><br />";

  print "</td><td align=\"left\" valign=\"top\">"; # <<< NEXT TABLE DATA
  
  
  print "email:<br />";
  print $q -> textfield ( -name => "email",
                          -value => "",
                          -size => "30",
                          -maxlength => "256");
  print "<br /><br />";

  print "other contacts:<br />";
  print $q -> textfield ( -name => "contacts",
                          -value => "",
                          -size => "20",
                          -maxlength => "1024");
  print "<br /><br />";

  print "project folder:<br />";
  print $q -> textfield ( -name => "project_folder",
                          -value => "",
                          -size => "50",
                          -maxlength => "1024");
  print "<br /><br />";

  print $q -> submit(-name=>'save_project',
                     -value=>'Save project');
  
  print "</td></table>"; # <<< NEXT TABLE DATA
  
  print "</form>";

  
}

sub save_project{
  my $proj_id = $q -> param('proj_id');
  my $title = $q -> param('title');
  my $owner = $q -> param('owner');
  my $email = $q -> param('email');
  my $contacts = $q -> param('contacts');
  my $project_folder = $q -> param('project_folder');
  
  my $sql = "insert into projects (proj_id, title, owner_name, owner_email, owner_other_contacts, project_folder) VALUES ('$proj_id', '$title', '$owner', '$email', '$contacts', '$project_folder');";
  my $sth = $dbh->prepare($sql)
   or die "Cannot prepare: " . $dbh->errstr();
  $sth->execute() or die "Cannot execute command: " . $sth->errstr();
  $sth->finish();
  &view_all_projects($q);

#  $dbh->disconnect(); # don't need this as view_all_projects disconnects
  
}
  
sub save_project_from_file{
  my $q = shift;
  my $lightweight_fh  = $q->upload('uploaded_file');
  
  # undef may be returned if it's not a valid file handle
  if (defined $lightweight_fh) {
    # Upgrade the handle to one compatible with IO::Handle:
    my $io_handle = $lightweight_fh->handle;

    open (OUTFILE,'>','/home/jambell/www/www/sample_tracking/uploads/tmp.csv');
    my $bytesread = undef;
    my $buffer = undef;
    while ($bytesread = $io_handle->read($buffer,1024)) {
      print OUTFILE $buffer;
    }
    close OUTFILE;
  }
  open IN, "< /home/jambell/www/www/sample_tracking/uploads/tmp.csv" or die "Unable to read uploaded file: $!\n\n";  
  my ($proj_id, $title,$owner,$email,$contacts,$project_folder) = (undef,undef,undef,undef,undef,undef);
  while(<IN>){
    next if(/^proj_id,/); # skip header
    next if (/^#/);
    ($proj_id, $title,$owner,$email,$contacts,$project_folder) = split(/,/);
    # Need to validate the fomats of these variables...
    my $sql = "insert into projects (proj_id, title, owner_name, owner_email, owner_other_contacts, project_folder) VALUES ('$proj_id', '$title', '$owner', '$email', '$contacts', '$project_folder');";
    my $sth = $dbh->prepare($sql)
      or die "Cannot prepare: " . $dbh->errstr();
    $sth->execute() or die "Cannot execute command: " . $sth->errstr();    
    $sth->finish();
  }
  &view_all_projects($q);
}



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
  print "<h1>PoP sample tracker</h1>\n";
  print "<p>$message</p>\n" if defined $message;
  print "<table width = 100%><tr><td align=left valign=top><b>Please log in:</b><br>";
  print $q -> startform (-method=>'POST');
  print $q -> p ( "username &nbsp; &nbsp;");
  print $q -> textfield (-name => "user", -size => 12);
  print $q -> p ( "Password.&nbsp;&nbsp;");
  print $q -> password_field (-name => "pass", -size => 20);
  print "&nbsp;";
  print "<p>Please note - this site uses cookies...</p>\n";
  print $q -> submit (-name => "authenticate_user", -value => "login...");
  print $q -> endform;
  print "</td><td align=left valign=top><b>Create a new account:</b><br>";
  print $q -> startform (-method=>'POST');
  print $q -> p ( "username &nbsp; &nbsp;");
  print $q -> textfield (-name => "user", -size => 12);
  print $q -> p ( "Password.&nbsp;&nbsp;");
  print $q -> password_field (-name => "pass", -size => 20);
  print $q -> p ( "Authentication code.&nbsp;&nbsp;");
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