#!/usr/bin/perl

    # Copyright 2009 CorpWatch.org 
    # San Francisco, CA | 94110, USA | Tel: +1-415-641-1633
    # Developed by Greg Michalec and Skye Bender-deMoll
    
    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU General Public License as published by
    # the Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU General Public License for more details.

    # You should have received a copy of the GNU General Public License
    # along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
#--------------------------------------------
#This file includes a number of utility functions that are shared in common in the backend parsing scripts
#---------------------------------------------

use DBI;
our $db = &dbconnect();
use utf8;
use Text::Unidecode;

our $datadir = "./data/";


#formats company name into a standard representation so that they can be matched as text strings	
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

#manages the connection to the database
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

