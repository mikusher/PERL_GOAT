package HaCi::Conf;

use strict;
use Config::General qw(ParseConfig);

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(getConfigValue);

our $conf	= {};

#------------------------------------------------
sub init($) {
	my $workDir	= shift;
	$conf				= {};

	$ENV{workdir}	= $workDir;

	my $internalConfFile	= $ENV{workdir} . '/etc/internal.conf';
	unless (open ICONF, $internalConfFile) {
		die "Cannot open internal Config File '$internalConfFile': $!\n";
	}
	my $data	= join('', <ICONF>);
	close ICONF;

	eval {
		my %config	= ParseConfig(
			-String							=> $data,
			-LowerCaseNames			=> 1,
			-UseApacheInclude		=> 1,
			-IncludeRelative		=> 1,
			-IncludeDirectories	=> 1,
			-IncludeGlob				=> 1,
			-AutoTrue						=> 1,
			-InterPolateVars		=> 1,
			-InterPolateEnv			=> 1,
			-FlagBits						=> {
				status													=> {},
				pluginDefaultOndemandMenu				=> [],
				pluginDefaultGlobRecurrentMenu	=> [],
				pluginDefaultRecurrentMenu			=> [],
				pluginDefaultGlobOndemandMenu		=> [],
			},
		);

		foreach (qw/plugindefaultglobondemandmenu plugindefaultglobrecurrentmenu plugindefaultrecurrentmenu plugindefaultondemandmenu/) {
			if (ref($config{static}{$_}) eq 'HASH') {
				if (keys %{$config{static}{$_}} == 0) {
					$config{static}{$_}  = [];
				} else {
					$config{static}{$_}  = [$config{static}{$_}];
				}
			}
		}

		%{$conf}	= %config;
		undef %config;
	};
	if ($@) {
		die "Error while reading Config String (Conf.pm): $@\n";
	}
}

sub getConfigValue {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my @keys	= @_;

	return unless @keys;

	my $key		= '';
	foreach (@keys) {
		my $currKey	= lc($_);
		$key				.= "->{$currKey}";
	}
	my $userKey		= eval"\$conf->{user}$key";
	my $staticKey	= eval"\$conf->{static}$key";

	return (defined $userKey) ? $userKey : $staticKey;
}

1;

# vim:ts=2:sw=2:sws=2
