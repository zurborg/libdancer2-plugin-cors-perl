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
        method  => 'GET',
        credentials => 1,
    );

    get '/foo' => sub { 'foo' };
    $share->add('/foo');
}

my $PT = boot('Webservice');

dotest(foo => 4, sub {
    my $R = request($PT, OPTIONS => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => $origin);
    isfc(header($R => 'access-control-allow-methods') => 'GET');
    isfc(header($R => 'access-control-allow-credentials') => 'true');
});

done_testing();
