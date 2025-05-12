# speedtest

At the moment `speedtest` is based on the https://wifiman.com/ and the assignment sent by email.

# Used code/modules
Since there is no ICMP ping in Swift, I used this project https://github.com/robertmryan/SimplePing which is just simple wrapper on public Apple sample PING.

# Workflow
Deployment target is set to iOS 15.4 and Xcode 16.3 was used for the development.
It contains documentation in the code only and some errors are shown on the display.
For better usability there is one additional feature silently using GPS coordinates of network provider when phone coordinates are not available.

# Out of Scope
The project does not contain UPLOAD test because it is not part of assignment.
The UI is very simple just for demonstration purposes.
Project was not published to AppStore review, but I think it should be OK after adding some graphics.

# Testing results
Project was tested on iOS 15,16,18 and few internet providers including 5G cellular network.