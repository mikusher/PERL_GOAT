package HaCi::GUI::gettext;

use warnings;
use strict;

use Locale::gettext;
use POSIX qw/setlocale LC_ALL/;
use Encode;

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(
	initLocale _gettext
);

our $conf; *conf	= \$HaCi::Conf::conf;

sub _gettext {
	my $msgid	= shift;

	unless (defined $conf->{var}->{GETTEXT}) {
		my $locale	= (defined $HaCi::HaCi::session) ? $HaCi::HaCi::session->param('locale') : 'C';
		&initLocale($locale);
	}

	return encode('UTF-8', $conf->{var}->{GETTEXT}->get($msgid));
}

sub initLocale {
		my $locale	= shift;

		setlocale(LC_ALL, $locale);
		$conf->{var}->{GETTEXT}	= Locale::gettext->domain_raw('HaCi');
		$conf->{var}->{GETTEXT}->dir($conf->{static}->{path}->{localepath});
		$conf->{var}->{GETTEXT}->codeset('utf-8-strict');
}

1;

# vim:ts=2:sw=2:sws=2
