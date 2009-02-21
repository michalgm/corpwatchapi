#!/usr/bin/perl
require 'common.pl';

use Text::JaroWinkler qw( strcmp95 );
use Data::Dumper;
select(STDOUT); $| = 1; #unbuffer STDOUT
$match_table = '_match_students';
#$namequeries[2] = "select ucase(name), id from fortune1000 where name like '%ford%' order by name limit 10";
$namequeries[1] = "select ucase(company_name), cw_id from companies where company_name like '%chevron%' order by company_name limit 10";
$namequeries[2] = "select ucase(company_name), cw_id from companies where company_name like '%chevron%' order by company_name limit 10";

our $db;

$db->do("DROP TABLE IF EXISTS `$match_table`");
$db->do("CREATE TABLE `$match_table` ( `id` int(11) NOT NULL auto_increment, `name1` varchar(60) default NULL, `name2` varchar(60) default NULL, `score` decimal(5,2) default NULL, id_a int(11), id_b int(11), `match` int(1) default 0, PRIMARY KEY  (`id`), KEY `id1` (`name1`), KEY `id2` (`name2`), KEY `score` (`score`))"); 

my $weights = $db->selectall_hashref("select word, weight from word_freq", 'word');

my $matches;
my $clean;
foreach ('1', '2') {
	my $set = $_;
	print "Fetching names $set...\n";
	#$query = "select ucase(name) from person_names where (sourcetable= 'facultylist' or sourcetable='courtesyapps') group by ucase(name) order by name"; 
	#$query = "select ucase(name) from person_names group by ucase(name) order by name"; 
	my $sth = $db->prepare($namequeries[$set]) || print "$DBI->errstr\n";
	$sth->execute() || print "$DBI->errstr\n";
	print $db->errstr;

	while (my $row = $sth->fetchrow_arrayref) { 
		#$row->[0] =~ s/-/ /;
		#$row->[0] =~ /^([^,]+), ([^"]+)/;
		#my $first = $2;
		#my $last = $1;
		#unless ($first && $last) { print "wtf! $row->[0] - $row->[1]\n"; exit;}
		$names = {name=>$row->[0], primary_id=>$row->[1]};
		push(@{$clean->[$set]}, $names);
	}
}
#print Data::Dumper::Dumper($clean);
print "Finding matches...\n";
my $sth2 = $db->prepare("insert into $match_table (name1, name2, score, id_a, id_b) values (?,?,?,?,?)");
#my $query = "select ucase(name) from person_names where (sourcetable= 'facultylist' or sourcetable='courtesyapps') group by ucase(name) order by name"; 
#my $query = "select ucase(name) from person_names group by ucase(name) order by name"; 
my $count = 0;
my $y = 0;
my $listsize = scalar(@{$clean->[1]});
my $time = time();
print "$count/$listsize\n";
my $matches;
my $percent = int($#{$clean->[1]}/100);
foreach my $names (@{$clean->[1]}) {
	if ($y == $percent) { 
		print "\r".int($count/$listsize*100) ."% (";
		my $ntime = time() - $time;
		print "$ntime)";  
		$y = 0; 
		$time = time();
	}
	$y++;
	my $name1 = ${$names}{name};
	foreach my $names2 (@{$clean->[2]}) {
		#if (${$names}{primary_id} == ${$names2}{primary_id}) { next; }
		my $name2 = ${$names2}{name};
		#$matches->{$name1}->{$name2}->{'count'}++;
		print "\t$name1 v $name2: $matches->{$name1}->{$name2}";
		unless ($efficient_matching && ${$names}{primary_id} > ${$names2}{primary_id}) {
			my $match = 0;
			if ($name1 eq $name2) { 
				$match = 100;  
			} else {
				#$match = name_eq(${$names}{first}, ${$names}{last}, ${$names2}{first}, ${$names2}{last});
				$match = &get_match_score(${$names}{name}, ${$names2}{name});
				$match *=100;
				unless ($match) { $match = 0; }
			}
			if ($match > 5) { $sth2->execute($name1, $name2, $match, ${$names}{primary_id}, ${$names2}{primary_id}); }
			print "$match\n";
		} #else { print "dupe\n"; }
	}
	$count++;
	#print total_size($clean)."\t".total_size($matches)."\t".total_size($sth)."\n";
}	

#$db->do("insert into $match_table select null, name2, name1, score from $match_table");
exit;

sub get_match_score() {
	my ($comp1, $comp2) = @_;
	my $score = 0;
	my $no_match_weight = 0.5;

	my @tokens1 = split(/ /,lc($comp1));
	my @tokens2 = split(/ /,lc($comp2));
	
	#//score=     2*(sum score tokens in comp) / (sum score comp1)+(sum score comp2);
	my $sum1 =0;
	my $sum2 =0;
	my $sumBoth = 0;
	foreach my $token (@tokens1){
	   #if it has a weight, it is at least somewhat common
	    if (defined $weights->{$token}){
			$sum1 += $weights->{$token}->{weight};
		} else {
		 #//it didn't show up the the db, so weight it as $no_match_weight 
		 $sum1 += $no_match_weight ;
		}
		#//check if it is in the other company set
		
		if (grep {$_ eq $token } @tokens2){
			if (defined $weights->{$token}){
				$sumBoth += $weights->{$token}->{'weight'} * 2;
			} else {
			    $sumBoth += $no_match_weight*2;
			}
		}
	}
	#// now compute weight for 2nd company
	foreach my $token (@tokens2){
	    if (defined $weights->{$token}){
			$sum2 += $weights->{$token}->{weight};
		} else {
		#since it is not in our list of common tokens, assume it is rare
			$sum2 += $no_match_weight ;
		}

	}
    $score = $sumBoth/($sum1+$sum2);
	return $score;
}

