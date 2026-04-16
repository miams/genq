# GenQuery Screencast

This directory contains a deterministic `asciinema` v3 demo workflow for `genq`.

## Record a cast

From the repo root:

```bash
./screencast/make-demo-cast.sh
```

This writes:

```text
screencast/genq-demo.cast
```

The recording script:

- uses the bundled `data/pres2025.rmtree` database,
- ignores your global Nushell config,
- creates a temporary `GENQ_HOME`,
- types a short sequence of demo queries automatically.

## Custom output path

```bash
./screencast/make-demo-cast.sh /tmp/genq-demo.cast
```

## Playback

```bash
asciinema play screencast/genq-demo.cast
```

## Optional rendering

`agg` is a separate renderer from the asciinema ecosystem. It can turn a `.cast`
file into a GIF, for example:

```bash
agg screencast/genq-demo.cast screencast/genq-demo.gif
```

`agg` is not required for generating the `.cast` file itself.
