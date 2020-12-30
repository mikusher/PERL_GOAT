package HaCi::Plugin;

use strict;
use warnings;

use HaCi::Utils qw(getPluginValue);

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw( $INFO );

our $INFO	= {
	name				=> 'NONAME',
	version			=> '0.1',
	recurrent		=> 0,
	onDemand		=> 0,
	description	=> '',
	api					=> [],
	globMenuRecurrent	=> [],
	globMenuOnDemand	=> [],
	menuRecurrent			=> [],
	menuOnDemand			=> [],
};

sub new {
	my $class				= shift;
	my $ID					= shift || -1;
	my $valueTable	= shift || undef;
	my $self				= {
		ID					=> $ID,
		VALUETABLE	=> $valueTable,
		ERROR				=> 0,
		ERRORSTR		=> '',
	};

	bless $self, $class;

	return $self;
}

sub run_recurrent {
	my $self	= shift;

	return 1;
}

sub run_onDemand {
	my $self	= shift;

	return 1;
}

sub show {
	my $self	= shift;
	my $show	= {};

	return $show;
}

sub saveValue {
	my $self		= shift;
	my $netID		= shift;
	my $origin	= shift;
	my $name		= shift;
	my $value		= shift;

	unless (defined $self->{VALUETABLE}) {
		warn "Cannot update Plugin Value. DB Error (pluginValue)\n";
		return 0;
	}

	my $pluginValueEntry = ($self->{VALUETABLE}->search(['ID'], {pluginID => $self->{ID}, netID => $netID, name => $name}))[0];
	$self->{VALUETABLE}->clear();
	$self->{VALUETABLE}->pluginID($self->{ID});
	$self->{VALUETABLE}->netID($netID);
	$self->{VALUETABLE}->origin($origin);
	$self->{VALUETABLE}->name($name);
	$self->{VALUETABLE}->value($value);
	if (defined $pluginValueEntry) {
		unless ($self->{VALUETABLE}->update({ID => $pluginValueEntry->{ID}})) {
			warn "Cannot update Plugin Value '$name': " . $self->{VALUETABLE}->errorStrs();
		}
	} else {
		$self->{VALUETABLE}->insert();
		if ($self->{VALUETABLE}->error()) {
			warn "Cannot insert Plugin Value '$name': " . $self->{VALUETABLE}->errorStrs();
		}
	}
}

sub getValues {
	my $self		= shift;
	my $origin	= shift;
	my $netID		= shift;
	my $results	= {};

	unless (defined $self->{VALUETABLE}) {
		warn "Cannot get Plugin Value. DB Error (pluginValue)\n";
		return 0;
	}

	my @entries	= ();
	if (defined $netID) {
		@entries = $self->{VALUETABLE}->search(['netID', 'name', 'value'], {pluginID => $self->{ID}, origin => $origin, netID => $netID});
	} else {
		@entries = $self->{VALUETABLE}->search(['netID', 'name', 'value'], {pluginID => $self->{ID}, origin => $origin});
	}

	if (@entries) {
		foreach (@entries) {
			$results->{$_->{netID}}->{$_->{name}}	= $_->{value};
		}
	}

	return $results;
}

sub getValue {
	my $self	= shift;

	return &getPluginValue($self->{ID}, @_);
}

sub warnl {
	my $self		= shift;
	my $msg			= shift;
	my $toUser	= shift;

#	unless ($toUser) {
#		warn $msg;
#		return;
#	}

	warn $msg;

	$self->{ERRORSTR}	.= "\n" if $self->{ERROR};
	$self->{ERROR}		= 1;
	$self->{ERRORSTR}	.= $msg;
}

sub ERROR {
	my $self	= shift;

	return $self->{ERROR};
}

sub ERRORSTR {
	my $self	= shift;

	return $self->{ERRORSTR};
}

1;

# vim:ts=2:sw=2:sts=2
