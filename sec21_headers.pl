#!/usr/bin/perl 
use HTML::TableExtract qw(tree);
use Data::Dumper;
use utf8;
#use Devel::Size qw(size total_size);
#use Devel::DumpSizes qw/dump_sizes/;
#$HTML::Entities::entity2char{nbsp} = " ";
#$HTML::Entities::entity2char{nbsp} = chr(32);
#$HTML::Entities::char2entity{chr(146)} = chr(39);
#print Data::Dumper::Dumper($HTML::Entities::entity2char{nbsp});
#exit;
require "./common.pl";
#$| =1;
our $db;
open(CHARS, '>>chars.txt');
binmode CHARS, ":utf8";
our $datadir;
#my $where = " and filing_id >= 10000 ";
#my $where = " ";
my $relationship_table = 'relationships';
my $debug =1;
if ($ARGV[0]) { 
	$where = " and filing_id = $ARGV[0] ";
} else {
	$db->do("alter table $relationship_table auto_increment = 0");
	$db->do("alter table filing_tables auto_increment = 0");
}
if ($ARGV[1]) { $debug = 1; }
$db->do("delete from $relationship_table where filing_id is not null $where");
$db->do("delete from filing_tables where filing_id is not null $where");
$db->do("delete from bad_locations where filing_id is not null $where");
my $filings = $db->selectall_arrayref("select filing_id, filename, quarter, year, cik, company_name from filings where has_sec21 = 1 $where order by filing_id") || die "$!";
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
		$html =~ s/<su[pb][^>]*>[^<]*<\/su[pb]>//gsi;
		#print $html;
		$p->parse($html);	
		my ($rowskip, $g_company_col, $g_local_col);
		my $locked = 0;
		my @tables = $p->tables;
		my $tableinfo->{headerrow} = undef;
		print "\n"; 
		foreach my $t (@tables) {
			my $tableinfo;
			$tableinfo->{results} = [];
			$tableinfo->{rows_parsed} = 0;
			$results->{num_tables}++;
			my @rows = $t->rows();
			my @cols = $t->columns();
			($tableinfo->{rows}, $tableinfo->{cols}) = ($#rows +1, $#cols+1);
			print "\t Table: $#rows x $#cols";
			foreach my $row (@rows) { 
				my $hierarchy;
				my $rowtext = '';
				my @cells;
				my $row_parsed = 0;
				foreach my $cell (@$row) {
					push(@cells, &check_cell($cell));
					if (&check_cell($cell)) {
						if ($hierarchy eq "") {
							if ($cell->as_HTML =~ /margin-left: ?([^;"]+);?( ?text-indent:?([^;"]+))?/i ) {
								my ($marge, $indent) = ($1, $3);
								$marge =~ s/(\s|px|em|pt|in)//g;
								$indent =~ s/(\s|px|em|pt|in)//g;
								if ($marge + $indent && $marge != $indent && $marge > 0 && "-$marge" != $indent) { 
									$hierarchy = $marge + $indent;
								}
							}
						}
					}
				}
				if ($row_parsed) { next; }
				my $rowtext = join('|', @cells);
				if ($rowtext =~ /^([\|\s−]*\|)/) {
					my $emptys = $1;
					$hierarchy += $emptys =~ tr/\|//;
				}
				if ($rowtext =~ /^([\s−]*)/) {
					my $emptys = $1;
					while ($emptys =~ /[\s\-−]/g) {
						$hierarchy++;
					}
				}
					#print "\n-----------------\n$rowtext\n";
					$rowtext = join('|', map(&strip_junk($_), split(/\|/, $rowtext)));
				$rowtext =~ s/[\|\s]*\|/\|/g;
				$rowtext =~ s/(^\||\|$)//g;
					#print " "x$hierarchy; print "$rowtext\n";
				unless ($rowtext =~ /\w/) { next; }
				if($rowtext !~ /\|/) {
					#print "----------$rowtext\n";
					if (($company, $location) = &parse_single($rowtext)) {
						if (&store_relationship($company, $location, $id, $tableinfo, 'simple table, single-parsed', $hierarchy)) {
							$tableinfo->{rows_parsed}++;
							next;
						}
					}
				} else {
					my @parts = split(/\|/, $rowtext);
					@parts = map(&strip_junk($_), @parts);
					if (&store_relationship($parts[0], $parts[1], $id, $tableinfo, 'simple table, company|location', $hierarchy)) {
						$tableinfo->{rows_parsed}++;
						next;
					} elsif (&store_relationship($parts[0], $parts[2], $id, $tableinfo, 'simple table, |location|?|company', $hierarchy)) {
						$tableinfo->{rows_parsed}++;
						next;
					} elsif (&store_relationship($parts[2], $parts[1], $id, $tableinfo, 'simple table, |?|location|company', $hierarchy)) {
						$tableinfo->{rows_parsed}++;
						next;
					}
				}
				#print "\t*$rowtext*\n";
				foreach my $cell (@$row) {
					if (&check_cell($cell)) {
						if (my $t_rows_parsed = &search_elements($cell, $id,$tableinfo, $hierarchy)) {
							$tableinfo->{rows_parsed} += $t_rows_parsed;
							$row_parsed = 1;
							last;
						}
					}
				}
			}
			unless ( $tableinfo->{rows_parsed}) {
				my $t_headerrow;
				my $headers;
				($tableinfo->{company_col}, $tableinfo->{local_col}, $headers, $t_headerrow) = &detect_headers($t);
				if (! defined $tableinfo->{headerrow}) {
					$tableinfo->{headerrow} = $t_headerrow;
				}
				if (defined $tableinfo->{company_col}) { $g_company_col = $tableinfo->{company_col}; } else { $tableinfo->{company_col} = $g_company_col; }
				if (defined $tableinfo->{local_col}) { $g_local_col = $tableinfo->{local_col}; } else { $tableinfo->{local_col} = $g_local_col; }
				#print "c: $tableinfo->{company_col} l: $tableinfo->{local_col}\n";
				my $sth3 = $db->prepare_cached("insert into filing_tables set filing_table_id = null, filing_id=?, table_num=?, num_rows=?, num_cols=?, headers=?");
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
						#if ($debug) { print "***********".$text."\n"; }
						#if ($debug) { print "***********".$row->[$datacol]->as_HTML."\n;"; }
						$text = &strip_junk($text);
						my ($company, $location) = &parse_single($text);
						if (&store_relationship($company,$location,$id,$tableinfo, 'single parsed from table')) {
							$tableinfo->{rows_parsed}++;
						} elsif ($text && $row->[$datacol]->find('div','p')) {
							if ($debug) { print "- parsing divs - "; }
							if (my $t_rows_parsed = &search_elements($row->[$datacol], $id,$tableinfo)) {
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
									my $t_rows_parsed = &search_elements($row->[$currcol], $id,$tableinfo);
									if ($t_rows_parsed > 0) {
										$tableinfo->{rows_parsed} += $t_rows_parsed;
										last;
									}	
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
							if ($company && $location) {
								if (&store_relationship($company,$location,$id,$tableinfo, 'grasping at straws')) {
									$tableinfo->{rows_parsed}++;
								}
							}
						}
					}
					unless ($tableinfo->{rows_parsed}) {
						if (my $t_rows_parsed = &search_elements($t->tree(), $id,$tableinfo)) {
							$tableinfo->{rows_parsed} += $t_rows_parsed;
						}
					}
				} else {
					#print " headers: ".&check_cell($rows[$tableinfo->{headerrow}]->[$tableinfo->{company_col}]).", ".&check_cell($rows[$tableinfo->{headerrow}]->[$tableinfo->{local_col}])." - ";
					$tableinfo->{rows_parsed} = &parse_table_by_headers($t, $results->{num_tables},$tableinfo);	
				}
			}
			if ($tableinfo->{rows_parsed} > 0) {  
				$results->{tables_parsed}++;
				$results->{rows_parsed} += $tableinfo->{rows_parsed};
				print " Parsed!\n"; 
				my $sth4 = $db->prepare_cached("update filing_tables set parsed = 1 where filing_id=? and table_num=?");
				$sth4->execute($id, $results->{num_tables});
			} else {  
				print " Failed!\n"; 
			}
			push (@{$results->{tables}}, $tableinfo);
			#print Data::Dumper::Dumper($tableinfo);
			foreach my $result (@{$tableinfo->{results}}) { 
				&store_results($result); 
			}
		} 
		unless ($tables[0] && $results->{rows_parsed}) {
			print " - no tables - ";
			$tableinfo->{results} = [];
			if (my $t_rows_parsed = &search_elements($p->tree(), $id,$tableinfo)) {
				$results->{rows_parsed} += $t_rows_parsed;
			}
			foreach my $result (@{$tableinfo->{results}}) { 
				&store_results($result); 
			}
		}
	} else {
		#No HTML
		print " - no html - ";
		$tableinfo->{results} = [];
		foreach my $line (split(/\n/, $content)) {
			my $text = $line;
			$text =~ s/\s\s\s+/|/g;
			$text =~ s/[\|\s]*\|/\|/g;
			$text =~ s/(^\||\|$)//g;
			#print "^^^^$text\n";
			if ($text =~ /\w/ && $text =~ /\|/) {
				my @parts = split(/\|/, $text);
				if (&store_relationship($parts[0], $parts[1], $id, $tableinfo, 'simple no html, company|location')) {
					$results->{rows_parsed}++;
					next;
				} elsif (&store_relationship($parts[2], $parts[1], $id, $tableinfo, 'simple no html, |?|location|company')) {
					$results->{rows_parsed}++;
					next;
				}
			}
			my ($company, $location) = parse_single($line);
			if (&store_relationship($company,$location,$id,$tableinfo, 'no html - single parsed')) {
				$results->{rows_parsed}++;
			} elsif ($line =~ /^(.*?\S)\s\s\s+(\S.*?)(\s\s+|$)/) {
				($company, $location) = ($1, $2);
				if (&store_relationship($company,$location,$id,$tableinfo, 'no html - parsed by spaces')) {
					$results->{rows_parsed}++;
				}
			}
		}
		foreach my $result (@{$tableinfo->{results}}) { 
			&store_results($result); 
		}
	}
	if ($results->{rows_parsed} > 0) {
		print "Parsed!\n";
	} else {
		print "Failed!\n"; 
	}
	my $sth2 = $db->prepare_cached("update filings set has_html=?, num_tables=?,num_rows=?,tables_parsed=?,rows_parsed=? where filing_id=?");
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
	my ($company_col, $local_col, $headerrow) = ($tableinfo->{company_col}, $tableinfo->{local_col}, $tableinfo->{headerrow});
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
		if (&store_relationship($company, $location, $id,$tableinfo, 'table parsed by headers')) { 
			$rows_parsed++;
		}
	}	
	return $rows_parsed;
}


sub store_relationship {
	my ($company, $location, $id,$tableinfo, $type, $hierarchy) = @_;
	($company, $location, $cc, $sc) = checkResults($company, $location);
	unless ($company && $location) { return; }
	print "after: $company|$location|$type\n";
	#print Data::Dumper::Dumper($tableinfo);
	push(@{$tableinfo->{results}}, {company=>$company, location=>$location, id=>$id, type=>$type, cc=>$cc, sc=>$sc, hierarchy=>$hierarchy});
	return 1;
}

sub store_results() {
	my $result = shift;
	#print Data::Dumper::Dumper($result);
	my $clean = &clean_for_match($result->{company});
	my $sth = $db->prepare_cached("insert into $relationship_table (relationship_id, company_name, location, filing_id, parse_method, country_code, subdiv_code, hierarchy, clean_company) values (null, ?, ?, ?, ?, ?, ?,?,?)");
	if ($sth->execute($result->{company},$result->{location}, $result->{id}, $result->{type}, $result->{cc}, $result->{sc}, $result->{hierarchy}, $clean)) { 
		#print "after|$result->{company}|$result->{location}|$result->{hierarchy}\n";
		return 1;
	} else { print $db->errstr; } 
}


sub parse_single() {
	my $text = shift;
	my ($company, $location);
	if (length($text) >=300) { return; }
	if ($text !~ /\w/) { return; }
	#print "In Parse Single: $text\n";
	$parse_single_type = 0;
	my $x = 0;
	if ($text =~ /(.+?)(,|is|was) (an? |our )?(wholly-owned |private |s.p.a. )?(subsidiary |foreign sales corporation |company )?(incorporated|located|chartered) in (the )?(.+?)( and|\s\s+| \(.+|$)/sig) {
		($company, $location) = checkResults($1, $8);
		$parse_single_type = 1;
	}
	if (!$company && $text =~ /(.+?)(, | \(|  )an? ([^\(]+?) (corporation|company|partnership|statutory trust|state[- ]chartered (commercial )?bank|business trust)\)?/sig) {
		($company, $location) = checkResults($1, $3);
		$parse_single_type = 2;
	}
	if (!$company && $text =~ /(.+?)(, | \(|is )(a (corporation|national banking (association|organization)) )?(organized|incorporated) (and existing )?under the laws of (the )?([^\(]+)/sig) {
		($company, $location) = checkResults($1, $9);
		$parse_single_type = 3;
	}
	if (!$company && $text =~ /(.+?)( is|, )? (formed|registered|incorporated|organized) (in|under) (the (laws of))?(.+?)($| and|\s\s+)/sig) {
		($company, $location) = checkResults($1, $7);
		$parse_single_type = 4;
	}
	#if (!$company && $text =~ /(\w.+?) ?[\(\[](.[^\)]+)[\]\)][\W0-9]*?( \(\d.+)?/sig) {
	if (!$company && $text =~ /(\w.+?) ?[\(\[](.[^\)\]]+)[\]\)](.+)?/sig) {
		($company, $location, $stuff) = ($1, $2, $3);
		if ($stuff) { 
			$company = $text;
		}
		($company, $location) = checkResults($company, $location);
		$parse_single_type = 5;
	}
	if (!$company && $text =~ /^\s*(\w.+) *jurisdiction of organization: ?(\w.+)$/i) {
		($company, $location) = checkResults($1, $2);
		$parse_single_type = 6;
	}
	if (!$company && $text =~ /^\s*(\w.+?)\s*(–|–|&#15[01];|-)\s*(\w.+)$/) {
		($company, $location) = checkResults($1, $3);
		$parse_single_type = 7;
	}
	if (!$company && $text =~ /^\s*(\w.+?)\s\s\s+(\w.+)$/) {
		($company, $location) = checkResults($1, $2);
		$parse_single_type = 8;
	}
	if (!$company && $text =~ /^\s*(\w.+?)  .*  (\w.+)$/) {
		($company, $location) = checkResults($1, $2);
		$parse_single_type = 9;
	}
	$text =~ s/\s\s+/ /g;	
	if (!$company && $text =~ /(\w.+?) \(?(.+?)\)?(\.|,| )+(\.|,| |ltd|company|co|S\.?(A\.?)?(R\.?L\.?)?|limited|inc|incorporated|corp|pty|private|gmbh|L\.?P\.?|B\.?V\.?|SAE|S\.?A\.?S\?|AG|partnership)+$/i) {
		($company, $location) = checkResults($text, $2);
		$parse_single_type = 10;
	}
	#print "End of parse_single: $company|$location|$parse_single_type\n";
	unless ($company && $location) { return; }
	return ($company, $location);
}

sub search_elements {
	my ($elem, $id,$tableinfo, $hierarchy) = @_;
	my $found = 0;
	#print ref($elem);
	foreach my $type ('div', 'p', 'font', 'pre') {
		foreach my $div ($elem->find($type)) {
			my $found_this_elem = 0;
			if ($div->as_HTML =~ /.<$type/) { next; }

			#if ($div->find('div','p', 'font')) { next; }
			my ($company, $location, $hierarchy);
			if ($div->as_HTML =~ /margin-left: ?([^;"]+);?( ?text-indent:?([^;"]+))?/i ) {
				my ($marge, $indent) = ($1, $3);
				$marge =~ s/(\s|px|em|pt|in|%)//g;
				$indent =~ s/(\s|px|em|pt|in|%)//g;
				if ($marge + $indent && $marge != $indent && $marge > 0 && "-$marge" != $indent) { 
					$hierarchy = $marge + $indent;
				}
			}
			my $text = $div->as_text;
			if (($type eq 'pre' &&  $div->as_HTML =~ /\n/) || $div->as_HTML =~ /<br ?\/?>/i) {
				my @lines;
				if ($type eq 'pre') { 
					@lines = split(/\n/, $div->as_HTML);
				} else {
					@lines = split(/<br ?\/?>/i, $div->as_HTML);
				}
				#print $div->as_HTML;
				foreach my $text (@lines) {
					#$text =~ s/\n//gs;
					$text =~ s/<[^>]+>/ /g;
					$text = HTML::Entities::decode_entities($text);
					$text = &strip_junk($text);
					#print "*$text\n";
					($company, $location) = &parse_single($text);
					if(&store_relationship($company,$location,$id,$tableinfo, "parsed from $type via br", $hierarchy)) {
						$found++;
						$found_this_elem++;
					}
				}	
			}
			#if ($type ne 'pre' && $found < 1) {
			if ($type ne 'pre' && $found_this_elem == 0) {
				#print $div->content_list;
				#print "**".$div->as_HTML."\n";
				#if ($debug) { print "FOUND IN $type**".$text."\n"; }
				my @results;
				$text = &strip_junk($text);
				($company, $location) = &parse_single($text);
				
					#print "$company - $location - $id\n";
					#print "$company, $location\n";
				if (&store_relationship($company,$location,$id,$tableinfo, "parsed from $type", $hierarchy)) {
					$found++;
					$found_this_elem++;
				}
			}
		}
				#print  "**here".$tableinfo->{rows_parsed};
		if ($found > 0) { last; }
	}
	unless ($found > 0) {
		if ($elem->as_HTML =~ /<br/i) {
			my @parts = split(/<br ?\/?>/i, $elem->as_HTML);
			if ($parts[$#parts] =~ /^([^,]+),\s+([^\d]+)\s+[\d- ]+<\/td>$/) {
				$location = "$1, $2";
				$parts[0] =~ s/^<td[^>]+>//i;
				($company, $location) = (HTML::Entities::decode_entities($parts[0]), HTML::Entities::decode_entities($location));
				if (&store_relationship($company,$location,$id,$tableinfo, "parsed from full address", $hierarchy)) {
					$found++;
				}
				#if (&store_relationship($company,$location,$id,$tableinfo, 'single parsed from table')) {
				#	$tableinfo->{rows_parsed} ++;
				#}
			}
			unless ($found > 0) {
				foreach my $part (@parts) { 
					$part =~ s/<[^>]+>/ /g;
					$part = &strip_junk(HTML::Entities::decode_entities($part));
					if (($company, $location) = &parse_single($part)) {
						if (&store_relationship($company, $location, $id, $tableinfo, 'parsed single via br', $hierarchy)) {
							$tableinfo->{rows_parsed}++;
							$found++;
						}
					}
				}
			}
		}
	}
	#print $rows_parsed;
	#$elem->delete();
	return $found;
}

sub strip_junk {
	my $text = shift;
	#print "$text\n";
	$name =~ s/\bL\.L\.C\.\b/LLC/gi;
	$name =~ s/\bL\.P\.\b/LP/gi;
	$text =~ s/(limited |liability |\((aquired )?inactive\)|\(unactivated\)|\((pty|dormant|non-trading|partnership|"PRC"|"BVI"|\d+)\)|\(?(in)?direct\)?|, \(?U\.?S\.?A?\.?\)?$|^\(?U\.?S\.?A?\.?\)?(-|, )|^(the )?(State|Commonwealth|^Republic|Province|Rep\.|Grand-Duchy|Federation|Kingdom) of | \([\d\/%\.,]+(-NV)?\)|\(LLC\)|^[\d\/%\.,\(\)]+(-NV)?$|[\267|\256|•|§]|^filed in |with a purpose trust charter)//gsi;
	$text =~ s/\((wholly|f\/k\/a|formerly|proprietary|previously known|contractually|see|name holder|acquired|joint venture|jv|jointly|a business|a company).*\)//ig;
	$text =~ s/^(Managing ?Member|Wholly ?owned|(General)? ?Partner|Owner|Member|LLC|Unaffiliated ?parties|Limited|ENtity ?Name|FOrmation|N\/A|\*+)$//gsi;
	$text =~ s/[\240|\205|\206|\225|\232|\231|\236]/ /g;
	$text =~ s/[\227|\226|\x{2013}|\x{8211}|\x{8212}|—]/-/g;
	$text =~ s/^(company|corporation|partnership|(formed)? in|-|[\*\/]|none|(limited liability )?(corporation|company)|)*$//gi;
	$text =~ s/(^|\()[\d\.]+% ((member|partner) interest )?(owned )?by.*?($|\)|,)//ig;
	$text =~ s/(^|\()owned [\d\.]+% by .*?($|\)|,)//ig;
	$text =~ s/holds interest in.*$//ig;
	$text =~ s/^[\d+\.%]+[%\.] ?//ig;
	$text =~ s/^(list of subsidiaries|registrant)//gi;
	$text =~ s/(general| and its subsidiar(y|ies):?)\s*$//gi;
	$text =~ s/[\(]?dba .*$//igs;
	$text =~ s/^[ \d%-]+$//igs;
	$text =~ s/[ ,]+$//;
	$text =~ s/\.\.+/\//g;
	return $text;
}

sub check_cell {
	my $cell = shift;
	$text = "";
	if (defined $cell && ref($cell) ne 'SCALAR') { 
		$text = $cell->as_text;
		#print $cell->as_HTML;
		#print "-----------CHECK: $text\n";
		$text =~ s/[\r\n\240]/ /gs;
		#if (length($text) > 120) { $text =  ""; }
	}
	return $text;
}

sub lookup_location {
	my $location = shift;
	#print "^^$location\n";
	
	$location = &strip_junk($location);
	$location =~ s/(an? )([^\(]+?) (corporation|company|(general )?partnership|corp)\)?.*/$2/ig;
	$location =~ s/^incorporated in ((the )?state of )?(.*)$/$3/ig;
	$location =~ s/^.*(incorporated|amalgamated|organized) under the laws of (the )?(.*)$/$3/ig;
	$location =~ s/\(\d{4}\)$//g;
	$location =~ s/ (LLC|Statutory Trust|General Part(nership)?|private|banking|special|closed)*$//gi;
	$location =~ s/^(incorporation|formed in)*:? //gi;
	$location =~ s/[\d\.,]+%(-NV)? ?//g;
	$location =~ s/^([^,]+) ?- ?([^,]+)$/$1, $2/;
	$location =~ s/(corporation|company|organization|(general )?partnership|corp)$//ig;
	$location =~ s/\(([^\)]+)\)/, $2/;
	$location = &strip_junk($location);
	#print "##$location\n";	
	if ($location =~ /^.?$/) { return; }
	my ($cc, $sc);
	if ($location =~ /delaware/i) {
		($sc, $cc) = ('DE', 'US');
	} elsif ($location =~ /,/) {		
		my ($first, $second) = split(/, ?/, $location, 2);
		foreach ($first, $second) {
			#print "$$ $first | $second\n";
			if ($_ =~ /^(INC|LTD|LLC|.|\d+)$/ig) { return; }
		}
		my $country_order = 2;
		$sth = $db->prepare_cached("select country_code from un_countries a where a.country_name = ? union select country_code from un_country_aliases b where b.subdiv_code is null and b.country_name = ?");
		$sth->execute($second,$second);
		unless (($cc) = $sth->fetchrow_array) {
		$sth->execute($first,$first);
			($cc) = $sth->fetchrow_array;
			$country_order = 1;
		}
		$sth->finish;
		if($cc) {
			$sth = $db->prepare_cached("select subdivision_code from un_country_subdivisions a where a.country_code = ? and a.subdivision_name = ? union select subdiv_code from un_country_aliases where country_code = ? and country_name = ? and subdiv_code is not null");
			if ($country_order == 1) {
				$sth->execute($cc,$second, $cc, $second);
			} else {
				$sth->execute($cc, $first, $cc, $first);
			}
			($sc) = $sth->fetchrow_array;
			$sth->finish;
		} else {
			$sth = $db->prepare_cached("select subdivision_code,country_code from un_country_subdivisions where subdivision_name = ? or subdivision_name = ? union select subdiv_code,country_code from un_country_aliases b where b.subdiv_code is not null and (b.country_name = ? or b.country_name = ?)");
			$sth->execute($first,$second,$second,$first);
			unless (($sc, $cc) = $sth->fetchrow_array) {
				$sth = $db->prepare_cached("select subdivision_code,country_code from un_country_subdivisions where subdivision_code = ? or subdivision_code = ? union select subdiv_code,country_code from un_country_aliases b where b.subdiv_code is not null and (b.country_code = ? or b.country_code = ?)");
				$sth->execute($first,$second,$second,$first);
				($sc, $cc) = $sth->fetchrow_array;
				$sth->finish;
			}
			$sth->finish;
		}
	}
	unless ($cc) {
		$sth = $db->prepare_cached("select subdivision_code, 'US' from un_country_subdivisions where country_code = 'US' and (subdivision_code = ? or subdivision_name = ?)");
		$sth->execute($location,$location);
		unless (($sc, $cc) = $sth->fetchrow_array) {
			my $sth = $db->prepare_cached("select country_code from un_countries where country_name = ? or country_code = ?");
			$sth->execute($location,$location);
			unless (($cc) = $sth->fetchrow_array) {
				my $sth = $db->prepare_cached("select country_code, subdiv_code from un_country_aliases where country_name = ?");
				$sth->execute($location);
				unless (($cc, $sc) = $sth->fetchrow_array) {
					$sth = $db->prepare_cached("select country_code, subdivision_code from un_country_subdivisions where subdivision_code = ? or subdivision_name = ? and subdivision_code != 'I'");
					$sth->execute($location,$location);
					($cc, $sc) = $sth->fetchrow_array;
					$sth->finish;
				}
				$sth->finish;
			}
			$sth->finish;
		}
		$sth->finish;

	}
	return ($cc, $sc, $location);
}

sub checkResults() {
	my ($company, $location) = @_;
	unless ($company && $location) { return; }
	$company = &clean_contents($company);
	$location = &clean_contents($location);
	unless ($company && $location) { return; }
	#print "before:$company|$location|$type\n";

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
		$data =~ s/,$//;
		$data =~ s/^([^\.]+)\.$/$1/;
	}
	if ($company =~ /^\(?(Names? of (Subsidiar|Compan|Entit)(y|ies)|Name|Subsidiar(y|ies)|[\d\.]+|Corporation|Entity|Jurisdiction|Incorporated State|Partners|Shareholders?|Managers?|Members?|Country of Organization|Doing Business As|Names?|Organizedunderlaws of|[a-z]{2}|(Corporation|Company|Subsidiary|Entity|Legal) Names?|Company|.):?\.?%?\)?$/i) { return; }
	#if ($location =~ /(In)?corporat(ed|ion)|Jurisdiction|Ownership|Organization|Subsidiary|%|Company/i) { return; }
	#if ($location =~ /Jurisdiction|Ownership|Organization|Subsidiary|%|Company/i) { return; }
	if ($company =~ /^combined ownership of /i) { return; }
	$company =~ s/\s\s+/ /g;
	$company =~ s/^[\*\s\-•·•]+//g;
	$company =~ s/[;,\s\*]+$//g;
	$company =~ s/\([\d\.\%\*]+ ?(owned|interest)?\)$//ig;
	$company =~ s/\(\w\)$//g;
	$company =~ s/[;,\s\*]+$//g;
	$company =~ s/^Exhibit [\d\.]+(( list of)? Subsidiaries( of( the)? ((registrant|company) )?)?)?//ig;
	$company =~ s/ is a (substantially )?wholly-owned.*$//ig;
	$company =~ s/[,\s]*(and its subsidiar(y|ies)|general partner of):?\s*$//gi;
	$company = strip_junk($company);
	$location = strip_junk($location);
	foreach my $data ($location, $company) { 
		my $sth5 = $db->prepare_cached("select term from parsing_stop_terms where term = ?");
		$sth5->execute($data);
		if ($sth5->rows()) { print "found $data in stop words\n"; $sth5->finish; return; }
		$sth5->finish;
		if ($data =~  /^\(?[\d\.]+\)?$/) { return; }
		if ($data !~ /\w/) { return; }
		if ($data =~ /^.$/) { return; }
		if ($data =~ /^[^A-z]+$/) { return; }
		if (length($data) > 120) { return; }
	}
	#print "before:$company|$location|$type\n";
	my ($cc, $sc, $newlocation) =  &lookup_location($location);
	my ($ccc, $csc, $newclocation) =  &lookup_location($company);
	if ($cc && $ccc) { print "Both $location and $company $ccc $csc are locations\n"; return; }
	if ($ccc) {
		my $temp = $location;
		$newlocation = $newclocation;
		$company = $temp;
		$cc = $ccc;
		$sc = $csc;
	} elsif (!$cc) {
		my $sth = $db->prepare_cached("insert into bad_locations values(null, ?, ?,?)");
		$sth->execute($company, $location,$id);
		return;
	}
	return ($company, $newlocation, $cc, $sc);	
}
