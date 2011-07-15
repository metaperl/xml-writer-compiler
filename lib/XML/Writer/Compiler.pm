package XML::Writer::Compiler;

# ABSTRACT: produce aoa from tree

use strict;
use warnings;
use feature "switch";

use autodie;

use Moose;

use Carp;

sub buildclass {
    my ( $self, $pkg, $tree, $firstdepth, $prepend_lib, $fileheader ) = @_;

    my $rootnode = $tree->look_down( '_tag' => qr/./ );

    my $lol = __PACKAGE__->mklol( $tree, $firstdepth );

    my $pkgstr = __PACKAGE__->_mkpkg(
        $pkg => $lol,
        $prepend_lib, $fileheader, $rootnode->{_tag}
    );

    warn "PKG:$pkg";

    my @part = split '::', $pkg;
    my $file = $part[$#part];
    warn "PART:@part";

    use File::Spec;
    my $path = File::Spec->catdir( $prepend_lib ? $prepend_lib : (),
        @part[ 0 .. $#part - 1 ] );
    warn "PATH:$path";
    use File::Path;
    File::Path::make_path( $path, { verbose => 1 } );

    $file = File::Spec->catfile( $path, "$file.pm" );
    warn "FILE:$file";
    open( my $fh, '>', $file );

    $fh->print($pkgstr);
    $pkgstr;

}

sub mklol {
    my ( $class, $tree, $firstdepth ) = @_;
    unless ($firstdepth) {
        Carp::cluck('Assuming firstdepth == 0');
        $firstdepth = 0;
    }
    open( my $fh, '>', \my $string ) or die "Could not open string for writing";
    $tree->methodsfrom( $fh, 0, '', $firstdepth );

    use Perl::Tidy;

    perltidy( source => \$string, destination => \my $dest );
    $dest;

}

sub _mkpkg {
    my ( $self, $pkg, $lol, $prepend_lib, $extends_string, $rootnode ) = @_;

    open( my $fh, '>', \my $pkgstr ) or die "Could not open pkg for writing";

    my $extends = $extends_string ? "extends qw($extends_string)" : '';
    $extends =~ s/^\s+//g;
    $fh->printf( <<'EOPKG', $pkg, $extends, $lol, $rootnode );
package %s;
use Moose;

with qw(XML::Writer::Compiler::AutoPackage);


%s;

use Data::Dumper;
use HTML::Element::Library;




use XML::Element;

has 'data' => (
  is => 'rw', 
  trigger => \&maybe_morph
);
has 'writer' => (is => 'rw', isa => 'XML::Writer');
has 'string' => (is => 'rw', isa => 'XML::Writer::String');


%s;

sub xml {
my($self)=@_;
  my $method = '_tag_%s';
  $self->$method;
$self->writer->end;
$self;
}


1;

EOPKG

    use Perl::Tidy;

    perltidy( source => \$pkgstr, destination => \my $dest );
    $dest;

}

1;

package XML::Element;

sub cleantag {
    my ( $self, $andattr ) = @_;
    my $tag = $self->{_tag};

    return $tag unless $andattr;

    my %attr = $self->all_external_attr;
    my $attr;
    if ( scalar keys %attr ) {
        use Data::Dumper;
        my $d = Data::Dumper->new( [ \%attr ] );
        $d->Purity(1)->Terse(1);
        $attr = $d->Dump;

        $tag .= " => $attr";

    }

    $tag;
}

sub tagmethod {
    my ( $self, $tag, $divecall, $children, $derefchain ) = @_;

    my $methodname = do {
        if ( scalar(@$derefchain) <= 1 ) {
	  "_tag_$tag";
	} else {
	  sprintf '_tag_%s', join '_', @$derefchain;
	}
    };
    warn "METHODNAME: $methodname";
    my @children = map {
        ref($_)
          ? sprintf '$self->%s_%s; %s', $methodname, $_->{_tag}, "\n"
          : ()
    } @$children;
    my $childstr = @children ? "@children" : '$self->writer->characters($data)';

    sprintf( <<'EOSTR', $methodname, $divecall, $tag, $childstr );
  sub %s {
  my($self)=@_;

  my $root = $self->data;
%s;
  my ($attr, $data) = $self->EXTRACT($elementdata);
  $self->writer->startTag(%s => @$attr);

%s;
 $self->writer->endTag;
}
EOSTR
}

sub divecall {
    my ( $self, $derefstring ) = @_;
    use Data::Dumper;
    my $str = Dumper($derefstring);
    sprintf( <<'EOSTR', "@$derefstring" );

my $elementdata = $self->DIVE( $root, qw(%s) ) ;
 
EOSTR
}

sub methodsfrom {
    my ( $self, $fh, $depth, $derefstring, $firstdepth ) = @_;
    $fh    = *STDOUT{IO} unless defined $fh;
    $depth = 0           unless defined $depth;

    my @newderef;

    if ( $depth < $firstdepth ) {
        @newderef = ();
    }
    else {
        if ( $depth == $firstdepth ) {
            @newderef = $self->cleantag;
        }
        if ( $depth > $firstdepth ) {
            @newderef = ( @$derefstring, $self->cleantag );
        }
    }

    #warn "DEREF: @newderef";
    my @children = @{ $self->{'_content'} };
    my $divecall = $self->divecall( \@newderef );

    #warn "DIVECALL: $divecall";
    my $tagmethod =
      $self->tagmethod( $self->cleantag, $divecall, \@children, \@newderef );

    $fh->print($tagmethod);
    for (@children) {

        if ( ref $_ ) {    # element
                           #use Data::Dumper;
                           #warn Dumper($_);
            $_->methodsfrom( $fh, $depth + 1, \@newderef, $firstdepth )
              ;            # recurse
        }
        else {             # text node
            ;
        }
    }

}

1;

