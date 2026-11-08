# OSDCloud Demo

Keep this foundation small. Settings live at the top of OSDCloudModules/Module.psm1. Documentation is Danish; conversation follows the user's language.

Read README.md and STATUS.md before changes. Startup is automatic with no initial DEMO confirmation; keep the VM and blank-disk guards. The agreed demo is Windows 11 25H2 x64 Danish, online Graph registration with the Group Tag entered by the technician at Windows OOBE, verification, exact allowlisted app removal, then restart to OOBE. Do not add JSON registration, autologon, tenant secrets, unrelated helpers, frameworks or generated configuration layers.

This public repository contains demo code only. Never commit hashes, tenant credentials, device identities or logs. Do not execute installation, app removal or registration as a host-side test. Keep unrun Windows/Hyper-V/tenant checks explicit. Follow /home/ax/dev/AGENTS.md when available; keep this repository the authoritative home of demo code.
