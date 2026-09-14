% Run only in a dedicated fresh Octave process, not an interactive session.
% Do not restore pkg settings: older Octave versions may create the default
% registry file when setting local_list, failing if its directory is absent.
library_root = fileparts (fileparts (mfilename ("fullpath")));
token = regexp (fileread (fullfile (library_root, "DESCRIPTION")), ...
                "(?m)^Version: ([0-9]+\\.[0-9]+\\.[0-9]+)$", "tokens", "once");
archive = fullfile (library_root, "dist", ...
                    ["esp_timeseries_octave-", token{1}, ".tar.gz"]);
assert (exist (archive, "file") == 2, "Build the package first");
sandbox = tempname ();
mkdir (sandbox);
sandbox = canonicalize_file_name (sandbox);
original_path = path ();
unwind_protect
  pkg ("prefix", fullfile (sandbox, "packages"), fullfile (sandbox, "arch"));
  pkg ("local_list", fullfile (sandbox, "local_list"));
  pkg ("global_list", fullfile (sandbox, "global_list"));
  assert (isempty (which ("esp_ts_capture")), "Use a fresh process without inst/ on path");
  pkg ("install", "-local", archive);
  pkg ("load", "esp_timeseries_octave");
  installed_path = which ("esp_ts_capture");
  assert (strncmp (installed_path, sandbox, length (sandbox)));

  % Exercise the installed code, not the source checkout's inst/ directory.
  test_installed = true;
  run (fullfile (library_root, "tests", "run_tests.m"));
  assert (strcmp (which ("esp_ts_capture"), installed_path));
  pkg ("unload", "esp_timeseries_octave");
  assert (isempty (which ("esp_ts_capture")));
  pkg ("uninstall", "-local", "esp_timeseries_octave");
  assert (isempty (pkg ("list")));
unwind_protect_cleanup
  path (original_path);
  % Settings remain process-local and the command-line process exits here.
  % Do not touch the real package registries to restore unused settings.
  rmdir (sandbox, "s");
end_unwind_protect
disp ("Package install/load/tests/unload/uninstall and cleanup passed");
