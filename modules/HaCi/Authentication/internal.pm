package HaCi::Authentication::internal;

use strict;
use HaCi::Log qw/warnl debug/;
use HaCi::GUI::gettext qw/_gettext/;
use POSIX qw(strftime);

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(getCryptPassword lwe bin2dec);

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

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		$conf->{var}->{authenticationError} = HaCi::Utils::_gettext("Authentication failed: Database Error!");
		return 0;
	}
	
	my $user			= ($userTable->search(['*'], {username => $self->user()}))[0];

	unless (defined $user) {
		$conf->{var}->{authenticationError} = HaCi::Utils::_gettext("Authentication failed!");
		return 0;
	} else {
		$self->{sess}->param('username', $self->user());
	}
	
	my $password	= $user->{password};

	my $newPass	= &getCryptPassword($self->pass());

	if ($password eq $newPass) {
		$self->{sess}->param('authenticated', 1);
		&HaCi::Utils::debug("Sucessfully logged in!");
	} else {
		$conf->{var}->{authenticationError} = HaCi::Utils::_gettext("Authentication failed!");
	}
	
	return &isAutenticated($self);
}

sub getCryptPassword {
	use Digest::SHA;
	my $clear	= shift;

	my $sha = Digest::SHA->new('256');
	$sha->add($clear);
	return $sha->hexdigest;
}

sub isAutenticated {
	my $self	= shift;

	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot authenticate! DB Error (user)\n";
		return 0;
	}
	
	if (defined $self->{sess}->param('username')) {
		my $user	= ($userTable->search(['ID'], {username => $self->{sess}->param('username')}))[0];
	
		if (!defined $user || !exists $user->{ID}) {
			$conf->{var}->{authenticationError} = HaCi::Utils::_gettext("Authentication failed!");
			$self->{sess}->clear('authenticated');
			$self->{sess}->param('authenticated', 0);
			return 0;
		}
	}

	return (defined $self->{sess}->param('authenticated')) ? $self->{sess}->param('authenticated') : 0;
}

sub init {
	my $self	= shift;

	&checkAdminGroup($self);
	&checkAdminUser($self);
}

sub checkAdminUser {
	my $self			= shift;
	my $session		= $self->session();
	my $userTable	= $conf->{var}->{TABLES}->{user};
	unless (defined $userTable) {
		warn "Cannot init Authentication! DB Error (user)\n";
		return 0;
	}
	
	my @users	= $userTable->search(['ID']);
	if ($#users == -1) {
		&HaCi::Utils::warnl("No Users available! Generating new Admin User with no Password! Please change it right after you logged in!");
		my $pass	= &getCryptPassword('');

		my $groupTable	= $conf->{var}->{TABLES}->{group};
		unless (defined $groupTable) {
			warn "Cannot init Authentication! DB Error (group)\n";
			return 0;
		}
		my $adminGroup	= ($groupTable->search(['ID'], {name	=> 'Administrator'}))[0];
		$userTable->username('admin');
		$userTable->password($pass);
		$userTable->description('The Administrator');
		$userTable->groupIDs(' ' . $adminGroup->{ID} . ',');
		my $DB = ($userTable->search(['ID'], {username => 'admin'}))[0];
		if ($DB) {
			$userTable->ID($DB->{'ID'});
			$userTable->modifyFrom($session->param('username'));
			$userTable->modifyDate(&HaCi::Utils::currDate('datetime'));
			&HaCi::Utils::debug("Change User 'admin'\n");
			return $userTable->replace();
		} else {
			$userTable->ID(undef);
			$userTable->createFrom($session->param('username'));
			$userTable->createDate(&HaCi::Utils::currDate('datetime'));
			return $userTable->insert();
		}
	}
}

sub checkAdminGroup {
	my $self				= shift;
	my $session			= $self->session();
	my $groupTable	= $conf->{var}->{TABLES}->{group};
	unless (defined $groupTable) {
		warn "Cannot init Authentication! DB Error (group)\n";
		return 0;
	}
	
	my @groups	= $groupTable->search(['ID']);
	if ($#groups == -1) {
		warn "No Groups available! Generating new Administator Group with all Rights!\n";

		my $rightsStr	= '1';
		foreach (keys %{$conf->{static}->{rights}}) {
			$rightsStr	.= '1';
		}
		$rightsStr	= &HaCi::Utils::lwe(&HaCi::Utils::bin2dec($rightsStr));
		$groupTable->name('Administrator');
		$groupTable->description('The Administrators');
		$groupTable->permissions('1' . $rightsStr);
		my $DB = ($groupTable->search(['ID'], {name => 'Administrator'}))[0];
		if ($DB) {
			$groupTable->ID($DB->{'ID'});
			$groupTable->modifyFrom($session->param('username'));
			$groupTable->modifyDate(&HaCi::Utils::currDate('datetime'));
			&HaCi::Utils::debug("Change Group 'Administrator'\n");
			return $groupTable->replace();
		} else {
			$groupTable->ID(undef);
			$groupTable->createFrom($session->param('username'));
			$groupTable->createDate(&HaCi::Utils::currDate('datetime'));
			return $groupTable->insert();
		}
	}
	return 1;
}

sub currDate {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $type  = shift;
	my $time  = shift;

	if ($type eq 'datetime') {
		return strftime "%F %T", ((defined $time) ? localtime($time) : localtime);
	}
}

sub lwe	{
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $clear	= shift;
	my $crypt	= '';
	my @nrs		= split//, $clear;
	my $last	= '';
	for (0 .. $#nrs) {
		$last		= $nrs[-1] if $last eq '';
		$last		= ($nrs[$_] + $last) % 10;
		$crypt .= $last;
	}

	return $crypt;
}

sub bin2dec {
	warn 'SUB: ' . (caller(0))[3] . ' (' . (caller(1))[3] . ")\n" if $conf->{var}->{showsubs};
	my $bin	= shift;
	my $dec	= 0;

	my $cnter	= 0;
	foreach (split//, reverse $bin) {
		$dec	+= 2 ** $cnter if $_;
		$cnter++;
	}

	return $dec;
}

1;

# vim:ts=2:sw=2:sws=2
