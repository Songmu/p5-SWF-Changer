package SWF::Builder::Bitmap::PNG8;
use strict;
use warnings;

use parent 'SWF::Builder::Bitmap';
use Compress::Zlib qw/compress/;

sub new {
    my $cls = shift;
    my $self = $cls->SUPER::new(@_);
    $self->{format} = 3;
    $self->build;
}

sub build {
    my $self = shift;
    my $imager = Imager->new;
    $imager->read(file => $self->{image_file});

    my $width = $imager->getwidth;
    # FIXME use padding for width not a multiple of 4
    die 'witdh must be a multiple of 4' if $width % 4;
    my $height = $imager->getheight;

    my @color_pallet;
    my %color_pallet_map;

    my $pixel_data = '';
    for my $y (0..($height-1)){ for my $x (0..($width-1)){
        my @rgba = $imager->getpixel(x => $x, y => $y)->rgba;
        my $key = join ',', @rgba;
        my ($red, $green, $blue, $alpha) = @rgba;

        unless (defined $color_pallet_map{$key}){
            if ($alpha == 0) {
                $self->{has_alpha} = 1;
                $red   = 0;
                $green = 0;
                $blue  = 0;
            }
            else {
                $alpha = 255;
            }
            push @color_pallet, {
                alpha   => $alpha,
                red     => $red,
                green   => $green,
                blue    => $blue,
            };
            $color_pallet_map{$key} = $#color_pallet;
        }
        $pixel_data .= chr($color_pallet_map{$key});
    }}
    push @color_pallet, {
        alpha   => 255,
        red     => 0,
        green   => 0,
        blue    => 0,
    } until sub {
         my $int = shift;
        ($int & ($int-1)) == 0
    }->(scalar @color_pallet);

    my $pallet_data = '';
    for my $pixel (@color_pallet) {
        if ($self->has_alpha) {
            $pallet_data .= chr($pixel->{$_}) for qw/red green blue alpha/;
        }
        else {
            $pallet_data .= chr($pixel->{$_}) for qw/red green blue/;
        }
    }
    $self->{content} = compress($pallet_data . $pixel_data);

    $self->{n_colormap} = $#color_pallet;
    $self->{code} = $self->has_alpha ? 36 : 20;
    $self;
}

sub n_colormap {
    shift->{n_colormap} || undef;
}

1;
