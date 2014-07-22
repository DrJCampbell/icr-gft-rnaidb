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
my $page_header = "<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=utf-8\" /><title>GFT RNAi database</title><link rel=\"stylesheet\" type=\"text/css\" media=\"screen\"  href=\"/css/rnaidb.css\" /><meta name=\"viewport\" content=\"width=1000, initial-scale=0.5, minimum-scale=0.45\" /></head><body><div id=\"Box\"></div><div id=\"MainFullWidth\"><a href=\"http://gft.icr.ac.uk\"><img src=\"http://www.jambell.com/sample_tracking/ICR_GFTRNAiDB_logo_placeholder.png\" width=415px height=160px></a>";
my $page_footer = "</div> <!-- end Main --></div> <!-- end Box --></body></html>";

# == config over, code below == #

# make a new CGI object
my $q = new CGI;

# This line may need to be moved in the future
# it allows us to create a hash to add to the 
# users.txt file...
if ($q -> param( "authenticate_user" )){
  &authenticate_user ( $q );
}
elsif ($q -> param( "add_new_user" )){
  &add_new_user ( $q );
}
elsif ($q -> param( "login" )){
  &login ( $q );
}

# either get a cookie or go to login page and exit
my $login_key = $q -> cookie("login_key") || &login($q) && exit(0);

# if we got a cookie, is it valid?
my $user = &authenticate_login_key($login_key);


# connect to the database
#my $dsn = "DBI:mysql:database=$sqldb_name;host=$sqldb_host;port=$sqldb_port";
#my $dbh = DBI->connect($dsn, $sqldb_user, $sqldb_pass, { RaiseError => 1, AutoCommit => 0 })
#  or die "Cannot connect to database: " . $DBI::errstr;

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
elsif ($q -> param( "configure_export" )){
  &configure_export ( $q );
}
elsif ($q -> param( "run_export" )){
  &run_export ( $q );
}
else{
 &home ( $q );
}

#
# Subs...
#


# home sub for debugging

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
  print "$page_footer";
  print $q -> end_html;
}


sub add_new_screen{
  print $q -> header ("text/html");
  my $user = $q -> param('user');
  print "$page_header";
  print "<h1>Add new screen:</h1>";


  print $q -> start_multipart_form(-method=>"POST"); 
  
  print "<table width = 100%>\n";
  print "<tr>\n";
  print "<td align=left valign=top>\n";
  
  # =========================
  # add main screen info here
  # =========================
 

  print "<p><b>General screen info:</b></p>";
  print "<p>";
 
  # get the CTG excel file
  print $q -> filefield(-name=>'uploaded_file',
                        -default=>'starting value',
                        -size=>35,
                        -maxlength=>256);
  print "</p>";
  # get the tissue
  my @tissues = ("Please select", "BREAST", "LARGE_INTESTINE"); # this should be read from a text file or from the SQL database

  print "<p>Tissue of origin:<br />";
  print $q -> popup_menu(
  	-name => 'tissue_type',
  	-values => \@tissues,
  	-default => 'Please select',
  	);

  print "</p><p>";
  # get the cell line name
  print "Cell line name:<br />";
  print $q -> textfield ( -name => "cell_line_name",
                          -value => 'Enter cell line name',
                          -size => "30",
                          -maxlength => "45");
  print "</p><p>";


  # get the screen name
  print "Screen name:<br />";
  print $q -> textfield ( -name => "screen_name",
                          -value => 'Enter screen name',
                          -size => "30",
                          -maxlength => "100");
  
  # get the date
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

  # get the user (who is logged in?)
  print "Operator:<br />";
  print $q -> textfield ( -name => "operator",
                          -value => $user,
                          -size => "30",
                          -maxlength => "45");

  print "</p><p>Transfection reagent:<br />";  
  # get the transfection_reagent
  my @transfection_reagent = ("Please select", "Lipofectamine", "Bleach"); # this should be read from a text file or from the SQL database
  print $q -> popup_menu(
  	-name => 'transfection_reagent',
  	-values => \@transfection_reagent,
  	-default => 'Please select',
  	);
  
  # get the intsrument
  print "</p><p>Instrument:<br />";
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
  
  print "<p><b>Information for isogenic screens</b></p>";

  # is the screen isogenic

  print "<p>";
  print $q -> checkbox(
    -name=>'is_isogenic',
    -checked=>0,
    -value=>'ON',
    -label=>'this is an isogenic screen');

  print "</p><p>";
  # which gene was modified
  print "Modified gene name:<br />";
  print $q -> textfield ( -name => "gene_name_if_isogenic",
                          -value => 'Enter gene name',
                          -size => "30",
                          -maxlength => "45");
  
  print "</p><p>";
  # what isogenic set is this part of
  print "Isogenic set:<br />";
  print $q -> textfield ( -name => "name_of_set_if_isogenic",
                          -value => 'Isogenic set name',
                          -size => "30",
                          -maxlength => "45");

  print "</p><p>";
  # get isogenic mutant description (i.e. parental etc)
  print "Isogenic description:<br />";
  print $q -> textfield ( -name => "isogenic_mutant_description",
                          -value => 'e.g. parental',
                          -size => "30",
                          -maxlength => "45");
  
  print "</p><p>";
  # get method of isogenic knockout etc
  print "Method of isogenic mutation:<br />";
  print $q -> textfield ( -name => "method_of_isogenic_knockdown",
                          -value => 'e.g. ZFN or shRNA',
                          -size => "30",
                          -maxlength => "45");
  print "</p>";
  print "</td>\n";
  print "</tr>\n";

  
  # ===========================================
  # put notes text field and submit button here
  # ===========================================

  print "<tr colspan=2>\n";
  print "<td align=left valign=top>\n";

  print "<p>";
  print "Notes about this screen:<br />";
  print $q -> textarea ( -name => "notes",
                          -default => 'optional notes go here',
                          -rows => "8",
                          -columns => "60");
  print "</p><p>";
  print "<input type=\"submit\" id=\"save_new_screen\" value=\"Save this project\" name=\"save_new_screen\" />";
  print "</p>";
  
  print "</td>\n";
  print "</tr>\n";
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

###########################


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
  open USERS, "< ./users.txt" or die "can't open the file with the list of user names: $!\n";
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
    -url => "/cgi-bin/rnaidb.pl?add_new_screen=1",
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
    -url => "/cgi-bin/rnaidb.pl",
    -cookie => $cookie
    );

  exit(0);
}


