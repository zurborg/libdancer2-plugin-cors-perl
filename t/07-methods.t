#!perl -T

use lib 't';
require tests;

plan(tests => 5);

my $origin = 'http://example.com/';

{

    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::CORS;

    my $share = cors;
    $share->rule(
        origin  => $origin,
        method  => 'GET',
        var => 'cors',
        extras => { rule => 1 },
    );
    $share->rule(
        origin  => $origin,
        method  => 'POST',
        var => 'cors',
        extras => { rule => 2 },
    );
    $share->rule(
        origin  => $origin,
        method  => 'PUT',
        var => 'cors',
        extras => { rule => 3 },
    );
    $share->rule(
        origin  => $origin,
        method  => 'PATCH',
        var => 'cors',
        extras => { rule => 4 },
    );
    $share->rule(
        origin  => $origin,
        method  => 'DELETE',
        var => 'cors',
        extras => { rule => 5 },
    );

    any '/foo' => sub { vars->{cors}->{rule} || 0 };
    $share->add('/foo');
}

my $PT = boot('Webservice');

dotest(get => 2, sub {
    my $R = request($PT, GET => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 1);
});

dotest(post => 2, sub {
    my $R = request($PT, POST => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 2);
});

dotest(put => 2, sub {
    my $R = request($PT, PUT => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 3);
});

dotest(patch => 2, sub {
    my $R = request($PT, PATCH => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 4);
});

dotest(delete => 2, sub {
    my $R = request($PT, DELETE => '/foo',
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
    );
    ok($R->is_success);
    isfc($R->content => 5);
});

done_testing();
