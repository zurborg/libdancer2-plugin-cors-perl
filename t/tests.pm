use strictures 1;
use Test::Most qw(!pass);
use Plack::Test;
use HTTP::Request::Common ();
use feature qw(fc);

sub isfc   { @_ = map { defined($_) ? fc($_) : undef } @_; goto &is;   }
sub isntfc { @_ = map { defined($_) ? fc($_) : undef } @_; goto &isnt; }

sub header {
	my ($R, $V) = @_;
    return $R->header(fc($V)) || undef;
}

sub boot {
	my $class = shift;
	return Plack::Test->create( $class->to_app );
}

sub dotest {
	my ($name, $plan, $code) = @_;
	return subtest $name => sub {
		plan tests => $plan;
		$code->();
	};
}

sub request {
	my $PT = shift;
	return $PT->request(HTTP::Request::Common::_simple_req(@_));
}

sub OPTIONS {
	return HTTP::Request::Common::_simple_req(OPTIONS => @_);
}

1;
