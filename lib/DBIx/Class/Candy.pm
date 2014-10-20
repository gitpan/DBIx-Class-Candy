package DBIx::Class::Candy;
BEGIN {
  $DBIx::Class::Candy::VERSION = '0.001006';
}

use strict;
use warnings;
use namespace::clean;
require DBIx::Class::Candy::Exports;
use MRO::Compat;
use Sub::Exporter 'build_exporter';

# ABSTRACT: Sugar for your favorite ORM, DBIx::Class

my %aliases = (
   column            => 'add_columns',
   primary_key       => 'set_primary_key',
   unique_constraint => 'add_unique_constraint',
   relationship      => 'add_relationship',
);

my @methods = qw(
   resultset_class
   resultset_attributes
   remove_columns
   remove_column
   table
   source_name

   inflate_column

   belongs_to
   has_many
   might_have
   has_one
   many_to_many

   sequence
);

sub import {
   my $self = shift;

   my $base = 'DBIx::Class::Core';
   my $perl_version = undef;
   my $components = [];

   my @custom_methods;
   my %custom_aliases;
   my @rest;

   my $inheritor = caller(0);
   my $skipnext;
   for my $idx ( 0 .. $#_ ) {
      my $val = $_[$idx];

      next unless defined $val;
      if ($skipnext) {
         $skipnext--;
         next;
      }

      if ( $val eq '-base' ) {
         $base = $_[$idx + 1];
         $skipnext = 1;
      } elsif ( $val eq '-perl5' ) {
         $perl_version = ord $_[$idx + 1];
         $skipnext = 1;
      } elsif ( $val eq '-components' ) {
         $components = $_[$idx + 1];
         $skipnext = 1;
      } else {
         push @rest, $val;
      }
   }

   # inlined from parent.pm
   for ( my @useless = $base ) {
      s{::|'}{/}g;
      require "$_.pm"; # dies if the file is not found
   }

   {
      no strict 'refs';
      # This is more efficient than push for the new MRO
      # at least until the new MRO is fixed
      @{"$inheritor\::ISA"} = (@{"$inheritor\::ISA"} , $base);
   }
   $inheritor->load_components(@{$components});
   for (@{mro::get_linear_isa($inheritor)}) {
      if (my $hashref = $DBIx::Class::Candy::Exports::aliases{$_}) {
         %custom_aliases = (%custom_aliases, %{$hashref})
      }
      if (my $arrayref = $DBIx::Class::Candy::Exports::methods{$_}) {
         @custom_methods = (@custom_methods, @{$arrayref})
      }
   }

   @_ = ($self, @rest);
   my $import = build_exporter({
      exports => [
         has_column => sub {
            my $i = $inheritor;
            sub {
               my $column = shift;
               $i->add_columns($column => { @_ })
            }
         },
         primary_column => sub {
            my $i = $inheritor;
            sub {
               my $column = shift;
               my $info   = shift;
               $i->add_columns($column => $info);
               $i->set_primary_key($column);
            }
         },
         (map { $_ => sub {
            my ($class, $name) = @_;
            my $i = $inheritor;
            sub { $i->$name(@_) }
         } } @methods, @custom_methods),
         (map { $_ => sub {
            my ($class, $name) = @_;
            my $meth = $aliases{$name} || $custom_aliases{$name};
            my $i = $inheritor;
            sub { $i->$meth(@_) }
         } } keys %aliases, keys %custom_aliases),
      ],
      groups  => {
         default => [
            'has_column', 'primary_column', @methods, @custom_methods, keys %aliases, keys %custom_aliases
         ],
      },
      installer  => sub {
         Sub::Exporter::default_installer @_;
         namespace::clean->import(
            -cleanee => $inheritor,
         )
      },
      collectors => [
         INIT => sub {
            my $orig = $_[1]->{import_args};
            $_[1]->{import_args} = [];
            %custom_aliases = ();
            @custom_methods = ();

            if ($perl_version) {
               require feature;
               feature->import(":5.$perl_version")
            }

            strict->import;
            warnings->import;

            1;
         }
      ],
   });

   goto $import
}

1;


__END__
=pod

=head1 NAME

DBIx::Class::Candy - Sugar for your favorite ORM, DBIx::Class

=head1 VERSION

version 0.001006

=head1 SYNOPSIS

 package MyApp::Schema::Result::Artist;

 use DBIx::Class::Candy;

 table 'artists';

 column id => {
   data_type => 'int',
   is_auto_increment => 1,
 };

 column name => {
   data_type => 'varchar',
   size => 25,
   is_nullable => 1,
 };

 primary_key 'id';

 has_many albums => 'A::Schema::Result::Album', 'artist_id';

 1;

=head1 DESCRIPTION

C<DBIx::Class::Candy> is a simple sugar layer for definition of
L<DBIx::Class> results.  Note that it may later be expanded to add sugar
for more C<DBIx::Class> related things.  By default C<DBIx::Class::Candy>:

=over

=item *

turns on strict and warnings

=item *

sets your parent class

=item *

exports a bunch of the package methods that you normally use to define your
L<DBIx::Class> results

=item *

makes a few aliases to make some of the original method names a shorter or
more clear

=item *

defines very few new subroutines that transform the arguments passed to them

=back

It assumes a L<DBIx::Class::Core>-like API, but you can tailor it to suit
your needs.

=head1 HERE BE DRAGONS

Part of the goal of this module is to fix some warts of the original API
for defining L<DBIx::Class> results.  Given that we would like to get a few
eyeballs on it before we finalize it.  If you are writing code that you will
not touch again for years, do not use this till this warning is removed.

=head1 IMPORT OPTIONS

=head2 -base

 use DBIx::Class::Candy -base => 'MyApp::Schema::Result';

The first thing you can do to customize your usage of C<DBIx::Class::Candy>
is change the parent class.  Do that by using the C<-base> import option.

=head2 -components

 use DBIx::Class::Candy -components => ['FilterColumn'];

C<DBIx::Class::Candy> allows you to set which components you are using at
import time so that the components can define their own sugar to export as
well.  See L<DBIx::Class::Candy::Exports> for details on how that works.

=head2 -perl5

 use DBIx::Class::Candy -perl5 => v10;

I love the new features in Perl 5.10 and 5.12, so I felt that it would be
nice to remove the boiler plate of doing C<< use feature ':5.10' >> and
add it to my sugar importer.  Feel free not to use this.

=head1 IMPORTED SUBROUTINES

Most of the imported subroutines are the same as what you get when you use
the normal interface for result definition: they have the same names and take
the same arguments.  In general write the code the way you normally would,
leaving out the C<< __PACKAGE__-> >> part.  The following are methods that
are exported with the same name and arguments:

 belongs_to
 has_many
 has_one
 inflate_column
 many_to_many
 might_have
 remove_column
 remove_columns
 resultset_attributes
 resultset_class
 sequence
 source_name
 table

There are some exceptions though, which brings us to:

=head1 IMPORTED ALIASES

These are merely renamed versions of the functions you know and love.  The idea is
to make your result classes a tiny bit prettier by aliasing some methods.
If you know your C<DBIx::Class> API you noticed that in the L</SYNOPSIS> I used C<column>
instead of C<add_columns> and C<primary_key> instead of C<set_primary_key>.  The old
versions work, this is just nicer.  A list of aliases are as follows:

 column            => 'add_columns',
 primary_key       => 'set_primary_key',
 unique_constraint => 'add_unique_constraint',
 relationship      => 'add_relationship',

=head1 SECONDARY API

Lastly, there is currently a single "transformer" for C<add_columns>, so that
people used to the L<Moose> api will feel more at home.  Note that this B<may>
go into a "Candy Component" at some point.

Example usage:

 has_column foo => (
   data_type => 'varchar',
   size => 25,
   is_nullable => 1,
 );

=head1 AUTHOR

Arthur Axel "fREW" Schmidt <frioux+cpan@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Arthur Axel "fREW" Schmidt.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

