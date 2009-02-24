#!/usr/bin/perl

require "./common.pl";

my $max_results = 0; #set this to 0 if you want all results

our $db;
my %dict;

my $names = $db->selectall_arrayref('select edgar_name from cik_name_lookup');
foreach my $name (@$names) {
	$name = $name->[0];
	my @words = split(/[\s\/]+/, $name);
	my $numtokens = @words;
	foreach my $i(0 .. $numtokens-2) {
	    my $bigram = @words[$i] ." ". @words[$i+1];
		$bigram =~ s/[\.,]//g;
		$dict{lc($bigram)}++;
	}	
}
my @word_list = sort { $dict{$b} <=> $dict{$a} } keys(%dict);

unless ($max_results) { $max_results = $#word_list; }
foreach my $x (0 .. 500) {
	print "$word_list[$x]\t$dict{$word_list[$x]}\n";
}
