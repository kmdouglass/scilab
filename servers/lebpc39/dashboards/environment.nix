{ lib }:

# Lab environment dashboard: temperature and humidity from the Tasmota
# sensors that publish to Mosquitto (mqtt.nix). Built here as a Nix attrset
# and turned into JSON by grafana.nix.
let
  # One entry per sensor. `topic` is the MQTT topic, which Telegraf stores as
  # the `topic` tag; `name` is what the dashboard shows.
  sensors = [
    { topic = "bsp125/tasmota_exterior/SENSOR"; name = "BSP 125 (exterior)"; }
    { topic = "bsp126/tasmota/SENSOR"; name = "BSP 126"; }
  ];

  datasource = { type = "influxdb"; uid = "influxdb"; };

  # Flux expression mapping a row's topic to its sensor name. Topics not
  # listed above keep the topic itself as their name, so a new sensor still
  # shows up before it's added here.
  sensorName = lib.foldr
    (s: rest: ''if r.topic == "${s.topic}" then "${s.name}" else ${rest}'')
    "r.topic"
    sensors;

  # Mean of `field` per sensor over the dashboard's time range, in windows
  # sized to the panel width.
  seriesQuery = field: ''
    from(bucket: "leb_time_series_data")
      |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
      |> filter(fn: (r) => r._measurement == "environmental_sensors" and r._field == "${field}")
      |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
      |> map(fn: (r) => ({r with sensor: ${sensorName}}))
      |> keep(columns: ["_time", "_value", "sensor"])
      |> group(columns: ["sensor"])
  '';

  # Latest value of `field` per sensor. Only the last hour is searched, so a
  # sensor that has stopped reporting disappears instead of showing a stale
  # reading.
  latestQuery = field: ''
    from(bucket: "leb_time_series_data")
      |> range(start: -1h)
      |> filter(fn: (r) => r._measurement == "environmental_sensors" and r._field == "${field}")
      |> last()
      |> map(fn: (r) => ({r with sensor: ${sensorName}}))
      |> keep(columns: ["_time", "_value", "sensor"])
      |> group(columns: ["sensor"])
  '';

  stat = { id, title, field, unit, gridPos }: {
    inherit id title gridPos datasource;
    type = "stat";
    targets = [{ refId = "A"; inherit datasource; query = latestQuery field; }];
    fieldConfig = {
      defaults = {
        inherit unit;
        decimals = 1;
        displayName = "\${__field.labels.sensor}";
        color = { mode = "fixed"; fixedColor = "text"; };
      };
      overrides = [ ];
    };
    options = {
      reduceOptions = { calcs = [ "lastNotNull" ]; fields = ""; values = false; };
      colorMode = "value";
      graphMode = "none";
      textMode = "value_and_name";
      orientation = "auto";
      justifyMode = "auto";
    };
  };

  timeSeries = { id, title, field, unit, gridPos }: {
    inherit id title gridPos datasource;
    type = "timeseries";
    targets = [{ refId = "A"; inherit datasource; query = seriesQuery field; }];
    fieldConfig = {
      defaults = {
        inherit unit;
        decimals = 1;
        displayName = "\${__field.labels.sensor}";
      };
      overrides = [ ];
    };
    options = {
      legend = { displayMode = "list"; placement = "bottom"; showLegend = true; };
      tooltip = { mode = "multi"; sort = "none"; };
    };
  };
in
{
  uid = "lab-environment";
  title = "Lab environment";
  tags = [ "environment" ];
  timezone = "browser";
  editable = false;
  refresh = "1m";
  time = { from = "now-24h"; to = "now"; };
  schemaVersion = 39;

  panels = [
    (stat {
      id = 3;
      title = "Temperature now";
      field = "SI7021_Temperature";
      unit = "celsius";
      gridPos = { x = 0; y = 0; w = 12; h = 4; };
    })
    (stat {
      id = 4;
      title = "Humidity now";
      field = "SI7021_Humidity";
      unit = "humidity";
      gridPos = { x = 12; y = 0; w = 12; h = 4; };
    })
    (timeSeries {
      id = 1;
      title = "Temperature";
      field = "SI7021_Temperature";
      unit = "celsius";
      gridPos = { x = 0; y = 4; w = 24; h = 9; };
    })
    (timeSeries {
      id = 2;
      title = "Humidity";
      field = "SI7021_Humidity";
      unit = "humidity";
      gridPos = { x = 0; y = 13; w = 24; h = 9; };
    })
  ];
}
