package HaCi::Authentication::imap;

use strict;
use HaCi::Log qw/warnl debug/;
use HaCi::GUI::gettext qw/_gettext/;
use Net::IMAP::Simple;

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(getCryptPassword);

our $conf; *conf  = \$HaCi::Conf::conf;

sub new {
	my $class	= shift;
	my $self	= {};

	bless $self, $class;
	return $self;
}

sub user {
	my $self	= shift;
	my $user	= shift;

	if (defined $user) {
		$self->{user}	= $user;
	} else {
		return $self->{user};
	}
}

sub pass {
	my $self	= shift;
	my $pass	= shift;

	if (defined $pass) {
		$self->{pass}	= $pass;
	} else {
		return $self->{pass};
	}
}

sub session {
	my $self	= shift;
	my $sess	= shift;

	if (defined $sess) {
		$self->{sess}	= $sess;
	} else {
		return $self->{sess};
	}
}

sub authenticate {
	my $self	= shift;

	$self->{sess}->param('authenticated', 0);

	my $host	= $conf->{user}->{auth}->{authparams}->{imap}->{host} || 'localhost';
	my $imap	= undef;
	unless ($imap = Net::IMAP::Simple->new($host)) {
		$conf->{var}->{authenticationError} = "Authentication failed: Cannot connect to IMAP Server: " . $Net::IMAP::Simple::errstr;
		return 0;
	}
	unless ($imap->login($self->user(), $self->pass())) {
		&HaCi::Utils::debug("Authentication Failed: " . $imap->errstr . "\n");
		$conf->{var}->{authenticationError} = _gettext("Authentication failed!");
	} else {
		$self->{sess}->param('authenticated', 1);
		$self->{sess}->param('username', $self->user());
		&HaCi::Utils::debug("Sucessfully logged in!");
	}
	
	return &isAutenticated($self);
}

sub isAutenticated {
	my $self	= shift;

	my $username	= $self->{sess}->param('username') || $self->user();
	
	if ($username) {
		my $userTable	= $conf->{var}->{TABLES}->{user};
		unless (defined $userTable) {
			warn "Cannot authenticate! DB Error (user)\n";
			return 0;
		}
		
		my $user	= ($userTable->search(['ID'], {'%CS%' => 1, username => $username}))[0];
	
		if (!defined $user || !exists $user->{ID}) {
			&debug("Authentication failed: User '$username' not in Database!");
			$conf->{var}->{authenticationError} = _gettext("Authentication failed!");
			$self->{sess}->clear('authenticated');
			$self->{sess}->param('authenticated', 0);
			return 0;
		}
	}

	return (defined $self->{sess}->param('authenticated')) ? $self->{sess}->param('authenticated') : 0;
}

1;
