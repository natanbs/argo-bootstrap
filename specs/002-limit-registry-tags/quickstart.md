# Quickstart: Limit Registry Tags Display

## What Changes

The `reg.sh` script gains tag limiting and a `--all` flag.

## Before

```bash
./reg.sh          # Shows ALL tags for every image
```

## After

```bash
./reg.sh          # Shows at most 3 tags per image (default)
./reg.sh -a       # Shows all tags (short flag)
./reg.sh --all    # Shows all tags (long flag)
```

## Implementation Steps

1. Add flag parsing at the top of `reg.sh` using a `case` statement
2. Set `SHOW_ALL` variable based on `-a` / `--all`
3. Validate: if `$1` starts with `-` and isn't `-a`/`--all`, print usage to stderr and exit 1
4. In the tag pipeline, conditionally add `tail -n 3` after `sort` when `SHOW_ALL` is not true
5. Test with a running registry that has images with varying tag counts

## Testing

1. Start a local registry (or use existing at `localhost:50000`)
2. Push images with 1, 2, 3, and 5+ tags
3. Run `./reg.sh` — verify each image shows ≤3 tags
4. Run `./reg.sh -a` — verify all tags shown
5. Run `./reg.sh --all` — verify all tags shown
6. Run `./reg.sh -x` — verify usage hint on stderr, exit code ≠ 0
7. Run `./reg.sh` with no args — verify default behavior unchanged
