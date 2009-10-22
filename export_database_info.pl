#!/usr/bin/perl -w

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
    
#---------------------------------
# This script is used to update the php include file that contains meta information about the database
#--------------------------------

require './common.pl';
our $db;
our $datadir;
$| = 1;

open(INFO, ">../db_info.php");
	print INFO "<?php\n\$db_info = array(\n";
my $res = $db->selectall_hashref("select * from meta", 'meta');
foreach my $key (keys(%$res)) {
	print INFO "\t'$key'=> '$res->{$key}->{value}',\n";
}
print INFO ");\n?>";

