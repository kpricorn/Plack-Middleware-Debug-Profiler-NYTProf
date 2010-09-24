package Plack::Middleware::Debug::Profiler::NYTProf;
use 5.008;
use strict;
use warnings;

use Plack::Util::Accessor qw(files root exclude);
use Time::HiRes;
use Devel::NYTProf;

use parent 'Plack::Middleware::Debug::Base';
our $VERSION = '0.01';

sub prepare_app {
    my $self = shift;
    $self->root($self->root || '/tmp');
    $self->files(Plack::App::File->new(root => $self->root));

    $self->exclude($self->exclude || [qw(/api.* /css.* /)]);
    Carp::croak "exclude not an array" if ref($self->exclude) ne 'ARRAY';
}

sub call {
    my($self, $env) = @_;

    if ($env->{PATH_INFO} =~ m!nytprofhtml!) {
        $env->{'plack.debug.disabled'} = 1;
        return $self->files->call($env);
    }
    return $self->SUPER::call($env);
}

sub run {
    my($self, $env, $panel) = @_;

    foreach my $pattern (@{$self->exclude}) {
        return if $env->{PATH_INFO} =~ m!^$pattern$!;
    }
    $self->start($env);
    return sub {
        my $res = shift;
        $self->end($env);
        $self->report($env);

        $panel->content('<iframe src ="/nytprofhtml/index.html" width="100%" height="100%">
          <p>Your browser does not support iframes.</p>
        </iframe>');
    };
}

sub start {
    my ( $self, $env ) = @_;
    my $id = Time::HiRes::gettimeofday;
    $env->{PROFILE_ID} = $id;
    DB::enable_profile($self->root . "/nytprof.$id.out");
}

sub end {
    DB::disable_profile();
}

sub report {
    my ( $self, $env ) = @_;
    if ( my $id = $env->{PROFILE_ID} ) {
        DB::enable_profile($self->root . "/nyprof.null.out");
        DB::disable_profile();
        system "nytprofhtml", "-f", $self->root . "/nytprof.$id.out", "-o", $self->root . "/nytprofhtml";
    }
}

sub DESTROY {
    DB::finish_profile();
}


1;
