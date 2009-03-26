#!/usr/bin/perl

use DBI;
our $db = &dbconnect();
use utf8;
use Text::Unidecode;

our $datadir = "./data/";

	
sub clean_for_match() {
	my $name = shift;
	$name = unidecode($name);  

	#replace bad characters and character strings
	$name =~ s/--/-/g;
	$name =~ s/\s\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;
	$name =~ s/^((Limited Liability )?Company|LLC|OOO|ZAO|OAO|TOO) "([^"]+)"/$3 $1/i;
	#$name =~ s/"[^"]*"//g;
	$name =~ s/\("[^"]+"\)//g;
	$name =~ s/\[[^\]]*\]//g;
	$name =~ s/<[^>]*>//g;
	$name =~ s/\([^\)]*\d%[^\)]*\)//g;
	$name =~ s/['\?]//g;
	$name =~ s/\([\sr]*\)//g;
	$name =~ s/[\-_]/ /g;
	$name =~ s/[\*\"]//g;
	$name =~ s/\s\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;
	$name =~ s/,//g;
	$name =~ s/\bL\.L\.C\.\b/LLC/gi;
	$name =~ s/\bL\.P\.\b/LP/gi;
	$name =~ s/\b([SA])\.([AL])\.\b/$1$2/gi;
	$name =~ s/\b(INC|CO|JR|SR|LTD|CORP|LLC)\./$1/gi;
	$name =~ s/( ?([\/\\]\w{0,3})?[\/\\]?)*$//;

	$name =~ s/^(A|AN|THE)\b//gi;
	$name =~ s/\bAND\b/&/gi;
	$name =~ s/ (Incorporated|Incorporation)\b/ Inc/gi;
	$name =~ s/ Company\b/ Co/gi;
	$name =~ s/ Corporation\b/ Corp/gi;
	$name =~ s/ Limited\b(?! Partnership)/ Ltd/gi;
	$name =~ s/\bJunior\b/Jr/gi;
	$name =~ s/\bSenior\b/Sr/gi;

	$name =~ s/\s\s+/ /g;
	$name =~ s/(^\s+|\s+$)//g;

	return $name;
}

#break a name up into a series of bigrams
sub list_bigrams() {
   my @gram_list;
   my $name = $_[0];
   my @words = split(/[\s\/]+/, $name); 
	my $numtokens = @words;
	foreach my $i(0 .. $numtokens-2) {
	    my $bigram = $words[$i] ." ". $words[$i+1];
	    #need a more standard function for stripping punctuation
		$bigram =~ s/[\.,]//g;  
		push(@gram_list, lc($bigram));
	}
	return @gram_list;
}

sub dbconnect {
	my $dbname = shift;
	unless($dbname) { $dbname = 'edgarapi';}
	my $dsn = "dbi:mysql:$dbname:localhost;mysql_compression=1";
	my $dbh;
	while (!$dbh) {
		$dbh = DBI->connect($dsn, 'edgar', 'edgar', {'mysql_enable_utf8'=>1});
		#unless ($dbh) {
		#	print("Unable to Connect to database\n");
			#sleep(10);
		#}
	}
	$dbh->{'mysql_auto_reconnect'} = 1;
	return $dbh;
}

