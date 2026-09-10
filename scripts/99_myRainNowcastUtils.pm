package main;
use strict;
use warnings;
use JSON::PP qw(decode_json);
use POSIX qw(strftime);

our $rainNowcastProtoDoorNameRe = qr/_Kontakt_Tuer/i;

# Zweck: FHEM-Initialisierungspunkt fuer die eingebundene myUtils-Datei.
# Parameter: $hash = Modul-/Datei-Hash, den FHEM beim Laden uebergibt.
# Ablauf: Reservierter Einstiegspunkt; aktuell ist keine Initialisierungslogik noetig.
# Rueckgabewert: keiner.
sub myRainNowcastProtoUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Zweck: Leitet aus dem aktuellen HTTPMOD-Payload die kompakten Regen-Kennwerte fuer das Device ab.
# Parameter: $name = Device-Name, $threshold = Mindestniederschlag, $logLevel = optionales Log-Level fuer Parserfehler.
# Ablauf: Bevorzugt waehrend eines laufenden HTTPMOD-Updates den frischen Response-Body, faellt sonst auf `.raw_json` zurueck, wertet `forecast[]` aus und bestimmt den ersten relevanten Regen-Slot.
# Rueckgabewert: Hash-Referenz mit abgeleiteten Werten wie `rain_state`, `rain_in_minutes` und `fresh_slot_count`.
sub _rainNowcastProto_summary($$;$)
{
  my ($name, $threshold, $logLevel) = @_;
  $threshold = 0.1 if !defined $threshold;

  # Ausgangszustand fuer trockene oder ungueltige Payloads.
  my $summary = {
    rain_now         => 0,
    rain_in_minutes  => -1,
    next_rain_rate   => 0,
    next_rain_type   => "no_precipitation",
    next_rain_begin  => "",
    rain_state       => "dry",
    fresh_slot_count => 0,
    first_slot       => undef,
  };

  # Innerhalb des HTTPMOD-Callbacks ist der aktuelle Response-Body verlaesslicher als ein spaeteres Hidden-Reading-Event.
  my $hash = $defs{$name};
  my $raw = "";
  if ($hash && defined $hash->{httpbody} && $hash->{httpbody} ne "") {
    $raw = $hash->{httpbody};
  } else {
    $raw = ReadingsVal($name, ".raw_json", "");
  }
  if (!$raw) {
    return $summary;
  }

  # Bevorzugt den JSON-Body hinter der Header-Trennzeile und faellt nur bei reinem Body auf den Direktfall zurueck.
  my $jsonText = "";
  if ($raw =~ /\r?\n\r?\n(\{.*)\z/s) {
    $jsonText = $1;
  } elsif ($raw =~ /^\s*\{.*\}\s*$/s) {
    $jsonText = $raw;
  }

  if (!$jsonText) {
    _rainNowcastProto_log($name, $logLevel,
      "could not extract JSON body from raw payload")
        if defined $logLevel;
    return $summary;
  }

  # JSON dekodieren und nur Payloads mit `forecast[]` weiterverarbeiten.
  my $payload = eval { decode_json($jsonText) };
  if (!$payload || ref($payload) ne "HASH") {
    _rainNowcastProto_log($name, $logLevel,
      "decode_json failed in payload parser: $@")
        if defined $logLevel && $@;
    return $summary;
  }

  my $forecast = $payload->{forecast};
  if (ref($forecast) ne "ARRAY") {
    return $summary;
  }

  my $now = time();
  my $idx = 0;
  my $firstSlot;

  # Forecast-Eintraege normalisieren und den ersten relevanten Regen-Slot merken.
  for my $entry (@$forecast) {
    next if ref($entry) ne "HASH";
    $idx++;

    my $slot = {
      idx   => $idx,
      rate  => 0 + ($entry->{precipRate} // 0),
      type  => $entry->{precipType} // "",
      begin => 0 + ($entry->{timestampBegin} // 0),
      end   => 0 + ($entry->{timestampEnd} // 0),
    };

    next if $firstSlot;
    next if $slot->{type} eq "no_precipitation";
    next if $slot->{rate} < $threshold;
    $firstSlot = $slot;
  }

  $summary->{fresh_slot_count} = $idx;
  $summary->{first_slot} = $firstSlot if $firstSlot;

  # Aus dem ersten relevanten Slot die fuer FHEM benoetigten Zielwerte berechnen.
  if ($firstSlot) {
    my $minutes = int(($firstSlot->{begin} - $now) / 60);
    $minutes = 0 if $minutes < 0;

    $summary->{rain_now} = $firstSlot->{idx} == 1 ? 1 : 0;
    $summary->{rain_in_minutes} = $minutes;
    $summary->{next_rain_rate} = sprintf("%.3f", $firstSlot->{rate});
    $summary->{next_rain_type} = $firstSlot->{type};
    $summary->{next_rain_begin}
      = strftime("%Y-%m-%d %H:%M:%S", localtime($firstSlot->{begin}));
    $summary->{rain_state}
      = $summary->{rain_now}
      ? "rain_now"
      : ($minutes <= 15 ? "rain_soon" : "later_rain");
  }

  return $summary;
}

# Zweck: Schreibt alle abgeleiteten Regen-Readings gesammelt auf das Ziel-Device.
# Parameter: $name = Device-Name, $threshold = Mindestniederschlag fuer die Relevanzbewertung.
# Ablauf: Holt die Summary einmal zentral und schreibt Zusatz-Readings innerhalb des bereits laufenden userReading-/HTTPMOD-Updatezyklus.
# Rueckgabewert: `rain_state`, damit das userReading direkt dieses Reading setzen kann.
sub myRainNowcastUpdateReadings($;$)
{
  my ($name, $threshold) = @_;
  my $summary = _rainNowcastProto_summary($name, $threshold);
  my $hash = $defs{$name};

  # Zusatz-Readings direkt im offenen HTTPMOD-Updatezyklus schreiben.
  if ($hash) {
    readingsBulkUpdate($hash, "rain_now", $summary->{rain_now});
    readingsBulkUpdate($hash, "rain_in_minutes", $summary->{rain_in_minutes});
    readingsBulkUpdate($hash, "next_rain_rate", $summary->{next_rain_rate});
    readingsBulkUpdate($hash, "next_rain_type", $summary->{next_rain_type});
    readingsBulkUpdate($hash, "next_rain_begin", $summary->{next_rain_begin});
    readingsBulkUpdate($hash, "fresh_slot_count", $summary->{fresh_slot_count});
  }

  return $summary->{rain_state};
}

# Zweck: Baut den kompakten Anzeigetext fuer `stateFormat` aus bereits berechneten Readings.
# Parameter: $name = Device-Name.
# Ablauf: Liest die Ziel-Readings, uebersetzt interne Zustandswerte in lesbare Labels und kombiniert optionale Details.
# Rueckgabewert: Formatierter Text fuer die Anzeige in FHEMWEB.
sub myRainNowcastStateFormat($)
{
  my ($name) = @_;
  my $state = ReadingsVal($name, "rain_state",
    ReadingsVal($name, "summary_intensity", "init"));
  my $minutes = ReadingsVal($name, "rain_in_minutes", "");
  my $nextType = ReadingsVal($name, "next_rain_type", "");

  # Interne Status- und Typwerte fuer die Benutzeranzeige in lesbare Labels uebersetzen.
  my %stateLabel = (
    "dry"        => "Trocken",
    "rain_now"   => "Regen jetzt",
    "rain_soon"  => "Regen bald",
    "later_rain" => "Regen spaeter",
  );
  my %typeLabel = (
    "no_precipitation" => "kein Niederschlag",
    "rain"             => "Regen",
    "snow"             => "Schnee",
    "sleet"            => "Schneeregen",
    "hail"             => "Hagel",
  );
  my $label = $stateLabel{$state} // $state;

  # Im trockenen Fall reicht ein kompakter Zweizeiler ohne Zusatzdetails.
  return "RN:$state\n<br/>$label" if $state eq "dry";

  # Nur bei abweichendem Niederschlagstyp einen zusaetzlichen Typ-Hinweis anzeigen.
  my $detail = "";
  if ($nextType ne "" && $nextType ne "no_precipitation" && $nextType ne "rain") {
    $detail = ": " . ($typeLabel{$nextType} // $nextType);
  }

  # Die Minutenangabe nur fuer zukuenftigen Regen anzeigen.
  my $minutesText = "";
  if ($minutes =~ /^-?\d+$/ && $minutes > 0) {
    $minutesText = " (in $minutes Min.)";
  }

  return "RN:$state\n<br/>"
    . $label
    . $detail
    . $minutesText;
}

# Zweck: Vereinheitlicht Logmeldungen dieses Moduls.
# Parameter: $device = Bezugs-Device fuer das Log, $level = FHEM-Log-Level, $message = Meldungstext.
# Ablauf: Waehlt einen sinnvollen Log-Namen und schreibt die Meldung mit festem Modul-Praefix.
# Rueckgabewert: keiner.
sub _rainNowcastProto_log($$$)
{
  my ($device, $level, $message) = @_;
  my $logDevice = defined $device && $device ne "" ? $device : "RainNowcastProto";
  Log3 $logDevice, $level, "rain-nowcast-warn ($logDevice) - $message";
}

# Zweck: Ordnet ein Kontakt-Device der unterstuetzten Warnlogik zu.
# Parameter: $device = zu pruefender Device-Name.
# Ablauf: Erkennt Dachfenster ueber Attribut und Tueren ueber Namensmuster und liefert die passende Offen-Regel.
# Rueckgabewert: Hash-Referenz mit `device`, `reading` und `open_re` oder `undef` bei irrelevanten Devices.
sub _rainNowcastProto_monitored_target($)
{
  my ($device) = @_;
  return undef if !defined $device || $device eq "";

  # Dachfenster werden ueber ein explizites Attribut und den Status `open|tilted` erkannt.
  if (AttrVal($device, "IsRoofWindow", "") eq "1") {
    return {
      device  => $device,
      reading => "state",
      open_re => qr/^(open|tilted)$/i,
    };
  }

  # Tueren werden ueber das Namensmuster erkannt und gelten nur bei `open` als offen.
  if ($device =~ /$rainNowcastProtoDoorNameRe/) {
    return {
      device  => $device,
      reading => "state",
      open_re => qr/^open$/i,
    };
  }

  return undef;
}

# Zweck: Sammelt alle aktuell offenen, fuer Warnungen relevanten Kontakte.
# Parameter: $devices = optionale Liste vorgefilterter Devices, $logDevice = Bezugs-Device fuer Logs, $logLevel = optionales Log-Level.
# Ablauf: Ermittelt bei Bedarf Kandidaten per devspec, klassifiziert sie und prueft ihren aktuellen Offen-Status.
# Rueckgabewert: Array-Referenz mit den offenen Ziel-Hashes.
sub _rainNowcastProto_collect_open_targets($;$$)
{
  my ($devices, $logDevice, $logLevel) = @_;
  my @candidateDevices;

  # Entweder die uebergebene Device-Liste verwenden oder Kandidaten dynamisch per devspec suchen.
  if ($devices && ref($devices) eq "ARRAY") {
    @candidateDevices = @$devices;
  } else {
    my %seen;
    for my $spec ("a:IsRoofWindow=1", "NAME=.*_Kontakt_Tuer.*") {
      my @matched = eval { devspec2array($spec) };
      _rainNowcastProto_log($logDevice, $logLevel,
        "devspec2array failed for '$spec': $@")
          if $@ && defined $logLevel;
      for my $device (@matched) {
        next if !defined $device || $device eq "";
        next if !$defs{$device};
        next if $seen{$device}++;
        push @candidateDevices, $device;
      }
    }
  }

  # Nur solche Kandidaten uebernehmen, deren aktuelles Reading dem Offen-Muster entspricht.
  my @openTargets;
  for my $device (@candidateDevices) {
    my $target = _rainNowcastProto_monitored_target($device);
    next if !$target;

    my $value = ReadingsVal($target->{device}, $target->{reading}, "");
    push @openTargets, $target if $value =~ /$target->{open_re}/;
  }

  return \@openTargets;
}

# Zweck: Erzeugt den gesprochenen oder weiterverarbeiteten Warntext fuer die beiden Triggerfaelle.
# Parameter: $triggerKind = `rain_update` oder `contact_open`, $minutes = Minuten bis zum Regen, $targets = betroffene offene Kontakte.
# Ablauf: Leitet sprechbare Zielnamen ab und formatiert daraus den passenden Textbaustein fuer den konkreten Warnfall.
# Rueckgabewert: Warntext oder leerer String, wenn kein sinnvoller Text erzeugt werden kann.
sub _rainNowcastProto_warn_text($$$)
{
  my ($triggerKind, $minutes, $targets) = @_;
  return "" if !$targets || ref($targets) ne "ARRAY" || !@$targets;

  # Fuer die Textausgabe bevorzugt Alias-Namen, sonst den technischen Device-Namen verwenden.
  my @targetNames;
  for my $target (@$targets) {
    next if !$target || ref($target) ne "HASH";
    my $device = $target->{device} // "";
    next if $device eq "";
    my $alias = AttrVal($device, "alias", "");
    push @targetNames, (defined $alias && $alias ne "") ? $alias : $device;
  }
  return "" if !@targetNames;

  # Mehrere Ziele fuer natuerliche Sprachausgabe zu einer lesbaren Liste zusammenfassen.
  my $targetNames = $targetNames[0];
  if (@targetNames == 2) {
    $targetNames = join(" und ", @targetNames);
  } elsif (@targetNames > 2) {
    my $last = pop @targetNames;
    $targetNames = join(", ", @targetNames) . " und " . $last;
  }

  return "" if $targetNames eq "";

  # Je nach Triggerfall den passenden Meldungstext fuer sofortigen oder baldigen Regen erzeugen.
  if ($triggerKind eq "rain_update") {
    return "Achtung, es regnet bereits. Offen sind $targetNames. Bitte schliessen."
      if $minutes <= 0;
    return "Achtung, Regen in $minutes Minuten. Offen sind $targetNames. Bitte schliessen.";
  }

  if ($triggerKind eq "contact_open") {
    my $targetName = $targetNames[0];
    return "Achtung, $targetName ist geoeffnet und es regnet bereits."
      if $minutes <= 0;
    return "Achtung, $targetName ist geoeffnet und Regen ist in $minutes Minuten angesagt.";
  }

  return "";
}

# Zweck: Komfort-Helfer fuer Kontakt-Events mit raumbezogener Alexa-/Speak-Ausgabe.
# Parameter: $rainDevice = RainNowcast-Device, $sourceDevice = ausloesender Kontakt, $opts = optionale Einstellungen fuer Logging und Speak-Kommando.
# Ablauf: Laesst die generische Warnpruefung laufen, leitet danach das Speak-Device aus dem Namenspraefix ab und sendet den Text.
# Rueckgabewert: Erzeugter Warntext oder leerer String, wenn keine Meldung ausgegeben werden soll.
sub myRainNowcastWarnContactOpenAlexa($$;$)
{
  my ($rainDevice, $sourceDevice, $opts) = @_;
  $opts = {} if !$opts || ref($opts) ne "HASH";

  # Optionen mit praxisnahen Defaults fuer Logging und Speak-Kommando vorbelegen.
  my $logLevel = defined $opts->{logLevel} ? $opts->{logLevel} : 4;
  my $speakerSuffix = defined $opts->{speaker_suffix} && $opts->{speaker_suffix} ne ""
    ? $opts->{speaker_suffix}
    : "alexa";
  my $speakCommand = defined $opts->{speak_command} && $opts->{speak_command} ne ""
    ? $opts->{speak_command}
    : "speak";

  # Die eigentliche Warnentscheidung an die generische Logik delegieren.
  my $text = myRainNowcastWarnIfNeeded(
    "contact_open",
    $rainDevice,
    $sourceDevice,
    undef,
    $opts
  );
  return "" if !defined $text || $text eq "";

  # Speak-Device aus dem Namenspraefix des Kontakt-Devices ableiten und pruefen.
  my $prefix = defined $sourceDevice && $sourceDevice =~ /^([^_]+)_/ ? $1 : "";
  my $speakDevice = $prefix ne "" ? $prefix . "_" . $speakerSuffix : "";
  if ($speakDevice eq "") {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip speak: could not derive room prefix from sourceDevice=$sourceDevice");
    return $text;
  }

  if (!$defs{$speakDevice}) {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip speak: derived speak device '$speakDevice' does not exist");
    return $text;
  }

  # Den finalen FHEM-Befehl zusammenbauen, sicher quoten und an das Speak-Device senden.
  my $quotedText = $text;
  $quotedText =~ s/\\/\\\\/g;
  $quotedText =~ s/"/\\"/g;
  my $cmd = "set $speakDevice $speakCommand \"$quotedText\"";
  fhem($cmd);
  _rainNowcastProto_log($rainDevice, $logLevel,
    "speak command executed on $speakDevice via '$speakCommand'");

  return $text;
}

# Zweck: Zentrale Entscheidungslogik fuer Regenwarnungen aus Update- und Kontakt-Events.
# Parameter: $triggerKind = `rain_update` oder `contact_open`, $rainDevice = Quelle der Regenprognose, $sourceDevice = optionaler Kontakt, $speakCb = optionale Ausgabefunktion, $opts = optionale Schwellen und Logging-Einstellungen.
# Ablauf: Prueft Regenfenster, ermittelt betroffene offene Kontakte, erzeugt einen Warntext und ruft bei Bedarf einen Callback auf.
# Rueckgabewert: Warntext oder leerer String, wenn keine Warnung ausgeloest werden soll.
sub myRainNowcastWarnIfNeeded($$$$;$)
{
  my ($triggerKind, $rainDevice, $sourceDevice, $speakCb, $opts) = @_;
  $opts = {} if !$opts || ref($opts) ne "HASH";

  # Schwellwerte und Zeitfenster mit sinnvollen Defaults initialisieren.
  my $threshold = defined $opts->{threshold} ? $opts->{threshold} : 0.1;
  my $rainWindowMinutes = defined $opts->{rain_window_minutes}
    ? $opts->{rain_window_minutes}
    : 30;
  my $logLevel = defined $opts->{logLevel} ? $opts->{logLevel} : 4;

  if (!$triggerKind || !$rainDevice) {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: missing triggerKind or rainDevice");
    return "";
  }

  # Zuerst die Regenlage auswerten und frueh aussteigen, wenn kein relevanter Regen bevorsteht.
  _rainNowcastProto_log($rainDevice, $logLevel,
    "start: triggerKind=$triggerKind sourceDevice="
    . (defined $sourceDevice ? $sourceDevice : "undef")
    . " threshold=$threshold rainWindowMinutes=$rainWindowMinutes");

  my $summary = _rainNowcastProto_summary($rainDevice, $threshold, $logLevel);
  my $minutes = $summary->{rain_in_minutes};
  if ($minutes < 0) {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: no relevant rain found (minutes=$minutes)");
    return "";
  }
  if ($minutes > $rainWindowMinutes) {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: rain outside window (minutes=$minutes window=$rainWindowMinutes)");
    return "";
  }

  _rainNowcastProto_log($rainDevice, $logLevel,
    "rain ok: minutes=$minutes");

  # Je nach Trigger offene Ziele sammeln oder das einzelne ausloesende Device pruefen.
  my $targets;
  if ($triggerKind eq "rain_update") {
    $targets = _rainNowcastProto_collect_open_targets(undef, $rainDevice, $logLevel);
    _rainNowcastProto_log($rainDevice, $logLevel,
      "rain_update open targets: "
      . (@$targets ? join(", ", map { $_->{device} // "" } @$targets) : "<none>"));
    if (!@$targets) {
      _rainNowcastProto_log($rainDevice, $logLevel,
        "skip: no open monitored devices");
      return "";
    }
  } elsif ($triggerKind eq "contact_open") {
    my $target = _rainNowcastProto_monitored_target($sourceDevice);
    if (!$target) {
      _rainNowcastProto_log($rainDevice, $logLevel,
        "skip: sourceDevice is not a monitored target");
      return "";
    }
    $targets = _rainNowcastProto_collect_open_targets([$sourceDevice], $rainDevice, $logLevel);
    if (!@$targets) {
      _rainNowcastProto_log($rainDevice, $logLevel,
        "skip: sourceDevice is monitored but not currently open");
      return "";
    }
    _rainNowcastProto_log($rainDevice, $logLevel,
      "contact_open target ok: " . join(", ", map { $_->{device} // "" } @$targets));
  } else {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: unsupported triggerKind=$triggerKind");
    return "";
  }

  # Aus den offenen Zielen einen Warntext erzeugen und leere Ergebnisse verwerfen.
  my $text = _rainNowcastProto_warn_text($triggerKind, $minutes, $targets);
  if ($text eq "") {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: warning text generation returned empty string");
    return "";
  }

  _rainNowcastProto_log($rainDevice, $logLevel,
    "warn text: $text");

  # Einen optionalen Ausgabecallback nur dann ausfuehren, wenn ein echter Warntext vorliegt.
  if ($speakCb && ref($speakCb) eq "CODE") {
    $speakCb->($text);
    _rainNowcastProto_log($rainDevice, $logLevel,
      "speak callback executed");
  }

  return $text;
}

1;
