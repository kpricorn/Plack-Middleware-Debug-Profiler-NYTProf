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

    $self->exclude($self->exclude || [qw(/css.*)]);
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
__END__

=head1 NAME

Plack::Middleware::Debug::Profiler::NYTProf - Runs NYTProf on your app

=head2 SYNOPSIS

    use Plack::Builder;

    my $app = ...; ## Build your Plack App

    builder {
        enable 'Debug', panels =>['Profiler::NYTProf'];
        $app;
    };

=head1 DESCRIPTION

Adds a debug panel that runs and displays Devel::NYTProf on your perl source 
code.

=head1 OPTIONS

This debug panel defines the following options.

=head2 root

Where to store nytprof.out and nytprofhtml output (default: '/tmp').

=head2 exclude

List of excluded paths (default: ['/css.*']).

=head1 SEE ALSO

L<Plack::Middleware::Debug>
L<Devel::NYTProf>

=head1 AUTHOR

Sebastian de Castelberg, C<< <sebu@kpricorn.org> >>

=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
