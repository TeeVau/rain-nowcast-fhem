package main;
use strict;
use warnings;
use JSON::PP qw(decode_json);
use POSIX qw(strftime);

sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

sub _rainNowcastProto_latest_update($)
{
  my ($name) = @_;
  return ReadingsTimestamp($name, "summary_intensity", "");
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

sub _rainNowcastProto_payload($)
{
  my ($name) = @_;
  my $raw = _rainNowcastProto_raw_json($name);
  return undef if !$raw;

  my $jsonText = _rainNowcastProto_extract_json_text($raw);
  return undef if !$jsonText;

  my $payload = eval { decode_json($jsonText) };
  return undef if !$payload || ref($payload) ne "HASH";

  return $payload;
}

sub _rainNowcastProto_slots($)
{
  my ($name) = @_;
  my $payload = _rainNowcastProto_payload($name);
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

sub _rainNowcastProto_first_relevant($$)
{
  my ($name, $threshold) = @_;
  $threshold = 0.1 if !defined $threshold;

  my $slots = _rainNowcastProto_slots($name);
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

sub _rainNowcastProto_warn_targets()
{
  # Customize this list to the roof windows and doors you want to monitor.
  return [
    {
      device  => "DachfensterBad",
      reading => "state",
      open_re => qr/^(open|tilted)$/i,
      label   => "Dachfenster Bad",
    },
    {
      device  => "DachfensterSchlafzimmer",
      reading => "state",
      open_re => qr/^(open|tilted)$/i,
      label   => "Dachfenster Schlafzimmer",
    },
    {
      device  => "Balkontuer",
      reading => "state",
      open_re => qr/^open$/i,
      label   => "Balkontuer",
    },
  ];
}

sub _rainNowcastProto_warn_target_by_device($)
{
  my ($device) = @_;
  return undef if !defined $device || $device eq "";

  my $targets = _rainNowcastProto_warn_targets();
  for my $target (@$targets) {
    next if !$target || ref($target) ne "HASH";
    next if !defined $target->{device};
    return $target if $target->{device} eq $device;
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

sub _rainNowcastProto_open_warn_targets()
{
  my $targets = _rainNowcastProto_warn_targets();
  my @openTargets;

  for my $target (@$targets) {
    push @openTargets, $target if _rainNowcastProto_is_target_open($target);
  }

  return \@openTargets;
}

sub _rainNowcastProto_join_labels($)
{
  my ($targets) = @_;
  return "" if !$targets || ref($targets) ne "ARRAY" || !@$targets;

  my @labels = map { $_->{label} // $_->{device} // "" } @$targets;
  @labels = grep { defined $_ && $_ ne "" } @labels;
  return "" if !@labels;
  return $labels[0] if @labels == 1;
  return join(" und ", @labels) if @labels == 2;

  my $last = pop @labels;
  return join(", ", @labels) . " und " . $last;
}

sub _rainNowcastProto_warn_text($$$)
{
  my ($triggerKind, $minutes, $targets) = @_;
  return "" if !$targets || ref($targets) ne "ARRAY" || !@$targets;

  my $labels = _rainNowcastProto_join_labels($targets);
  return "" if $labels eq "";

  if ($triggerKind eq "rain_update") {
    return "Achtung, es regnet bereits. Offen sind $labels. Bitte schliessen."
      if $minutes <= 0;
    return "Achtung, Regen in $minutes Minuten. Offen sind $labels. Bitte schliessen.";
  }

  if ($triggerKind eq "contact_open") {
    my $label = $targets->[0]{label} // $targets->[0]{device} // "ein Kontakt";
    return "Achtung, $label ist geoeffnet und es regnet bereits."
      if $minutes <= 0;
    return "Achtung, $label ist geoeffnet und Regen ist in $minutes Minuten angesagt.";
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

  return "" if !$triggerKind || !$rainDevice;

  my $minutes = myRainNowcastMinutes($rainDevice, $threshold);
  return "" if !defined $minutes || $minutes < 0 || $minutes > $rainWindowMinutes;

  my $targets;
  if ($triggerKind eq "rain_update") {
    $targets = _rainNowcastProto_open_warn_targets();
    return "" if !@$targets;
  } elsif ($triggerKind eq "contact_open") {
    my $target = _rainNowcastProto_warn_target_by_device($sourceDevice);
    return "" if !$target;
    return "" if !_rainNowcastProto_is_target_open($target);
    $targets = [$target];
  } else {
    return "";
  }

  my $text = _rainNowcastProto_warn_text($triggerKind, $minutes, $targets);
  return "" if $text eq "";

  if ($speakCb && ref($speakCb) eq "CODE") {
    $speakCb->($text);
  }

  return $text;
}

1;
