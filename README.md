# nbx

This is a simple API wrapper for the [Netbox API](https://demo.netbox.dev/static/docs/rest-api/overview/).

## Requirements

- bash
- curl
- jq

## Usage

```shell
export NETBOX_URL=https://demo.netbox.dev
export NETBOX_API_TOKEN=0123456789abcdef0123456789abcdef01234567

./nbx.sh dcim/sites
```
