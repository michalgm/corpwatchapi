#!/usr/bin/perl

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

#this script counts the number of bi-grams (two word sequences) in names of companies
#THIS VERSION IS NO LONGER USED, FUNCTIONALITY IS INCLUDED IN WORDCOUNTS.PL

require "./common.pl";

my $max_results = 0; #set this to 0 if you want all results

our $db;
my %dict;

my $names = $db->selectall_arrayref('select name, source from company_names where source != "filer_conformed_name" group by name');
foreach my $name (@$names) {
	$name = $name->[0];
	my @words = split(/[\s\/]+/, $name); 
	my $numtokens = @words;
	foreach my $i(0 .. $numtokens-2) {
	    my $bigram = @words[$i] ." ". @words[$i+1];
		$bigram =~ s/[\.,]//g;  #need to figure a standardized funtion for this..
		$dict{lc($bigram)}++;
	}	
}
my @word_list = sort { $dict{$b} <=> $dict{$a} } keys(%dict);

unless ($max_results) { $max_results = $#word_list; }
foreach my $x (0 .. $max_results) {
#TODO  need to add escapes to deal with ' and " 
	print "$word_list[$x]\t$dict{$word_list[$x]}\n";
}

