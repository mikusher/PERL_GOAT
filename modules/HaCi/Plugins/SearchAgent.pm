package HaCi::Plugins::SearchAgent;

use strict;
use warnings;

use base qw/HaCi::Plugin/;
use HaCi::Mathematics qw/dec2net netv6Dec2net/;
use HaCi::Utils qw/netID2Stuff/;
use HaCi::GUI::gettext qw/_gettext/;

our $INFO	= {
	name				=> 'Search Agent',
	version			=> '0.1',
	recurrent		=> 1,
	onDemand		=> 0,
	description	=> _gettext('This Plugin fills the Search-Database'),
	globMenuRecurrent	=> [],
	globMenuOnDemand	=> [],
	menuRecurrent	=> [],
	menuOnDemand	=> [],
};

sub run_recurrent {
	my $self			= shift;
	my $networks	= shift;
	my $config		= shift;

	warn "SearchAgent: I'm running...\n";

	return 1;
}

sub show {
	my $self				= shift;
	my $netID				= shift;
	my $values			= $self->getValues($netID);
	my $results			= {};
	my $lastUpdated	= $self->getValue(-1, 'lastUpdated');

	my $show	= {
		HEADER	=> "TEMPLATE",
		BODY		=> [
			{
				elements	=> [
					{
						target	=> 'single',
						type		=> 'label',
						value		=> 'TEMPLATE',
					},
				]
			},
		]
	};

	return $show;
}

1;
