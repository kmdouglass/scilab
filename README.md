# scilab
Self-hosted services for a science lab

## Deployments

To deploy a configuration onto a server, first create a secrets file in `.private/<SERVER_NAME>.secrets`. Then run:

```console
./scripts/deploy_<SERVER_NAME>.sh
```

### Local files

An untracked file called `network-local.nix` is expected next to each configuration.nix file.

```
{
  address = "w.w.w.w";
  prefixLength = 24;
  gateway = "x.x.x.x";
  nameservers = [ "y.y.y.y" "z.z.z.z" ];
}
```
