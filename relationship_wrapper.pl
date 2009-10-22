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
    
#-----------------------------------   
# This script manages the execution of multiple copies of the section21Header processing cript in order to get around a memory leak in a perl library, and at the same time take advantage of multiple processors on the host machine.
#-----------------------------------
 

use Parallel::ForkManager;

require "./common.pl";
#$| =1;
our $db;
our $logdir;
open (LOG, ">$logdir/log.txt");

my ($year, $nuke) = @ARGV;
if ($year && $year ne 'all') {
	$where = " and year = $year ";
}
if ($nuke) { 
	print "deleting tables...\n";
	$db->do("delete from filing_tables where filing_id in(select filing_id from  filings where has_sec21 = 1 $where)");
	$db->do("delete from relationships  where filing_id in(select filing_id from  filings where has_sec21 = 1 $where)");
	$db->do("update filings set bad_sec21 = 0, rows_parsed=0,num_tables=0 $where");
	$db->do("delete from bad_locations");
	$db->do("alter table relationships auto_increment = 0");
	$db->do("alter table filing_tables auto_increment = 0");
	$db->do("alter table bad_locations auto_increment = 0");
	print "done\n";
}

my $filings = $db->selectall_arrayref("select filing_id from filings where has_sec21 = 1 $where and bad_sec21 = 0 and rows_parsed =0 and num_tables = 0 order by filing_id") || die "$!";

my $manager = new Parallel::ForkManager( 5 );
my ($x, $y) = 0;
my $limit = int($#${filings}*.01);
print "Need to parse $#${filings} filings\n";
foreach my $filing (@$filings) {
	my $cmd = "perl sec21_headers.pl $filing->[0]";
	print LOG "$filing->[0] started\n";
    if ($x == $limit) { print "\r".++$y."%"; $x = 0; }
	print ".";
	$x++;

	$manager->start and next;
	my $time = time();
	$null = `$cmd`;
	print LOG "$null";
	#print `$cmd`;
	print LOG "$filing->[0] finished: ".(time() - $time)."\n";
	$manager->finish;
}

$manager->wait_all_children;
print "\nDone\n";
#$db->do("alter table $relationship_table enable keys");
#$db->do("alter table filing_tables enable keys");

