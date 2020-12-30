#!/usr/bin/perl

###############################################################################
##    HaCi - IP Address Administration                                        #
##    Copyright (C) 2006-2010 by Lars Wildemann                               #
##    Author: Lars Wildemann <HaCi@larsux.de>                                 #
##                                                                            #
##    HaCi is an IP Address / Network Administration Tool with IPv6 Support.  #
##    It stores its data efficiently in a relational Database and uses a      #
##    treelike Strukture to illustrate supernets and subnets.                 #
##                                                                            #
##    This program is free software; you can redistribute it and#or modify    #
##    it under the terms of the GNU General Public License as published by    #
##    the Free Software Foundation; either version 2 of the License, or       #
##    (at your option) any later version.                                     #
##                                                                            #
##    This program is distributed in the hope that it will be useful,         #
##    but WITHOUT ANY WARRANTY; without even the implied warranty of          #
##    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           #
##    GNU General Public License for more details.                            #
###############################################################################

sub getWorkDir {
	my $currDir = `pwd`;
	chomp($currDir);
	my $scriptFile	= $0;
	$scriptFile			= $ENV{SCRIPT_FILENAME} if exists $ENV{SCRIPT_FILENAME};
	(my $scriptDir  = $scriptFile) =~ s/\/[^\/]+$//;
	my $destDir			= ($scriptDir =~ /^\//) ? $scriptDir : $currDir . '/' . $scriptDir;
	chdir "$destDir/../" or die "Cannot change into workdir '$destDir/../': $!\n";
	my $workDir = `pwd`;
	chomp($workDir);

	return $workDir;
}

BEGIN {
	$workDir			= &getWorkDir();
	$ENV{workdir}	= $workDir;
	unshift @INC, $ENV{workdir} . '/modules';
}

use strict;
use warnings;
use Carp ();
local $SIG{__WARN__}	= \&Carp::cluck if 0;
$|										= 1;
use vars qw/$workDir/;

use SOAP::Transport::HTTP;
use HaCi::HaCiAPI;

map { warn " $_ => $ENV{$_}\n"; } keys %ENV if 0;

$workDir			= &getWorkDir();
$ENV{workdir}	= $workDir;
unshift @INC, $ENV{workdir} . '/modules';
my $query	= $ENV{'QUERY_STRING'};

my $startTime	= time;
warn "Start: " . localtime() . "\n";
if (defined $query && $query =~ /getWSDL/) {
	&prWSDL();
} else {
	SOAP::Transport::HTTP::CGI
	  -> dispatch_to('HaCi::HaCiAPI')
		-> handle;
}
warn "End: " . localtime() . "\n";
my $endTime	= time;
warn "Running: " . ($endTime - $startTime) . "s\n";

#--------------------------------
sub prWSDL {
	eval {
		require Pod::WSDL;
	};
	if ($@) {
		die "Cannot print WSDL: $@\n";
	}

	use CGI;
	my $q		= new CGI;
	my $pod	= new Pod::WSDL(
		source						=> 'HaCi::HaCiAPI', 
		location					=> ((($ENV{'HTTPS'} && $ENV{'HTTPS'} !~ /off/i) ? 'https' : 'http') . '://' . $ENV{'SERVER_NAME'} . $ENV{'SCRIPT_NAME'}),
		pretty						=> 1,
		withDocumentation	=> 1
	);

	print $q->header();
	print $pod->WSDL;
}

exit 0;

# vim:ts=2:sw=2:sws=2
