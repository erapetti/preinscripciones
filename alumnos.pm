use strict;
use utf8;

package alumnos;

sub new {
  my $class = shift;

  my $self = bless {}, $class;

  $self->{alumnos} = {};
  $self->{destino} = {};
  $self->{clasificacion} = {};

  return $self;
}

sub load_derivados_a_ces {
  my $self = shift;
  my ($filename) = @_;

  $self->{derivados_a_ces} = {};

	open(DERIVADOS,"<:utf8",$filename) || die "No de puede abrir $filename: $!";
	while(<DERIVADOS>) {
    next if (/^#/);
		s/"//g;
		chop();
		@_ = split('\t');

		$self->{derivados_a_ces}{$_[0]} = 1;
	}
	close(DERIVADOS);
}

sub load_derivados_a_cetp {
  my $self = shift;
  my ($filename) = @_;

  $self->{derivados_a_cetp} = {};

	open(DERIVADOS,"<:utf8",$filename) || die "No de puede abrir $filename: $!";
	while(<DERIVADOS>) {
    next if (/^#/);
		s/"//g;
		chop();
		@_ = split('\t');

		$self->{derivados_a_cetp}{$_[0]} = 1;
	}
	close(DERIVADOS);
}

sub load_vulnerabilidad {
  my $self = shift;
  my ($filename) = @_;

	$self->{vulnerabilidad} = {};

	open(FILE3,"<:utf8","$filename") || die "No de puede abrir $filename: $!";
	while(<FILE3>) {
    next if (/^#/);
		s/"//g;
		chop();
		@_ = split(',');

		$self->{vulnerabilidad}{$_[0]} = $_[12];
	}
	close(FILE3);
}

sub load_alumnos {
  my $self = shift;
  my ($filename) = @_;

	my %clasificacion;
	my $total_alumnos = 0;

  if (!defined($self->{vulnerabilidad})) {
      print "ERROR: No están cargados los puntajes de vulnerabilidad de los alumnos\n";
      exit(1);
  }
  if (!defined($self->{derivados_a_ces})) {
      print "ERROR: No están cargados los alumnos derivados de CETP a CES\n";
      exit(1);
  }
  if (!defined($self->{derivados_a_cetp})) {
      print "ERROR: No están cargados los alumnos derivados de CES a CETP\n";
      exit(1);
  }

  # paso las inicializaciones al constructor para poder usar este método más de una vez:
  #$self->{alumnos} = {};
  #$self->{destino} = {};

	open(FILE,"<:utf8",$filename) || die "No de puede abrir $filename: $!";
	while(<FILE>) {
		next if ($total_alumnos == 0 && /^["']?departamento/i);
    if (!/^"/) {
      print "ERROR: load_alumnos: línea mal formada en archivo $filename:\n\n$_";
      exit(1);
    }
		$total_alumnos++;
		s/"//g;
		chop();
		@_ = split('\t');

		if ($_[23] ne "Si") {
			# no preinscribió
			$self->{clasificacion}{'no preinscribió'}++;
			next;
		}

		my $opc1 = new opcion($_[32], $_[33], $_[34], $_[35], $_[36], $_[37], $_[38], $_[39]);
		if (!$opc1) {
			# opc1 no es ANEP
			$self->{clasificacion}{'opc1 no es ANEP'}++;
			next;
		}

		my $deft = new opcion($_[41], $_[42], $_[43], $_[44], $_[45]);
		my $opc2 = new opcion($_[47], $_[48], $_[49], $_[51], $_[52], $_[50], $_[53], $_[54]);
		my $opc3 = new opcion($_[55], $_[56], $_[57], $_[58], $_[59], $_[60], $_[61], $_[62]);
		my $ci = $_[18];

    if (defined($self->{derivados_a_ces}{$ci})) {
      if ($opc2 && $opc2->consejo == 'Liceo') {
        $opc1 = $opc2;
        $opc2 = undef;
      } elsif ($opc3 && $opc3->consejo == 'Liceo') {
        $opc1 = $opc3;
        $opc3 = undef;
      } elsif ($deft) {
        $opc1 = $deft;
      } else {
        print "ERROR: Alumno $ci fue derivado a CES pero no tiene opciones en CES\n";
        exit(1);
      }
      $self->{clasificacion}{'derivados_a_ces'}++;
      $self->{derivados_a_ces}{$ci}++; # lo marco como visto para controlar que los vi a todos

    } elsif (defined($self->{derivados_a_cetp}{$ci})) {
        if ($opc2 && $opc2->consejo == 'UTU') {
          $opc1 = $opc2;
          $opc2 = undef;
        } elsif ($opc3 && $opc3->consejo == 'UTU') {
          $opc1 = $opc3;
          $opc3 = undef;
        } else {
          print "ERROR: Alumno $ci fue derivado a CETP pero no tiene opciones en CETP\n";
          exit(1);
        }
        $self->{clasificacion}{'derivados_a_cetp'}++;
        $self->{derivados_a_cetp}{$ci}++; # lo marco como visto para controlar que los vi a todos

    } else {
      $self->{clasificacion}{'para distribuir'}++;
    }

		if ($::soloCES) {
      if (defined($opc1) && $opc1->consejo ne 'Liceo') {
        $self->{clasificacion}{'para distribuir'}--;
        $self->{clasificacion}{'primera opción CETP'}++;
        next;
      }
			if (defined($opc2) && $opc2->consejo ne 'Liceo') {
				$opc2 = undef;
			}
			if (defined($opc3) && $opc3->consejo ne 'Liceo') {
				$opc3 = undef;
			}
		}

		if (($_[6] eq "ESPECIAL" && $_[7] eq "DISCAPACIDAD AUDITIVA") && $opc1->consejo eq 'Liceo') {
      if (!($opc1->depto eq "MONTEVIDEO" || $opc1->depto eq "SALTO")) {
        print "ATENCIÓN: El alumno $ci tiene discapacidad auditiva y no es de Montevideo o Salto\n";
      } else {
        # Le agrego -49 al dependid
        $opc1 = new opcion($_[32], $_[33], $_[34], $_[35], $_[36]."-49", $_[37], $_[38], $_[39]);
      }
		}

		# El liceo 1801 quedó en la oferta por error, ignoro esas opciones:
		if (defined($opc1) && $opc1->dependid eq '1801') {
			# Cintia Trindade y otros eligieron el liceo 1801 por error. Los cambio al 1807
			$opc1 = new opcion('TACUAREMBO Nº 3','Liceo','Tacuarembó',1218007,1807);
		}
		if (defined($opc2) && $opc2->dependid eq '1801') {
			$opc2 = undef;
		}
		if (defined($opc3) && $opc3->dependid eq '1801') {
			$opc3 = undef;
		}

		# La escuela 338 quedó predeterminada al liceo 45 pero va al 49
#		if ($_[0] eq 'MONTEVIDEO' && $_[3] eq '338') {
#			$deft = new opcion('MONTEVIDEO Nº 49 - MTRO. VIRGILIO SCARABELLI','Liceo','Montevideo','1201049','1049');
#		}
    # Nicolás pidió que el liceo Las Piedras 5 no sea predeterminado de nadie
#    if ($deft && $deft->dependid eq '274') {
#      $deft = undef;
#    }

		if ($::debug > 1) {
			print "doc : ".$_[18]."\n";
			print "prei: ".$_[23]."\n";
			print "opc1: $_[32], $_[33], $_[34], $_[35], $_[36]\n";
			print "deft: $_[41], $_[42], $_[43], $_[44], $_[45]\n";
			print "opc2: $_[47], $_[48], $_[49], $_[51], $_[52]\n";
			print "opc3: $_[55], $_[56], $_[57], $_[58], $_[59]\n";
			print "fa15: ".$_[63]."\n";
			print "fa16: ".$_[64]."\n";
			print "fa17: ".$_[65]."\n";
			print "nota: ".$_[66]."\n";
			print "af  : ".$_[67]."\n";
			print "afam: ".$_[68]."\n";
			print "tus : ".$_[69]."\n";
			print "tus2: ".$_[70]."\n";
		}

    my $vulnerabilidad = $_[6] eq "ESPECIAL" ? 99 : $self->{vulnerabilidad}{$ci};
		if (!defined($vulnerabilidad)) {
			print "ATENCIÓN: El alumno $ci no tiene definido el coeficiente de vulnerabilidad\n";
			$self->{vulnerabilidad}{$ci} = 0;
		}
    $self->{alumnos}{$ci} = [ $opc1, $opc2, $opc3, $deft, $vulnerabilidad ];
	}
	close(FILE);
}

sub verifico {
  my $self = shift;

  # Verifico que todos los alumnos derivados a CES fueron considerados
  for my $ci (keys %{$self->{derivados_a_ces}}) {
    next if ($self->{derivados_a_ces}>1);
    print "ATENCIÓN: Alumno derivado a CES $ci no tiene preinscripción\n";
  }
  # Verifico que todos los alumnos derivados a CETP fueron considerados
  for my $ci (keys %{$self->{derivados_a_cetp}}) {
    next if ($self->{derivados_a_cetp}>1);
    print "ATENCIÓN: Alumno derivado a CETP $ci no tiene preinscripción\n";
  }

  my $tot = 0;
	print "Clasificación de alumnos:\n";
	foreach $_ (sort {$self->{clasificacion}{$a} <=> $self->{clasificacion}{$b}} keys %{$self->{clasificacion}}) {
		print "\t$_: $self->{clasificacion}{$_}\n";
    $tot += $self->{clasificacion}{$_};
	}
	print "Total de alumnos: $tot\n";
}

sub alumnos {
  my $self = shift;

  return keys %{$self->{alumnos}};
}

sub opcion {
  my $self = shift;
  my ($ci,$opc) = @_;

  return defined($self->{alumnos}{$ci}[$opc]) ? $self->{alumnos}{$ci}[$opc] : undef;
}

sub asignar {
  my $self = shift;
  my ($ci,$opc) = @_;

  $self->{destino}{$ci} = $opc;
}

sub opcdestino {
  my $self = shift;
  my ($ci) = @_;

  return $self->{destino}{$ci};
}

sub destino {
  my $self = shift;
  my ($ci) = @_;

  return $self->opcion($ci, $self->opcdestino($ci));
}

sub vulnerable {
  my $self = shift;
  my ($ci) = @_;

  return ($self->{alumnos}{$ci}[4] > 5);
}

sub predeterminada {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci}[3];
}



1;
