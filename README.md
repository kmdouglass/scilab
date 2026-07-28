# scilab
Self-hosted services for a science lab

## Deployments

### Out-of-band files

These files must be deployed out-of-band to the target machine:

- `/etc/mosquitto/secrets/laboleb.password` - The password for the laboleb mosquitto user
- `/etc/influxdb2/secrets/laboleb.password` - The password for the laboleb InfluxDB2 user (must be owned by the `influxdb2:influxdb2` Linux user:group)
- `/etc/influxdb2/secrets/laboleb.token` - API token generated with the command `openssl rand -hex 32`
- `/etc/telegraf/secrets.env` - Credentials Telegraf uses to connect to the local Mosquitto broker as the laboleb user, and to authenticate to InfluxDB2:

  ```
  MQTT_USERNAME=laboleb
  MQTT_PASSWORD=<same password as /etc/mosquitto/secrets/laboleb.password>
  INFLUX_TOKEN=<same token as /etc/influxdb2/secrets/laboleb.token>
  ```

### Private flake input

Nix flakes only see files tracked by Git, so anything with real
host-specific values (currently just network settings) lives outside this
repo, in its own private, local-only git repository, and is pulled in as a
flake input named `scilab-private`.

On whichever machine you run the deploy command from, set it up once:

```console
mkdir -p ~/src/scilab-private/servers/<SERVER_NAME>
cd ~/src/scilab-private
git init
cat > servers/<SERVER_NAME>/network-local.nix <<'EOF'
{
  address = "w.w.w.w";
  prefixLength = 24;
  gateway = "x.x.x.x";
  nameservers = [ "y.y.y.y" "z.z.z.z" ];
}
EOF
git add servers/<SERVER_NAME>/network-local.nix
git commit -m "Add <SERVER_NAME> network settings"
```

`flake.nix` points at `git+file:///home/kmd/src/scilab-private` by default. If
you're deploying from a different machine or user, override it:

```console
nix run nixpkgs#nixos-rebuild -- switch --flake .#<SERVER_NAME> \
  --override-input scilab-private git+file:///path/to/your/scilab-private \
  --target-host root@<SERVER_NAME>
```

Whenever you edit a file under `scilab-private`, commit it there before
deploying (Nix reads the latest committed revision of that repo).

### hardware-configuration.nix

Each server's `hardware-configuration.nix` is generated on that machine by
`nixos-generate-config` and committed as-is into this repo (unlike
`network-local.nix`, it holds no sensitive values — just filesystem labels
and detected kernel modules — and the flake needs it to evaluate at all). If
a server's hardware changes (disk swapped, NIC added, etc.), regenerate it
there and copy the updated file back into this repo.

Then commit the update. Deploying without doing this risks the config
referencing stale device labels.

### Deployment command

Then apply the configuration:

```console
nix run nixpkgs#nixos-rebuild -- switch --flake .#<SERVER_NAME> \
  --target-host <USER>@<SERVER_NAME> --build-host <USER>@<SERVER_NAME> --ask-sudo-password
```
