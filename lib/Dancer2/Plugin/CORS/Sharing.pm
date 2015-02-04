use strictures 1;

package Dancer2::Plugin::CORS::Sharing;

# ABSTRACT: A plugin for using cross origin resource sharing

use Moo;
use Method::Signatures;
use Types::Standard qw(InstanceOf ArrayRef HashRef);
use Carp qw(croak confess);
use feature qw(fc);
use Scalar::Util qw(blessed);
use URI;

# VERSION

use constant DEBUG => 0;

sub _isuri {
    shift =~
      m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
}

=for Pod::Coverage dsl

=cut

has dsl => (
    is       => 'ro',
    isa      => InstanceOf['Dancer2::Core::DSL'],
	required => 1,
);

=for Pod::Coverage rules

=cut

has rules => (
    is       => 'ro',
    isa      => ArrayRef,
    default  => sub { [] },
);

=for Pod::Coverage store

=cut

has store => (
    is       => 'ro',
    isa      => HashRef,
	required => 1,
);

=method rule

=cut

method rule (
	Str|RegexpRef|CodeRef|ArrayRef[Str] :$origin = '*',
	Bool :$credentials = 0,
	Str|ArrayRef[Str] :$expose = [],
	Str :$method,
	ArrayRef[Str] :$methods = [],
	ArrayRef[Str] :$headers = [],
	Int :$maxage = 0,
	Bool :$timing = 0,
	HashRef :$extras = {},
	Str|Undef :$var = undef,
) {
	
	if ($credentials and $origin eq '*') {
		croak "For a shared resource that required credentials an origin must be specified";
	}

	push @{$self->rules} => {
		%$extras,
		origin => $origin,
		credentials => !!$credentials,
		expose => (ref($expose) ? $expose : [$expose]),
		methods => (defined $method ? [$method] : $methods),
		headers => $headers,
		maxage => $maxage,
		timing => $timing,
		var => $var,
	};

	return $self;
}

=method add

=cut

method add (
	Str|RegexpRef|Dancer2::Core::Route|ArrayRef[Str]|ArrayRef[RegexpRef]|ArrayRef[Dancer2::Core::Route] $path!
) {
	return map { $self->add($_) } @$path if ref $path eq 'ARRAY';
	my $dsl = $self->dsl;
	my $app = $dsl->app;
	my $store = $self->store;
	$store->{$app} //= [];
	$path = $path->regexp if blessed($path) and $path->isa('Dancer2::Core::Route');
	$path = qr{^\Q$path\E$} unless ref $path eq 'Regexp';
	push @{$store->{$app}} => {
		share => $self,
		path => $path,
		rules => $self->rules,
	};
	$dsl->options($path => sub { '' });
	return $self;
}

=method get

=cut

method get (Str|RegexpRef $path!, CodeRef $code) {
	$self->dsl->get($path, $code);
	$self->add($path);
}

=method post

=cut

method post (Str|RegexpRef $path!, CodeRef $code) {
	$self->dsl->post($path, $code);
	$self->add($path);
}

=method put

=cut

method put (Str|RegexpRef $path!, CodeRef $code) {
	$self->dsl->put($path, $code);
	$self->add($path);
}

=method del

=cut

method del (Str|RegexpRef $path!, CodeRef $code) {
	$self->dsl->del($path, $code);
	$self->add($path);
}

=method patch

=cut

method patch (Str|RegexpRef $path!, CodeRef $code) {
	$self->dsl->patch($path, $code);
	$self->add($path);
}

=method match

=cut

method match(Dancer2::Core::App $app!) {
	return unless defined wantarray;
	my $request = $app->request;
	
	$self->dsl->debug("matching for request $request") if DEBUG;
	
	my $origin = scalar $request->header(fc 'origin') || return;
	return unless _isuri $origin;
	
	$self->dsl->debug("\torigin: $origin") if DEBUG;

	my @rules = map {( @{$_->{rules}} )} grep { $request->path =~ $_->{path} } @{$self->store->{$app}};
	return unless @rules;
	
	$self->dsl->debug("\trules: @rules") if DEBUG;

	my $requested_method = $request->method;
	if (fc $requested_method eq fc 'options') {
		$requested_method = scalar $request->header(fc 'access-control-request-method') || return;
	}
	
	$self->dsl->debug("\trequested method: $requested_method") if DEBUG;

	my @requested_headers = map { s{\s+}{}lg; } split /,+/, ( scalar( $request->header(fc 'access-control-request-headers') ) || '' ); ## no critic
	$self->dsl->debug("\trequested headers: @requested_headers") if DEBUG;

	RULE: foreach my $rule (@rules) {
		$self->dsl->debug("\ttesting rule $rule:") if DEBUG;
		if (ref $rule->{origin} eq 'CODE') {
			next RULE unless $rule->{origin}->( URI->new($origin) );
		} elsif (ref $rule->{origin} eq 'ARRAY') {
			next RULE unless grep { fc($_) eq fc($origin) } @{$rule->{origin}};
		} elsif (ref $rule->{origin} eq 'Regexp') {
			next RULE unless $origin =~ $rule->{origin};
		} elsif ($rule->{origin} ne '*') {
			next RULE unless fc($origin) eq fc($rule->{origin});
		}

		$self->dsl->debug("\t\torigin ok") if DEBUG;
		
		if (@{$rule->{methods}}) {
			next RULE unless grep { fc($requested_method) eq fc($_) } @{$rule->{methods}};
		}

		$self->dsl->debug("\t\tmethod ok") if DEBUG;

		if (@requested_headers and @{$rule->{headers}}) {
			foreach my $header (@requested_headers) {
				next RULE unless grep { fc($header) eq fc($_) } @{$rule->{headers}};
			}
		}

		$self->dsl->debug("\t\theaders ok") if DEBUG;

		return $rule;
	}
	$self->dsl->debug("\t\tno rule matched") if DEBUG;
	return;
}

=method apply

=cut

method apply(Dancer2::Core::App $app!, HashRef $rule!) {
	my $request = $app->request;
	my $response = $app->response;
	
	my $origin = scalar $request->header(fc 'origin');
	
	return unless _isuri $origin;
	
	my $requested_method = $request->method;
	my $preflight = 0;
	if (fc $requested_method eq fc 'options') {
		$requested_method = scalar $request->header(fc 'access-control-request-method') || return;
		$preflight = 1;
	}
	
	my @requested_headers = map { s{\s+}{}lg; } split /,+/, ( scalar( $request->header(fc 'access-control-request-headers') ) || '' ); ## no critic
	
	my %headers;

	$headers{'access-control-allow-origin'} = $origin;
	if ($origin ne '*') {
		$headers{'vary'} = 'Origin';
	}
    if ($rule->{timing}) {
        $headers{'timing-allow-origin'} = $headers{'access-control-allow-origin'};
	}
	if ($rule->{credentials}) {
		$headers{'access-control-allow-credentials'} = 'true';
	}
	if (@{$rule->{expose}}) {
        $headers{'access-Control-expose-headers'} = join ',' => @{$rule->{expose}};
    }
	if (@{$rule->{methods}}) {
		$headers{'access-control-allow-methods'} = join ', ' => map uc, @{$rule->{methods}};
	}
	if (@{$rule->{headers}}) {
		$headers{'access-control-allow-headers'} = join ', ' => @{$rule->{headers}};
	} elsif (@requested_headers) {
		$headers{'access-control-allow-headers'} = join ', ' => @requested_headers;
	}
    
	if ( $preflight and $rule->{maxage} ) {
        $headers{'access-control-max-age'} = $rule->{maxage};
    }
	
	
	foreach (keys %headers) {
		$self->dsl->debug("set header $_") if DEBUG;
		$response->header(fc($_) => $headers{$_}) ;
	}
	
	return !0;
}

1;
