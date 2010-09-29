package Plack::Middleware::Debug::Profiler::NYTProf;
use 5.008;
use strict;
use warnings;

use Plack::Util::Accessor qw(root exclude);
use Time::HiRes;

use parent 'Plack::Middleware::Debug::Base';
our $VERSION = '0.01';

sub prepare_app {
    my $self = shift;
    $self->root($self->root || '/tmp');
    $self->{files} = Plack::App::File->new(root => $self->root);

    unless(-d $self->root){
        mkdir $self->root or die "Cannot create directory " . $self->root;
    }

    $ENV{NYTPROF} ||= "addpid=1:start=no:file=".$self->root."/nytprof.out";
    require Devel::NYTProf;

    $self->exclude($self->exclude || [qw(.*.css .*.png .*.ico .*.js)]);
    Carp::croak "exclude not an array" if ref($self->exclude) ne 'ARRAY';
}

sub call {
    my($self, $env) = @_;
    print STDERR "NYTProf:  ", $env->{PATH_INFO}, "\n";
    if ($env->{PATH_INFO} =~ m!nytprofhtml!) {
        print STDERR "NYTProf: MATCH \n";
        $env->{'plack.debug.disabled'} = 1;
        return $self->{files}->call($env);
    }

    print STDERR "NYTProf: enable_profile \n";
    DB::enable_profile();
    return $self->SUPER::call($env);
}

sub run {
    my($self, $env, $panel) = @_;

    foreach my $pattern (@{$self->exclude}) {
        if ($env->{PATH_INFO} =~ m!^$pattern$!) {
            $panel->nav_subtitle('Excluded');
            print STDERR "NYTProf: excluded ", $env->{PATH_INFO}, " \n";
            return;
        }
    }

    return sub {
        my $res = shift;
        print STDERR "NYTProf: finish_profile\n";
        DB::finish_profile();
        $self->report($env);
        $panel->nav_subtitle('OK');

        $panel->content('<iframe src ="/nytprofhtml.'.$$.'/index.html" width="100%" height="100%">
          <p>Your browser does not support iframes.</p>
        </iframe>');
    };
}

sub report {
    my ( $self, $env ) = @_;
    print STDERR "NYTProf: report\n";
    if ( -f $self->root . "/nytprof.out.$$" ) {
        print STDERR "NYTProf: nytprofhtml\n";
        system "nytprofhtml", "-f", $self->root . "/nytprof.out.$$", "-o", $self->root . "/nytprofhtml.$$";
    }
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

List of excluded paths (default: ['/css.*', '/favicon.ico']).

=head1 SEE ALSO

L<Plack::Middleware::Debug>
L<Devel::NYTProf>

=head1 AUTHOR

Sebastian de Castelberg, C<< <sebu@kpricorn.org> >>

=head1 COPYRIGHT & LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
