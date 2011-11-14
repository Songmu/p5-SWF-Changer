package SWF::Changer::Bitmap::PNG;
use strict;
use warnings;

use parent 'SWF::Changer::Bitmap';
use Math::Round qw/round/;
use Compress::Zlib qw/compress/;

sub new {
    my $cls = shift;
    my $self = $cls->SUPER::new(@_);
    $self->{format} = 5;
    $self->build;
}

sub build {
    my $self = shift;
    my $imager = Imager->new;
    $imager->read(file => $self->{image_file});

    my $width = $imager->getwidth;
    my $height = $imager->getheight;

    my @pixel_datas;
    for my $y (0..($height-1)){ for my $x (0..($width-1)){
        my ($red, $green, $blue, $alpha) = $imager->getpixel(x => $x, y => $y)->rgba;
        $self->{has_alpha} = 1 if $alpha < 255;

        push @pixel_datas, {
            alpha   => round($alpha),
            red     => round($red   * $alpha / 255),
            green   => round($green * $alpha / 255),
            blue    => round($blue  * $alpha / 255),
        };
    }}

    my $bitmap = '';
    for my $pixel (@pixel_datas) {
        if ($self->has_alpha) {
            if ($pixel->{alpha} == 0) {
                $bitmap .= chr(0)x4;
            }
            else {
                $bitmap .= chr($pixel->{$_}) for qw/alpha red green blue/;
            }
        }
        else {
            $bitmap .= chr(0);
            $bitmap .= chr($pixel->{$_}) for qw/red green blue/;
        }
    }
    $self->{content} = compress($bitmap);
    $self->{code} = $self->has_alpha ? 36 : 20;
    $self;
}


1;
