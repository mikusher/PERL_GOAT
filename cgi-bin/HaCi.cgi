#!/usr/bin/perl -w

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

use strict;
use Carp ();
local $SIG{__WARN__}	= \&Carp::cluck if 0;
$|										= 1;

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
	my $workDir		= &getWorkDir();
	$ENV{workdir}	= $workDir;
	unshift @INC, $ENV{workdir} . '/modules';
}

# Polluting Environment for Config::General
$ENV{script_name}	= $ENV{SCRIPT_NAME};

my $workDir		= &getWorkDir();
$ENV{workdir}	= $workDir;
unshift @INC, $ENV{workdir} . '/modules';

use HaCi::HaCi;
use HaCi::Conf;

my $startTime	= time;

&HaCi::Conf::init($workDir);
&HaCi::HaCi::run();

my $endTime	= time;
warn "Processtime (" , localtime($startTime) . " - ". localtime($endTime) . "): " . ($endTime - $startTime) . "\n" if 0;
warn "Processtime : " . ($endTime - $startTime) . "\n" if 0;

exit 0;

# vim:ts=2:sw=2:sws=2
