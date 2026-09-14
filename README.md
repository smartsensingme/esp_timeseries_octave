# ESP time-series client for GNU Octave

Reusable client for esp_timeseries_usb_transport, maintained in its own
repository. Only inst/ is needed at runtime. No motor driver,
PID, application paths, or angle-LUT package is required.

## Installation and first capture

### Installable package (0.2.0)

Download the built `esp_timeseries_octave-0.2.0.tar.gz` archive, then in Octave:

```octave
pkg install -local esp_timeseries_octave-0.2.0.tar.gz
pkg load esp_timeseries_octave
```

Installation is persistent; run `pkg load esp_timeseries_octave` in each new
session instead of manually adding `inst/`. Use `pkg list` to inspect installed
versions, `pkg unload esp_timeseries_octave` to remove it from the session, and
`pkg uninstall esp_timeseries_octave` to remove the installed package.
GNU Octave 8.4 or newer is required. Live USB also requires instrument-control
with `serialport` and `serialportlist`; install that separately. It is a runtime
requirement for USB, not a mandatory package dependency, so offline decoding
and protocol tests remain usable without it. No native compilation is needed.

The package is generated in `dist/` locally and as a GitHub Actions artifact
after tests pass. An Actions artifact is temporary (30 days); extract its outer
ZIP to obtain the installable tar.gz. For permanent distribution, attach the
tested tar.gz to a GitHub Release for the matching version. This workflow does
not create that release automatically; do not assume a release asset exists
until it is published. The source-code ZIP from GitHub is not the tested package.

### Source checkout / submodule

Clone the library using the public URL:

```sh
git clone https://github.com/smartsensingme/esp_timeseries_octave.git
```

In the motor example project, it is a submodule at
`tools/esp_timeseries_octave`; run `git submodule update --init --recursive`
after cloning or updating that project.

Install instrument-control once using Octave's package manager, then:

```octave
addpath("/path/to/esp_timeseries_octave/inst");
esp_ts_load_instrument_control();
ports = esp_ts_ports();
disp(ports);
device = esp_ts_open(ports{1}, 30); % Select the native USB port deliberately.
unwind_protect
  status = esp_ts_status(device);
  % ARM can start an actuator if the firmware application defines that callback.
  esp_ts_arm(device, 500);
  esp_ts_wait_full(device, 2, 120); % poll period and overall wait, seconds
  capture = esp_ts_capture(device, struct("mode", "auto"));
  esp_ts_save("capture.mat", capture);
  esp_ts_clear(device); % Only reached after successful validation and save.
unwind_protect_cleanup
  clear device;
end_unwind_protect
```

For an existing FULL buffer, omit ARM and wait. Opening USB can reset some
boards; re-read status rather than assuming RAM contents survived. The motor
application adds its own boot synchronization and CONTROL STOP on console exit.
Releasing the serial object does not itself command an actuator to stop.

## API

| Function | Behavior |
|---|---|
| esp_ts_open(port, timeout_s=30) | Load instrument-control, open at nominal 115200, configure LF, wait 1 s and discard startup input |
| esp_ts_ports() | Normalize and list serial ports; accepts an optional list for offline normalization |
| esp_ts_command(device_or_port, command, print_response=true) | One text request/response; caller interprets application commands |
| esp_ts_status(device) | Validated recorder state, IDs, rate and sample counts |
| esp_ts_capabilities(device) | Command list obtained from HELP |
| esp_ts_arm(device, rate_hz) | Explicitly arm; firmware validates supported rate |
| esp_ts_wait_full(device, poll_s=2, timeout_s=120, callback=[]) | Wait for FULL; callback receives status; no implicit ARM/CLEAR |
| esp_ts_capture(device_or_port, options=struct()) | Download and validate a FULL capture, without saving, plotting or clearing |
| esp_ts_save(filename, capture) | Save a MAT file; filesystem errors propagate |
| esp_ts_clear(device) | Explicitly release the recorder buffer |
| esp_ts_decode_payload(...) / esp_ts_crc32(bytes) | Endian-independent linear decoding and CRC-32/IEEE |

Keep one device object open for a session. Functions receiving an existing
object do not close it. Functions accepting a port string release their local
object on completion/error. To close a session, release all references to that
object with clear; this is why there is no misleading close-by-value wrapper.

## Capture options and output

- mode: auto (default), binary-framed or block-hex. Auto uses blocks on Windows
  and binary elsewhere. macOS binary and Windows blocks were validated in the
  original application; Linux hardware performance is unverified.
- timeout_s: positive serial timeout, default 30 seconds. Block exchanges use
  bounded retries with a 2-second per-read timeout. Existing device Timeout is
  restored even when capture fails.
- max_payload_bytes: allocation guard, default 16 MiB.
- progress: optional function handle receiving (received_bytes, total_bytes).
  Binary reports completion; blocks report roughly each ten percent.

HELP must advertise the required transfer commands. Firmware using the old
256-byte response buffer with long application extensions may fail HELP;
the accompanying transport update increases that buffer to 512 bytes.
No mode fallback is attempted after partial reception.

The returned structure preserves raw (int16 channels-by-samples), values
(linearly scaled doubles), channels (name/unit/scale/offset/encoding/counters),
time_s, capture_id, rates, start_time_us, header_lines, payload_crc32,
usb_transfer_mode, usb_transfer_seconds and usb_transfer_kib_s.
The invalid int16 sentinel maps to NaN in values; raw remains intact.
Custom encodings remain the application's responsibility. For example, this
library does not decode BTS7960 fault markers or invoke motor graphs.

CRC validation is compulsory. Never CLEAR after an exception. A failed binary
stream may need connection resynchronization before another attempt.
The library does not certify motor safety, stop on cable removal, or change
firmware control-loop timing.

## Development and release

`examples/download_full.m` is a motor-independent example for an already-open
connection and FULL buffer. It saves the validated capture without clearing it
or issuing actuator commands. Add both `inst/` and `examples/` to use it.

Publish this repository's commit before publishing a consuming project's
submodule reference to it. Do not add an ESP-IDF `idf_component.yml` for this
host-only Octave library: it is not a firmware component.

```sh
octave --quiet tests/run_tests.m
```

See VALIDATION.md for the baseline and hardware checklist. The motor project
continues to use its pinned submodule with addpath; package installation is an
alternative for other applications. Avoid loading both copies in one session.

Build and test the distributable from the library root:

```sh
octave --no-gui --quiet --no-init-file --no-site-file scripts/build_package.m
octave --no-gui --quiet --no-init-file --no-site-file tests/test_package.m
```

Version and archive name come from DESCRIPTION. Generated archives are ignored
by Git. The build includes only metadata, license, functions, and documentation.
COPYING is the package-manager copy of LICENSE; keep their contents identical.

### Continuous integration

The `Octave offline tests` GitHub Actions workflow runs on every push and pull
request, and can also be started manually from the repository's Actions tab.
It installs GNU Octave on Ubuntu 24.04 and runs `tests/run_tests.m` without user
startup files. An assertion failure fails the job; stalled tests time out.
Both binary and hexadecimal modes are exercised through `MockSerial`, so no
ESP32, USB connection, credentials, or instrument-control package is needed.
The workflow has read-only repository permission and does not publish releases.
It also builds the archive, installs it into an isolated package registry,
loads it, runs the protocol tests against the installed functions, unloads and
uninstalls it, and uploads the tested archive as the `octave-package` artifact.
The existing v0.1.0 tag is unchanged; packaging starts with version 0.2.0.

Run the same test command locally from the library root:

```sh
octave --no-gui --quiet --no-init-file --no-site-file tests/run_tests.m
```

Inspect results under [Actions](https://github.com/smartsensingme/esp_timeseries_octave/actions).
These Linux-based simulated tests do not validate Windows/macOS USB drivers,
physical Linux USB behavior, throughput, or motor safety. Hardware validation
remains separate. Requiring this check before merging is an optional repository
branch-protection setting; the workflow alone does not enforce it.

## License

MIT; see [LICENSE](LICENSE). This applies to this library, not to external
dependencies such as GNU Octave or instrument-control, which retain their own
licenses.
