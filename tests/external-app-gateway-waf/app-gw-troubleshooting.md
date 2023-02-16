# Troubleshooting Application Gateway Errors

Application Gateway with TFE errors can be hard to troubleshooting. Here are some lessons learned.

## ERR_SSL_UNRECOGNIZED_NAME_ALERT When browsing to the App GW  Address

- Ensure the PFX certificate uploaded to the HTTPS listener is the full chain certificate, if included.
- Ensure proper communication between the App GW listener and Key Vault if cert is pulled from key vault
- Add the load balancer subnet where the application gateway sits to the ACL for the key vault
- Add the service delegation Microsoft.Keyvault to the load balancer subnet where the Application Gateway resides
- If cert is stored in and pulled from key vault, upload it to the listener manually and check connection again. This will tell you if you have a networking misconfiguration with Key Vault

## The Common Name (CN) of the backend server certificate does not match the host header entered in the health probe configuration (v2 SKU) or the FQDN in the backend pool (v1 SKU). Verify if the hostname matches with the CN of the backend server certificate. To learn more visit - <https://aka.ms/backendcertcnmismatch>

- Change probe hostname to the hostname of the tfe server on the backend

## The root certificate of the server certificate used by the backend does not match the trusted root certificate added to the application gateway. Ensure that you add the correct root certificate to whitelist the backend

- Check to see if the TFE server is serving up the full chain cert which includes the CA root cert.
  - Log into the TFE server and run the command below

```bash
OpenSSL> s_client -connect 10.0.0.4:443 -servername tfe.example.com -showcerts
```

- If you don’t see the full chain, or at least the server + root certificates, then you did not upload the correct certificate and thus TFE is not returning all the proper certificates to be trusted by the application gateway
- <https://learn.microsoft.com/en-us/azure/application-gateway/application-gateway-backend-health-troubleshooting#trusted-root-certificate-mismatch>

## Too many redirects to port 443

- Turn `hairpin_addressing` off

## 403  Forbidden

- Turn the WAF off and see if it works
- If it does, find the WAF rule blocking access and fix or remove it

## I can connect a VCS, see repos when creating workspaces, but it won’t finish creating the configuration version or parse my variables

- Workspaces and publishing modules gives SIW-001 error
- This means that, for some reason, you cannot access the Storage Account for the TFE backend.

## Plan fails to Run

```bash
Initializing Terraform Cloud...
╷
│ Error: Failed to request discovery document: Get "https://josh2.is.tfe.rocks/.well-known/terraform.json": context deadline exceeded
│ 
│   on zzz_cloud_override.tf.json line 4, in terraform[0].cloud[0]:
│    4:    "hostname": "josh2.is.tfe.rocks",
```

- Try and run this from inside the tfe server
sudo docker run --rm -it hashicorp/build-worker:now /bin/bash -c "curl <https://josh2.is.tfe.rocks>"
- If there is a NAT GW on the VM subnet, allow its IP inbound on the App GW subnet. Because we do not have `hairpin_addressing` set like we would normally for a L4 load balancer, the worker container is trying to resolve the hostname/FQDN of the TFE app externally. `hairpin_addressing` is off with the app gw because it causes “too many redirects” on port 443 with the app gw configured. So traffic goes TFE VM worker container → NAT → APP GW → TFE VM

## Plans and Applies Fail

- Check the App GW WAF logs for any rules being violated <https://learn.microsoft.com/en-us/azure/application-gateway/log-analytics>
