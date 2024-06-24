# nbx

This script provides a command-line interface for interacting with a NetBox
instance. It supports a range of operations to list, filter, and manipulate
NetBox data through both [REST](https://demo.netbox.dev/static/docs/rest-api/overview/)
and [GraphQL](https://demo.netbox.dev/static/docs/graphql-api/overview/) APIs.

## 📋 Table of Contents

- [📦 Installation](#installation)
- [⚙️ Configuration](#configuration)
- [🚀 Usage](#usage)
  - [Global Options](#global-options)
  - [List Actions](#list-actions)
  - [Meta Actions](#meta-actions)
  - [Workflows](#workflows)
  - [Raw Commands](#raw-commands)
- [🔍 Examples](#examples)
  - [List Devices](#list-devices)
  - [Assign Devices to a Cluster](#assign-devices-to-a-cluster)
  - [GraphQL Query](#graphql-query)
  - [More Examples](#more-examples)
- [📜 License](#license)

## 📦 Installation

Requirements:

- awk (GNU, gawk)
- bash
- curl
- jq

Clone the repository and make the script executable:

```bash
git clone https://github.com/pschmitt/nbx.git
cd nbx
chmod +x nbx.sh
```

## ⚙️ Configuration

The script uses environment variables to configure its behavior:

- `NETBOX_URL`: The base URL for your NetBox instance. Default is `https://demo.netbox.dev`.
- `NETBOX_API_TOKEN`: Your [API token](https://demo.netbox.dev/static/docs/rest-api/authentication/) for authentication.
- Additional environment variables can be set to customize the script's behavior (e.g., `COMPACT`, `CONFIRM`, `DRY_RUN`).

## 🚀 Usage

Run the script with the desired options and actions:

```bash
nbx [options] ACTION [ARGS]
```

### Global Options

| Option              | Description                                                            |
| ------------------- | ---------------------------------------------------------------------- |
| `-a, --api TOKEN`   | NetBox API Token (default: `$NETBOX_API_TOKEN`).                       |
| `-u, --url URL`     | NetBox URL (default: `$NETBOX_URL`).                                   |
| `-g, --graphql`     | Use GraphQL API instead of REST API (list actions only).               |
| `-D, --debug`       | Enable debug output.                                                   |
| `-P, --pedantic`    | Enable pedantic mode (exit on any error).                              |
| `-W, --no-warnings` | Disable warnings.                                                      |
| `-k, --dry-run`     | Dry-run mode.                                                          |
| `--confirm`         | Confirm before executing actions.                                      |
| `--no-confirm`      | Do not confirm before executing actions.                               |
| `-o, --output TYPE` | Output format: pretty (default), json.                                 |
| `-j, --json`        | Output format: json.                                                   |
| `-N, --no-header`   | Do not print header.                                                   |
| `-c, --no-color`    | Disable color output.                                                  |
| `--compact`         | Truncate long fields.                                                  |
| `--header`          | Keep header when piping output (default: remove).                      |
| `-I, --with-id`     | Include ID column.                                                     |
| `-C, --comments`    | Include comments column (shorthand for `--columns +comments`).         |
| `--columns COLUMNS` | List of columns to display (prefix with '+' to append, '-' to remove). |
| `-s, --sort FIELD`  | Sort by field/column (prefix with '-' to sort in reverse order).       |

### List Actions

| Action                       | Description            |
| ---------------------------- | ---------------------- |
| `aggregates [FILTERS]`       | List aggregates.       |
| `cables [FILTERS]`           | List cables.           |
| `circuits [FILTERS]`         | List circuits.         |
| `clusters [FILTERS]`         | List clusters.         |
| `config-contexts [FILTERS]`  | List config contexts.  |
| `contacts [FILTERS]`         | List contacts.         |
| `devices [FILTERS]`          | List devices.          |
| `interfaces [FILTERS]`       | List interfaces.       |
| `ip-addresses [FILTERS]`     | List IP addresses.     |
| `locations [FILTERS]`        | List locations.        |
| `manufacturers [FILTERS]`    | List manufacturers.    |
| `platforms [FILTERS]`        | List platforms.        |
| `prefixes [FILTERS]`         | List prefixes.         |
| `providers [FILTERS]`        | List providers.        |
| `racks [FILTERS]`            | List racks.            |
| `regions [FILTERS]`          | List regions.          |
| `services [FILTERS]`         | List services.         |
| `sites [FILTERS]`            | List sites.            |
| `tags [FILTERS]`             | List tags.             |
| `tenants [FILTERS]`          | List tenants.          |
| `virtual-chassis [FILTERS]`  | List virtual chassis.  |
| `virtual-machines [FILTERS]` | List virtual machines. |
| `vlans [FILTERS]`            | List VLANs.            |
| `vrfs [FILTERS]`             | List VRFs.             |
| `wireless-lans [FILTERS]`    | List wireless LANs.    |

### Meta Actions

| Action                                                | Description                                |
| ----------------------------------------------------- | ------------------------------------------ |
| `cols OBJECT_TYPE`                                    | List available columns for an object type. |
| `introspect (--types,--query,--fields) [OBJECT_TYPE]` | Introspect GraphQL API.                    |

### Workflows

| Action                                | Description                  |
| ------------------------------------- | ---------------------------- |
| `assign-to-cluster CLUSTER [FILTERS]` | Assign devices to a cluster. |

### Raw Commands

| Action                           | Description                             |
| -------------------------------- | --------------------------------------- |
| `graphql [--raw] QUERY [FIELDS]` | GraphQL query.                          |
| `raw ENDPOINT`                   | Fetch raw data from an endpoint (REST). |

## 🔍 Examples

### List Devices

To list all devices, sorted by name, with a pretty output format:

```bash
nbx devices
```

### Assign Devices to a Cluster

To assign devices matching certain criteria to a specific cluster:

```bash
nbx assign-to-cluster CLUSTER_NAME "role=server" "site=NYC"
```

### GraphQL Query

To run a GraphQL query against the NetBox API:

```bash
nbx graphql --raw '{ list_devices { id name } }'
```

### More examples

Check out the [examples](./examples) directory for more examples.

## 📜 License

This project is licensed under the GPL-3.0 License.
See the [LICENSE](LICENSE) file for more details.
