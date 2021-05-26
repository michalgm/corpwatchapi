#!/usr/bin/perl -w

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
    
#---------------------------------
# This script is used to download a list of former and alternative names for companies and store them in the table 'cik_name_lookup'
#--------------------------------

require './common.pl';
our $db;
$| = 1;

use Compress::Zlib;
use Parallel::ForkManager;

my $ua = create_agent();

print "Deleting existing data\n";
$db->do("delete from cik_name_lookup");
$db->do("alter table cik_name_lookup auto_increment 0");
$db->do("alter table cik_name_lookup disable keys");

print "Fetching index from SEC...\n";
$res = $ua->get("https://www.sec.gov/Archives/edgar/cik-lookup-data.txt"); 
unless ($res->is_success) { die "Unable to download https://www.sec.gov/Archives/edgar/cik-lookup-data.txt: $!"; }
my @lines = split(/\n/, $res->decoded_content); 
my $count = 0;
my $total = $#lines;
my $set_size = int($total * .01);
$limit = int($total / $set_size * .01);
my $manager = new Parallel::ForkManager( 5 );
my ($x, $y) = 0;

$db->disconnect;
print "inserting names\n";
for my $set (0 .. int($total/$set_size)+1) { 
	#print "\r".int((++$count/$total)*100)."%";
	if ($x == $limit) { $y++; print "\r".($y)."%"; $x = 0; } $x++;
	$manager->start and next;
	$db = &dbconnect();
	for my $count (0 .. $set_size-1) {
		$count += ($set * $set_size);
		if ($count > $total) { $manager->finish; }
		if ($lines[$count]) {
			my ($name, $cik) = split(/:([^:]+):$/, $lines[$count]);
			my $clean_name =  &clean_for_match($name);
			
			my $sth  = $db->prepare_cached("insert into  cik_name_lookup (edgar_name, cik, match_name) values (?, ?, ?)");
			$sth->execute($name, $cik, $clean_name);
		}
	}
	$db->disconnect;
	$manager->finish();
}
$manager->wait_all_children;
print "Re-enabling keys\n";
$db->do("alter table cik_name_lookup enable keys");

print "\nDone!\n";

