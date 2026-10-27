Mounts a samba share through SSH. SSH is forwarded through ngrok using an ngrok API key to automatically fetch the URL. Essentially, this is only useful if you're running an SMB share and you don't have port forwarding. Being a college student, this got me through 2 years of server hosting until I got my own internet.

The ngrok API key must be stored in a bare .txt file (ngrok_key.txt) in the user's home directory. It would be advisable to store this key with restrictive permissions (e.g. chmod 440 ngrok_key.txt).

The local IP of the server must be directly edited in the source code, unless the server is also 192.168.1.45.
