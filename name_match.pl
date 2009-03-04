#!/usr/bin/perl
require 'common.pl';

#use Text::JaroWinkler qw( strcmp95 );
use Data::Dumper;
select(STDOUT); $| = 1; #unbuffer STDOUT

$match_table = '_company_matches';  #where the output goes

$match_source = 'filer_names';  #what we match against:  'cw_companies' 'cik_names'  'relation_names' 'filer_names'

$match_keep_level = 70;  # only put matches in db if bigger than this
$efficient_matching = 0;  #only match in one direction based on id
$match_locations = 0;  #include location informtion in the match scores

print "Matching against ".$match_source." saving results with score above ".$match_keep_level." into table ".$match_table."\n";



#get the sets of names we are gonna be comparing
#$namequeries[1] = "select ucase(name),id  from fortune1000";   
$namequeries[1] = "select ucase(clean_company),relationship_id as id,null,null from relationships";
#$namequeries[2] = "select name,cw_id as id from company_names where source = 'filer_match_name' or source = 'relationships_clean_company' ";

our $db;

#debug

my %stopterms = &get_stopterms();

$db->do("DROP TABLE IF EXISTS `$match_table`");
$db->do("CREATE TABLE `$match_table` ( `id` int(11) NOT NULL auto_increment, `name1` varchar(255) default NULL, `name2` varchar(255) default NULL, `score` decimal(5,2) default NULL, id_a varchar(25), id_b varchar(25),`match_type` varchar(10), `match` int(1) default 0, PRIMARY KEY  (`id`), KEY `id1` (`name1`), KEY `id2` (`name2`), KEY `score` (`score`))"); 

#load in the single word frequency rates
my $weights = $db->selectall_hashref("select word, weight from word_freq", 'word');

#load in the bigram frequency rates
my $bi_weights = $db->selectall_hashref("select bigram, weight from bigram_freq", 'bigram');

if ($match_locations) {
   print "loading country frequencies...\n";
	#load in the country codes and scores
	 $country_weights = $db->selectall_hashref("select country_code, 1/(log(count(*))+1) score from (select country_code, subdiv_code from company_locations group by cw_id,country_code) locs  group by country_code ","country_code");
	
	#subdive counts (and scores) are conditional on country scores: "US:DE"
	 $subdiv_weights = $db->selectall_hashref("select concat(country_code,':', subdiv_code) code, 1/(log(count(*))+1) score from (select country_code, subdiv_code from company_locations group by cw_id,country_code) locs  where subdiv_code is not null group by country_code,subdiv_code","code");

}

my $clean;
foreach ('1', '2') {
	my $set = $_;
	print "Fetching names $set...\n";
	#$query = "select ucase(name) from person_names where (sourcetable= 'facultylist' or sourcetable='courtesyapps') group by ucase(name) order by name"; 
	#$query = "select ucase(name) from person_names group by ucase(name) order by name"; 
	my $sth = $db->prepare($namequeries[$set]) || print "$DBI->errstr\n";
	$sth->execute() || print "$DBI->errstr\n".$db->errstr;

	while (my $row = $sth->fetchrow_arrayref) { 
	  #clean out puncuation for matching

	    $row->[0] = &clean_for_match($row->[0]);
		$names = {name=>$row->[0], id=>$row->[1], country_code=>$row->[2], subdiv_code=>$row->[3]};
		push(@{$clean->[$set]}, $names);
	}
}
#print Data::Dumper::Dumper($clean);
print "Finding matches...\n";
#prepare a statment for inserting matches into db.
my $sth2 = $db->prepare("insert into $match_table (name1, name2, score, id_a, id_b,match_type) values (?,?,?,?,?,?)");

my $count = 0;
my $y = 0;
my $listsize = scalar(@{$clean->[1]});
my $time = time();
print "$count/$listsize\n";
my $matches;
my $percent = int($#{$clean->[1]}/100);

#---------------------NAME MATCHING LOOP------------------
#loop over the names, computing match score for each. 
foreach my $names (@{$clean->[1]}) {
    #tracker to print out percent done
	if ($y == $percent) { 
		print "\r".int($count/$listsize*100) ."% (";
		my $ntime = time() - $time;
		print "$ntime)";  
		$y = 0; 
		$time = time();
	}
	$y++;
	
	#get the name off the list
	my $name1 = ${$names}{name};
	#set up a query to get the a corresponding subset of names to match against
	#print "getting matchlist for ".$name1."  (id: ".${$names}{id}.")";
	my @match_subset;
	my $query = &name_subset_query($name1,$match_source);
	#print ($query."\n");
    #my $sth3 = $db->prepare($query) || print "$DBI->errstr\n";
	#$sth3->execute() || print "$DBI->errstr\n".$db->errstr;
	#load the query results into array (assuming they already cleaned) 
	while (my $row = $db->selectrow_arrayref($query)) { 
	  	$record = {name=>$row->[0], id=>$row->[1],country_code=>$row->[2],subdiv_code=>$row->[3]};
		push(@match_subset, $record);
	}
	if ($db->errstr){print $db->errstr."\n";}
	#print " comparing to ".scalar(@match_subset)." names.\n";
	 
	foreach my $names2 (@match_subset) {
		#if (${$names}{primary_id} == ${$names2}{primary_id}) { next; }
		my $name2 = ${$names2}{name};
		#$matches->{$name1}->{$name2}->{'count'}++;

		#print "$name1 (".${$names}{id}." ".${$names}{country_code}.":".${$names}{subdiv_code}.")\t$name2 (".${$names2}{id}." ".${$names2}{country_code}.":".${$names2}{subdiv_code}.")\n";
		 
		#------ location matching (if we are doing it
		my $loc_score = 0;
		if ($match_locations){
		    $loc_score =  &location_match_score(${$names}{country_code}, ${$names}{subdiv_code}, ${$names2}{country_code},${$names2}{subdiv_code});
		}
		
		#----- bigram matching
		#if matching efficiently, only match pair in one direction
		unless ($efficient_matching && ${$names}{id} > ${$names2}{id}) {
			my $match = 0;
			if ($name1 eq $name2) { 
				$match = 100;  
			} else {
				$match = &get_bigram_score(${$names}{name}, ${$names2}{name});
				$match *=100;
				unless ($match) { $match = 0; }
			}
			
			$match += $loc_score; #add in the location score
			#print "\t".$name2." (bigram): ".$match."\n";
			#if the match is above a threshold, insert in db
			if ($match > $match_keep_level) { 
				$sth2->execute($name1, $name2, $match, ${$names}{id}, ${$names2}{id},"bigram_".$match_locations); 
			}
			#print "\tbigram:$match";
		} #else { print "dupe\n"; }
		
		# ----------- term frequency matching
		#if matching efficiently, only match pair in one direction
		unless ($efficient_matching && ${$names}{id} > ${$names2}{id}) {
			my $match = 0;
			if ($name1 eq $name2) { 
				$match = 100;  
			} else {
				$match = &get_term_score(${$names}{name}, ${$names2}{name});
				$match *=100;
				unless ($match) { $match = 0; }
			}
			
		    $match += $loc_score; #add in the location score
			#print "\t".$name2." (term_freq): ".$match."\n";
			#if the match is above a threshold, insert in db
			if ($match > $match_keep_level) { $sth2->execute($name1, $name2, $match, ${$names}{id}, ${$names2}{id},"term_".$match_locations); }
			#print " term_freq:$match";
		} #else { print "dupe\n"; }
		
	}
	$count++;
	#print total_size($clean)."\t".total_size($matches)."\t".total_size($sth)."\n";
}	

#$db->do("insert into $match_table select null, name2, name1, score from $match_table");
print "\nDone.\n";
exit;

#compute a match score based on the intersecting set of terms, weighted by their observed frequency in our set of names
sub get_term_score() {
	my ($comp1, $comp2) = @_;
	my $score = 0;
	my $no_match_weight = 0.2;

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



#compute a match score based on the frequency of bigram occurances observed in our set of names
sub get_bigram_score() {
	my ($comp1, $comp2) = @_;
	my $score = 0;
	my $no_match_weight = 0.2;
	#how to handle names that have just a single term?

	my @tokens1 = &list_bigrams($comp1);
	my @tokens2 = &list_bigrams($comp2);
	
	#Score is compute by comparing the weights of the matching tokens to the weights of each name's tokens:
	#score=   2*(sum score tokens in comp) / (sum score comp1)+(sum score comp2);
	my $sum1 =0;
	my $sum2 =0;
	my $sumBoth = 0;
	foreach my $token (@tokens1){
	   #if it has a weight, it is at least somewhat common
	    if (defined $bi_weights->{$token}){
			$sum1 += $bi_weights->{$token}->{weight};
		} else {
		 #//it didn't show up the the db, so weight it as $no_match_weight 
		 $sum1 += $no_match_weight ;
		}
		#//check if it is in the other company set
		
		if (grep {$_ eq $token } @tokens2){
			if (defined $bi_weights->{$token}){
				$sumBoth += $bi_weights->{$token}->{'weight'} * 2;
			} else {
			    $sumBoth += $no_match_weight*2;
			}
		}
	}
	#// now compute weight for 2nd company
	foreach my $token (@tokens2){
	    if (defined $bi_weights->{$token}){
			$sum2 += $bi_weights->{$token}->{weight};
		} else {
		#since it is not in our list of common tokens, assume it is rare
			$sum2 += $no_match_weight ;
		}

	}
	
	#deal with case to avoid divide by zero
	if ($sum1+$sum2 > 0){
      $score = $sumBoth/($sum1+$sum2);
    } 
	return $score;
}

#create a query that will return a subset of names that match at least one term each.  This costs some mysql query time, but makes it so we are only matching aginst 100 or a few thousand names instead of tens of thousands. 

sub name_subset_query() {
  my $comp1 = $_[0];  #the company name that will be matched. 
  my $match_set = $_[1];  #this determines what nameset we should match against
  #need to escape quotes in company name for db
  $comp1 = &clean_for_match($comp1);
 # $comp1 =~ s/'/\'/;
 #$comp1 =~ s/"/\"/;
  my $query = "";
  my @tokens1;
  
  #split the name on into tokens on space, kick out tokens that match the stopword list
  foreach my $token (split(/ /,lc($comp1))) {
   	if (!exists $stopterms{$token}) {
   		push(@tokens1,$token);
   	}
  }
    
  #if we are matching against all EDGAR names in cik lookup table
  if ($match_set eq "cik_names") {
	  $first = pop(@tokens1);
	   $query = "select ucase(match_name),cik as id,null,null from cik_name_lookup where match_name like '%".$first."%'";
	  foreach my $token (@tokens1){
	   	$query = $query." union distinct select ucase(match_name),cik as id ,null,null from cik_name_lookup where match_name like '%".$token."%'";
	  }
   } 
   
   #use these queries if we are matching against names of companies in relationships table
     elsif ($match_set eq "relation_names") {
   		$first = pop(@tokens1);
	   $query = "select ucase(clean_company), relationship_id as id, country_code,subdiv_code from relationships where clean_company like '%".$first."%' ";
	  foreach my $token (@tokens1){
		 $query = $query."union distinct select ucase(clean_company), relationship_id as id,country_code,subdiv_code from relationships where clean_company like '%".$token."%' ";
      }
    } 
    
   #use these quries if we are only matching aginst company_names table	  
   elsif ($match_set eq "cw_companies") {
   		$first = pop(@tokens1);
	   $query = "select ucase(name), cw_id as id,null,null from company_names where (source = 'filer_match_name' or source='relationships_clean_company') and name like '%".$first."%' ";
	  foreach my $token (@tokens1){
	    $query = $query."union distinct select ucase(name), cw_id as id,null,null from company_names where (source = 'filer_match_name' or source='relationships_clean_company') and name like '%".$token."%' ";
      }
    } 
    
    #use these queries if we are matching against filer names
    #TODO: add location info
    elsif ($match_set eq "filer_names") {
   		$first = pop(@tokens1);
	   $query = "select ucase(match_name), cik as id,null,null from filers where match_name like '%".$first."%' ";
	  foreach my $token (@tokens1){
	    $query = $query."union distinct select ucase(match_name), cik as id, null,null from filers where match_name like '%".$token."%' ";
      }
    }else {
       #uh oh, what should default be?
    }
  return $query;
}

#returns a hash with the list of some of the most common terms to avoid using in queires
sub get_stopterms() {

   my %stopterms = ();
   my $stopquery = "select word from word_freq order by count desc limit 75";
   my $sth4 = $db->prepare($stopquery) || print "$DBI->errstr\n";
   $sth4->execute() || print "$DBI->errstr\n".$db->errstr;
	#load the query results into the hash 
	while (my $row = $sth4->fetchrow_arrayref) { 
	  	$stopterms{$row->[0]} = $row->[0];
	} 
   return %stopterms;
}

#scores match country_code and subdiv_code of passed arguments
sub location_match_score() {
   my ($country1, $subdiv1,$country2,$subdiv2) = @_;
   $subdiv1 = $country1.":".$subdiv1;
   $subdiv2 = $country2.":".$subdiv2;
   my $score = 0.25;
   #if either side is null, don't match
   if ((defined $country1) & (defined $country2 )){
	   if ($country1 eq $country2){
		$score = $country_weights->{$country1}->{score};
		#now check if the subdivision also matches
		if ((defined $subdiv1) & (defined $subdiv2)){
			if ($subdiv1 eq $subdiv2) {
				$score = $score+ $subdiv_weights->{$subdiv1}->{score};
			} else {
			  #mismatch, so punish
			  $score=0;
			}
		}
	   } else {
	     #countries do *not* match, so punish
	     $score=0;
	   }
   }
   
   return $score * 100;
   
}