package Mojolicious::Plugin::ConsoleLogger;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream;
use Mojo::JSON;

our $VERSION = 0.03;

our @SEVERITIES = qw(fatal info debug error);

has logs => sub {
    return { map { $_ => [] } @SEVERITIES };
};

sub register {
    my ($plugin, $app, $conf) = @_;

    # override Mojo::Log->log
    no strict 'refs';
    my $stash = \%{"Mojo::Log::"};
    my $orig  = delete $stash->{"log"};

    *{"Mojo::Log::log"} = sub {
        push @{$plugin->logs->{$_[1]}} => $_[-1];

        # Original Mojo::Log->log
        $orig->(@_);
    };

    $app->helper(clear_console_log => sub {
        my ($app) = @_;
        my $logs = $plugin->logs;
        $logs->{$_} = [] for @SEVERITIES;
        return $app;
    });

    $app->hook(
        after_dispatch => sub {
            my $self = shift;
            my $logs = $plugin->logs;

            # leave static content untouched
            return if $self->stash('mojo.static');

            my $str = "\n<!-- Mojolicious logging -->\n<script>";

            for (sort keys %$logs) {
                next if !@{$logs->{$_}};
                $str .= "console.group(\"$_\"); ";
                $str .= _format_msg($_) for @{$logs->{$_}};
                $str .= "console.groupEnd(\"$_\"); ";
            }

            $str .= "</script>\n";

            $self->res->body($self->res->body . $str);
        }
    );

    unless ($conf && $conf->{preserve_log}) {
        $app->hook(before_dispatch => sub {
            shift->app->clear_console_log;
        });
    }
}

sub _format_msg {
    my $msg = shift;

    return "console.log(" . Mojo::JSON->new->encode($_) . "); " if ref $msg;

    return "console.log(" . Mojo::ByteStream->new($_)->quote . "); ";
}

1;

=head1 NAME

Mojolicious::Plugin::ConsoleLogger - Console logging in your browser

=head1 DESCRIPTION

L<Mojolicious::Plugin::ConsoleLogger> pushes Mojolicious log messages to your browser's console tool.

=head1 USAGE

    use Mojolicious::Lite;

    plugin 'console_logger';

    get '/' => sub {

        app->log->debug("Here I am!");
        app->log->error("This is bad");
        app->log->fatal("This is really bad");
        app->log->info("This isn't bad at all");

        shift->render(text => 'Ahm in ur browzers, logginz ur console');
    };

    app->start;

=head1 METHODS

L<Mojolicious::Plugin::ConsoleLogger> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 C<register>

    $plugin->register;

Register condition in L<Mojolicious> application.

=head1 HELPERS

=head2 C<clear_console_log>

    app->clear_console_log;

Clear the console log entries accumulated in the L<Mojolicious> application.
A C<before_dispatch> hook is automatically installed to call this before each
request unless a true value to the option C<preserve_log> at plugin load time.

=head1 SEE ALSO

L<Mojolicious>

=head1 DEVELOPMENT

L<http://github.com/tempire/mojolicious-plugin-consolelogger>

=head1 VERSION

0.03

=head1 CREDITS

Implementation stolen from L<Plack::Middleware::ConsoleLogger>

=head1 AUTHOR

Glen Hinkle tempire@cpan.org

=cut
