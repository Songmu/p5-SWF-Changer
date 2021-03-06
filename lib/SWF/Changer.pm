package SWF::Changer;
use strict;
use warnings;
use utf8;
use 5.00800;
our $VERSION = '0.01';

use File::Spec;
use IPC::Run qw/run/;
use XML::LibXML;
use SWF::Changer::Bitmap::PNG;
use SWF::Changer::Bitmap::PNG8;

sub include_path    { shift->{include_path}     || '.'}
sub material_path   { shift->{material_path}    || '.'}
sub default_params  { shift->{default_params}   || {} }

sub new {
    my $cls = shift;
    my $self = ref $_[0] ? $_[0] : {@_};
    $self->{swfmill_option} ||= [];
    bless $self, $cls;
    if ($self->{file}) {
        $self->load_file($self->{file});
    }
    $self;
}

sub dom {
    my $self = shift;
    unless ($self->{_dom}){
        $self->{_dom} = XML::LibXML->new->parse_string($self->content);
        delete $self->{_content};
    }
    $self->{_dom};
}

sub content {
    my ($self, $content) = @_;
    if (defined $content){
        utf8::decode($content) unless utf8::is_utf8($content);
        $self->{_content} = $content;
        delete $self->{_dom};
        $self;
    }
    elsif ($self->{_dom}){
        my $content = $self->dom->toString;
        utf8::decode($content) unless utf8::is_utf8($content);
        $content;
    }
    else {
        $self->{_content} || '';
    }
}

sub load_file {
    my ($self, $file) = @_;
    $file = File::Spec->catfile($self->include_path, $file);
    $self->content(do {
        local $/;
        open my $fh,'<:utf8',$file or die "can't open file: $file $!";
        <$fh>;
    });
    $self;
}

sub load_swf {
    my ($self, $swf_file) = @_;
    $swf_file = File::Spec->catfile($self->include_path, $swf_file);
    my $err;
    run ['swfmill', @{$self->{swfmill_option}}, 'swf2xml', $swf_file], \my $in, \my $xml, \$err or die $err;

    utf8::decode($xml);
    $self->content($xml);
    $self;
}

sub render {
    my ($self, $params) = @_;
    my $render_params = {
        %{ $self->default_params },
        %$params,
    };
    my $xml = $self->_render_xml($render_params);
    utf8::encode($xml);
    my $err;
    run ['swfmill', @{$self->{swfmill_option}}, qw/xml2swf stdin/], \$xml, \my $swf, \$err or die $err;

    $swf;
}

sub replace_png8_by_base64 {
    my ($self, $base64_str, $file) = @_;
    my $png8 = $self->_load_png8($file);

    my @nodes = $self->_find_image_nodes_by_base64($base64_str);
    $self->_replace_image_node($_, $png8) for @nodes;
    $self;
}

sub replace_png8_by_name {
    my ($self, $name, $file) = @_;
    my $png8 = $self->_load_png8($file);

    my @nodes = $self->_find_image_nodes_by_name($name);
    $self->_replace_image_node($_, $png8) for @nodes;

    $self;
}

sub replace_png_by_base64 {
    my ($self, $base64_str, $file) = @_;
    my $png8 = $self->_load_png($file);

    my @nodes = $self->_find_image_nodes_by_base64($base64_str);
    $self->_replace_image_node($_, $png8) for @nodes;

    $self;
}

sub replace_png_by_name {
    my ($self, $name, $file) = @_;
    my $png8 = $self->_load_png($file);

    my @nodes = $self->_find_image_nodes_by_name($name);
    $self->_replace_image_node($_, $png8) for @nodes;

    $self;
}

sub _find_image_nodes_by_base64 {
    my ($self, $base64_str) = @_;
    my @nodes = $self->dom->findnodes("//data[.='$base64_str']");
    my @result_nodes;
    push @result_nodes, $_->parentNode->parentNode for @nodes;
    @result_nodes;
}

sub _find_image_nodes_by_name {
    my ($self, $name) = @_;
    my @result_nodes;
    my @nodes = $self->dom->findnodes("//PlaceObject2[\@name='$name']");
    for my $node ( @nodes ){
        $node = $node->previousNonBlankSibling while $node && $node->nodeName !~ /^DefineBits/;
        push @result_nodes, $node if $node;
    }
    @result_nodes;
}

sub _replace_image_node {
    my ($self, $node, $img) = @_;

    $node->setAttribute(format => $img->format);
    +(+($node->nonBlankChildNodes)[0]->nonBlankChildNodes)[0]->firstChild->setData($img->base64);

    if ($img->can('n_colormap')){
        $node->setAttribute(n_colormap => $img->n_colormap);
    }
    else {
        $node->removeAttribute('n_colormap');
    }

    my $node_name = 'DefineBitsLossless';
    $node_name .= '2' if $img->has_alpha;
    $node->setNodeName($node_name);
}

sub _load_png8 {
    my ($self, $file) = @_;
    $file = File::Spec->catfile($self->material_path, $file);
    SWF::Changer::Bitmap::PNG8->new($file);
}

sub _load_png {
    my ($self, $file) = @_;
    $file = File::Spec->catfile($self->material_path, $file);
    SWF::Changer::Bitmap::PNG->new($file);
}

sub _render_xml {
    my ($self, $params) = @_;
    my $xml = $self->content;

    for my $key (keys %$params) {
        $key = quotemeta $key;
        my $val = $params->{$key};
        $xml =~ s/\[%\s*$key\s*%\]/$val/g;
    }
    $xml;
}

sub replace_colors {
    my ($self, @colors) = @_;

    @colors = @{$colors[0]} if @colors == 1;

    my $content = $self->content;
    while (@colors) {
        my ($from_color, $to_color) = splice @colors, 0, 2;
        my $from_str = quotemeta _parse_rgb($from_color);
        my $to_str   = _parse_rgb($to_color);
        $content =~ s/$from_str/$to_str/g;
    }
    $self->content($content);
    $self;
}

sub _parse_rgb {
    my $str = shift;

    my ($red, $green, $blue) = _get_rgb($str);
    sprintf 'red="%s" green="%s" blue="%s"', $red, $green, $blue;
}


sub _get_rgb {
    my $str = shift;

    $str =~ s/^#//;
    map {hex($_)} $str =~ /^(..)(..)(..)$/;
}


sub process {
    my ($self, $file, $params) = @_;
    $self->load_file($file)->render($params);
}

1;
__END__

=head1 NAME

SWF::Changer -

=head1 SYNOPSIS

  use SWF::Changer;
  my $swf = SWF::Changer->new(
    swfmill_option => [qw/-e cp932/],
    file           => 'swf.xml'
  );
  $swf->replace_png8_by_base64('eNrtwQEBAAAIwyD7l54VHgCoDgAAAAAAAAAAADYPGNQC/g==', '2.png');
  $swf->replace_png8_by_name('CHARACTER', '2.png');
  binmode STDOUT;
  print $swf->render({ hoge => 'fuga'});


=head1 DESCRIPTION

SWF::Changer is

=head1 AUTHOR

Masayuki Matsuki E<lt>y.songmu@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
