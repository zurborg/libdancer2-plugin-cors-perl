#!perl -T

use lib 't';
require tests;

plan(tests => 2);

my $origin = 'http://example.com/';

{

    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::CORS;

    my $share = cors;
    $share->rule(
        origin => $origin,
        method => 'GET'
    );

    get '/foo' => sub { 'foo' };
    $share->add('/foo');
}

my $PT = boot('Webservice');

dotest(foo1 => 3, sub {
    my $R = request($PT, GET => '/foo');
    ok($R->is_success);
    isfc($R->content => 'foo');
    isfc(header($R => 'access-control-allow-origin') => undef);
});

dotest(foo2 => 3, sub {
    my $R = request($PT, GET => '/foo', Origin => $origin);
    ok($R->is_success);
    isfc($R->content => 'foo');
    isfc(header($R => 'access-control-allow-origin') => $origin);
});

done_testing();
