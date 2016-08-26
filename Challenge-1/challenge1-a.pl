#!/usr/bin/perl

##################################################################################################
#
#  Name:     Challenge1-a.pl
#  Date:     8/25/2016
#  Author:   Jim Henk
#  Rev:      0.1
#
#    Script reads config file consisting of server names and types - 'development' or 'production',
#    and uses it to deploy a config file named app-config.conf to each server mentioned, configured
#    appropriatly for the corresponding server type.
#
#    The default user and password to be included in the config file may be overridden by parameters
#
#    ASSUMPTIONS:
#        The user running this script has an existing account on each server which has write privs
#        inside the /etc, as well as privs to change ownership to those same files.
#
#        The account has existing private/public key relationships with each server to allow for
#        password-less ssh.
#
##################################################################################################

use Getopt::Long;
use File::Basename;
use Data::Dumper;
use Switch;

my $temp_file = "app-config.conf";
my $out_filename = "/etc/$temp_file";
my $default_user = "Walter White";
my $default_pwd = 'Wh@tsmyN@m3?';
my $program = basename($0);

## Parse command line arguments
Getopt::Long::Configure('pass_through');
GetOptions(
    "help"					=> \my $help_opt,
    "config=s"				=> \my $config_file_opt,
    "name=s"				=> \my $name_opt,
    "password=s"			=> \my $pwd_opt,
    "silent"				=> \my $silent_opt
);

###################################################################
#
#    Input parameter validation and configuration
#
###################################################################

if (! length $name_opt) {
	$finalUserName  = $default_user;
} else {
	$finalUserName  = $name_opt;
}

if (! length $pwd_opt) {
	$finalPassword = $default_pwd;
} else {
	$finalPassword = $pwd_opt;
}

if ($help_opt) {
	usage("", 0);
}

if (! length $config_file_opt) {
	$err_msg = "Config filename is mandatory - quitting.";
	usage($err_msg, "2");
}

###################################################################
#
#    Main routine
#    Reads input config rtn to to display pending actions for user
#    approval (unless -silent parameter is provided)
#
#    On approval, deployment is performed
#
###################################################################

$local_file_name = shift;
my %local_hash;

if (! length $silent_opt) {
	open(INDATA, "<$config_file_opt") or die "Couldn't open file $config_file_opt, $!";
	while(<INDATA>){
		if(/^([A-Za-z0-9\_\.]+):\s+"*([A-Za-z]+)"*/) {
			%values_hash = construct_hash($1, $2);
			display_settings(%values_hash);
		}
	}
	close DATA;

	print "\nOkay to proceed? [Yn] (default n)";
	$a = <STDIN>;
	chomp $a;
	$a = substr $a, 0, 1;
	if (uc($a) ne 'Y') {
		exit;
	}
}

open(INDATA, "<$config_file_opt") or die "Couldn't open file $config_file_opt, $!";
while(<INDATA>){
	if(/^([A-Za-z0-9\_\.]+):\s+"*([A-Za-z]+)"*/) {
		%values_hash = construct_hash($1, $2);
		copyit($out_filename, %values_hash)
	}
}
close DATA;


###################################################################
#        Support Routines
###################################################################
###################################################################
#
#        construct_hash - called for each line in input config
#        file to build data structure
#
###################################################################
sub construct_hash {
	$server_name = shift;
	$serverType = shift;
	switch ($serverType) {
		case /development/i 		{$dbserver = 'development-mysql.dev.graymattertech.org'} 
		case /production/i 			{$dbserver = 'production-mysql.graymattertech.org'} 
	}
	$local_hash{'serverName'} = $1;
	$local_hash{'userName'} = $finalUserName;
	$local_hash{'userPassword'} = $finalPassword;
	$local_hash{'databaseServer'} = $dbserver;

	return %local_hash;
}

###################################################################
#
#        display_settings - single-item report of each server line
#        in input config file
#
###################################################################
sub display_settings {
	$local_hash = shift;

	print "    User - $local_hash{'userName'}    Password - $local_hash{'userPassword'}\n";
	print "    server: $local_hash{'serverName'},    db_server: $local_hash{'databaseServer'}\n";
	print "\n";
}

###################################################################
#
#        usage rtn - help screen, err msg if provided, and exit code
#
###################################################################
sub usage {
	my $local_err_msg = shift;
	my $local_err_code = shift;

	if ($local_err_msg) {
		print "***** $local_err_msg\n";
	}
	print "\n*** Usage: $program <-config (file name)> [-name (user name)] [-password (string)] [-silent] [-help]\n";
	print "\n";
	print "    -h help (print this screen\n";
	print "    -c input config file name          current setting: $config_file_opt\n";
	print "    -n username (override)             current setting: $finalUserName\n";
	print "    -p password (override)             current setting: $finalPassword\n";
	print "    -s (silent)                        current setting: $silent_opt\n\n";

   exit($local_err_code);
}

###################################################################
#
#        copyit - single-item steps:
#            announcement
#            create/configure temp file to copy
#            copy to server (via scp)
#            change permissions (via ssh)
#            change owership (via ssh)
#            destroy temp file
#
###################################################################
sub copyit {
	my $out_filename = shift;
	my $local_hash = shift;

	print "destination: $values_hash{'serverName'}:$out_filename\n";

	open(DATA, ">$temp_file") or die "Couldn't open file $temp_file, $!";
	print DATA "serverName: $values_hash{'serverName'}\n";
	print DATA "userName: \"$values_hash{'userName'}\"\n";
	print DATA "userPassword: \"$values_hash{'userPassword'}\"\n";
	print DATA "databaseServer: $values_hash{'databaseServer'}\n";
	close DATA;

	system('scp ' . $temp_file . " $values_hash{'serverName'}:$out_filename");
	system('ssh ' . $values_hash{'serverName'} . ' chmod 644 ' . $out_filename);
	system('ssh ' . $values_hash{'serverName'} . ' sudo chown root:users ' . $out_filename);
	unlink $temp_file;

	print "\n";
}
