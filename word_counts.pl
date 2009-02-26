#!/usr/bin/perl

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
		my @words = split(/[\s\/]+/, $name);
		my $numtokens = $#words;
		if ($bigram) { $numtokens -=2; }
		foreach my $i(0 .. $numtokens) {
			my $word = $words[$i];
			if ($bigram) { $word .= " ". $words[$i+1]; }
			$word = clean_for_match($word);
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
