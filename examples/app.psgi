use Plack::Builder;

my $app = sub {
    my $env = shift;
    sleep 1;
    return [ 200, [ 'Content-Type' => 'text/html' ],
           [ '<body>Hello World</body><br/><a href="/">Include</a><br/><a href="/exclude">Exclude</a>' ] ];
};

builder {
    enable 'Debug', panels => [ [ 'Profiler::NYTProf', exclude => ['/exclude']] ];
    $app;
};
