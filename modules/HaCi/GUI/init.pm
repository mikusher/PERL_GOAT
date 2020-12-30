package HaCi::GUI::init;

use warnings;
use strict;
use Template;

use HaCi::Conf qw/getConfigValue/;
use HaCi::GUI::gettext qw/_gettext initLocale/;

local our $t			= undef;
our $conf; *conf	= \$HaCi::Conf::conf;

sub init {
	my $s					= $HaCi::HaCi::session;

	if (&getConfigValue('gui', 'enableLocaleSupport')) {
		my $locale		= (defined $s) ? ($s->param('locale') || undef) : undef;
		my $langsT		= (exists $ENV{HTTP_ACCEPT_LANGUAGE}) ? $ENV{HTTP_ACCEPT_LANGUAGE} : '';
		my $langs			= (split(/;/, $langsT))[0] || '';
		my @httpLangs	= split(/,/, $langs);
	
		unless (defined $locale) {
			foreach (reverse @httpLangs) {
				my $currLoc	= (split(/[^a-z]/, lc($_)))[0];
				foreach (@{$conf->{static}->{gui}->{locales}}) {
					my $newLoc	= (split(/[^a-z]/, lc($_->{id})))[0];
					$locale	= $_->{id} if $currLoc eq $newLoc;
				}
			}
		}
		$locale	= 'C' unless defined $locale && $locale;
	
		&initLocale($locale);
		$s->param('locale', $locale);
	}

	$t->{T}	= Template->new(
		INCLUDE_PATH	=> $conf->{static}->{path}->{templateincludepath},
		PRE_CHOMP			=> 3,
		POST_CHOMP		=> 3,
		TRIM					=> 1,
		COMPILE_DIR		=> $conf->{static}->{path}->{templatecompilepath},
		COMPILE_EXT		=> '.ttc',
	);

}

sub setUserVars {
	my $s	= $HaCi::HaCi::session;

	$t->{V}->{showTreeStructure}	= (defined $s->param('settings') && exists $s->param('settings')->{bShowTreeStruct}) ? ${$s->param('settings')->{bShowTreeStruct}}[0] : $conf->{user}->{gui}->{showtreestructure};
	$t->{V}->{directaccess}				= $conf->{user}->{gui}->{directaccess};
	my $style											= (defined $s->param('settings') && exists $s->param('settings')->{layout}) ? ${$s->param('settings')->{layout}}[0] : $conf->{user}->{gui}->{style} || $conf->{static}->{gui}->{style};

	foreach (@{$conf->{static}->{gui}->{layouts}}) {
		my $layout	= $_;
		if ($layout->{name} eq $style) {
			$t->{V}->{style}			= $layout->{file};
			$t->{V}->{styleDescr}	= $layout->{descr};
		}
	}
}

sub setVars {
	$t->{V}												= $conf->{static}->{gui};
	$t->{V}->{thisScript}					= $conf->{var}->{thisscript};
	$t->{V}->{techContact}				= $conf->{user}->{gui}->{techcontact};
	$t->{V}->{gettext_contact}		= _gettext("Contact");
	$t->{V}->{gettext_support}		= _gettext("Supports");

	&setUserVars();
}

1;

# vim:ts=2:sw=2:sws=2
