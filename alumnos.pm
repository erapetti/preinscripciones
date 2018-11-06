use strict;
use utf8;
use alumno;

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
		@_ = split('\t');

		$self->{vulnerabilidad}{$_[0]} = $_[12];
	}
	close(FILE3);
}

sub load_alumnos {
  my $self = shift;
  my ($filename,$vulnerabilidad,$separador) = @_;

  (defined($separador)) or $separador='\t';

	my %clasificacion;
	my $total_alumnos = 0;

  #if (!defined($self->{vulnerabilidad})) {
  #    print "ERROR: No están cargados los puntajes de vulnerabilidad de los alumnos\n";
  #    exit(1);
  #}
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
  # leo el encabezado
  my %columna;
  $_ = <FILE>;
  s/"//g;
  chop();
  @_ = split($separador);
  my $pos=0;
  foreach my $encabezado (@_) {
    $columna{$encabezado} = $pos++;
  }

  # un tag para identificar el archivo
  my $tag = substr($filename, 0, 3);

  # valido que estén definidas las columnas que preciso
  foreach my $encabezado ('preinscripto','Centro opción 1','Consejo opción 1','Departamento opción 1','Ruee opción 1','DependId-RepCod opción 1','EscCod opción 1','Curso código opc 1','Tipo curso opc 1','Centro predeterminado','Centro predeterminado consejo','Centro predeterminado departamento','Centro predeterminado ruee','Centro predeterminado dependId-RepCod','Centro opción 2','Consejo opción 2','Departamento opción 2','Ruee opción 2','DependId-RepCod opción 2','EscCod opción 2','Curso código opc 2','Tipo curso opc 2','Centro opción 3','Consejo opción 3','Departamento opción 3','Ruee opción 3','DependId-RepCod opción 3','EscCod opción 3','Curso código opc 3','Tipo curso opc 3','documento','documento','preinscripto','Centro opción 1','Consejo opción 1','Departamento opción 1','Ruee opción 1','DependId-RepCod opción 1','Centro predeterminado','Centro predeterminado consejo','Centro predeterminado departamento','Centro predeterminado ruee','Centro predeterminado dependId-RepCod','Centro opción 2','Consejo opción 2','Departamento opción 2','Ruee opción 2','DependId-RepCod opción 2','Centro opción 3','Consejo opción 3','Departamento opción 3','Ruee opción 3','DependId-RepCod opción 3','indice','Opcion Derivada') {
    if (!defined($columna{$encabezado})) {
      print "ERROR: el archivo $filename no contiene la columna $encabezado\n";
      exit(1);
    }
  }

  # leo el resto del archivo
	while(<FILE>) {
		next if ($total_alumnos == 0 && /^["']?departamento/i);
		$total_alumnos++;
		s/"//g;
		chop();
		@_ = split($separador);

		if ($_[$columna{'preinscripto'}] ne "Si") {
			# no preinscribió
			$self->{clasificacion}{'no preinscribió'}++;
			next;
		}
		my $opc1 = new opcion($_[$columna{'Centro opción 1'}], $_[$columna{'Consejo opción 1'}], $_[$columna{'Departamento opción 1'}], $_[$columna{'Ruee opción 1'}], $_[$columna{'DependId-RepCod opción 1'}], $_[$columna{'EscCod opción 1'}], $_[$columna{'Curso código opc 1'}], $_[$columna{'Tipo curso opc 1'}]);
		if (!$opc1) {
			# opc1 no es ANEP
			$self->{clasificacion}{'opc1 no es ANEP'}++;
			next;
		}

		my $deft = new opcion($_[$columna{'Centro predeterminado'}], $_[$columna{'Centro predeterminado consejo'}], $_[$columna{'Centro predeterminado departamento'}], $_[$columna{'Centro predeterminado ruee'}], $_[$columna{'Centro predeterminado dependId-RepCod'}]);
		my $opc2 = new opcion($_[$columna{'Centro opción 2'}], $_[$columna{'Consejo opción 2'}], $_[$columna{'Departamento opción 2'}], $_[$columna{'Ruee opción 2'}], $_[$columna{'DependId-RepCod opción 2'}], $_[$columna{'EscCod opción 2'}], $_[$columna{'Curso código opc 2'}], $_[$columna{'Tipo curso opc 2'}]);
		my $opc3 = new opcion($_[$columna{'Centro opción 3'}], $_[$columna{'Consejo opción 3'}], $_[$columna{'Departamento opción 3'}], $_[$columna{'Ruee opción 3'}], $_[$columna{'DependId-RepCod opción 3'}], $_[$columna{'EscCod opción 3'}], $_[$columna{'Curso código opc 3'}], $_[$columna{'Tipo curso opc 3'}]);
		my $ci = $_[$columna{'documento'}];
    my $tipodoc = $_[19];
    my $paisdoc = $_[20];

    # en las preinscripciones 2019 los derivados a CES vienen con la columna "Opcion Derivada" con SIN INFORMACIÓN:
    if ($opc1->consejo eq 'UTU' &&
        $_[$columna{'Opcion Derivada'}] eq "SIN INFORMACIÓN" &&
        ($opc2 && $opc2->consejo eq 'Liceo' || $opc3 && $opc3->consejo eq 'Liceo')) {

      $self->{derivados_a_ces}{$ci} = 1;
    }

    if (defined($self->{derivados_a_ces}{$ci})) {

      # El alumno Alexander Silveira fue derivado por CETP y no tiene opción deft
#      if ($ci eq '54332499') {
#        $deft = new opcion('DELTA EL TIGRE','Liceo','San José','1216614','1614');
#      }
      # El alumno Alan Mora fue derivado por CETP y no tiene opción deft
#      if ($ci eq '56214689') {
#        $deft = new opcion('PLAYA PASCUAL','Liceo','San José','1216010','1610');
#      }
      # El alumno Alexander González fue derivado por CETP y no tiene opción deft
#      if ($ci eq '56312122') {
#        $deft = new opcion('LIBERTAD','Liceo','San José','1216002','1602');
#      }

      if ($opc2 && $opc2->consejo eq 'Liceo') {
        $opc1 = $opc2;
        $opc2 = undef;
      } elsif ($opc3 && $opc3->consejo eq 'Liceo') {
        $opc1 = $opc3;
        $opc3 = undef;
      } elsif ($deft) {
        $opc1 = $deft;
      } else {
        print "ERROR: Alumno $ci fue derivado a CES pero no tiene opciones en CES\n";
        exit(1);
      }
      if ($opc2 && $opc2->consejo eq 'UTU') {
        $opc2 = undef;
      }
      if ($opc3 && $opc3->consejo eq 'UTU') {
        $opc3 = undef;
      }
      $self->{clasificacion}{'derivados a ces'}++;
      $self->{derivados_a_ces}{$ci}++; # lo marco como visto para controlar que los vi a todos

    } elsif (defined($self->{derivados_a_cetp}{$ci})) {
        if ($opc2 && $opc2->consejo eq 'UTU') {
          $opc1 = $opc2;
          $opc2 = undef;
        } elsif ($opc3 && $opc3->consejo eq 'UTU') {
          $opc1 = $opc3;
          $opc3 = undef;
        } else {
          print "ERROR: Alumno $ci fue derivado a CETP pero no tiene opciones en CETP\n";
          exit(1);
        }
        $self->{clasificacion}{'derivados a cetp'}++;
        $self->{derivados_a_cetp}{$ci}++; # lo marco como visto para controlar que los vi a todos
        if ($::soloCES) {
          next;
        }
    } else {
      if ($::soloCES) {
        if (defined($opc1) && $opc1->consejo eq 'UTU') {
          $self->{clasificacion}{'primera opción CETP'}++;
          next;
        }
      }
      $self->{clasificacion}{'para distribuir'}++;
    }

		if ($::soloCES) {
			if (defined($opc2) && $opc2->consejo ne 'Liceo') {
				$opc2 = undef;
			}
			if (defined($opc3) && $opc3->consejo ne 'Liceo') {
				$opc3 = undef;
			}
		}

		if (($_[6] eq "ESPECIAL" && $_[7] eq "DISCAPACIDAD AUDITIVA") && $opc1->consejo eq 'Liceo') {
      if (!($opc1->depto eq "MONTEVIDEO")) {
        print "ATENCIÓN: El alumno $ci tiene discapacidad auditiva y no es de Montevideo\n";
      } else {
        # Le agrego -49 al dependid
        $opc1->cambio_plan("49");
      }
		}

		# El liceo 1801 quedó en la oferta por error, ignoro esas opciones:
#		if (defined($opc1) && $opc1->dependid eq '1801') {
#			# Cintia Trindade y otros eligieron el liceo 1801 por error. Los cambio al 1807
#			$opc1 = new opcion('TACUAREMBO Nº 3','Liceo','Tacuarembó','1218007','1807');
#		}
#		if (defined($opc2) && $opc2->dependid eq '1801') {
#			$opc2 = undef;
#		}
#		if (defined($opc3) && $opc3->dependid eq '1801') {
#			$opc3 = undef;
#		}

		# La escuela 338 quedó predeterminada al liceo 45 pero va al 49
#		if ($_[0] eq 'MONTEVIDEO' && $_[3] eq '338') {
#			$deft = new opcion('MONTEVIDEO Nº 49 - MTRO. VIRGILIO SCARABELLI','Liceo','Montevideo','1201049','1049');
#		}
    # Nicolás pidió que el liceo Las Piedras 5 no sea predeterminado de nadie
#    if ($deft && $deft->dependid eq '274') {
#      $deft = undef;
#    }

		if ($::debug > 1) {
			print "doc : ".$_[$columna{'documento'}]."\n";
			print "prei: ".$_[$columna{'preinscripto'}]."\n";
			print "opc1: $_[$columna{'Centro opción 1'}], $_[$columna{'Consejo opción 1'}], $_[$columna{'Departamento opción 1'}], $_[$columna{'Ruee opción 1'}], $_[$columna{'DependId-RepCod opción 1'}]\n";
			print "deft: $_[$columna{'Centro predeterminado'}], $_[$columna{'Centro predeterminado consejo'}], $_[$columna{'Centro predeterminado departamento'}], $_[$columna{'Centro predeterminado ruee'}], $_[$columna{'Centro predeterminado dependId-RepCod'}]\n";
			print "opc2: $_[$columna{'Centro opción 2'}], $_[$columna{'Consejo opción 2'}], $_[$columna{'Departamento opción 2'}], $_[$columna{'Ruee opción 2'}], $_[$columna{'DependId-RepCod opción 2'}]\n";
			print "opc3: $_[$columna{'Centro opción 3'}], $_[$columna{'Consejo opción 3'}], $_[$columna{'Departamento opción 3'}], $_[$columna{'Ruee opción 3'}], $_[$columna{'DependId-RepCod opción 3'}]\n";
		}

    if (!defined($self->{vulnerabilidad}{$ci})) {
      $self->{vulnerabilidad}{$ci} = (defined($vulnerabilidad) ? $vulnerabilidad : $_[$columna{'indice'}])
    }

		if ($self->{vulnerabilidad}{$ci} !~ /^\d+$/) {
			print "ATENCIÓN: El alumno $ci no tiene definido el coeficiente de vulnerabilidad\n";
			$self->{vulnerabilidad}{$ci} = 0;
		}
    if (defined($self->{alumnos}{$ci})) {
      # si un alumno aparece más de una vez me quedo con el último y contabilizo para que cierre la clasificación
      $self->{clasificacion}{'repetidos'}++;
    }
    $self->{alumnos}{$ci} = new alumno($ci, $opc1, $opc2, $opc3, $deft, $self->{vulnerabilidad}{$ci}, $tipodoc, $paisdoc, $tag);
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
	printf "Total de alumnos: %d\n",$tot - $self->{clasificacion}{repetidos};

  my $para_distribuir = $self->{clasificacion}{'para distribuir'} + $self->{clasificacion}{'derivados a ces'} - $self->{clasificacion}{'repetidos'};
  if ($para_distribuir != scalar($self->alumnos)) {
    printf "ERROR: El total de la clasificación (%d) no cierra con el total de alumnos (%d)\n", $para_distribuir, scalar($self->alumnos);
    exit(1);
  }
}

sub alumnos {
  my $self = shift;

  return keys %{$self->{alumnos}};
}

sub alumno {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci};
}

sub opcion {
  my $self = shift;
  my ($ci,$opc) = @_;

  return $self->{alumnos}{$ci}->opcion($opc);
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

sub predeterminada {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci}->predeterminada();
}

sub vulnerable {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci}->vulnerabilidad() > 5;
}

sub tipodoc {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci}->tipodoc();
}

sub paisdoc {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci}->paisdoc();
}

sub tag {
  my $self = shift;
  my ($ci) = @_;

  return $self->{alumnos}{$ci}->tag();
}

1;
