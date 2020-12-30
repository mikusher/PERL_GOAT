#!/usr/bin/perl

use strict;
use warnings;
use CGI;

sub getWorkDir {
	my $currDir = `pwd`;
	chomp($currDir);
	my $scriptFile	= $0;
	$scriptFile		= $ENV{SCRIPT_FILENAME} if exists $ENV{SCRIPT_FILENAME};
	(my $scriptDir  = $scriptFile) =~ s/\/[^\/]+$//;
	my $destDir		= ($scriptDir =~ /^\//) ? $scriptDir : $currDir . '/' . $scriptDir;
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

$|				= 1;
my $workDir		= &getWorkDir();
$ENV{workdir}	= $workDir;
unshift @INC, $ENV{workdir} . '/modules';

my $q		= new CGI(@_);
my $title	= 'HaCi - IP Address Administration';
my $ver		= '0.9.7a';
my
@mands	= qw/CGI CGI::Ajax CGI::Carp CGI::Cookie CGI::Session Class::Accessor Class::MakeMethods Config::General DBD::mysql Digest::MD5 Digest::SHA Encode Encode::Guess File::Temp HTML::Entities Locale::gettext Log::LogLite Math::Base85 Math::BigInt#1.87 Net::CIDR Net::IMAP::Simple Net::IPv6Addr Net::SNMP Storable Template Time::Local/;
my
@opts	= qw/Cache::FastMmap Cache::FileCache DNS::ZoneParse IO::Socket::INET6 Math::BigInt::GMP Net::DNS Net::Nslookup Net::Ping Pod::WSDL SOAP::Transport::HTTP SQL::Translator#0.09000 SQL::Translator::Diff Text::CSV_XS Apache::DBI/;

print $q->header(-charset=>'UTF-8');

print $q->start_html({
	title	=> $title
});

print $q->h1($title);
print $q->h2("Version: " . $ver . (($ENV{MOD_PERL}) ? ' (running under mod-perl)' : ''));
print $q->h6($ENV{SERVER_SOFTWARE});

print $q->br, $q->h3("<u>Mandatory Modules:</u>");
print $q->start_table({cellpadding=>3, rules=>'all'});
foreach (sort @mands) {
	s/#/ /g;
	eval "use $_";
	warn $@ if $@;
	print $q->Tr($q->th({align=>'left'}, $_), $q->td({bgcolor=>(($@) ? '#FFAAAA' : '#AAFFAA')}, (($@) ? 'NOT' : '') . ' available'));
}
print $q->end_table;

print $q->start_table({cellpadding=>3, rules=>'all'});
print $q->br, $q->h3("<u>Recommended Modules:</u>");
foreach (sort @opts) {
	s/#/ /g;
	eval "use $_";
	warn $@ if $@;
	print $q->Tr($q->th({align=>'left'}, $_), $q->td({bgcolor=>(($@) ? '#FFAAAA' : '#AAFFAA')}, (($@) ? 'NOT' : '') . ' available'));
}

exit 0;

# vim:ts=4:sw=4
