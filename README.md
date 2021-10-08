# bgpdebug
Bash script that automates all debug steps from sk101399 for debugging BGP and the RouteD daemon of Check Point Security Gateways.

All output and logfiles are put together in a single directory for further investigation (by TAC). Security Gateways in VSX Mode and Security Gateways in Gateway Mode are both supported.

Version History  
0.1    Initial version. Only Security Gateways in VSX are supported.  
0.2    Security Gateway in Gateway Mode is now supported.  
       Added new menu options: - Show debug status  
                               - Switch to other Virtual System (VSX only)  
                               - Quit the script  
0.2.1  FIX: Option 6 now only works in VSX mode.  
       Minor quality updates  

This project is licensed under the terms of the MIT license.
