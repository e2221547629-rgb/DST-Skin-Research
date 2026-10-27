name = "DST Skin Probe"
description = "Read-only server diagnostics for normally selected, authorized appearances. No unlocks or skin setters."
author = "DST Skin Research"
version = "0.2.0"
api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
client_only_mod = false
all_clients_require_mod = false
configuration_options = {
    { name = "poll_seconds", label = "Snapshot interval", options = {
        {description = "5 seconds", data = 5},
        {description = "10 seconds", data = 10},
        {description = "30 seconds", data = 30},
    }, default = 10 },
    { name = "trace_methods", label = "Trace completed Skinner methods (experimental)", options = {
        {description = "Off", data = false},
        {description = "On", data = true},
    }, default = false },
}
