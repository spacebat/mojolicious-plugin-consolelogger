use Test::More tests => 27;
use Test::Mojo;

# Make sure sockets are working
plan skip_all => 'working sockets required for this test!'
  unless Mojo::IOLoop->new->generate_port;    # Test server

use Mojolicious::Lite;

plugin 'console_logger';

get '/:template' => sub {
    my $self = shift;
    app->log->info('info');
    app->log->debug('debug');
    app->log->error('error');
    app->log->fatal({json => 'structure'});

    $self->render($self->stash->{template})
      if $self->stash->{template};

    # Template not found, generates exception
    $self->rendered;
};

# Tests
my $t = Test::Mojo->new;

# Script tag in dynamic content
$t->get_ok($_)->status_is(200)->element_exists('script')
  ->content_like(
    qr/console\.group\("info"\);\s*console\.log\("info"\);\s*console\.groupEnd\("info"\);/
  )
  ->content_like(
    qr/console\.group\("debug"\);.*?console\.log\("debug"\);.*?console\.groupEnd\("debug"\);/s
  )
  ->content_like(
    qr/console\.group\("error"\);\s*console\.log\("error"\);\s*console\.groupEnd\("error"\);/
  )
  ->content_like(
    qr/console\.group\("fatal"\);\s*console\.log\({"json":"structure"}\);\s*console\.groupEnd\("fatal"\);/
  )

  for qw| /normal /exception |;

# Log content not accumulated over requests
$t->get_ok($_)->status_is(200)->element_exists('script')
  ->content_like(
    qr/console\.group\("info"\);\s*console\.log\("info"\);\s*console\.groupEnd\("info"\);/
  )
  ->content_unlike(
    qr/console\.group\("info"\);\s*console\.log\("info"\);\s*console\.log\("info"\);\s*console\.groupEnd\("info"\);/
  )
  for qw| /normal /exception |;

# No script tag in static content
$t->get_ok('/js/prettify.js')->status_is(200)->element_exists(':not(script)');

__DATA__

@@ normal.html.ep
<html>
<body>
</body>
</html>
