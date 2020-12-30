package HaCi::Log;

use warnings;
use strict;

require Exporter;
our @ISA				= qw(Exporter);
our @EXPORT_OK	= qw(warnl debug);

our $conf; *conf  = \$HaCi::Conf::conf;

sub warnl {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $error	= shift;
	my $bNPub	= shift || 0;
	my ($caller, $line)	= (caller)[0, 2];
	
	warn "$caller:$line $error\n";

	push @{$conf->{var}->{warnl}}, $error unless $bNPub;
}

sub debug {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $msg = shift;

	chomp($msg);
	$msg	.= "\n";
	  
	warn $msg if $conf->{static}->{misc}->{debug};
}

# vim:ts=2:sw=2:sws=2
