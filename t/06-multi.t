#!perl -T

use lib 't';
require tests;

plan(tests => 2);

my $origin = 'http://example.com/';

{

    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::CORS;

    my $share1 = cors;
    $share1->rule(
        origin  => '???',
        var => 'cors',
        extras => { rule => 1 },
    );
    $share1->rule(
        origin  => $origin,
        var => 'cors',
        extras => { rule => 2 },
    );

    get '/foo' => sub { vars->{cors}->{rule} || 0 };
    $share1->add('/foo');

    my $share2 = cors;
    $share2->rule(
        origin  => $origin,
        var => 'cors',
        extras => { rule => 1 },
    );
    $share2->rule(
        origin  => $origin,
        var => 'cors',
        extras => { rule => 2 },
    );

    get '/bar' => sub { vars->{cors}->{rule} || 0 };
    $share2->add('/bar');
}

my $PT = boot('Webservice');

dotest(foo => 2, sub {
    my $R = request($PT, GET => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 2);
});

dotest(bar => 2, sub {
    my $R = request($PT, GET => '/bar',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 1);
});

done_testing();
