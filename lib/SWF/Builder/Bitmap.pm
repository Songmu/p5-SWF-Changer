package SWF::Builder::Bitmap;
use strict;
use warnings;
our $VERSION = '0.01';

use Imager;
use MIME::Base64 qw/encode_base64/;

sub content     { shift->{content}   || '' }
sub code        { shift->{code}      || undef }
sub format      { shift->{format}    || undef }
sub has_alpha   { shift->{has_alpha} || undef }

sub new {
    my ($cls, $image_file) = @_;
    my $self = {};
    $self->{image_file} = $image_file;
    bless $self, $cls;
}

sub base64 {
    encode_base64(shift->content, '');
}


1;
__END__

=head1 NAME

SWF::Builder::Bitmap -

=head1 SYNOPSIS

  use SWF::Builder::Bitmap;

=head1 DESCRIPTION

SWF::Builder::Bitmap is

=head1 AUTHOR

Masayuki Matsuki E<lt>y.songmu@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
