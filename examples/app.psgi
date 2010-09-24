use Plack::Builder;

my $app = sub {
    my $env = shift;
    sleep 1;
    return [ 200, [ 'Content-Type' => 'text/html' ],
           [ '<body>Hello World</body>' ] ];
};

builder {
    enable 'Debug', panels => [ qw(Profiler::NYTProf) ];
    $app;
};
