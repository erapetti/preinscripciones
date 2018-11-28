use strict;
use utf8;

package opcion;


sub new {
  my $class = shift;
  my ($nombre,$consejo,$depto,$ruee,$dependid,$esccod,$curso,$tipo) = @_;

  my $self = bless {}, $class;

  if (!($consejo eq 'Liceo' || $consejo eq 'UTU')) {
    return undef;
  }
  $self->{nombre}=$nombre;
  $self->{consejo}=$consejo;
  $self->{depto}=ucutf8($depto);
  $self->{dependid}=$dependid;
  if ($consejo eq 'UTU') {
    $esccod =~ /SIN INFORMACI/ and $esccod=0;
    $curso =~ /SIN INFORMACI/ and $curso=0;
    $tipo =~ /SIN INFORMACI/ and $tipo=0;
    $self->{esccod}=$esccod;
    $self->{curso}=$curso;
    $self->{tipo}=$tipo;
  }
  # Registro el departamento de cada dependencia porque no conozco el criterio que usa CETP
  if (!defined($::depto)) {
    $::depto{'1027'} = 'MONTEVIDEO';
    $::depto{'1075'} = 'MONTEVIDEO';
  }
  if (!defined($::depto{$self->dependid}) && defined($self->{depto})) {
    $::depto{$self->dependid} = $self->{depto};
  }
  return $self;
}

sub consejo {
  my $self = shift;
  return $self->{consejo};
}

sub depto {
  my $self = shift;
  return $self->{depto};
}

sub dependid {
  my $self = shift;
  return $self->consejo eq "Liceo" ? $self->{dependid} : $self->{dependid}."-".$self->{esccod}."-".$self->{curso}."-".$self->{tipo};
}

sub ucutf8($) {
	my ($texto) = @_;

	$texto = uc($texto);
	$texto =~ tr/áéíóúüñ/ÁÉÍÓÚÚÑ/;
  $texto =~ s/^ +//; # trim
  $texto =~ s/ +$//; # trim

	return $texto;
}

sub cambio_plan($) {
  my $self = shift;
  my ($plan) = @_;

  $self->{dependid} =~ s/-[^-]*$//; # saco el plan anterior
  $self->{dependid} = $self->{dependid}."-".$plan;
}

1;
