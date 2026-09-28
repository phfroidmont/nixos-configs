---
name: herdr-processes
description: >-
  Start, inspect, restart, and stop long-running development processes (dev
  servers, watchers, databases) in tabs of the current Herdr workspace. Use when
  HERDR_ENV=1 and a task needs a process that keeps running, its logs, or a
  restart.
---

# Herdr processes

Long-running processes live in tabs of the current Herdr workspace so the user
can see them. Manage them with `herdr-proc`; never start them as background
bash jobs (`&`, `nohup`, `setsid`).

## Commands

```sh
herdr-proc list                                   # every pane: id, tab, state, foreground argv
herdr-proc start <name> [--cwd PATH] -- <cmd...>  # creates tab <name> and runs <cmd>
herdr-proc logs <target> [--lines N]              # recent output (default 200, max 1000)
herdr-proc stop <target>                          # Ctrl-C, keeps the tab
herdr-proc restart <target> [-- <cmd...>]         # stop, then rerun the recorded or given cmd
herdr-proc close <target>                         # stop, then close the pane (and its tab if last)
```

`<target>` is a tab label or a pane id from `herdr-proc list`. Use a pane id
when a tab has several panes.

Commands: several arguments are quoted as an argv (`-- npm run dev`); a single
argument is a raw shell line (`'PORT=4000 npm run dev | tee dev.log'`).

## Workflow

- Run `herdr-proc list` first: the user may already run the process in some tab.
  Reuse it instead of starting a duplicate. `start` refuses existing tab labels.
- Name tabs after the process role (`web`, `api`, `db`, `worker`).
- After `start` or `restart`, check `herdr-proc logs` for readiness or errors
  before depending on the process.
- Restart after changes the process does not hot-reload (config, dependencies,
  env files).
- `restart` without a command only works for commands started through
  `herdr-proc`. For a process the user launched, pass the command explicitly,
  inferred from the argv in `list` or asked from the user when unclear.
- Panes shown as `protected` run an agent or are your own pane; the script
  refuses to stop them. Do not work around it.
- Do not close tabs the user created unless asked; `stop` is enough.
