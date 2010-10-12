package Plack::Middleware::Debug::Profiler::NYTProf;
use 5.008;
use strict;
use warnings;

use Plack::Util::Accessor qw(root exclude);
use Time::HiRes;

use parent 'Plack::Middleware::Debug::Base';
our $VERSION = '0.05';

sub prepare_app {
    my $self = shift;
    $self->root($self->root || '/tmp');
    $self->{files} = Plack::App::File->new(root => $self->root);

    unless(-d $self->root){
        mkdir $self->root or die "Cannot create directory " . $self->root;
    }

    # start=begin - start immediately (the default)
    # start=init  - start at beginning of INIT phase (after compilation)
    # start=end   - start at beginning of END phase
    # start=no    - don't automatically start
    $ENV{NYTPROF} ||= "start=begin:file=".$self->root."/nyprof.null.out";
    require Devel::NYTProf::Core;
    require Devel::NYTProf;

    $self->exclude($self->exclude || [qw(.*\.css .*\.png .*\.ico .*\.js)]);
    Carp::croak "exclude not an array" if ref($self->exclude) ne 'ARRAY';
}

sub call {
    my($self, $env) = @_;
    my $panel = $self->default_panel;

    if ($env->{PATH_INFO} =~ m!nytprofhtml!) {
        $env->{'plack.debug.disabled'} = 1;
        return $self->{files}->call($env);
    }

    foreach my $pattern (@{$self->exclude}) {
        if ($env->{PATH_INFO} =~ m!^$pattern$!) {
            return $self->SUPER::call($env);
        }
    }

    DB::enable_profile($self->root."/nytprof.out.$$");
    my $res = $self->SUPER::call($env);
    DB::disable_profile();
    DB::enable_profile($self->root."/nyprof.null.out");
    DB::disable_profile();

    $self->report($env);
    return $res;
}

sub run {
    my($self, $env, $panel) = @_;
    return sub {        
        my $res = shift;
        $panel->nav_subtitle('OK');
        $panel->content('<iframe src ="/nytprofhtml.'.$$.'/index.html" width="100%" height="100%">
          <p>Your browser does not support iframes.</p>
        </iframe>');
    };
}

sub report {
    my ( $self, $env ) = @_;
    if ( -f $self->root . "/nytprof.out.$$" ) {
        system "nytprofhtml", "-f", $self->root . "/nytprof.out.$$", "-o", $self->root . "/nytprofhtml.$$";
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

List of excluded paths (default: [qw(.*\.css .*\.png .*\.ico .*\.js)]).

=head1 SEE ALSO

L<Plack::Middleware::Debug>
L<Devel::NYTProf>

=head1 AUTHOR

Sebastian de Castelberg, C<< <sdecaste@cpan.org> >>

=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
