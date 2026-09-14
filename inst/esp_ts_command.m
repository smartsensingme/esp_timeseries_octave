function response = esp_ts_command (endpoint, command, print_response)
  % Send one LF-terminated text command and return its trimmed response line.
  % endpoint is an open serial object or a port name; print_response defaults
  % to true. A caller-owned connection is never closed by this function.
  % Application commands and error responses are interpreted by the caller.
  if (nargin < 2 || nargin > 3)
    print_usage ();
  endif
  if (nargin < 3)
    print_response = true;
  endif

  owns_device = ischar (endpoint);
  if (owns_device)
    device = esp_ts_open (endpoint, 10);
  else
    device = endpoint;
  endif
  unwind_protect
    write (device, uint8 ([char(command), char(10)]), "uint8");
    response = strtrim (char (readline (device)));
    if (print_response)
      fprintf ("%s\n", response);
    endif
  unwind_protect_cleanup
    if (owns_device)
      clear device;
    endif
  end_unwind_protect
endfunction
