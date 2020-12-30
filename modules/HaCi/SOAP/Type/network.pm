package HaCi::SOAP::Type::network;

=begin WSDL

	_ATTR rootName		$string Name of Root
	_ATTR network			$string Network
	_ATTR description	$string Description
	_ATTR state				$string State

=cut

sub new {
	my $class				= shift;
	my $rootName		= shift || '';
	my $network			= shift || '';
	my $description	= shift || '';
	my $state				= shift || 0;

	bless {
		rootName		=> $rootName,
		network			=> $network,
		description	=> $description,
		state				=> $state,
	}, $class;
}

1;
