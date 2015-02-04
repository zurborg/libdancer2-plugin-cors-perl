#!perl -T

use lib 't';
require tests;

plan(tests => 6);

my $origin = 'http://example.com/';

{

    package Webservice;
    use Dancer2;
    use Dancer2::Plugin::CORS;

    my $sub = sub { 1 };
    
    get '/sub_uri' => $sub;
    cors->rule(origin => sub { shift eq $origin })->add('/sub_uri');

    get '/sub_0' => $sub;
    cors->rule(origin => sub { 0 })->add('/sub_0');

    get '/sub_undef' => $sub;
    cors->rule(origin => sub { undef })->add('/sub_undef');

    get '/sub_1' => $sub;
    cors->rule(origin => sub { 1 })->add('/sub_1');

    get '/array' => $sub;
    cors->rule(origin => [$origin])->add('/array');

    get '/regexp' => $sub;
    cors->rule(origin => qr{^\Q$origin\E$})->add('/regexp');
}

my $PT = boot('Webservice');

sub mkreq {
    my ($name, %extras) = @_;
    return request($PT, GET => "/$name",
        'Access-Control-Request-Method' => 'GET',
        'Origin'                        => $origin,
        %extras
    );
}

dotest(sub_uri => 2, sub {
    my $R = mkreq('sub_uri');
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => $origin);
});

dotest(sub_0 => 2, sub {
    my $R = mkreq('sub_0');
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => undef);
});

dotest(sub_undef => 2, sub {
    my $R = mkreq('sub_undef');
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => undef);
});

dotest(sub_1 => 2, sub {
    my $R = mkreq('sub_1');
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => $origin);
});

dotest(array => 2, sub {
    my $R = mkreq('array');
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => $origin);
});

dotest(regexp => 2, sub {
    my $R = mkreq('regexp');
    ok($R->is_success);
    isfc(header($R => 'access-control-allow-origin') => $origin);
});

done_testing();
