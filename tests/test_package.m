% Run in a fresh Octave process. Keep the user's package registry untouched.
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
[original_prefix, original_archprefix] = pkg ("prefix");
original_local_list = pkg ("local_list");
original_global_list = pkg ("global_list");
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
  disp ("Package install/load/tests/unload/uninstall passed");
unwind_protect_cleanup
  path (original_path);
  pkg ("prefix", original_prefix, original_archprefix);
  pkg ("local_list", original_local_list);
  pkg ("global_list", original_global_list);
  rmdir (sandbox, "s");
end_unwind_protect
