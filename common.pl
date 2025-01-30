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
use LWP::RobotUA;
use LWP::UserAgent;

our @years_available = (2003 .. (localtime)[5] + 1900);
our $datadir = "./data/";
our $logdir ="./log/";

unless (-d $datadir) { mkdir($datadir) || die "Unable to create data directory $datadir\n"; }
unless (-d $logdir) { mkdir($logdir) || die "Unable to create log directory $logdir\n"; }

sub get_current_year() {
	return (localtime)[5] + 1900;
}

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
	$name =~ s/\bL\.L\.C\.(\b|$)/LLC/gi;
	$name =~ s/\bL\.P\.(\b|$)/LP/gi;
	$name =~ s/\b([SA])\.([AL])\.(\b|$)/$1$2/gi;
	$name =~ s/\b(INC|CO|JR|SR|LTD|CORP|LLC)\./$1/gi;
	$name =~ s/( ?([\/\\]\w{0,3})?[\/\\]?)*$//;

	$name =~ s/^(A|AN|THE)(\b|$)//gi;
	$name =~ s/\bAND(\b|$)/&/gi;
	$name =~ s/ (Incorporated|Incorporation)(\b|$)/ Inc/gi;
	$name =~ s/ Company(\b|$)/ Co/gi;
	$name =~ s/ Corporation(\b|$)/ Corp/gi;
	$name =~ s/ Limited(\b|$)(?! Partnership)/ Ltd/gi;
	$name =~ s/\bJunior(\b|$)/Jr/gi;
	$name =~ s/\bSenior(\b|$)/Sr/gi;

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
	my $db_host = $ENV{'EDGAR_DB_HOST'} || 'localhost';
	my $db_name = $ENV{'EDGAR_DB_NAME'} || 'edgarapi_live';
	my $db_user = $ENV{'EDGAR_DB_USER'} || 'edgar';
	my $db_password = $ENV{'EDGAR_DB_PASSWORD'} || 'edgar';
	my $dsn = "dbi:mysql:$db_name:$db_host";
	my $dbh;
	my $attributes = {
		mysql_enable_utf8mb4 => 1,    # Modern UTF8 handling
		RaiseError           => 1,    # Better error handling
		AutoCommit           => 1,    # Explicit transaction control
		PrintError           => 0,    # Let RaiseError handle it
		mysql_auto_reconnect => 1,    # Move this into initial connection
		mysql_server_prepare => 1,    # Better prepared statement handling

	};
	while (!$dbh) {
		$dbh = DBI->connect( $dsn, $db_user, $db_password, $attributes );
	}
	$dbh->{'mysql_auto_reconnect'} = 1;
	$dbh->do("SET NAMES utf8mb4");
	$dbh->do("SET CHARACTER SET utf8mb4");
	$dbh->do("SET session sql_mode=(SELECT REPLACE(\@\@sql_mode, 'ONLY_FULL_GROUP_BY,', ''))");
	return $dbh;
}

sub create_agent {
	$agent = LWP::UserAgent->new(keep_alive=>1);
    $ua = LWP::RobotUA->new($agent, 'support@api.corpwatch.org');
	$encoding = HTTP::Message::decodable;
    # set headers according to https://www.sec.gov/os/accessing-edgar-data
    $ua->default_header('User-Agent' => 'CorpWatch API support@api.corpwatch.org');
    $ua->default_header('Accept-Encoding' => $encoding);
    $ua->default_header('Host' => 'www.sec.gov');
    $ua->delay(1/60);
    return $ua;
}