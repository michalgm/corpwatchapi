#!/usr/bin/perl 
use HTML::TableExtract qw(tree);
use Data::Dumper;
use utf8;
#use Devel::Size qw(size total_size);
#use Devel::DumpSizes qw/dump_sizes/;
$HTML::Entities::entity2char{nbsp} = chr(32);
#$HTML::Entities::char2entity{chr(146)} = chr(39);
#print Data::Dumper::Dumper($HTML::Entities::entity2char{nbsp});
#exit;

require "./common.pl";
$| =1;
our $db;
open(CHARS, '>>chars.txt');
binmode CHARS, ":utf8";
our $datadir;
#my $where = " and filing_id >= 10000 ";
#my $where = " ";
my $relationship_table = 'relationships';
my $debug =0;
if ($ARGV[0]) { 
	$where = " and filing_id = $ARGV[0] ";
} else {
	$db->do("alter table $relationship_table auto_increment = 0");
	$db->do("alter table filing_tables auto_increment = 0");
}
if ($ARGV[1]) { $debug = 1; }
$db->do("delete from $relationship_table where filing_id is not null $where");
$db->do("delete from filing_tables where filing_id is not null $where");
my $filings = $db->selectall_arrayref("select filing_id, filename, quarter, year, cik, company_name from filings where has_sec21 = 1 $where order by filing_id") || die "$!";
$sth = $db->prepare("insert into $relationship_table (relationship_id, company_name, location, filing_id) values (null, ?, ?, ?)");
$sth2 = $db->prepare("update filings set has_html=?, num_tables=?,num_rows=?,tables_parsed=?,rows_parsed=? where filing_id=?");
$sth3 = $db->prepare("insert into filing_tables set filing_table_id = null, filing_id=?, table_num=?, num_rows=?, num_cols=?, headers=?");
$sth4 = $db->prepare("update filing_tables set parsed = 1 where filing_id=? and table_num=?");
$sth5 = $db->prepare("select name from not_company_names where name = ?");
unless ($filings->[0]) { die "No filings found!"; }
foreach my $filing (@$filings) {
	my $p = HTML::TableExtract->new();
	$p->utf8_mode(1);
	my $id = $filing->[0];
	print "$id - $filing->[5]: ";
	open(FILE, "$datadir/$filing->[3]/$filing->[2]/$id.sec21") || die "$!";
	my $content;
	my $results;
	$results->{rows_parsed} = 0;
	while (<FILE>) { $content .= $_; }
	close FILE;
	if ($content =~ /(<HTML>.+<\/HTML>)/si) { 
		$has_html = 1;
		my $html = $1;
		$html =~ s/<tr[^>]*>[^<]*<tr/<tr/gsi;
		#print $html;
		$p->parse($html);	
		my ($rowskip, $g_company_col, $g_local_col);
		my $locked = 0;
		my @tables = $p->tables;
		my $tableinfo->{headerrow} = undef;
		print "\n"; 
		foreach my $t (@tables) {
			my $tableinfo;
			$tableinfo->{rows_parsed} = 0;
			$results->{num_tables}++;
			my @rows = $t->rows();
			my @cols = $t->columns();
			($tableinfo->{rows}, $tableinfo->{cols}) = ($#rows +1, $#cols+1);
			print "\t Table: $#rows x $#cols";
			my $t_headerrow;
			my $headers;
			($tableinfo->{company_col}, $tableinfo->{local_col}, $headers, $t_headerrow) = &detect_headers($t);
			if (! defined $tableinfo->{headerrow}) {
				$tableinfo->{headerrow} = $t_headerrow;
			}
			if (defined $tableinfo->{company_col}) { $g_company_col = $tableinfo->{company_col}; } else { $tableinfo->{company_col} = $g_company_col; }
			if (defined $tableinfo->{local_col}) { $g_local_col = $tableinfo->{local_col}; } else { $tableinfo->{local_col} = $g_local_col; }
			#print "c: $tableinfo->{company_col} l: $tableinfo->{local_col}\n";
			$sth3->execute($id, $results->{num_tables}, $#rows+1,  $#cols+1, $headers);
			if (! defined $tableinfo->{company_col} || ! defined $tableinfo->{local_col} || $tableinfo->{company_col} == $tableinfo->{local_col}) { 
				print " - bad headers - ";
				my $datacol = 0;
				$tableinfo->{headerrow} = 0;
				#try to skip until we find data
				while ($tableinfo->{headerrow} <= $#rows) {
					$datacol = 0;
					while ($datacol <= $#cols) {
						if(&check_cell($rows[$tableinfo->{headerrow}]->[$datacol]) =~ / \(/) { last; }
						$datacol++;
					}
					$tableinfo->{headerrow}++;
				}
				foreach my $row (@rows) { 
					$text = &check_cell($row->[$datacol]);
					if ($debug) { print "***********".$text."\n"; }
					#if ($debug) { print "***********".$row->[$datacol]->as_HTML."\n;"; }
					$text = &strip_junk($text);
					if($text =~ /^(.+) an? ([^\(]+?) (corporation|company|partnership)\)?/ig) {
						my ($company, $location) = ($1, $3);
						if (&store_relationship($company,$location,$id)) {
							$tableinfo->{rows_parsed}++;
						}
					} elsif ($text =~ /^(.+) ?\((.[^\)]+)\)$/ ) {
						if ($debug) { print "- parsing single columns - "; }
						my ($company, $location) = ($1, $2);
						if (&store_relationship($company,$location,$id)) {
							$tableinfo->{rows_parsed}++;
						}
					} elsif ($text && $row->[$datacol]->find('div','p')) {
						if ($debug) { print "- parsing divs - "; }
						if (my $t_rows_parsed = &search_elements($row->[$datacol], $id)) {
							$tableinfo->{rows_parsed} += $t_rows_parsed;
						}
					} else {
						if ($debug) { print " - grasping at straws - "; }
						my $currcol = 0;
						my ($company, $location);
						while ($currcol <= $#cols) {
							my $text = &check_cell($row->[$currcol]);
							if ($debug) { print "STRAW: $text\n"; } 
					#		print &check_cell($row->[$currcol])."|";
							if($text =~ /\w/) {
								if(! $company) { 
									$company = $text;
								} else {
									$text = &strip_junk($text);
									if ($text =~ /\w/) {
										$location = $text;
										last;
									}
								}
							}
							$currcol++;
						}
					#	print " $company - $location \n";
						if (&store_relationship($company,$location,$id)) {
							$tableinfo->{rows_parsed}++;
						}
					}
				}
				unless ($tableinfo->{rows_parsed}) {
					if (my $t_rows_parsed = &search_elements($t->tree(), $id)) {
						$tableinfo->{rows_parsed} += $t_rows_parsed;
					}
				}
			} else {
				#print " headers: ".&check_cell($rows[$tableinfo->{headerrow}]->[$tableinfo->{company_col}]).", ".&check_cell($rows[$tableinfo->{headerrow}]->[$tableinfo->{local_col}])." - ";
				$tableinfo->{rows_parsed} = &parse_table_by_headers($t, $tableinfo->{company_col}, $tableinfo->{local_col}, $tableinfo->{headerrow}, $id, $results->{num_tables});	
			}
			if ($tableinfo->{rows_parsed} > 0) {  
				$results->{tables_parsed}++;
				$results->{rows_parsed} += $tableinfo->{rows_parsed};
				print " Parsed!\n"; 
				$sth4->execute($id, $results->{num_tables});
			} else {  
				print " Failed!\n"; 
			}
			push (@{$results->{tables}}, $tableinfo);

		} 
		unless ($tables[0] && $results->{rows_parsed}) {
			print " - no tables - ";
			if (my $t_rows_parsed = &search_elements($p->tree(), $id)) {
				$results->{rows_parsed} += $t_rows_parsed;
			}
		}
	} else {
		#No HTML
		print " - no html - ";
		foreach my $line (split(/\n/, $content)) {
			#print "$line\n";
			my ($company, $location);
			if ($line =~ /(\w.+?)\s\s+(\w.+)$/ || $line =~ /^(\w.+)\s*\((\w.+)\)$/) {
				($company, $location) = ($1,$2);
				#print "$1,$2\n";
			} 
			if (&store_relationship($company,$location,$id)) {
				$results->{rows_parsed}++;
			}
		}
	}
	if ($results->{rows_parsed} > 0) {
		print "Parsed!\n";
	} else {
		print "Failed!\n"; 
	}
	$sth2->execute($results->{has_html}, $results->{num_tables}, $results->{num_rows}, $results->{tables_parsed}, $results->{rows_parsed}, $id);
	$p->tree->delete;
}

sub clean_contents {
	my $contents = shift;
	if ($contents) {
		$contents =~ s/[\n\r\t]/ /sg;
		$contents =~ s/^\s*(\S.*\S)\s*$/$1/s;
		$contents =~ s/\s\s+/ /sg;;	
	}
	return $contents;
}

sub detect_headers {
	my $t = shift;	
	my $headers = "";
	my $currow = 0;
	my ($company_col, $local_col, $headerrow) = undef; 
	foreach my $r ($t->rows()) {
		my $curcol = 0;
		foreach my $c (@$r) {
			my $z =  $t->cell($currow , $curcol);
			my $coldata = &check_cell($c);
			if ($coldata) {
				$coldata = &clean_contents($coldata);		
				$headers .= "$coldata|";	
				if ($coldata =~ /\w/) {
					if (! defined $company_col) {
						if ($coldata =~ /(investment|SUBSIDIAR|Entity|Name|Company|[^n]Corporat)/i) { $company_col = $curcol; }
					} elsif (! defined $local_col) {
						if ($coldata =~ /(ORGANIZ|Juris|Incorporat|Location|state|domicile|formatio|country|laws of)/i) { $local_col = $curcol;} 
					}
				}
			}
			$curcol++; 
		}
		#print "$company_col - $local_col\n";
		#print "$headers - $company_col - $local_col\n";
		if ($headers =~ /\w.*\|.*\w/) { $headerrow = $currow; }
		$currow++;
		#if (($results->{num_tables} >1 && defined $headerrow) || ( defined $company_col && defined $local_col && $results->{num_tables} ==1)) { last; }
		if (defined $company_col && defined $local_col ) { last; }
	}
	return ($company_col, $local_col, $headers, $headerrow);
}

sub parse_table_by_headers {
	my ($t, $company_col, $local_col, $headerrow, $id, $num_tables) = @_;
	my ($orig_company_col, $orig_local_col) = ($company_col, $local_col);
	my @cols = $t->columns();
	my $rows_parsed = 0;
	my $num_rows = 0;
	foreach my $r ($t->rows()) {
		#print "c: $company_col l: $local_col\n";
		$num_rows++;
		if ($num_tables == 1 && $num_rows <= $headerrow) { next; }
		if (&check_cell($r->[$company_col]) =~ /^1\.?$/) { 
			$company_col++; 
			$local_col++;
			while (&check_cell($r->[$company_col]) !~ /\w/ && $company_col <=$#cols) {
				$company_col++; 
				$local_col++;
			} 
		}
		#print "c: $company_col l: $local_col\n";
		if ($rows_parsed == 0 && &check_cell($r->[$company_col]) =~ /\w/ && &check_cell($r->[$local_col]) !~ /\w/) { 
			my $temp_local = $local_col;
			while (&check_cell($r->[$temp_local]) !~ /\w/ && $temp_local <= $#cols) {  $temp_local++; }
			if (&check_cell($r->[$temp_local]) =~ /\w/) { $local_col = $temp_local; }
		}
		if ($rows_parsed == 0 && &check_cell($r->[$local_col]) =~ /\w/ && &check_cell($r->[$company_col]) !~ /\w/) { 
			my $temp_com = $company_col;
			while (&check_cell($r->[$temp_com]) !~ /\w/ && $temp_com <= $#cols) { $temp_com++; }
			if (&check_cell($r->[$temp_com]) =~ /\w/) { $company_col = $temp_com; }
		}
		#print "c: $company_col l: $local_col\n";
		if ($company_col == $local_col) { 
			($company_col, $local_col) = ($orig_company_col, $orig_local_col); 
		}	

		unless (&check_cell($r->[$company_col]) && &check_cell($r->[$local_col])) { next; }
		my $company = &check_cell($r->[$company_col]);
		my $location = &check_cell($r->[$local_col]);
		if (&store_relationship($company, $location, $id)) { 
			$rows_parsed++;
		}
	}	
	return $rows_parsed;
}


sub store_relationship {
	my ($company, $location, $id) = @_;
	unless ($company && $location) { return; }
	#print "before|$company|$location|\n";
	$company = &clean_contents($company);
	$location = &clean_contents($location);
	unless ($company && $location) { return; }

	foreach my $data ($location, $company) { 
		if (length($data) >=300) { return; }
		#$val = chr(160); $data =~ s/$val/ /gs;
		#$val = chr(710); $data =~ s/$val/^/gs;
		$data =~ s/ˆ/^/g;
		#$data =~ s/[\267|\256|\x8226|§]//gs;
		$data =~ s/[\267|\256|•|§]//g;
		$data =~ s/[\240|\205|\206|\225|\232|\231|\236]/ /g;
		$data =~ s/[\227|\226|\x{2013}|\x{8211}|\x{8212}|—]/-/g;
		$data =~ s/[\221|\222|\x{2018}|\x{2019}]/'/g;
		$data =~ s/[\223|\224|\x{201c}|\x{201d}]/"/g;
		if ($data =~ /([^\*:A-z0-9%\-,'\(\)\&\. ;\/\372\351\374\$<>\+#"!\?~\}@\-])/) {
			#print CHARS "$1: ".ord($1)." - ".chr(ord($1))." - ".HTML::Entities::encode($1)." - ".$HTML::Entities::entity2char{$1}." - $id\n";
		}
		if ($data =~ /^\(?\d+\.[\)\d%]*$/) { return; }
		$data =~ s/^\(([^\)]+)\)/$1/g;
		$data =~ s/^\(?\d+\.[\)\d%]* //g;
		$data =~ s/^o //g;
	}
	if ($company =~ /^\(?(Names? of (Subsidiar|Compan|Entit)(y|ies)|Name|Subsidiar(y|ies)|[\d\.]+|Corporation|Entity|Jurisdiction|Incorporated State|Partners|Shareholders?|Managers?|Members?|Country of Organization|Doing Business As|Names?|Organizedunderlaws of|[a-z]{2}|(Corporation|Company|Subsidiary|Entity|Legal) Names?|Company|.):?\.?%?\)?$/i) { return; }
	#if ($location =~ /(In)?corporat(ed|ion)|Jurisdiction|Ownership|Organization|Subsidiary|%|Company/i) { return; }
	if ($location =~ /Jurisdiction|Ownership|Organization|Subsidiary|%|Company/i) { return; }
	$location = &strip_junk($location);
	$location =~ s/(an? )?([^\(]+?) (corporation|company|partnership)\)?/$2/ig;
	$location =~ s/^incorporated in ((the )?state of )?(.*)$/$3/ig;
	$location =~ s/^(incorporated|almagamated) under the laws of (the )?(.*)$/$3/ig;
	$location =~ s/\(\d{4}\)$//g;
	$company =~ s/\s\s+/ /g;
	$company =~ s/^[\*\s\-•·•]+//g;
	$company =~ s/[;,\s\*]+$//g;
	$company =~ s/\([\d\.\%\*]+ ?(owned|interest)?\)$//ig;
	$company =~ s/\(\w\)$//g;
	$company =~ s/[;,\s\*]+$//g;
	$company =~ s/^Exhibit [\d\.]+( Subsidiaries( of( the)? ((registrant|company) )?)?)?//ig;
	
	foreach my $data ($location, $company) { 
		$sth5->execute($data);
		if ($sth5->rows()) { return; }
		if ($data =~  /^\(?[\d\.]+\)?$/) { return; }
		if ($data !~ /\w/) { return; }
		if ($data =~ /^.$/) { return; }
		if ($data =~ /^\d+$/) { return; }
	}
	if ($sth->execute($company,$location, $id)) { 
		#print "after|$company|$location|\n";
		return 1;
	} else { print $db->errstr; } 
}

sub search_elements {
	my ($elem, $id) = @_;
	#print ref($elem);
	my $rows_parsed = 0;
	foreach my $type ('div', 'p', 'font') {
		foreach my $div ($elem->find($type)) {
			#if ($div->find('div','p', 'font')) { next; }
			my ($company, $location);
			my $text = $div->as_text;
			#print $div->content_list;
			#print "**".$div->as_HTML."\n";
			if ($debug) { print "FOUND IN DIV**".$text."\n"; }
			my @results;
			#if ($text =~ /(.+?)(, | \()a (corporation organized and existing under the laws of the )?([^\(]+?) ?((limited( liability)? )?(corporation|company|partnership))\)?/i) {
			$text = &strip_junk($text);
			if ($text =~ /(.+?)(, | \()an? ([^\(]+) (corporation|company|partnership)\)?/sig) {
				push(@results, [$1, $3]);
				($company, $location) = ($1, $3);
			} elsif ($text =~ /(.+?)(, | \()a corporation organized and existing under the laws of (the )?([^\(]+)/sig) {
				push(@results, [$1, $4]);
				($company, $location) = ($1, $4);
			} elsif ($text =~ /(\w.+?) [\(\[](.[^\)]+)[\]\)][\W0-9]*?( \(\d.+)?/sig) {
				push(@results, [$1, $2]);
				($company, $location) = ($1, $2);
			}
			#print "$company - $location - $id\n";
			#foreach my $result (@results) { 
			#	my ($company, $location) = ($result->[0], $result->[1]);
			#	print "$company, $location\n";
			if (&store_relationship($company,$location,$id)) {
				$rows_parsed++;	
			}
		}
		if ($rows_parsed) { last; }
	}
	#print $rows_parsed;
	$elem->delete();
	return $rows_parsed;
}

sub strip_junk {
	my $text = shift;
	$text =~ s/(limited |liability |\((aquired )?inactive\)|\(unactivated\)|\((pty|dormant|non-trading|partnership|"PRC"|"BVI"|\d+)\)|\(?(in)?direct\)?|, \(?U\.?S\.?A?\.?\)?$|^\(?U\.?S\.?A?\.?\)?(-|, )|(State|Commonwealth|^Republic|Province|Rep\.|Grand-Duchy|Federation|Kingdom) of | \([\d\/%\.,]+\)|\(LLC\))//gsi;
	if (length($text) > 120) { $text =  ""; }
	return $text;
}

sub check_cell {
	my $cell = shift;
	$text = "";
	if (defined $cell && ref($cell) ne 'SCALAR') { 
		$text = $cell->as_trimmed_text;
		if (length($text) > 120) { $text =  ""; }
	}
	return $text;
}
