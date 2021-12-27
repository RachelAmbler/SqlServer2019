[![ci](https://github.com/RachelAmbler/SqlServer2019/actions/workflows/docker-image.yml/badge.svg)](https://github.com/RachelAmbler/SqlServer2019/actions/workflows/docker-image.yml)

# SqlServer2019 Development Docker Containers

## Forward

### What's this all about?

Whilst Microsoft provide a pretty easy method of creating Linux basid containers of Sql Server 2019, they're pretty limited in what they can do (no Polybase, Full text search etc.) and you're pretty much left to your own devices in manageing them.

In addition, standing up multipe instances, checking ports, validating volume persistence can be a bt messy if you're not careful.

Finally, having somewhere you can pass data in, and out, of te container isn't something the standard cpontainer supplies.

### What this provides

The [Dockerfile](https://github.com/RachelAmbler/SqlServer2019/blob/main/DockerFiles/Dockerfile) is used to build a minimal Ubuntu 20.04 image and installs Sql Server, the Sql Server Agent, Full Text Search, Polybase and Hadoop. This image can then be used by the accompying [SqlServer.sh](https://github.com/RachelAmbler/SqlServer2019/blob/main/SqlServer.sh) script to Create or Destroy various 'Instances' (Containers) as you see fit.

## Installing

1. Close this repo onto your local computer into your chosen location (e.g. `/user/rachel/Docker/SqlServer`)
2. Create a local image from the `Dockerfile` (See below)

## Usage

### Creating a raw image

To create the raw image on your local computer run the following:

#### Linux

```sh
sudo ./SqlServer.sh Init
```

#### MacOS

```sh
/SqlServer.sh Init
```

### Creating an Instance (Container)

#### Linux

```sh
sudo ./SqlServer.sh Create [InstanceName] | [InstanceName Port]
```

#### MacOS

```sh
./SqlServer.sh Create [InstanceName] | [InstanceName Port]
```

- If no InstanceName is supplied, then the default name of `MSSQLSERVER` will be used.
- If no port number is supplied, then Port `1433` will be used.
