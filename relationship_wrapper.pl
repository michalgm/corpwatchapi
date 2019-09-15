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
use Term::ProgressBar;
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

# Count all EX21's:
my $count_all_ex21s = $db->prepare("SELECT COUNT(*) FROM filings;") or die "Prepare Count Error: $DBI::errstr\n";
$count_all_ex21s->execute() or die "Execute Count Error: $DBI::errstr\n";
$count_all_ex21s = $count_all_ex21s->fetchrow;

# Select only the EX21's not yet parsed:
my $filings = $db->selectall_arrayref("
    SELECT filing_id, company_name
    FROM   filings
") || die "$!";

my $manager = new Parallel::ForkManager( 40 );
my ($x, $y) = 0;
my $total = 0+@$filings; # length of the array "filings"

my $progress = Term::ProgressBar->new({name  => 'Deploying',
       count => $count_all_ex21s,
       ETA   => 'linear'}); # initialize progressbar
$progress->update($count_all_ex21s - $total); # Skip to current amount of EX21's parsed already.

foreach my $filing (@$filings) {
    $progress->update(); # update progressbar
    &print_message("Deploying job for $filing->[0]: \"$filing->[1]\" ...\n");
	my $cmd = "perl sec21_headers.pl $filing->[0]";

	$manager->start and next;   # In a forked process, do the following:
        my $time = time();      # start the timer
        my $null = `$cmd`;      # Run the command and collect output.
        $null =~ s/\n/\n    /g; # Indent second to last lines.
        $null = "    " . $null; # Indent the first line.
        &print_message($null);
        &print_message("$filing->[0] finished: ".(time() - $time)."\n");
        #$db->do('UPDATE ex21_found SET if_parsed=1 WHERE ex21_found.index=?', undef, $filing->[2] ) || die "$!";
	$manager->finish;
}

sub print_message {
    my ($msg) = @_;
    $progress->message($msg);
    print LOG $msg;
}

$manager->wait_all_children;
print "\nDone\n";
#$db->do("alter table $relationship_table enable keys");
#$db->do("alter table filing_tables enable keys");
