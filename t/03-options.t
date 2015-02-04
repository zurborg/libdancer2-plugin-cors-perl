#!perl -T

use lib 't';
require tests;

plan(tests => 1);

my $origin = 'http://example.com/';

{

    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::CORS;

    my $share = cors;
    $share->rule(
        origin  => $origin,
        methods => [qw[ GET POST ]],
        expose  => 'X-Baf',
        headers => [qw[ X-Foo X-Bar ]],
        maxage  => 1111,
    );

    get '/foo' => sub { 'foo' };
    $share->add('/foo');
}

my $PT = boot('Webservice');

dotest(foo => 6, sub {
    my $R = request($PT, GET => '/foo', Origin => $origin);
    ok($R->is_success);
    isfc($R->content => 'foo');
    isfc(header($R => 'access-control-allow-origin') => $origin);
    isfc(header($R => 'access-Control-expose-headers') => 'X-Baf');
    isfc(header($R => 'access-control-allow-methods') => 'GET, POST');
    isfc(header($R => 'access-control-allow-headers') => 'X-Foo, X-Bar');
});

done_testing();
