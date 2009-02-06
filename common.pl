#!/usr/bin/perl

use DBI;
our $db = &dbconnect();

our $datadir = "./data/";

	
sub clean_for_match() {
	my $name = shift;

	#replace bad characters and character strings
	$name =~ s/\s\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;
	$name =~ s/"[^"]*"//g;
	$name =~ s/\[[^\]]*\]//g;
	$name =~ s/<[^>]*>//g;
	$name =~ s/\([^\)]*\d%[^\)]*\)//g;
	$name =~ s/['\?]//g;
	$name =~ s/\([\sr]*\)//g;
	$name =~ s/_/ /g;
	$name =~ s/[\*\"]//g;
	$name =~ s/\s\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;

	$name =~ s/,//g;
	$name =~ s/\bL\.L\.C\.\b/LLC/gi;
	$name =~ s/\bL\.P\.\b/LP/gi;
	$name =~ s/\b([SA])\.([AL])\.\b/$1$2/gi;
	$name =~ s/\b(INC|CO|JR|SR|LTD|CORP)\./$1/gi;
	$name =~ s/( ?([\/\\]\w{0,3})?[\/\\]?)*$//;
	$name =~ s/\s\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;

	return $name;
}

sub dbconnect {
	my $db = shift;
	unless($db) { $db = 'edgarapi';}
	my $dsn = "dbi:mysql:$db:localhost;mysql_compression=1";
	my $dbh;
	while (!$dbh) {
		$dbh = DBI->connect($dsn, 'edgar', 'edgar');
		unless ($dbh) {
			print("Unable to Connect to database\n");
			sleep(10);
		}
	}
	$dbh->{'mysql_auto_reconnect'} = 1;
	return $dbh;
}

