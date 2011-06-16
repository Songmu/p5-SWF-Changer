package SWF::Builder;
use strict;
use warnings;
our $VERSION = '0.01';

use IPC::Run qw/run/;
use XML::LibXML;
use SWF::Builder::Bitmap::PNG;
use SWF::Builder::Bitmap::PNG8;

sub new {
    my $cls = shift;
    my $self = ref $_[0] ? $_[0] : {@_};
    bless $self, $cls;
    if ($self->{file}) {
        $self->load_file($self->{file});
    }
    $self;
}

sub load_file {
    my ($self, $file) = @_;
    $file = $self->include_path . $file;
    $self->{content} = do {
        local $/;
        open my $fh,'<',$file or die "can't open file: $file $!";
        <$fh>;
    };
    $self;
}

sub render {
    my ($self, $params) = @_;

    my $xml = $self->render_xml($params);
    my $err;
    run ['swfmill', @{$self->{_swfmill_option}}, qw/xml2swf stdin/], \$xml, \my $swf, \$err or die $err;

    $swf;
}

sub replace_png8_by_base64 {
    my ($self, $base64_str, $file) = @_;
    my $png8 = $self->load_png8($file);

    my $dom = XML::LibXML->new->parse_string($self->content);
    my @nodes = $dom->findnodes("//data[.='$base64_str']");
    for my $node ( @nodes ){
        $node = $node->parentNode->parentNode;
        $self->replace_image_node($node, $png8);
    }

    $self->{content} = $dom->toString;
}

sub replace_image_node {
    my ($self, $node, $img) = @_;

    $node->setAttribute(format => $img->format);

    [[$node->nonBlankChildNodes]->[0]->nonBlankChildNodes]->[0]->firstChild->setData($img->base64);

    if ($img->can('n_colormap')){
        $img->setAttribute(n_colormap => $img->n_colormap);
    }
    else {
        $node->removeAttribute('n_colormap');
    }

    my $node_name = 'DefineBitsLossless';
    $node_name .= '2' if $img->has_alpha;
    $node->setNodeName($node_name);
}

sub load_png8 {
    my ($self, $file) = @_;
    $file = $self->material_path . $file;
    SWF::Builder::Builder::PNG8->new($file);
}

sub render_xml {
    my ($self, $params) = @_;
    my $xml = $self->content;

    for my $key (keys %$params) {
        $key = quotemeta $key;
        my $val = $params->{$key};
        $xml =~ s/\[%\s*$key\s*%\]/$val/g;
    }
    $xml;
}

sub include_path {
    shift->{include_path} || '';
}

sub content {
    shift->{content};
}

sub material_path {
    shift->{material_path} || '';
}

1;
__END__

=head1 NAME

SWF::Builder -

=head1 SYNOPSIS

  use SWF::Builder;

=head1 DESCRIPTION

SWF::Builder is

=head1 AUTHOR

Masayuki Matsuki E<lt>y.songmu@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
