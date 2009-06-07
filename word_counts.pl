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
# This script updates the counts of words and bigrams (two word phrases) appearing in company names so that they can be used to weight the name matching
#-----------------------------------
 

require "./common.pl";

#my $max_results = 0; #set this to 0 if you want all results

our $db;

&update_word_counts(); #update the word list
&update_word_counts(1); #update the bigrams

sub update_word_counts {
	my $bigram = shift;
	my %dict;
	#get all the cleaned match names from various sources
	my $names = $db->selectall_arrayref('select clean_company as compname from relationships
union select match_name as compname from cik_name_lookup
union select match_name as compname from filers group by compname');
	my $table = $bigram ? 'bigram_freq' : 'word_freq';
	foreach my $name (@$names) {
		$name = $name->[0];
		#TODO: add split on "-" (replace with " ") 
		#TODO: USE list_bigram function
		$name = &clean_for_match($name);
		my @words = split(/[\s\/]+/, $name);  
		my $numtokens = $#words;
		if ($bigram) { $numtokens -=2; }
		foreach my $i(0 .. $numtokens) {
			my $word = $words[$i];
			if ($bigram) { $word .= " ". $words[$i+1]; }
			#$word =~ s/[\.,]//g;
			$dict{lc($word)}++;
		}	
	}
	my @word_list = sort { $dict{$b} <=> $dict{$a} } keys(%dict);
	$db->do("delete from $table");
	my $sth = $db->prepare_cached("insert into $table values(?,?,?)");
	foreach my $word (@word_list) {
		$score = 1/(log($dict{$word})+1);
		$sth->execute($word, $dict{$word}, $score);
	}
}
