% Build only distributable files; never include .git or user captures.
root = fileparts (fileparts (mfilename ("fullpath")));
assert (strcmp (fileread (fullfile (root, "LICENSE")), ...
                fileread (fullfile (root, "COPYING"))), ...
        "COPYING must match LICENSE");
description = fileread (fullfile (root, "DESCRIPTION"));
token = regexp (description, "(?m)^Version: ([0-9]+\\.[0-9]+\\.[0-9]+)$", "tokens", "once");
assert (! isempty (token), "Missing semantic version in DESCRIPTION");
package_name = ["esp_timeseries_octave-", token{1}];
stage = tempname ();
mkdir (stage);
output_dir = fullfile (root, "dist");
if (! exist (output_dir, "dir")), mkdir (output_dir); endif
unwind_protect
  target = fullfile (stage, package_name);
  mkdir (target);
  for name = {"DESCRIPTION", "INDEX", "COPYING", "inst"}
    [ok, message] = copyfile (fullfile (root, name{1}), target);
    assert (ok, message);
  endfor
  mkdir (fullfile (target, "doc"));
  for name = {"README.md", "VALIDATION.md", "examples"}
    [ok, message] = copyfile (fullfile (root, name{1}), fullfile (target, "doc"));
    assert (ok, message);
  endfor
  archive = fullfile (output_dir, [package_name, ".tar.gz"]);
  tar (archive, {package_name}, stage);
  fprintf ("Built %s\n", archive);
unwind_protect_cleanup
  % Only remove the temporary directory created by this invocation.
  rmdir (stage, "s");
end_unwind_protect
