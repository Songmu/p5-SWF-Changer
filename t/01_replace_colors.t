use strict;
use warnings;
use utf8;
use Test::More;

use SWF::Changer;

my $swf = SWF::Changer->new;
$swf->content('<color red="11" green="11" blue="11" />');
$swf->replace_colors('#0B0B0B' => '#ffffff');

is($swf->content, '<color red="255" green="255" blue="255" />');

done_testing;
