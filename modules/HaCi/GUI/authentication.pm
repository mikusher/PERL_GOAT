package HaCi::GUI::authentication;

use strict;

use HaCi::Conf qw/getConfigValue/;
use HaCi::GUI::init;

use HaCi::GUI::gettext qw/_gettext/;

our $conf; *conf	= \$HaCi::Conf::conf;

sub login {
	my $t								= $HaCi::GUI::init::t;
	my $s								= $HaCi::HaCi::session;
	my $q								=	$HaCi::HaCi::q;
	my $locales					= $conf->{static}->{gui}->{locales};
	my $localesEnabled	= &getConfigValue('gui', 'enableLocaleSupport');
	map {$_->{ID}	= $_->{id}} @{$locales};

	$localesEnabled			= 1 unless defined $localesEnabled;

	$t->{V}->{buttonFocus}	= 'login';
	$t->{V}->{loginMenu}		= [
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext('Username'),
				},
				{
					target		=> 'value',
					type			=> 'textfield',
					value			=> (defined $q->param('username')) ? $q->param('username') : '',
					name			=> 'username',
					size			=> 13,
					maxlength	=> 255,
					focus			=> 1
				},
			]
		},
		{
			elements	=> [
				{
					target	=> 'key',
					type		=> 'label',
					value		=> _gettext('Password'),
				},
				{
					target		=> 'value',
					type			=> 'passwordfield',
					value			=> '',
					name			=> 'password',
					size			=> 13,
					maxlength	=> 255,
				},
			]
		},
		($localesEnabled) ? (
			{
				elements	=> [
					{
						target	=> 'key',
						type		=> 'label',
						value		=> _gettext('Language'),
					},
					{
						target		=> 'value',
						type			=> 'popupMenu',
						name			=> 'locale',
						size			=> 1,
						values		=> $locales,
						onChange	=> 'submit()',
						selected	=> $s->param('locale')
					},
				]
			}) : (),
		{
			value	=> {
				type	=> 'hline',
				colspan	=> 2,
			}
		},
		{
			elements	=> [
				{
					target	=> 'single',
					type		=> 'buttons',
					colspan	=> 2,
					align		=> 'center',
					buttons	=> [
						{
							name	=> 'login',
							type	=> 'submit',
							value	=> _gettext('Login'),
							img		=> 'login_small.png',
						}
					],
				},
			]
		},
	];
	
	$t->{V}->{loginHeader}	= _gettext('Authentication');
	$t->{V}->{authError}		= $conf->{var}->{authenticationError} if exists $conf->{var}->{authenticationError};
}

1;

# vim:ts=2:sts=2:sw=2
