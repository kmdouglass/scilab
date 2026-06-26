# scilab
Self-hosted services for a science lab

## Deployments

To deploy a configuration onto a server, first create a secrets file in `.private/<SERVER_NAME>.secrets`. Then run:

```console
./scripts/deploy_<SERVER_NAME>.sh
```

### Required secrets per host

`.private/` is gitignored, so these keys aren't recoverable from git history if lost. Each file holds `KEY=value` lines sourced by the matching deploy script.

- `lebpc39.secrets`:
  - `IP_ADDRESS` - static IP for the `enp0s25` interface
  - `DEFAULT_GATEWAY`
  - `NAMESERVER_1`
  - `NAMESERVER_2`
  - `MQTT_PASSWORD` - password for the mosquitto user (see `configs/mosquitto.nix.lebpc39`)
