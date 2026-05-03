package main;
use strict;
use warnings;
use JSON::PP qw(decode_json);
use POSIX qw(strftime);

our $rainNowcastProtoDoorNameRe = qr/_Kontakt_Tuer/i;

sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

sub _rainNowcastProto_raw_json($)
{
  my ($name) = @_;
  my $raw = ReadingsVal($name, ".raw_json", "");
  return $raw if defined $raw && $raw ne "";

  my $hash = $defs{$name};
  return "" if !$hash;

  return $hash->{httpbody} // "";
}

sub _rainNowcastProto_extract_json_text($)
{
  my ($raw) = @_;
  return "" if !defined $raw || $raw eq "";

  # Preferred case: HTTP headers and body are separated by an empty line.
  if ($raw =~ /\r?\n\r?\n(\{.*)\z/s) {
    return $1;
  }

  # Fast path for a body-only reading.
  if ($raw =~ /^\s*\{.*\}\s*$/s) {
    return $raw;
  }

  # Defensive fallback: try every JSON-looking start and keep the first
  # substring that decodes as a complete JSON document.
  while ($raw =~ /(\{)/g) {
    my $start = pos($raw) - 1;
    my $candidate = substr($raw, $start);
    next if $candidate !~ /^\s*\{/s;

    eval { decode_json($candidate); 1 } and return $candidate;
  }

  return "";
}

sub _rainNowcastProto_payload($;$)
{
  my ($name, $logLevel) = @_;
  my $raw = _rainNowcastProto_raw_json($name);
  return undef if !$raw;

  my $jsonText = _rainNowcastProto_extract_json_text($raw);
  _rainNowcastProto_log($name, $logLevel,
    "could not extract a decodable JSON document from raw payload")
      if !$jsonText && defined $logLevel;
  return undef if !$jsonText;

  my $payload = eval { decode_json($jsonText) };
  _rainNowcastProto_log($name, $logLevel,
    "decode_json failed in payload parser: $@")
      if !$payload && $@ && defined $logLevel;
  return undef if !$payload || ref($payload) ne "HASH";

  return $payload;
}

sub _rainNowcastProto_slots($;$)
{
  my ($name, $logLevel) = @_;
  my $payload = _rainNowcastProto_payload($name, $logLevel);
  return [] if !$payload;

  my $forecast = $payload->{forecast};
  return [] if ref($forecast) ne "ARRAY";

  my @slots;
  my $idx = 0;

  for my $entry (@$forecast) {
    next if ref($entry) ne "HASH";
    $idx++;

    push @slots, {
      idx   => $idx,
      rate  => 0 + ($entry->{precipRate} // 0),
      type  => $entry->{precipType} // "",
      begin => 0 + ($entry->{timestampBegin} // 0),
      end   => 0 + ($entry->{timestampEnd} // 0),
    };
  }

  return \@slots;
}

sub _rainNowcastProto_first_relevant($$;$)
{
  my ($name, $threshold, $logLevel) = @_;
  $threshold = 0.1 if !defined $threshold;

  my $slots = _rainNowcastProto_slots($name, $logLevel);
  return undef if !@$slots;

  for my $slot (@$slots) {
    next if $slot->{type} eq "no_precipitation";
    next if $slot->{rate} < $threshold;
    return $slot;
  }

  return undef;
}

sub myRainNowcastNow($;$)
{
  my ($name, $threshold) = @_;
  my $slot = _rainNowcastProto_first_relevant($name, $threshold);
  return 0 if !$slot;
  return $slot->{idx} == 1 ? 1 : 0;
}

sub myRainNowcastMinutes($;$)
{
  my ($name, $threshold) = @_;
  my $slot = _rainNowcastProto_first_relevant($name, $threshold);
  return -1 if !$slot;

  my $minutes = int(($slot->{begin} - time()) / 60);
  $minutes = 0 if $minutes < 0;
  return $minutes;
}

sub myRainNowcastRate($;$)
{
  my ($name, $threshold) = @_;
  my $slot = _rainNowcastProto_first_relevant($name, $threshold);
  return 0 if !$slot;
  return sprintf("%.3f", $slot->{rate});
}

sub myRainNowcastType($;$)
{
  my ($name, $threshold) = @_;
  my $slot = _rainNowcastProto_first_relevant($name, $threshold);
  return "no_precipitation" if !$slot;
  return $slot->{type};
}

sub myRainNowcastBegin($;$)
{
  my ($name, $threshold) = @_;
  my $slot = _rainNowcastProto_first_relevant($name, $threshold);
  return "" if !$slot;
  return strftime("%Y-%m-%d %H:%M:%S", localtime($slot->{begin}));
}

sub myRainNowcastState($;$)
{
  my ($name, $threshold) = @_;
  my $slot = _rainNowcastProto_first_relevant($name, $threshold);
  return "dry" if !$slot;

  return "rain_now" if $slot->{idx} == 1;

  my $minutes = myRainNowcastMinutes($name, $threshold);
  return "rain_soon" if $minutes >= 0 && $minutes <= 15;
  return "later_rain";
}

sub myRainNowcastFreshSlotCount($)
{
  my ($name) = @_;
  my $slots = _rainNowcastProto_slots($name);
  return scalar @$slots;
}

sub _rainNowcastProtoStateLabel($)
{
  my ($state) = @_;
  my %label = (
    "dry"        => "Trocken",
    "rain_now"   => "Regen jetzt",
    "rain_soon"  => "Regen bald",
    "later_rain" => "Regen spaeter",
  );
  return $label{$state} // $state;
}

sub _rainNowcastProtoIntensityLabel($)
{
  my ($intensity) = @_;
  my %label = (
    "none"     => "keine",
    "light"    => "leicht",
    "moderate" => "moderat",
    "heavy"    => "stark",
    "extreme"  => "extrem",
    "intense"  => "intens",
  );
  return $label{$intensity} // $intensity;
}

sub myRainNowcastStateFormat($)
{
  my ($name) = @_;
  my $state = ReadingsVal($name, "rain_state",
    ReadingsVal($name, "summary_intensity", "init"));
  my $intensity = ReadingsVal($name, "summary_intensity", "init");
  my $minutes = ReadingsVal($name, "rain_in_minutes", "?");

  return "RN:$state\n<br/>"
    . _rainNowcastProtoStateLabel($state)
    . " "
    . _rainNowcastProtoIntensityLabel($intensity)
    . " (in "
    . $minutes
    . " Min.)";
}

sub _rainNowcastProto_log($$$)
{
  my ($device, $level, $message) = @_;
  my $logDevice = defined $device && $device ne "" ? $device : "RainNowcastProto";
  Log3 $logDevice, $level, "rain-nowcast-warn ($logDevice) - $message";
}

sub _rainNowcastProto_warn_candidate_devices(;$$)
{
  my ($logDevice, $logLevel) = @_;
  my %seen;
  my @devices;

  for my $spec ("a:IsRoofWindow=1", "NAME=.*_Kontakt_Tuer.*") {
    my @matched = eval { devspec2array($spec) };
    _rainNowcastProto_log($logDevice, $logLevel,
      "devspec2array failed for '$spec': $@")
        if $@ && defined $logLevel;
    next if !@matched;

    for my $device (@matched) {
      next if !defined $device || $device eq "";
      next if !$defs{$device};
      next if $seen{$device}++;
      push @devices, $device;
    }
  }

  return \@devices;
}

sub _rainNowcastProto_warn_target_for_device($)
{
  my ($device) = @_;
  return undef if !defined $device || $device eq "";

  if (AttrVal($device, "IsRoofWindow", "") eq "1") {
    return {
      device  => $device,
      reading => "state",
      open_re => qr/^(open|tilted)$/i,
    };
  }

  if ($device =~ /$rainNowcastProtoDoorNameRe/) {
    return {
      device  => $device,
      reading => "state",
      open_re => qr/^open$/i,
    };
  }

  return undef;
}

sub _rainNowcastProto_is_target_open($)
{
  my ($target) = @_;
  return 0 if !$target || ref($target) ne "HASH";

  my $device = $target->{device} // "";
  my $reading = $target->{reading} // "state";
  my $openRe = $target->{open_re};
  return 0 if $device eq "" || !$openRe;

  my $value = ReadingsVal($device, $reading, "");
  return $value =~ /$openRe/ ? 1 : 0;
}

sub _rainNowcastProto_open_warn_targets($)
{
  my ($devices) = @_;
  return [] if !$devices || ref($devices) ne "ARRAY";

  my @openTargets;
  for my $device (@$devices) {
    my $target = _rainNowcastProto_warn_target_for_device($device);
    next if !$target;
    push @openTargets, $target if _rainNowcastProto_is_target_open($target);
  }

  return \@openTargets;
}

sub _rainNowcastProto_target_name($)
{
  my ($target) = @_;
  return "" if !$target || ref($target) ne "HASH";

  my $device = $target->{device} // "";
  return "" if $device eq "";

  my $alias = AttrVal($device, "alias", "");
  return $alias if defined $alias && $alias ne "";
  return $device;
}

sub _rainNowcastProto_warn_text($$$)
{
  my ($triggerKind, $minutes, $targets) = @_;
  return "" if !$targets || ref($targets) ne "ARRAY" || !@$targets;

  my @targetNames = map { _rainNowcastProto_target_name($_) } @$targets;
  @targetNames = grep { defined $_ && $_ ne "" } @targetNames;
  return "" if !@targetNames;

  my $targetNames = $targetNames[0];
  if (@targetNames == 2) {
    $targetNames = join(" und ", @targetNames);
  } elsif (@targetNames > 2) {
    my $last = pop @targetNames;
    $targetNames = join(", ", @targetNames) . " und " . $last;
  }

  return "" if $targetNames eq "";

  if ($triggerKind eq "rain_update") {
    return "Achtung, es regnet bereits. Offen sind $targetNames. Bitte schliessen."
      if $minutes <= 0;
    return "Achtung, Regen in $minutes Minuten. Offen sind $targetNames. Bitte schliessen.";
  }

  if ($triggerKind eq "contact_open") {
    my $targetName = _rainNowcastProto_target_name($targets->[0]);
    return "Achtung, $targetName ist geoeffnet und es regnet bereits."
      if $minutes <= 0;
    return "Achtung, $targetName ist geoeffnet und Regen ist in $minutes Minuten angesagt.";
  }

  return "";
}

sub myRainNowcastWarnIfNeeded($$$$;$)
{
  my ($triggerKind, $rainDevice, $sourceDevice, $speakCb, $opts) = @_;
  $opts = {} if !$opts || ref($opts) ne "HASH";

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

  _rainNowcastProto_log($rainDevice, $logLevel,
    "start: triggerKind=$triggerKind sourceDevice="
    . (defined $sourceDevice ? $sourceDevice : "undef")
    . " threshold=$threshold rainWindowMinutes=$rainWindowMinutes");

  my $slot = _rainNowcastProto_first_relevant($rainDevice, $threshold, $logLevel);
  my $minutes = -1;
  if ($slot) {
    $minutes = int(($slot->{begin} - time()) / 60);
    $minutes = 0 if $minutes < 0;
  }
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

  my $targets;
  if ($triggerKind eq "rain_update") {
    my $candidateDevices = _rainNowcastProto_warn_candidate_devices($rainDevice, $logLevel);
    _rainNowcastProto_log($rainDevice, $logLevel,
      "rain_update candidates: "
      . (@$candidateDevices ? join(", ", @$candidateDevices) : "<none>"));

    $targets = _rainNowcastProto_open_warn_targets($candidateDevices);
    _rainNowcastProto_log($rainDevice, $logLevel,
      "rain_update open targets: "
      . (@$targets ? join(", ", map { $_->{device} // "" } @$targets) : "<none>"));
    if (!@$targets) {
      _rainNowcastProto_log($rainDevice, $logLevel,
        "skip: no open monitored devices");
      return "";
    }
  } elsif ($triggerKind eq "contact_open") {
    my $target = _rainNowcastProto_warn_target_for_device($sourceDevice);
    if (!$target) {
      _rainNowcastProto_log($rainDevice, $logLevel,
        "skip: sourceDevice is not a monitored target");
      return "";
    }
    if (!_rainNowcastProto_is_target_open($target)) {
      _rainNowcastProto_log($rainDevice, $logLevel,
        "skip: sourceDevice is monitored but not currently open");
      return "";
    }
    $targets = [$target];
    _rainNowcastProto_log($rainDevice, $logLevel,
      "contact_open target ok: " . join(", ", map { $_->{device} // "" } @$targets));
  } else {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: unsupported triggerKind=$triggerKind");
    return "";
  }

  my $text = _rainNowcastProto_warn_text($triggerKind, $minutes, $targets);
  if ($text eq "") {
    _rainNowcastProto_log($rainDevice, $logLevel,
      "skip: warning text generation returned empty string");
    return "";
  }

  _rainNowcastProto_log($rainDevice, $logLevel,
    "warn text: $text");

  if ($speakCb && ref($speakCb) eq "CODE") {
    $speakCb->($text);
    _rainNowcastProto_log($rainDevice, $logLevel,
      "speak callback executed");
  }

  return $text;
}

1;
