function esp_ts_load_instrument_control ()
  % Load instrument-control and require serialport and serialportlist support.
  % Raise an actionable error when the package or serial API is unavailable.
  try
    pkg load instrument-control;
  catch
    error (["The Octave instrument-control package is required. ", ...
            "Install it with: pkg install -forge instrument-control"]);
  end_try_catch
  if (exist ("serialport", "file") == 0 || ...
      exist ("serialportlist", "file") == 0)
    error ("instrument-control does not provide the serialport API");
  endif
endfunction
