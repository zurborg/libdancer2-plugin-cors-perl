use strictures 1;

package Dancer2::Plugin::CORS;

# ABSTRACT: A plugin for using cross origin resource sharing

=head1 DESCRIPTION

Cross origin resource sharing is a feature used by modern web browser to bypass cross site scripting restrictions. A webservice can provide those rules from which origin a client is allowed to make cross-site requests. This module helps you to setup such rules.

=head1 SYNOPSIS

    use Dancer2::Plugin::CORS;

	my $share = cors;
	$share->rule(
		origin => 'http://localhost/',
		credentials => 1,
		expose => [qw[ Content-Type ]],
		method => 'GET',
		headers => [qw[ X-Requested-With ]],
		maxage => 7200,
		timing => 1,
	);

    get '/foo' => sub { ... };
	$share->add('/foo');
	
=cut

use Dancer2::Plugin;
use Carp qw(croak confess);
use Sub::Name;
use Scalar::Util qw(blessed);
use URI;

use Dancer2::Plugin::CORS::Sharing;

use constant DEBUG => 0;

# VERSION

my $store = {};
my $shares = [];

register cors => sub {
	my $dsl = shift;
	my $share = Dancer2::Plugin::CORS::Sharing->new(dsl => $dsl, store => $store);
	push @$shares => $share;
	return $share;
}, { is_global => 1 };

on_plugin_import {
    my $dsl = shift;
    $dsl->app->add_hook(
        Dancer2::Core::Hook->new(
            name => 'before',
            code => sub {
				my $app = $dsl->app;
				return unless exists $store->{$app};
				foreach my $share (@$shares) {
					my $rule = $share->match($app) || next;
					$dsl->debug("matched rule: $rule") if DEBUG;
					$share->apply($app, $rule) || last;
					$dsl->var($rule->{var} => $rule) if defined $rule->{var};
					return;
				}
				$dsl->debug("no rule applied") if DEBUG;
			},
        )
    );
};

register_plugin;

1;
